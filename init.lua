-- LandClaim - Copyright (c) 2026 Damie310
-- Licensed under the MIT License. See LICENSE.

local MODNAME = minetest.get_current_modname()
local STORAGE = minetest.get_mod_storage()
local MAX_CLAIMS_PER_PLAYER = tonumber(minetest.settings:get("landclaim_max_claims")) or 10
local MIN_CLAIM_SIZE = tonumber(minetest.settings:get("landclaim_min_size")) or 5
local MAX_CLAIM_SIZE = tonumber(minetest.settings:get("landclaim_max_size")) or 128
local WORLD_MIN = tonumber(minetest.settings:get("landclaim_world_min")) or -31000
local WORLD_MAX = tonumber(minetest.settings:get("landclaim_world_max")) or 31000
local claims = {}
local selections = {}
local next_id = 1
local admin_bypass = {}

local function notify(name, msg)
  minetest.chat_send_player(name, minetest.colorize("#8fd3ff", "[LandClaim] ") .. msg)
end

local function save()
  STORAGE:set_string("claims", minetest.serialize(claims))
  STORAGE:set_int("next_id", next_id)
end

local saved = minetest.deserialize(STORAGE:get_string("claims"))
if type(saved) == "table" then claims = saved end
next_id = math.max(1, STORAGE:get_int("next_id"))
for _, c in pairs(claims) do
  if type(c) == "table" and tonumber(c.id) then next_id = math.max(next_id, c.id + 1) end
end

local function player_claim_count(name)
  local n = 0
  for _, c in pairs(claims) do if c.owner == name then n = n + 1 end end
  return n
end

local function get_claim(pos)
  for _, c in pairs(claims) do
    if pos.x >= c.x1 and pos.x <= c.x2 and pos.z >= c.z1 and pos.z <= c.z2
      and pos.y >= c.y1 and pos.y <= c.y2 then return c end
  end
end

local function can_build(c, name)
  if not c then return true end
  if name == c.owner or admin_bypass[name] or minetest.check_player_privs(name, {protection_bypass = true}) then return true end
  for _, friend in ipairs(c.friends or {}) do if friend == name then return true end end
  return false
end

local function is_claim_protected(pos, name)
  local c = get_claim(pos)
  return c ~= nil and not can_build(c, name)
end

local old_is_protected = minetest.is_protected
function minetest.is_protected(pos, name)
  if is_claim_protected(pos, name or "") then return true end
  return old_is_protected(pos, name)
end

minetest.register_on_protection_violation(function(pos, name)
  local c = get_claim(pos)
  if c and not can_build(c, name) then
    notify(name, "This land is claimed by " .. c.owner .. ". Ask them to add you as a friend.")
  end
end)

-- Protect entities from player punches. In claims, non-trusted players cannot
-- damage any registered entity. Outside claims, protect tamed/owned pets globally.
local function entity_owner(luaentity)
  if not luaentity then return nil end
  local fields = {"owner", "owner_name", "tamed_by", "_owner", "ownername", "playername"}
  for _, field in ipairs(fields) do
    local value = luaentity[field]
    if type(value) == "string" and value ~= "" then return value end
  end
  -- Common conventions used by several Luanti mob frameworks.
  if luaentity.tamed == true or luaentity.is_tamed == true then
    return luaentity.owner or luaentity.owner_name or luaentity.tamed_by or "__tamed_pet__"
  end
  return nil
end

