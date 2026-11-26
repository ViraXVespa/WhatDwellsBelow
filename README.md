# What Dwells Below

Gamepad-first dungeon crawler. Pilot disposable spirit avatars, mail loot home, remember skills earned in the dark.

**[Play the demo](https://viraxvespa.github.io/WhatDwellsBelow/)** (GitHub Pages).  
Support on **[Patreon](https://www.patreon.com/cw/ViraXVespa)**.

Click the canvas for input. Xbox pad works in Chromium; WASD + mouse otherwise.  
Controls: WASD move, mouse aim, LMB attack, RMB special, Space dash, E interact, F potion, C food, Esc pause, M map, Q lock, `[` / `]` tabs.  
Wipe: Pause → Settings → Gameplay → Delete Save Data. Exit: “Dispel”.

Prompts follow last-used input. Rebind in Settings → Controls.

Local web rebuild: `python tools/release.py export-web` → `_out/web/`.  
Full Pages (with archives): `python tools/release.py export-web --archives` → `_pages/`.

## Code graphs

Interactive dependency graphs (updated on every Pages deploy):

- [Game (GDScript)](https://viraxvespa.github.io/WhatDwellsBelow/graphs/game.html)
- [Tools (Python)](https://viraxvespa.github.io/WhatDwellsBelow/graphs/tools.html)
- [Index](https://viraxvespa.github.io/WhatDwellsBelow/graphs/)

Machine-readable (for agents): [game.json](https://viraxvespa.github.io/WhatDwellsBelow/graphs/game.json), [tools.json](https://viraxvespa.github.io/WhatDwellsBelow/graphs/tools.json).

Local preview: `python tools/release.py graphs --out _out/graphs` then open `_out/graphs/index.html`.

## Open in Godot

Steam Godot Engine 4.7.2 → Open `project.godot`.

Editor play: F5.

Shamelessly Vibecoded with Grok by [@ViraXVespa](https://github.com/ViraXVespa).  
Dungeon music: **Bitter** — ViraXVespa.
