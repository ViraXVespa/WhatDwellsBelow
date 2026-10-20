# Archives — browser UI

Status: current plan  
Read when: split chevron, Documents reader, dim inactive columnstack

## Archives browser UI

Opened from title **Archives** only. Pause Settings MUST NOT open this browser.

Shared two-column chrome: `split_menu.gd` + `split_menu_view.gd` (same helper as Pause Settings). Archive-specific Play / Documents / Video stay in `ui_act.gd`.

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

List MUST include every catalog row (`design/archives-catalog.md`). Videos do not exist; the Video button stays disabled until they do.
