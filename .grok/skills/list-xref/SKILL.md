---
name: list-xref
description: >
  Preferred invocations for tools/list_xref.py (repo search that replaces grep/rg).
  Use when about to search scripts/, design/, tools/, scenes/, or shot-flow texts.
when-to-use: >
  search the tree, find a symbol, list funcs/consts in a file or folder,
  grep, rg, list_xref, xref. Prefer this over opening files to hunt for a name.
user-invocable: true
metadata:
  short-description: Repo search with list_xref
---

# list_xref

Run from repo root. Do not use grep/rg on scripts/, design/, tools/, or scenes/.

Preferred shapes (copy these; do not invent flag combinations):

Index of hits (file + count + first line):
python tools/list_xref.py --pattern SYMBOL --path scripts/ui

Regex inventory of funcs/consts/class_names in one or more files:
python tools/list_xref.py --regex --pattern "^func |^const |^class_name" --path scripts/ui/recap

Show every hit inside specific files after the index:
python tools/list_xref.py --pattern JournalSpread --expand scripts/ui/pause_menu/journal_page.gd

Shot-flow text dumps:
python tools/list_xref.py --pattern recap --texts

Rules:
- The tool requires --pattern; a bare positional string is rejected.
- Start with an index-style call. Add --expand FILE only for the files you actually need the body of.
- --regex only when the pattern is a real regex (anchors, groups, |). Plain text does not need it.
- Default paths are already scripts scenes tools design. Narrow with --path when you know the area.
- Read the printed index. The RESULT line is only in the _logs/xref summary file, not on stdout. Do not re-run the same search this slice.
- Catalog row and full flags: design/tools.md. Do not open the tool body to learn flags.
