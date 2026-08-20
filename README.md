# What Dwells Below

A gamepad-first dungeon crawler where you pilot disposable spirit avatars, mail loot home, and slowly remember the skills you earned in the dark.

**Playable demo** — a polished proof of the full game, not a greybox. Staging hub is **Placeholdia** (a fragment, not the real city). Take a Great Axe and pickaxe into the dungeon, fight, mine, extract, and wake with a fragment of what you earned. It should look and feel like What Dwells Below; a lot of the full game (other skills, weapons, biomes, co-op, story, the actual city) is simply not in this build yet.

## Play in the browser

**[Play the demo](https://viraxvespa.github.io/WhatDwellsBelow/)** on GitHub Pages.

Support development on **[Patreon](https://www.patreon.com/cw/ViraXVespa)**.

Click the game once so the canvas can take keyboard / gamepad input. Xbox pad works in Chromium-based browsers; WASD + mouse still work.

This is a no-threads Web export so it runs on GitHub Pages without special COOP/COEP headers. Rebuild with:

```powershell
powershell -File tools/export_web.ps1
```

That writes into `docs/`, which Pages serves from `main`.

## Open in Godot

1. Steam **Godot Engine** 4.7.2
2. Import / Open `project.godot` in this folder (not the old `GrokSandbox` copy)

## Play locally

Editor: Play (`F5`).  
Keyboard: WASD, mouse aim, LMB hold-attack, Space dash, Shift slam, E interact.

Proudly vibecoded with Grok by [@ViraXVespa](https://github.com/ViraXVespa). [Patreon](https://www.patreon.com/cw/ViraXVespa).
