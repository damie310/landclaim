## Luanti LandClaim

A game-independent, server-side land-claim mod for Luanti, inspired by Minecraft golden-shovel claim plugins.

**Author:** Damie310  
**Version:** 1.2.0  
**License:** MIT

**Texture Artist:** ac.adapter

## Features

- Select two opposite corners using the Golden Claim Shovel.
- Claims protect a rectangular X/Z area through the configured world height.
- Owners can add trusted friends with `/claim add <player>` and remove them with `/claim remove <player>`.
- `/claim list` lists claims you own or are trusted in.
- `/claim abandon [claim_id]` abandons a claim; if you own multiple claims, specify its ID.
- `/claim cancel` clears an unfinished shovel selection.
- Claims are saved in mod storage and survive restarts.
- Claim boundaries cannot overlap.
- Includes its own shovel texture and has no Mineclonia-specific dependency.

## Install

1. Extract the `landclaim` folder into the world's `worldmods` directory (or your Luanti mods directory).
2. Enable the mod for the world.
3. Restart the world/server.
4. In chat, use `/claimshovel` to get the Golden Claim Shovel.
5. Right-click one block for the first corner, then right-click the opposite corner.

## Player commands

- `/claimshovel` — get a claim shovel.
- `/claim add <player>` — trust a player on all your claims.
- `/claim remove <player>` — remove a trusted player from all your claims.
- `/claim list` — show claims you own or have access to.
- `/claim abandon [claim_id]` — abandon one of your claims.
- `/claim cancel` — cancel an in-progress selection.

## Settings

Add these to `minetest.conf` to customize limits:

- `landclaim_max_claims = 10` — maximum claims per player.
- `landclaim_min_size = 5` — minimum length of each horizontal side.
- `landclaim_max_size = 128` — maximum length of each horizontal side.
- `landclaim_world_min = -31000` and `landclaim_world_max = 31000` — vertical range protected by claims.

## Administrator commands

All `/claimadmin` commands require Luanti's built-in `server` privilege. Regular players cannot run them.

- `/claimadmin list <player>` — list that player's claims.
- `/claimadmin remove <player> <claim_id>` — remove one specific claim owned by that player.
- `/claimadmin clear <player>` — remove all claims owned by that player.
- `/claimadmin trust <owner> <friend>` — trust a friend on all claims owned by the specified player.
- `/claimadmin untrust <owner> <friend>` — remove that friend's access from all of the specified owner's claims.
- `/claimadmin info` — show claim details for the claim where the admin is standing.
- `/claimadmin bypass` — toggle claim-protection bypass for yourself; run it again to disable. Bypass resets when you leave the server.

The commands are registered with `privs = {server = true}` and are restricted to server-privileged administrators.

## Notes

Friend management commands add or remove the player across all claims owned by the command issuer. The mod integrates with Luanti's `is_protected` API. Some game-specific interactions may need additional integration to ensure they respect claims.
