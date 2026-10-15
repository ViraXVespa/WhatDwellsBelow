---
name: show-func
description: >
  Extract one GDScript/Python declaration with tools/show_func.py instead of reading whole files.
  Use when you need a specific func, const, or var from a live script.
when-to-use: >
  show a function, open a declaration, show_func, need the body of one func
  in a script I am not fully rewriting. Prefer over read_file of a whole .gd.
user-invocable: true
metadata:
  short-description: Extract one func/const with show_func
---

# show_func

Run from repo root. Prefer this over read_file of an entire live script when you only need one or a few declarations.

Preferred shapes:

Single:
python tools/show_func.py scripts/ui/theme.gd skill_row

Batch several related ones in one command (semicolon-separated; works in PowerShell):
python tools/show_func.py scripts/ui/recap/rebuild.gd rebuild; python tools/show_func.py scripts/ui/recap/recap_ui.gd build

Rules:
- Positional PATH NAME is enough. --path / --name are optional.
- Batch related funcs from the same system in one shell command.
- Output is capped (first 80 lines of the declaration) and logged under _logs/show-func/. Read the printed RESULT / summary; do not open the log files.
- If you need the whole file or are about to edit it, then read_file is fine. Otherwise stay with show_func.
- Catalog row: design/tools.md. Do not open the tool body to learn flags.
