# Tools: size, duplicates, dead code, splits and doc edits

Status: protocol  
Read when: running a size, dupe, dead-code, split, relocate or doc-edit tool  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. Bot flows: the Bot job files; doc edit detail: `doc-library.md`.

## Jobs

- **Script sizes:** `check_script_cap.py --bot --sweep` (Bot; `--verbose` for every row). Doc sizes: `list_oversize_docs.py --bot --boot --dupes`.
- **Duplicates:** `list_dupes.py --lang gd --out-md PATH`.
- **Dead code:** `list_unused_funcs.py --limit 30` (report only).
- **Split a script:** `split_funcs.py FILE --list`, write `plan.json`, `split_funcs.py FILE --plan plan.json --dry-run`, then without `--dry-run`.
- **Move a cluster:** `move_script_cluster.py --list-cluster FACADE`, then `--to-dir DIR --dry-run`.
- **Host pitfalls (advisory):** `lint_hostify.py`. Blank lines: `normalize_blanks.py PATH --dry-run`.
- **Doc edits:** `doc_patch.py replace FILE --old A --new B`, `ensure-line FILE --line L`, `replace-file FILE --from-file NEW`, `changelog --bullet "..."`, `apply plan.json`.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `list_dupes.py` | Duplicate finder (read-only): exact / shape / near function clones and repeated line blocks across `scripts/**/*.gd` and `tools/*.py`, ranked by (copies-1) x lines. `--lang gd\|py\|all`, `--min-lines`, `--min-block`, `--top`, `--out-md PATH`. Feeds `design/reuse-map.md`. Summary: `dupes`. | B | `--help` | Y |
| `list_unused_funcs.py` | Dead-code report (`--limit N` rows on stdout): `unused` funcs, `shadowed` (defined in 2+ files, nothing resolves to that def), `decl` (unused const/signal/preload alias), `maybe` (bare-name string only: check by hand); `dynamic` (called by name) counts only. **`--apply` DELETES** unused+shadowed+decl until none are left: only when the opt item says so. Summary: `unused-funcs`. | B | `--help` | Y |
| `list_oversize_docs.py` | Bot-only doc sweep (runs with `--bot`): `design/*.md` by size, `--boot` boot-chain bytes, `--dupes` sentences repeated across docs | B | `--help` | Y |
| `split_funcs.py` | Split a GDScript into the facade + helpers in its stem folder (trimmed unique names; `--dry-run` shows them): `FILE --list`, then `--plan plan.json [--dry-run] [--in-folder]` (`{<stem>_<rest>: [names]}`); node funcs move host-first; runs `facade_requal.py` and a line-multiset check. Flow: grok-bot-size.md. | B | `--help` | Y |
| `facade_requal.py` | Qualify names that moved to helpers (same folder or the facade's stem folder; `FILE`, `--check`, `--dry-run`, `--sym NAME=Mod`). `split_funcs.py` runs it itself. | B | `--help` | Y |
| `move_script_cluster.py` | `git mv` a facade + helpers and rewrite `res://`, bare paths and renamed basenames repo-wide, incl. tools, skills, root docs (`--to-dir`, `--plan plan.json` batch, `--map map.json` exact old->new, `--list-cluster FACADE`, `--dry-run`, `--wrapper`). Only for a user-named relocate job; can touch non-allowlisted docs. | BD | `--help` | Y |
| `lint_hostify.py` | Advisory scan for `:=`/load inference and host pitfalls; always exits 0 (RESULT INFO) | BD | `--help` | Y |
| `normalize_blanks.py` | Collapse consecutive blank lines to one (BOM/EOL kept). Paths or dirs; `--ext`, `--dry-run`. Summary: `normalize-blanks`. | BD | `--help` | Y |
| `doc_patch.py` | Idempotent doc edits. CLI: `replace`, `ensure-line`, `set-read-when`, `changelog`, `next-label`, `write`, `replace-file`, `apply plan.json`, `check` (`--dry-run`, `--eol keep\|crlf\|lf`); also importable (`write_changelog`, `replace_once`, `replace_func`, `upsert_func`). Keeps each file's BOM and line endings. Detail: `doc-library.md`. | BWD | `--help` | Y |
