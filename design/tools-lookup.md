# Tools: find, read and measure

Status: protocol  
Read when: finding where something is used, reading one function, row, tunable, scene or route card, or a tool's last run  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. These print the rows you asked for; open a file only when the row is not enough.

## Jobs

- **Where is X used:** `list_xref.py TEXT` (`--regex`, `--path DIR`, `--expand FILE`). Text shown on screen: `list_xref.py TEXT --texts` (after `run_shot_flow.py`).
- **One function:** `show_func.py scripts/x.gd func_name`.
- **Which doc, flows and phases for a job:** `list_route.py --job door.job` (no args lists doors; `--digest --door D`).
- **Which system owns a file:** `code_map.py row --path scripts/x.gd`; edit the row: `code_map.py patch --system S --add P`.
- **A tunable:** `tunables.py get KEY`; change it: `tunables.py set KEY --set "cell" --dry-run`, then without `--dry-run`.
- **Scene nodes:** `list_scenes.py --path scenes/x.tscn`. Facade and helpers: `list_facade_cluster.py scripts/x.gd`.
- **Bytes, BOM, EOL:** `file_stat.py PATH` (`--glob`). Funcs per script: `summarize_scripts.py --path P`.
- **What changed / doc vs code:** `list_changed.py`; `list_changed.py --history design/x.md scripts/x.gd`.
- **A tool's last run:** `read_summary.py JOB` (no args lists jobs).
- **Grok sessions:** `session_dump.py` (interactive, to clipboard); a share link: `grok_share.py URL --print-convo`.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `list_xref.py` | Text search (case-insensitive) in the current project: `TEXT` or `--pattern`, `--regex`, `--path DIR ...`, `--include GLOB`; many hits print a per-file index (`--expand FILE` for one file); `--texts` searches the shot-flow text dumps (after `run_shot_flow.py`). Skips the Bot's own docs. Summary: `xref`. | D | `--help` | N |
| `show_func.py` | One GDScript or Python declaration: `PATH NAME` (or `--path`, `--name`); a missing file or name prints a hint. Summary: `show-func`. | D | `--help` | N |
| `list_route.py` | One `routes.yaml` door or job card: `--door D` / `--job door.job` (the one doc to read, smoke phases, shot flows); `--digest` one line per doc or a doc's headings; `--gates` lists gate names and triggers; no args lists the doors. | BD | `--help` | Y |
| `tunables.py` | `get KEY` (one line per matching row: file:line, key, Live cell, section; `--verbose` for all fields), `set KEY --set "cell"` (exactly one hit; `--dry-run`), `add NEW --after KEY --set "cell"` on `design/tunables*.md`. Summaries: `tunable-row`, `tunable-patch`. | D | `--help` | N |
| `list_scenes.py` | `.tscn` nodes and scripts without dumping scenes (`--path`, `--max-nodes`). Summary: `scenes`. | D | `--help` | N |
| `list_facade_cluster.py` | A facade + its stem-folder helpers by bytes (`FACADE` or `--facade`). Summary: `facade-cluster`. | D | `--help` | N |
| `file_stat.py` | Bytes, BOM, CRLF/LF, indent for a path or glob (verify a split kept them); prints the absolute root it read. Summary: `file-stat`. | BD | `--help` | Y |
| `summarize_scripts.py` | Func inventory per `.gd` (`--path`, `--top-funcs`) | BD | `--help` | Y |
| `list_changed.py` | Git-changed paths with on-disk bytes (`--scope`); `--history PATH ...` shows each path's recent commits and which is newer (doc vs code); `--head` adds HEAD and the log. Summary: `changed`. | D | `--help` | N |
| `read_summary.py` | A job's last run: `JOB` (or `--job`) prints the index (newest first) and the newest summary; `--run N`, `--index`, `--path`; no args lists jobs. Prints the absolute root it read. | WD | `--help` | N |
| `session_dump.py` | Interactive dump of a recent Grok session (chat, events, updates, usage, prompt_context, system prompt, terminal logs) into one .txt on the clipboard. Skips wdb-iso worktrees. | D | `--help` | N |
| `grok_share.py` | Pull conversation + images from a Grok share URL via Playwright: `URL --print-convo`, `--list-images`, `--save-images DIR [--turn N] [--index 0,2]`; `--headed` once to log in. | W | `--help` | N |
