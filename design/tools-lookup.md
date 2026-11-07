# Tools: find, read and measure

Status: protocol  
Read when: finding where something is used, reading one function, row, tunable, scene or route card, or a tool's last run  

Use these commands to locate a route, source function or result without dumping unrelated files. Read the relevant source before editing; an inventory alone is not analysis. Tool contracts and surface permissions stay in the tools door.

Entries here: `find.py`, `docs.py`, `session.py`; their code: `tools/lib/docs/`, `tools/lib/lookup/`, `tools/lib/session/`.

## Jobs

- **Where is X used:** `find.py xref TEXT` (`--regex`, `--path DIR`, `--expand FILE`). Text shown on screen: `find.py xref TEXT --texts` (after `shots.py flow`).
- **One function:** `find.py func scripts/x.gd func_name`.
- **Which doc, flows and phases for a job:** `find.py route --job door.job` (no args lists doors; `--digest --door D`).
- **Which system owns a file:** `docs.py code-map row --path scripts/x.gd`; edit the row: `docs.py code-map patch --system S --add P`.
- **A tunable:** `docs.py tunable get KEY` (doc row) or `tunable list PREFIX` (code); change it: `docs.py tunable set KEY VALUE --dry-run` (code default + doc cell), then without `--dry-run`; `--set "cell"` patches the doc cell only.
- **Scene nodes:** `find.py scenes --path scenes/x.tscn`. Facade and helpers: `find.py facade scripts/x.gd`.
- **Bytes, BOM, EOL:** `find.py stat PATH` (`--glob`). Funcs per script: `find.py scripts --path P`.
- **What changed / doc vs code:** `find.py changed`; `find.py changed --prior-week`; `find.py changed --since REV`; `find.py changed --history DOC.md SCRIPT.gd`.
- **A tool's last run:** `session.py summary JOB` (no args lists jobs). Long output folds without hiding its source RESULT; `--verbose` prints the full index and summary. A slice of that file or any log: `--match`, `--section`, `--head`, `--tail`, `--list 'GLOB'`. Files that log names: `--files` lists same-stamp artifacts and cited repo paths (no bodies); `--files --read` prints a capped text slice of each and skips images and other binaries. JSON lines, no row dump: `--jsonl --where key=eq:VALUE --group KEY --stat FIELD --pick key,key`. PowerShell compares: `key=ge:N`, `le`, `gt`, `lt`, `ne`, `has`. Single-quote globs and `---` headings. An unquoted `>` redirects. A `.jsonl` path with no filter is refused.
- **Grok sessions:** `session.py dump` (interactive, to clipboard); a share link: `session.py share URL --print-convo`.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `find.py xref` | Text search (case-insensitive) in the current project: `TEXT` or `--pattern`, `--regex`, `--path DIR ...`, `--include GLOB`; many hits print a per-file index (`--expand FILE` for one file); `--texts` searches the shot-flow text dumps (after `shots.py flow`). Skips the Bot's own docs. Summary: `xref`. | D | `--help` | N |
| `find.py func` | One GDScript or Python declaration: `PATH NAME` (or `--path`, `--name`); a missing file or name prints a hint. Summary: `show-func`. | D | `--help` | N |
| `find.py route` | One `routes.yaml` door or job card: `--door D` / `--job door.job` (the one doc to read, smoke phases, shot flows); `--digest` one line per doc or a doc's headings; `--gates` lists gate names and triggers; no args lists the doors. | BD | `--help` | Y |
| `docs.py tunable` | `get KEY` (one line per matching row: file:line, key, Live cell, section; `--verbose` for all fields), `set KEY --set "cell"` (exactly one hit; `--dry-run`), `add NEW --after KEY --set "cell"` on `design/tunables*.md`. Code: `set KEY VALUE [--range] [--changelog "b"]` (default + doc cell), `range KEY MIN MAX [STEP]`, `add KEY --default V --range MIN MAX STEP [--after VAR] [--system S] [--doc-after ROW] [--note] [--cat]` (var, slider, doc row, menu category), `list [PREFIX]`, `diff` (drift; prove runs it). Summaries: `tunable-row`, `tunable-patch`, `tunable-set-code`, `tunable-range`, `tunable-add-code`, `tunable-diff`. | D | `--help` | N |
| `find.py scenes` | `.tscn` nodes and scripts without dumping scenes (`--path`, `--max-nodes`). Summary: `scenes`. | D | `--help` | N |
| `find.py facade` | A facade + its stem-folder helpers by bytes (`FACADE` or `--facade`). Summary: `facade-cluster`. | D | `--help` | N |
| `find.py stat` | Bytes, BOM, CRLF/LF, indent for a path or glob (verify a split kept them); prints the absolute root it read. Summary: `file-stat`. | BD | `--help` | Y |
| `find.py scripts` | Func inventory per `.gd` (`--path`, `--top-funcs`) | BD | `--help` | Y |
| `find.py changed` | Git-changed paths with on-disk bytes (`--scope`, default includes the agents file and `BOT.md`); `--prior-week` lists paths that differ between the previous week seed and this week's seed; `--since REV` lists committed paths from that commit to HEAD; `--history PATH ...` shows each path's recent commits and which is newer (doc vs code); `--head` adds HEAD and the log (on a clean tree, the log only). Summary: `changed`. | D | `--help` | N |
| `session.py summary` | A job's last run: `JOB` (or `--job`) prints the index (newest first) and the newest summary, folded when long but retaining its source RESULT; `--verbose` prints every line; `--selftest` checks this contract; `--run N`, `--index`, `--path`; no args lists jobs. A filter does not print the whole file: `--match`, `--section`, `--head`, `--tail`, `--list GLOB`, `--files` (same-stamp artifacts and cited paths, no bodies), `--files --read` (capped text; images and other binaries skipped), or `--jsonl --where --group --stat --pick`. Compares: `key=value` or `key=ge:N` `le` `gt` `lt` `ne` `has` `eq` (PowerShell-safe; an unquoted `>` redirects). Bad regex, a broken `--where`, a heading of only dashes, or a `.jsonl` path with no filter exits with `error:` and does not print the file. Prints the absolute root it read. | WD | `--help` | N |
| `session.py dump` | Interactive dump of a recent Grok session (chat, events, updates, usage, prompt_context, system prompt, terminal logs) into one .txt on the clipboard. Skips wdb-iso worktrees. | D | `--help` | N |
| `session.py share` | Pull conversation + images from a Grok share URL via Playwright: `URL --print-convo`, `--list-images`, `--save-images DIR [--turn N] [--index 0,2]`; `--headed` once to log in. | W | `--help` | N |
