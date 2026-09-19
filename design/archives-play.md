# Archives — Play and Pages

Status: binding design  
Read when: worktree minimize, Godot child restore, slug copyhit


## Play

**Web:** loader overlay, then same-tab redirect to the catalog `pages_url` (`JavaScriptBridge` `location` assign). Do not `OS.shell_open` a new tab. The browser Back button returns to the live title. The archive is a pre-exported Godot Web build under GitHub Pages. Never spawn Godot or checkout in the browser.

**Editor / desktop with git:** reuse `scripts/ui/loader.gd`. Checkout `.archive_worktrees/<id>` (gitignored) if needed, stamp the project name, headless `--import` if `.godot/` is missing, then `OS.create_process` Godot `--path` that worktree. Keep the live instance running: minimize the parent window, watch the child PID, restore the parent and `App.go_title()` when the child exits. Keep frames pumping until spawn. B / Esc cancels before spawn.

**No git / packaged exe:** same as web (Pages URL, same tab on web).

Cached worktree + existing import: short “Opening snapshot…” beat, no re-import.

## Pages

Live site root is the current HEAD export. Each archive is `https://viraxvespa.github.io/WhatDwellsBelow/<pages_slug>/`.

Player-facing changelogs for skipped weeks live at `https://viraxvespa.github.io/WhatDwellsBelow/changelog/`. That route is built in CI from flat `design/changelog/*.md` plus `design/changelog/archive/*/*.md`. Do not store those notes inside the Godot `docs/` export tree on `main`.

GitHub Actions (`.github/workflows/pages.yml`) always exports HEAD. That live export is fatal: if it fails, Pages does not deploy.

Catalog pins are exported by `tools/export_archives.py` as best-effort. A pin that fails `git worktree add`, `project.godot` stamp, `--import`, or `--export-release Web` is logged (Godot stdout/stderr included) and skipped. It MUST NOT fail the live deploy. Each pin uses its own `XDG_CACHE_HOME` and a wiped worktree `.godot/`. Do not change `HOME` during archive export; export templates stay in the runner user dir.

Archive wasm/pck is not stored on `main`. CI restores `.archive_export_cache/` with key `wdb-pages-archives-` plus `hashFiles('scripts/data/archive_catalog.json')`, and `restore-keys` of `wdb-pages-archives-`. A cache hit for `{id}/{commit}/index.html` is copied into `site/<pages_slug>/`. A miss exports that pin once, then stores it under `{id}/{commit}/`. A later catalog-hash key miss still restores the previous cache so unchanged pins are not rebuilt. Local preview: `powershell -File tools/export_web.ps1 -Archives` → `_pages/`, same helper and gitignored `.archive_export_cache/`.

Repo setting: Pages source = GitHub Actions.
