---
name: list-xref
description: >
  Repo search that replaces grep/rg. When wdb__lookup is connected, use action=xref.
  Otherwise use tools/find.py xref. Use when about to search scripts/, design/, tools/, scenes/, or shot-flow texts.
when-to-use: >
  search the tree, find a symbol, list funcs/consts in a file or folder,
  grep, rg, list_xref, xref. Prefer this over opening files to hunt for a name.
user-invocable: true
metadata:
  short-description: Repo search with list_xref
---

# list_xref

Run from repo root. Do not use grep/rg on scripts/, design/, tools/, or scenes/. When `wdb__lookup` is connected, use `action=xref` (and `action=names` for a name list), with `all=true` or `reads` when you need the whole result. When it is not, use the commands below.

Fallback shapes (copy these; do not invent flag combinations):

Index of hits (file + count + first line):
python tools/find.py xref --pattern SYMBOL --path scripts/ui

Function and const names in one file or folder (not xref):
python tools/find.py scripts --names --path scripts/ui/recap
python tools/find.py scripts --all-names --path scripts/ui/recap.gd

Show every hit inside specific files after the index:
python tools/find.py xref --pattern JournalSpread --expand scripts/ui/pause_menu/journal_page.gd

Shot-flow text dumps:
python tools/find.py xref --pattern recap --texts

Rules:
- Pass the text as --pattern (one positional TEXT is the same).
- Start with an index-style call. Add --expand FILE only for the files you actually need the body of.
- --regex only when the pattern is a real regex (anchors, groups, |). Plain text does not need it. Do not use it to inventory `^func`.
- Function and const inventories are `find.py scripts --names` or `--all-names` with one `--path`.
- Default paths are already scripts scenes tools design. Narrow with --path when you know the area.
- Read the printed index. If the CLI prints only a RESULT line, page it with `wdb__lookup action=summary` when that MCP is connected, otherwise `session.py summary xref`. Never open `_logs/` with a file read. Do not re-run the same search this slice.
- Catalog row and jobs: design/tools-lookup.md; full flags: `--help`. Do not open the tool body to learn flags.
