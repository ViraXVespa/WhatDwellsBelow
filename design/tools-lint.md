# Tools: size, duplicates, dead code, splits and doc edits

Status: protocol  
Read when: running a size, dupe, dead-code, split, relocate or doc-edit tool  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. Bot flows: the Bot job files; doc edit detail: `doc-library.md`.

Entries here: `lint.py`, `check.py`, `docs.py`; their code: `tools/lib/checks/`, `tools/lib/docs/`, `tools/lib/lint/`. `lint.py dupes` helpers: `tools/lib/lint/dupes_clone.py` (run / clone finder), `tools/lib/lint/dupes_gate.py` (gate, exceptions, selftest).

## Jobs

- **Script sizes:** `check.py script-cap --bot --sweep` (Bot; `--verbose` for every row). Doc sizes: `check.py docs-size --bot --boot --dupes`.
- **Duplicates:** `lint.py dupes` (summary first; `--out-md PATH` for the ranked list); the Bot gate is `lint.py dupes --gate` (run by `bot_status.py --bot --prove`).
- **Dead code:** `lint.py unused --limit 30` (report only).
- **Split a script:** `lint.py split FILE --list`, write `plan.json`, `lint.py split FILE --plan plan.json --dry-run`, then without `--dry-run`.
- **Move a cluster:** `lint.py move --list-cluster FACADE`, then `--to-dir DIR --dry-run`.
- **Host pitfalls (advisory):** `lint.py hostify`. Blank lines: `lint.py blanks PATH --dry-run`.
- **Doc edits:** `docs.py patch replace FILE --old A --new B`, `ensure-line FILE --line L`, `replace-file FILE --from-file NEW`, `changelog --bullet "..."`, `apply plan.json`.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `lint.py dupes` | Duplicate finder over every live `.gd` (`scripts/**`, `tools/data/**`) and `tools/**/*.py` (not `tools/retired`): exact / shape / near function clones, `block` / `nblock` line blocks, `run` (4+ adjacent calls differing only in literals or signs, one file) and `clone` (6+ lines equal once literals, signs and local names are masked; one file or across files). Summary first (counts, finding files, top files), then rows ranked by (copies-1) x lines, each with a stable `key`. Not counted: module-header lines (imports, preloads, the `tools/lib` bootstrap) and pure output sinks (`add_argument` / `print` / `append` of literals). `--gate`: every run and every row scoring `--gate-score` (12)+ must be refactored or listed with a `why` in `tools/data/dupes_allow.json`; new or stale keys FAIL. `--selftest`: the pre-fix stall builder fixture (`tools/data/dupes-fixture/`) must be flagged. `--lang`, `--min-lines`, `--min-block`, `--min-run`, `--min-clone`, `--top`, `--out-md PATH`. Summary: `dupes`. | B | `--help` | Y |
| `lint.py unused` | Dead-code report (`--limit N` rows on stdout): `unused` funcs, `shadowed` (defined in 2+ files, nothing resolves to that def), `decl` (unused const/signal/preload alias), `maybe` (bare-name string only: check by hand); `dynamic` (called by name) counts only. **`--apply` DELETES** unused+shadowed+decl until none are left: only when the opt item says so. Summary: `unused-funcs`. | B | `--help` | Y |
| `check.py docs-size` | Bot-only doc sweep (runs with `--bot`): `design/*.md` by size, `--boot` boot-chain bytes, `--dupes` sentences repeated across docs | B | `--help` | Y |
| `lint.py split` | Split a GDScript into the facade + helpers in its stem folder (trimmed unique names; `--dry-run` shows them): `FILE --list`, then `--plan plan.json [--dry-run] [--in-folder]` (`{<stem>_<rest>: [names]}`); node funcs move host-first; runs `lint.py requal` and a line-multiset check. Flow: grok-bot-size.md. | B | `--help` | Y |
| `lint.py requal` | Qualify names that moved to helpers (same folder or the facade's stem folder; `FILE`, `--check`, `--dry-run`, `--sym NAME=Mod`). `lint.py split` runs it itself. | B | `--help` | Y |
| `lint.py move` | `git mv` a facade + helpers and rewrite `res://`, bare paths and renamed basenames repo-wide, incl. tools, skills, root docs (`--to-dir`, `--plan plan.json` batch, `--map map.json` exact old->new, `--list-cluster FACADE`, `--dry-run`, `--wrapper`). Only for a user-named relocate job; can touch non-allowlisted docs. | BD | `--help` | Y |
| `lint.py hostify` | Advisory scan for `:=`/load inference and host pitfalls; always exits 0 (RESULT INFO) | BD | `--help` | Y |
| `lint.py blanks` | Collapse consecutive blank lines to one (BOM/EOL kept). Paths or dirs; `--ext`, `--dry-run`. Summary: `normalize-blanks`. | BD | `--help` | Y |
| `docs.py patch` | Idempotent doc edits. CLI: `replace`, `ensure-line`, `set-read-when`, `changelog`, `next-label`, `write`, `replace-file`, `apply plan.json`, `check` (`--dry-run`, `--eol keep\|crlf\|lf`); also importable (`write_changelog`, `replace_once`, `replace_func`, `upsert_func`). Keeps each file's BOM and line endings. Detail: `doc-library.md`. | BWD | `--help` | Y |
