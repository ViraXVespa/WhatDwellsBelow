# Save, export, performance

Status: binding design  
Read when: persistence, wasm headers, autoloads, perf
Code: `scripts/data/save_store.gd`, `scripts/app.gd`, `scripts/app_set.gd`, `scripts/display_mode.gd`, `scripts/data/version.json`, `scripts/data/changelog.json`, `scripts/data/game_ver.gd`, `tools/web_shell.html`, `tools/export_web.ps1`, `tools/enable_texture_mips.py`, `tools/export_archives.py`, `tools/web_postexport.py`, `tools/build_changelog.py`, `.github/workflows/version.yml`, `.github/workflows/pages.yml`, `project.godot`, `export_presets.cfg`  


This file is the door. Open the Job-table sibling only when that row matches.

| Job | Open |
|-----|------|
| primary backup wipe, game_ver stamp, isolated AI profiles | `design/save-tech-persist.md` |
| COOP COEP off, id.txt querybust, serviceworker rename | `design/save-tech-web.md` |
| borderless exclusive, mip decode ban, Compatibility preferred | `design/save-tech-runtime.md` |
