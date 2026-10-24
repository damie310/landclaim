# Luanti LandClaim

A game-independent, server-side land-claim mod for Luanti, inspired by Minecraft golden-shovel claim plugins.

## Project information

- **Author:** Damie310
- **Version:** 1.3.0
- **Mod license:** MIT (see [`LICENSE`](LICENSE))
- **Golden shovel texture:** Created for LandClaim by **ac.adapter**. Licensed under the MIT License with the copyright holder's approval. See [`GOLDEN-SHOVEL-LICENSE.md`](GOLDEN-SHOVEL-LICENSE.md) and [`TEXTURE-LICENSE.md`](TEXTURE-LICENSE.md).

## Features

- Select two opposite corners using the Golden Claim Shovel.
- Claims protect a rectangular X/Z area through the configured world height.
- Players who are not the owner or trusted friends cannot damage registered creatures inside a claim.
- Tamed or owned pets are protected from player punches everywhere in the world, including outside claims.
- Owners can add trusted friends with `/claim add <player>` and remove them with `/claim remove <player>`.
- `/claim list` lists claims you own or are trusted in.
- `/claim abandon [claim_id]` abandons a claim; if you own multiple claims, specify its ID.
- `/claim cancel` clears an unfinished shovel selection.
- Claims are saved in mod storage and survive restarts.
- Claim boundaries cannot overlap.

## Install

1. Extract the `landclaim` folder into the world's `worldmods` directory (or your Luanti mods directory).
2. Enable the mod for the world.
3. Restart the world/server.
4. In chat, use `/claimshovel` to get the Golden Claim Shovel.
5. Right-click one block for the first corner, then right-click the opposite corner.

## Player commands

| Command | Description |
| --- | --- |
| `/claimshovel` | Get a claim shovel. |
| `/claim add <player>` | Trust a player on all your claims. |
| `/claim remove <player>` | Remove a trusted player from all your claims. |
| `/claim list` | Show claims you own or have access to. |
| `/claim abandon [claim_id]` | Abandon one of your claims. |
| `/claim cancel` | Cancel an in-progress selection. |

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

## Protection notes

The mod integrates with Luanti's `is_protected` API for block protection. Entity protection wraps entity `on_punch` callbacks when mods finish loading. Exact pet ownership/taming fields vary between games and mob mods, so global pet protection works for entities that expose a recognized owner field (`owner`, `owner_name`, `tamed_by`, `_owner`, `ownername`, `playername`) or a `tamed`/`is_tamed` flag. Some games may use different conventions or custom damage paths and may need a game-specific adapter. Claim animal protection likewise depends on the entity's registered `on_punch` callback.

## Credits and licensing

- **Golden shovel texture** (`textures/landclaim_golden_shovel.png`): Created for LandClaim by **ac.adapter**. Licensed under the MIT License with approval from the copyright holder. See [`GOLDEN-SHOVEL-LICENSE.md`](GOLDEN-SHOVEL-LICENSE.md) for the texture-specific terms and [`TEXTURE-LICENSE.md`](TEXTURE-LICENSE.md) for details.
- **Mod source code:** Copyright (c) 2026 Damie310, licensed under the MIT License.
