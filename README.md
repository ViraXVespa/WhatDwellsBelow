# What Dwells Below

A gamepad-first dungeon crawler where you pilot disposable spirit avatars, mail loot home, and slowly remember the skills you earned in the dark.

**Playable demo** — a polished proof of the full game, not a greybox. Staging hub is **Placeholdia** (a fragment, not the real city). Take a Great Axe and pickaxe into the dungeon, fight, mine, extract, and wake with a fragment of what you earned. It should look and feel like What Dwells Below; a lot of the full game (other skills, weapons, biomes, co-op, story, the actual city) is simply not in this build yet.

## Play in the browser

**[Play the demo](https://viraxvespa.github.io/WhatDwellsBelow/)** on GitHub Pages.

Support development on **[Patreon](https://www.patreon.com/cw/ViraXVespa)**.

Click the game once so the canvas can take keyboard / gamepad input. Xbox pad works in Chromium-based browsers; WASD + mouse still work.

Default keyboard: WASD move, mouse aim, LMB hold-attack, RMB special, Space dash, E interact, F potion, C food, Esc pause (inventory / skills / system), M bigger map, Q target-lock, `[` / `]` tab menus. Wipe save is Pause → System → Delete Save Data. Voluntary exit is **“Dispel”**.

On-screen prompts follow **last used** input. One scheme at a time: pad glyphs after a gamepad event, keyboard / mouse glyphs after a key or mouse event. Rebind from Pause → System; the glyphs follow the live InputMap.

This is a no-threads Web export so it runs on GitHub Pages without special COOP/COEP headers. Rebuild live locally with:

powershell -File tools/export_web.ps1

That writes into `docs/`. Combined live + archived builds (preview):

powershell -File tools/export_web.ps1 -Archives

That writes into `_pages/` (gitignored). GitHub Actions exports HEAD plus each pin in `scripts/data/archive_catalog.json` and deploys Pages. After the workflow exists, set **Settings → Pages → Source = GitHub Actions**. Archived builds are those commits, served at `/archives/<id>/`. Title Play always launches live.

## Open in Godot

1. Steam **Godot Engine** 4.7.2
2. Import / Open `project.godot` in this folder (not the old `GrokSandbox` copy)

## Play locally

Editor: Play (`F5`).
Keyboard: WASD, mouse aim, LMB hold-attack, RMB special, Space dash, E interact, Esc pause/inventory, M map.

## Prompts

Chunky pixel glyphs live under `assets/ui/prompts/` (`kb/`, `pad/`, `mouse/`). Regenerate with:

python tools/gen_prompt_glyphs.py

Code map:

- `scripts/input/pad.gd` — last-used device (`Pad.mode`)
- `scripts/input/prompts.gd` — bind → glyph id / texture
- `scripts/ui/prompt_view.gd` — `fill`, `footer`, `pulse`
- `scripts/ui/menu_pad.gd` — menu confirm / back / tabs / paging; notes the event and refills the footer on a scheme flip
- `scripts/input/binds.gd` — `tab_left`, `tab_right`, `gear_tip`, `gear_drop`, `crystal_zoom`

Menus keep Select / Back in a footer strip at the bottom-right of the panel. Tab glyphs sit on the tab header. Stats paging stays on the stats card (Q / E on keyboard, LT / RT on pad). World interact uses the `interact` glyph plus a verb on the HUD.

Shamelessly Vibecoded with Grok by [@ViraXVespa](https://github.com/ViraXVespa). [Patreon](https://www.patreon.com/cw/ViraXVespa). Dungeon music: **Bitter** — ViraXVespa.