local function wrap_entity_punch(def)
  if type(def) ~= "table" or def._landclaim_punch_wrapped or type(def.on_punch) ~= "function" then return end
  local original = def.on_punch
  def.on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
    if puncher and puncher:is_player() then
      local pos = self.object and self.object:get_pos()
      if pos then
        local claim = get_claim(pos)
        local player_name = puncher:get_player_name()
        if claim and not can_build(claim, player_name) then
          notify(player_name, "You cannot hurt animals or creatures in a claim unless you are trusted there.")
          return
        end
      end
      -- Owned or explicitly tamed entities are treated as pets everywhere.
      -- This blocks player punches regardless of location or who owns the pet.
      if entity_owner(self) then
        notify(puncher:get_player_name(), "Pets are protected from player damage everywhere in this world.")
        return
      end
    end
    return original(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
  end
  def._landclaim_punch_wrapped = true
end

minetest.register_on_mods_loaded(function()
  for _, def in pairs(minetest.registered_entities) do wrap_entity_punch(def) end
end)

local function claim_summary(c)
  return "Claim #" .. c.id .. " owned by " .. c.owner .. " (" .. (c.x2-c.x1+1) .. " x " .. (c.z2-c.z1+1) .. ")"
end

local function set_corner(name, pos)
  local s = selections[name] or {}
  if not s.p1 then
    s.p1 = {x=pos.x, y=pos.y, z=pos.z}
    selections[name] = s
    notify(name, "First corner set at " .. minetest.pos_to_string(pos) .. ". Right-click the opposite corner with the claim shovel.")
    return
  end
  local p1 = s.p1
  local x1, x2 = math.min(p1.x, pos.x), math.max(p1.x, pos.x)
  local z1, z2 = math.min(p1.z, pos.z), math.max(p1.z, pos.z)
  local width, depth = x2-x1+1, z2-z1+1
  if width < MIN_CLAIM_SIZE or depth < MIN_CLAIM_SIZE then
    notify(name, "Claim is too small. Each side must be at least " .. MIN_CLAIM_SIZE .. " blocks. Try the second corner again.")
    return
  end
  if width > MAX_CLAIM_SIZE or depth > MAX_CLAIM_SIZE then
    notify(name, "Claim is too large. Each side can be at most " .. MAX_CLAIM_SIZE .. " blocks.")
    return
  end
  if player_claim_count(name) >= MAX_CLAIMS_PER_PLAYER then
    notify(name, "You have reached the limit of " .. MAX_CLAIMS_PER_PLAYER .. " claims.")
    selections[name] = nil
    return
  end
  -- Claims span the configured vertical world range, like a 2D Minecraft claim.
  local candidate = {x1=x1, x2=x2, z1=z1, z2=z2, y1=WORLD_MIN, y2=WORLD_MAX}
  for _, c in pairs(claims) do
    local overlaps = candidate.x1 <= c.x2 and candidate.x2 >= c.x1
      and candidate.z1 <= c.z2 and candidate.z2 >= c.z1
    if overlaps then
      notify(name, "That area overlaps claim #" .. c.id .. " owned by " .. c.owner .. ". Choose another area.")
      return
    end
  end
  candidate.id, candidate.owner, candidate.friends = next_id, name, {}
  claims[tostring(next_id)] = candidate
  next_id = next_id + 1
  selections[name] = nil
  save()
  notify(name, "Land claimed! " .. claim_summary(candidate) .. ". Use /claim add <player> to trust a friend.")
end

local function is_claim_shovel(stack)
  local name = stack:get_name()
  return name == MODNAME .. ":golden_shovel" or name == "mcl_tools:shovel_gold"
    or name == "mcl_tools:shovel_golden"
end

minetest.register_tool(MODNAME .. ":golden_shovel", {
  description = "Golden Claim Shovel",
  inventory_image = "landclaim_golden_shovel.png",
  wield_image = "landclaim_golden_shovel.png",
  tool_capabilities = {full_punch_interval = 1.2, max_drop_level = 0, groupcaps = {}, damage_groups = {fleshy = 1}},
  on_place = function(stack, user, pointed)
    if not user or not user:is_player() then return stack end
    local name = user:get_player_name()
    if pointed and pointed.type == "node" and pointed.under then
      set_corner(name, pointed.under)
    else
      selections[name] = nil
      notify(name, "Selection cleared. Right-click two blocks with the shovel to choose claim corners.")
    end
    return stack
  end,
  on_secondary_use = function(stack, user)
    if user and user:is_player() then
      selections[user:get_player_name()] = nil
      notify(user:get_player_name(), "Selection cleared. Right-click two blocks with the shovel to choose claim corners.")
    end
    return stack
  end,
})

-- The claim shovel is granted with /claimshovel. No game-specific crafting recipe is registered.


minetest.register_chatcommand("claim", {
  params = "<add|remove|list|abandon|cancel> [player]",
  description = "Manage your land claims and trusted friends",
  func = function(name, param)
    local action, target = param:match("^(%S+)%s*(.-)$")
    if not action or action == "" then
      return true, "Use /claim add <player>, /claim remove <player>, /claim list, /claim abandon, or /claim cancel."
    end
    if action == "cancel" then selections[name] = nil; return true, "Claim selection cleared." end
    if action == "list" then
      local lines = {}
      for _, c in pairs(claims) do
        if c.owner == name or can_build(c, name) then
          local friends = table.concat(c.friends or {}, ", ")
          lines[#lines+1] = claim_summary(c) .. (friends ~= "" and ("; trusted: " .. friends) or "")
        end
      end
      if #lines == 0 then return true, "You do not own or have access to any claims." end
      table.sort(lines)
      return true, table.concat(lines, "\n")
    end
    if action == "add" or action == "remove" then
      if target == "" then return false, "Usage: /claim " .. action .. " <player>" end
      if target == name then return false, "You do not need to add yourself." end
      local owned = {}
      for _, c in pairs(claims) do
        if c.owner == name then
          c.friends = c.friends or {}
          owned[#owned + 1] = c
        end
      end
      if #owned == 0 then return false, "You need to own a claim first." end
      if action == "add" then
        if not minetest.player_exists(target) then return false, "That player name is not registered yet." end
        local changed = 0
        for _, c in ipairs(owned) do
          local exists = false
          for _, friend in ipairs(c.friends) do if friend == target then exists = true; break end end
          if not exists then table.insert(c.friends, target); changed = changed + 1 end
        end
        if changed == 0 then return false, target .. " is already trusted on all your claims." end
        save()
        return true, "Added " .. target .. " as a trusted friend on " .. changed .. " claim(s)."
      else
        local changed = 0
        for _, c in ipairs(owned) do
          for i = #c.friends, 1, -1 do
            if c.friends[i] == target then table.remove(c.friends, i); changed = changed + 1 end
          end
        end
        if changed == 0 then return false, target .. " is not trusted on any of your claims." end
        save()
        return true, "Removed " .. target .. " from " .. changed .. " claim(s)."
      end
    end
    if action == "abandon" then
      local id = tonumber(target)
      local found_key, found
      for key, c in pairs(claims) do
        if c.owner == name and (not id or c.id == id) then found_key, found = key, c; break end
      end
      if not found then return false, "No matching claim found. Use /claim abandon <claim_id> to select one." end
      claims[found_key] = nil
      save()
      return true, "Abandoned claim #" .. found.id .. "."
    end
    return false, "Unknown action. Use /claim add <player>, /claim remove <player>, /claim list, /claim abandon [claim_id], or /claim cancel."
  end,
})

minetest.register_chatcommand("claimshovel", {
  description = "Get a golden land-claim shovel",
  privs = {interact = true},
  func = function(name)
    local player = minetest.get_player_by_name(name)
    if not player then return false, "You must be online." end
    local stack = ItemStack(MODNAME .. ":golden_shovel")
    local leftover = player:get_inventory():add_item("main", stack)
    if not leftover:is_empty() then minetest.add_item(player:get_pos(), leftover) end
    return true, "Golden Claim Shovel added to your inventory."
  end,
})



-- Administrative commands: all require the built-in Luanti "server" privilege.
local function admin_claims_for(owner)
  local found = {}
  for key, c in pairs(claims) do
    if c.owner == owner then found[#found + 1] = {key = key, claim = c} end
  end
  table.sort(found, function(a, b) return a.claim.id < b.claim.id end)
  return found
end

minetest.register_chatcommand("claimadmin", {
  params = "<list|remove|clear|trust|untrust|info|bypass> [arguments]",
  description = "Administer land claims (server privilege required)",
  privs = {server = true},
  func = function(name, param)
    local action, rest = param:match("^(%S+)%s*(.-)$")
    if not action or action == "" then
      return true, "Usage: /claimadmin list <player> | remove <player> <claim_id> | clear <player> | trust <owner> <friend> | untrust <owner> <friend> | info | bypass"
    end
    if action == "list" then
      local owner = rest
      if owner == "" then return false, "Usage: /claimadmin list <player>" end
      local found, lines = admin_claims_for(owner), {}
      for _, entry in ipairs(found) do
        local c = entry.claim
        local friends = table.concat(c.friends or {}, ", ")
        lines[#lines + 1] = claim_summary(c) .. (friends ~= "" and ("; trusted: " .. friends) or "")
      end
      if #lines == 0 then return true, "No claims found for " .. owner .. "." end
      return true, table.concat(lines, "\n")
    elseif action == "remove" then
      local owner, id_text = rest:match("^(%S+)%s+(%d+)$")
      local id = tonumber(id_text)
      if not owner or not id then return false, "Usage: /claimadmin remove <player> <claim_id>" end
      for key, c in pairs(claims) do
        if c.owner == owner and c.id == id then
          claims[key] = nil; save()
          return true, "Admin " .. name .. " removed claim #" .. id .. " owned by " .. owner .. "."
        end
      end
      return false, "Claim #" .. id .. " owned by " .. owner .. " was not found."
    elseif action == "clear" then
      local owner = rest
      if owner == "" then return false, "Usage: /claimadmin clear <player>" end
      local found = admin_claims_for(owner)
      if #found == 0 then return true, "No claims found for " .. owner .. "." end
      for _, entry in ipairs(found) do claims[entry.key] = nil end
      save()
      return true, "Removed all " .. #found .. " claim(s) owned by " .. owner .. "."
    elseif action == "trust" or action == "untrust" then
      local owner, friend = rest:match("^(%S+)%s+(%S+)$")
      if not owner or not friend then return false, "Usage: /claimadmin " .. action .. " <owner> <friend>" end
      if owner == friend then return false, "The owner does not need to be trusted." end
      local found, changed = admin_claims_for(owner), 0
      for _, entry in ipairs(found) do
        local c = entry.claim; c.friends = c.friends or {}
        local index
        for i, f in ipairs(c.friends) do if f == friend then index = i; break end end
        if action == "trust" and not index then table.insert(c.friends, friend); changed = changed + 1
        elseif action == "untrust" and index then table.remove(c.friends, index); changed = changed + 1 end
      end
      if changed > 0 then save() end
      if #found == 0 then return false, "No claims found for owner " .. owner .. "." end
      return true, (action == "trust" and "Trusted " or "Untrusted ") .. friend .. " on " .. changed .. " claim(s) owned by " .. owner .. "."
    elseif action == "info" then
      local player = minetest.get_player_by_name(name)
      if not player then return false, "This command requires you to be in the world." end
      local c = get_claim(player:get_pos())
      if not c then return true, "You are not standing inside a claim." end
      return true, claim_summary(c) .. "; trusted: " .. table.concat(c.friends or {}, ", ")
    elseif action == "bypass" then
      if admin_bypass[name] then
        admin_bypass[name] = nil
        return true, "Claim protection bypass disabled."
      end
      admin_bypass[name] = true
      return true, "Claim protection bypass enabled for you. Use /claimadmin bypass again to disable it."
    end
    return false, "Unknown action. Use /claimadmin for command usage."
  end,
})

minetest.register_on_leaveplayer(function(player)
  local name = player:get_player_name()
  selections[name] = nil
  admin_bypass[name] = nil
end)

minetest.log("action", "[" .. MODNAME .. "] loaded with " .. tostring((function() local n=0; for _ in pairs(claims) do n=n+1 end; return n end)()) .. " saved claims")
