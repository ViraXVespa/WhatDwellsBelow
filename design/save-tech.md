# Save, export, performance

Status: binding design  
Read when: changing persistence, web export, autoloads, or perf  
Code: `scripts/data/save_store.gd`, `scripts/app.gd`, `tools/export_web.ps1`, `project.godot`  
See also: `design/debug.md`, `design/archives.md`, `design/camera.md`

## Save system

- Save data is stored in browser `user://` (or equivalent platform-appropriate location).
- A primary save file and a backup of the last successfully loaded save MUST both be maintained.
- If the primary save is missing, corrupted, or fails to parse, the game automatically falls back to the backup. If both fail, a fresh dungeon delver is created.
- Save data MUST persist across sessions and include at minimum:
  - Permanent XP and levels for all eleven skills
  - Banked gold
  - Banked resources (ore, wood, etc.)
  - The three forged holds for every equipment slot
  - Unlocked deepest floor
  - Selected character type (male / female)
  - Camera zoom (range 1.0–2.5, fresh default 1.75) and HUD scale settings
  - Sprite filter id, mip-blend sharp flag, and mip bias
  - Aim-line on/off state and opacity
  - Any other player settings and debug overrides that should persist

Live player slot name: `"live"`. `App.save_now()` / `App.wipe_save()`.

Missing `cam_zoom` on an old save applies 1.75. A save that already stored `1.0` keeps 1.0 until the player moves the slider.

## Restock-on-return

If the player returns to Placeholdia with gold or consumables below configurable thresholds, a limited free restock of basic food and potions is granted.

## Debug profiles

Named debug profiles (unlimited) are saved to files by default and persist across live-path sessions. Archives builds use the default values that existed at the moment of archiving.

## Automated Playtest saves

The Automated Playtest / AI Player system maintains two completely independent save files that never interact with the player’s normal save data:
1. Fresh-start save – repeatedly cleared by the system.
2. Progressed save – contains full skill progression and can be reset to a fixed default progressed state.
Both are stored under isolated paths and follow the same primary + backup safety rules.

## Presentation switcher

The Archives browser MUST ship in the final demo. Selecting title “Play” always launches the live path. Catalog rows are pinned commits (Classic 2D, Art experiment, Full 3D Pass, Grok Build Week 1, Grok Web Week 1) per `design/archives.md`. This system exists to support the Patreon development narrative and MUST not be removed.

## Web export requirements

- MUST run in modern browsers.
- MUST NOT require special COOP/COEP headers or other non-standard server configuration to function on GitHub Pages or equivalent static hosting.

Rebuild live locally with `powershell -File tools/export_web.ps1` into `docs/`. Combined live + archive preview: `powershell -File tools/export_web.ps1 -Archives` into `_pages/`. GitHub Actions deploys Pages from HEAD plus each catalog SHA; do not commit archive wasm/pck to `main`.

## Performance

- Consistent 60 FPS minimum on target hardware at all times. Higher frame rates are allowed and desirable.
- Frame time and memory usage MUST remain stable even on the deepest floors with full enemy and particle load.

Streaming in `design/dungeon.md` exists to keep 432×432 floors inside that budget: enemies via `dungeon_stream.gd`, floor/wall meshes and wall collision via `dungeon_geo_stream.gd`.

## Renderer

Compatibility renderer is preferred for the shippable build if it does not break the web export. Mobile renderer may be retained only if required for web stability.

Godot target: **4.7.2**. Main scene `res://scenes/boot.tscn`. Autoload `App = *res://scripts/app.gd`.