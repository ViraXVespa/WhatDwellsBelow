# Archived builds

Status: current plan  
Read when: Pages builds, catalog pins
Code: `scripts/ui/archives_ui.gd`, `scripts/ui/archives_ui/ui_view.gd`, `scripts/ui/archives_ui/ui_act.gd`, `scripts/ui/split_menu.gd`, `scripts/ui/split_menu/split_menu_view.gd`, `scripts/ui/split_menu/chrome.gd`, `scripts/data/archives/archives_catalog.gd`, `scripts/data/archives/launch.gd`, `scripts/data/archive_catalog.json`, `scripts/ui/loader.gd`, `tools/release.py archives`, `.github/workflows/pages.yml`  

## Core rule

Archived builds are **pinned git commits**, not folders copied into the live tree.

- Do not copy snapshot projects into `archives/` or onto the live path.
- Do not back-port live changes into a pinned commit.
- The Archives browser MUST ship in the demo (Patreon development narrative) and opens from the title card only; Pause MUST NOT open it and there is no presentation-mode switcher. Title Play always launches the live path.
- Do not create a new archive unless the User explicitly asks, except the standing Grok Build week pins in the versioning gate.

`scripts/data/archive_catalog.json` is the catalog. A row's `docs` list is `design/` as it is on that pin. Changelog notes are not copied into another folder.

This file is the door. Open the Job-table sibling only when that row matches.

| Job | Open |
|-----|------|
| classic_2d entry, snapshot tags, week ritual freeze | `design/archives-catalog.md` |
| worktree minimize, Godot child restore, slug copyhit | `design/archives-play.md` |
| split chevron, Documents reader, dim inactive columnstack | `design/archives-ui.md` |
