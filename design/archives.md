# Archived builds

Status: binding design  
Read when: Pages builds, catalog pins
Code: `scripts/ui/archives_ui.gd`, `scripts/ui/archives_ui_view.gd`, `scripts/ui/archives_ui_act.gd`, `scripts/ui/split_menu.gd`, `scripts/ui/split_menu_view.gd`, `scripts/ui/split_menu_chrome.gd`, `scripts/data/archives_catalog.gd`, `scripts/data/archives_launch.gd`, `scripts/data/archive_catalog.json`, `scripts/ui/loader.gd`, `tools/export_archives.py`, `.github/workflows/pages.yml`  


## Core rule

Archived builds are **pinned git commits**, not folders copied into the live tree.

- Do not copy snapshot projects into `archives/` or onto the live path.
- Do not back-port live changes into a pinned commit.
- Do not create a new archive unless the User explicitly asks, except the standing Grok Build week pins in the versioning gate.

`scripts/data/archive_catalog.json` is the catalog. Slim museum markdown that is **not** in a pin lives under `archives/docs/<id>/`.

This file is the door. Open the Job-table sibling only when that row matches.

| Job | Open |
|-----|------|
| classic_2d entry, snapshot tags, week ritual freeze | `design/archives-catalog.md` |
| worktree minimize, Godot child restore, slug copyhit | `design/archives-play.md` |
| split chevron, Documents reader, dim inactive columnstack | `design/archives-ui.md` |
