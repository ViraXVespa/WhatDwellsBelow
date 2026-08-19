# What Dwells Below

A gamepad-first 2D dungeon crawler: RuneScape-style skills mashed with Heroes of Hammerwatch. Godot 4.7.

**Vertical slice** — Vylenheim plaza, Great Axe + pickaxe, 2–6 dungeon floors, mining, extract clerks, floor guardians every 3 floors.

## Play in the browser

**[Play the slice](https://viraxvespa.github.io/WhatDwellsBelow/)** on GitHub Pages.

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

Proudly vibecoded with Grok by [@ViraXVespa](https://github.com/ViraXVespa).
