# Reference images

Status: convention
Read when: a task needs a visual reference that is not markdown

Images that support a task live here, not inside `design/tasks/`.
Tasks link them with a relative path and a short caption.
`docs.py task check` and load-graph checks ignore this folder. `.gdignore` keeps Godot from importing the images (no `.import` files here).

Layout:
- `design/refs/<task-id>/<name>.jpg` (or .png)
- One folder per task that needs refs.

The quest-board reference is at `design/refs/ui-quest-board-posters/quest-board.jpg`.
