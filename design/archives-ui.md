# Archives — browser UI

Status: binding design + live snapshot  
Read when: split chevron, Documents reader, dim inactive columnstack


## Archives browser UI

Opened from title **Archives** only. Pause Settings MUST NOT open this browser.

Shared two-column chrome: `split_menu.gd` + `split_menu_view.gd` (same helper as Pause Settings). Archive-specific Play / Documents / Video stay in `archives_ui_act.gd`.

Two columns. Only one column is active.

- Left: vertical list of catalog rows plus Back.
- Right: info panel — description, Video (disabled if missing), Documents, Play.
- While the list column is active, highlight / hover a left row updates the right pane immediately. Focus stays on the list.
- While the detail column is active, hover MUST NOT change the right pane. Click a different left row opens that row’s page. Click the already-open row returns focus to the list.
- A / click a left row moves focus to the first enabled right button (skip disabled Video).
- B / Esc on the right column returns focus to the current left row. Menu stays open.
- B / Esc on the left column closes the browser.
- Inactive column is dimmed. A gold rail marks the active column. A chevron tracks the selected row. Path text reads `Snapshots › {label}` and deeper for Documents / reader.

Documents: `archives/docs/<id>/` first, else `git show <sha>:<path>` locally, else GitHub raw on web. Truncate long files. Documents and reader stay a right-column mode stack; B steps read → docs → info → list.

List MUST include every catalog row, including Classic 2D, Art experiment, Full 3D Pass, Grok Build Results (Week 1–3), Grok Web Results (Week 1–3), Grok Build Results (Week 4) once that pin exists, and any week pins added by the ritual above. Videos do not exist yet; the Video button stays disabled until they do.

## Live snapshot

`archives_ui.gd` is the facade and split host. `archives_ui_view.gd` still owns archive-only panels. `archives_ui_act.gd` handles Play, docs fetch, and video. Column focus / dim / chevron come from `split_menu_view.gd`.

Pages CI exports live HEAD first, then runs `tools/export_archives.py` against the catalog. Failed pins stay in the catalog and in the Archives browser; their Pages URL may 404 until that SHA imports cleanly under the CI Godot and lands in `.archive_export_cache/`.
