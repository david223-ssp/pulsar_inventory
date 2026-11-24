<div align="center">

<img src="https://r2.fivemanage.com/GPYOH8Hq4GPyAY7czrgLe/pulsarbanner.png" alt="Pulsar Framework" width="100%" />

<br/>

# PULSAR-INVENTORY

### Player inventory — drag-and-drop grid, crafting, and hotbar

<br/>

![Lua](https://img.shields.io/badge/Lua_5.4-2C2D72?style=flat-square&logo=lua&logoColor=white)
![FiveM](https://img.shields.io/badge/FiveM-F40552?style=flat-square)
![Svelte](https://img.shields.io/badge/Svelte_5-FF3E00?style=flat-square&logo=svelte&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=flat-square&logo=typescript&logoColor=white)
![Vite](https://img.shields.io/badge/Vite-646CFF?style=flat-square&logo=vite&logoColor=white)
![Bun](https://img.shields.io/badge/Bun-000000?style=flat-square&logo=bun&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=flat-square&logo=mariadb&logoColor=white)

<br/>

<sub>Enjoy the framework? A coffee helps keep active development, hardening, and support going.</sub>

<a href="https://buymeacoffee.com/pulsarframework"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 50px !important;width: 180px !important;" /></a>

<br/>

[Overview](#overview) · [What's Changed](#whats-changed) · [Theming](#theming) · [Hotkeys](#hotkeys) · [Dependencies](#dependencies)

</div>

---

## Overview

The custom inventory system includes a dual-pane item grid (your inventory on one side, a secondary pane on the other reused for trunk, glovebox, ground, stashes, shops, and other players' inventories), a custom mouse-driven drag-and-drop engine, a crafting screen, an always-on hotbar, and a pickup/loss/use toast feed.

---

## What's Changed

Changes made on top of the original Pulsar release (`v1.0.3`):

**Physical ground items** — `server/ground_items.lua`, `client/drops.lua`, `Config.GroundItems`
- Every entry in a dropzone is now its own prop where it landed, instead of one bag per dropzone. Storage is unchanged (dropzones, `invType 10`, one DB row each); each entry just stores its own `groundPos`, decided by the server in `SaveInventory`.
- Per-item and per-type props (`Props`, `TypeProps`); weapons use their own weapon model.
- Floating pickup prompt with outline and **[E]** to pick up; `UseTarget = true` switches back to the targeting menu.
- `Enabled = false` restores the old single-bag behaviour (`Config.DropProp`).

**Place mode** — `client/place.lua`, `Config.PlaceMode`
- "Place" in the item menu shows a transparent preview that follows the camera: **[E]** place, **[Mouse wheel]** rotate, **[C]** cancel. The server checks the distance before moving the item.

**Give / throw mode** — `client/give.lua`, `Config.GiveMode`
- "Give" puts the item in your hand: **[E]** hands it to the player you are facing, **[Left Click]** throws it where you aim, **[C]** cancels.
- Server-side checks for distance, rate limit, room and weight; a one-shot trusted access (`GrantTrustedAccess`) lets these flows bypass the normal 3 m dropzone rule only after those checks pass.
- Per-item blacklists for give, throw and place. All player-facing text lives in `Config.GiveMode.Text`.

**Character equipment** — `server/equipment.lua`, `Config.Equipment`
- New per-character equipment inventory (`invType 300`, owner = SID) shown around a body silhouette in the UI.
- Backpack slot: any item with `backpack = true` (a type 10 container) can be equipped, and its storage opens directly under the player pane. A `backpack` item was added to `items/containers.lua`.
- The other slots (armor, phone, parachute, wallet, key) are display-only for now, so other resources that look for those items in the player inventory keep working.

**Health & Injuries tab** — `client/health.lua`, `server/health.lua`, `Config.HealthTab`
- New UI tab showing health, armor, stamina and per-limb injuries/bleeding from `pulsar_damage`, with Major/Critical severity levels.
- "Heal Injury" uses the first item from `healItems` the player carries through the normal item-use flow, so `pulsar_damage` still owns all healing. The tab shows as unavailable when `pulsar_damage` is not running.

**Cash as an item** — `Config.CashAsItem`, `server/inventory_store.lua`, `items/misc.lua`
- A `cash` item kept in sync with the character's wallet cash. Set `Config.CashAsItem = false` to disable.

**Inventory store**
- Write-through cache for inventory loads: every write is still saved to the DB synchronously, the cache only skips repeat loads and always hands out deep copies.

**UI (Svelte)**
- New shell with tab navigation (Inventory / Health / Crafting), equipment panel and body highlight.
- New right-click context menu (item header, quick-action tiles, item-specific actions, favourites, keyboard navigation) positioned with `@floating-ui/dom`.
- Reworked slot grid, pane panel, item tooltip and theme (`ui/src/theme.css`). `ui/dist/` has been rebuilt.

---

## Theming

Edit `ui/src/theme.css` for base colors, fonts, and the `--rarity-1` through `--rarity-7` item rarity ladder. Edit `ui/src/config.ts` for rarity/item-type labels and timing constants (hotbar, toasts, crafting). Then rebuild:

```
cd ui
bun install
bun run build
```

Commit the rebuilt `ui/dist/` — that's what actually ships.

---

## Hotkeys

| Input | Action |
|---|---|
| **Shift + Left Click** | Quick Transfer to the other inventory |
| **Left Click** | Pick up the typed quantity, or the full stack |
| **Ctrl + Right Click** | Pick up a single item |
| **Shift + Right Click** | Split Stack |
| **Right Click** | Pick up half the stack |
| **Middle Click** | Use the selected item |

---

## Dependencies

- `pulsar_core` — framework core
- `pulsar_pwnzor` — anti-cheat check loaded alongside every resource
- `oxmysql` — inventory persistence
- `pulsar_damage` *(optional)* — source of the Health & Injuries tab data and healing; the tab is disabled when it is not started (resource name set in `Config.HealthTab.resource`)

### UI build dependencies

Only needed to rebuild `ui/dist/` ([Bun](https://bun.sh) is used as the package manager):

| Package | Version | Use |
|---|---|---|
| `@floating-ui/dom` | 1.6.13 | Context menu / tooltip positioning |
| `@fortawesome/free-solid-svg-icons` | ^6.6.0 | Icons |
| `dompurify` | ^3.2.7 | Sanitizing item descriptions/metadata |
| `svelte` *(dev)* | ^5.1.0 | UI framework |
| `@sveltejs/vite-plugin-svelte` *(dev)* | ^4.0.0 | Vite integration |
| `vite` *(dev)* | ^5.4.11 | Bundler |
| `typescript` *(dev)* | ^5.6.3 | Type checking |
| `svelte-check` *(dev)* | ^4.0.5 | `bun run check` |
| `@tsconfig/svelte`, `@types/dompurify` *(dev)* | ^5.0.4, ^3.0.5 | Type configs |

---

## License

This resource is free to use and modify under the [Pulsar Framework License](LICENSE.md). Redistribution is welcome as long as it stays free — selling this resource or any derivative of it requires written permission from the Pulsar Framework team.

---

<div align="center">

![Pulsar Framework](https://img.shields.io/badge/Pulsar-Framework-7c3aed?style=flat-square)
![Built for FiveM](https://img.shields.io/badge/Built_for-FiveM-F40552?style=flat-square)

</div>
