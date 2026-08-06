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

[Overview](#overview) · [Theming](#theming) · [Hotkeys](#hotkeys) · [Dependencies](#dependencies)

</div>

---

## Overview

The custom inventory system includes a dual-pane item grid (your inventory on one side, a secondary pane on the other reused for trunk, glovebox, ground, stashes, shops, and other players' inventories), a custom mouse-driven drag-and-drop engine, a crafting screen, an always-on hotbar, and a pickup/loss/use toast feed.

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

---

## License

This resource is free to use and modify under the [Pulsar Framework License](LICENSE.md). Redistribution is welcome as long as it stays free — selling this resource or any derivative of it requires written permission from the Pulsar Framework team.

---

<div align="center">

![Pulsar Framework](https://img.shields.io/badge/Pulsar-Framework-7c3aed?style=flat-square)
![Built for FiveM](https://img.shields.io/badge/Built_for-FiveM-F40552?style=flat-square)

</div>
