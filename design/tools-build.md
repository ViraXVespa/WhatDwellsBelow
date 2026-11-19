# Tools: Build session, release and Pages

Status: protocol  
Read when: starting or ending a Build slice, cleaning logs, the week ritual, or a Pages / release tool (User PC / Build only)  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. Runner habits: `pc-offload.md`. Not for the Bot.

Entries here: `slice.py`, `session.py`, `release.py`; their code: `tools/lib/release/`, `tools/lib/session/`, `tools/lib/slice/`.

## Jobs

- **Start a slice:** the User runs `python tools/slice.py open AREA` (or `--task ID`); open seeds and gathers `session-plan.md` and writes `session-context.md` before Build launches. After start, open runs `slice.py gather-pick --chain` (local Ollama role sessions). A pick marks `gather: agent` and the packet inlines those func bodies; the main session writes the Approach from them. A miss keeps the mechanical seed, and the main session closes that index and writes the Approach. The launch still happens. `--seed-only` does not run the chain. It prints each step as it runs. Build changes the index and the Approach only with `slice.py adjust` and writes Outcome, Open questions, Changed files and Latest results as facts land.
- **Necessary visual references:** `slice.py references export`, explicit `grant`, then direct image reads; `status`/`revoke` control the temporary scope.
- **A one-off script:** `session.py py --script _logs/agent-py/x.py` (deleted after the run); prefer a tool.
- **Logs:** `session.py clean` (raw logs), `--new-week` (everything).
- **Web export:** `release.py export-web` (Pages build), `release.py export-web --debug --out DIR` (debug build for perf or hitch work).
- **Week and pins:** `release.py week-start` (Build, `build-week-start.md`), `release.py week-pin --web N` / `--build N`; CI runs `release.py ci-archive`.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `slice.py open` | **User-run launcher** (PowerShell), never run by Build: `python tools/slice.py open [AREA] [--task ID \| --prompt TEXT \| --prompt-file PATH] [--ref REF \| --in WT] [--no-gather \| --review \| --seed-only] [--dry-run]` creates a worktree from `grok-build-w{N}` (`grok worktree create`) and starts `grok --cwd PATH --trust [-s SID] [PROMPT]` there. For a door or job, unless `--no-gather` (gathering off: no `-s`, no packet, the session runs `slice.py start` itself), it first runs `slice.py start` for that session, then `slice.py gather-pick --chain`, then `expand --check`, and writes `session-context.md`. A pick inlines the marked func bodies (`gather: agent`); a miss keeps the mechanical seed and the main session closes that index. Either way the launch continues. A halt file or a failed check refuses the launch. It prints each prepare step as it starts; `--launch WT` resumes after `--review` (`--launch WT --review`: check, packet and report only). `--seed-only` stops after start and the seed for a hand gather; `--in WT` reuses an existing slice worktree (its branch is the ref). After create, junctions `worktree/addons` to this checkout's gitignored `addons/` (the Godot AI Asset Library install) so the plugin loads. Copies only if the junction cannot be created. A missing `addons/` is reported and the launch still proceeds. Remove the worktree with `grok worktree rm` or `git worktree remove`, which drops the junction and leaves the checkout install. Prints the commands first; no grok on PATH: prints them to copy, exit 1. AREA is checked against the doors. `--selftest`. Summary: `open-slice`. | D | `--help` | N |
| `slice.py references` | Necessary direct visual references for an active Build task: `export --task ID --bible FILE [--walk-dir DIR] [--out DIR]`, `grant --task ID --reason TEXT --path FILE` (repeat) or `--manifest FILE`, `status`, `revoke`. Exact content-bound read-only images, original session/unit, 2-hour expiry; no shell or generation exception. `--selftest` uses synthetic fixtures. Summary: `reference-access`. | D | `--help` | N |
| `slice.py start` | First command inside a slice worktree: the door card (phases, shot flows, STEP 0 note, job cycle, first-message rules, session facts). First run writes `_logs/slice-state.json` and records the original session id for a retry; a later run prints `SLICE ALREADY STARTED` (`--full` reprints). A named door or job also writes the `session-plan.md` seed when missing (`slice.py open` runs this start). `--door D` / `--job door.job` / `--task ID`; a `unit_queue` door starts its next unit, `--unit-done` marks it. Survey -> implement: `--handoff`, then `--from-handoff PATH` or `--from-task ID`. `--failed` prints `Did not work:` lines. In a main checkout it only points to `slice.py open`. `--selftest`. Summary: `slice-boot`. | D | `--help` | N |
| `slice.py plan` | Mechanical seed of the gitignored `session-plan.md` context index (Identity, Core, Candidates with `when:`, Card; format in tools-libs.md). Existing file kept; `--refresh` re-seeds and replays `_logs/gather/delta.jsonl` (`--clean` drops it); the sections above the marker are kept (Outcome, Open questions, Changed files, Latest results, Approach). Not a worktree: fails. `--dry-run`, `--selftest`. Summary: `session-plan`. | D | `--help` | N |
| `slice.py adjust` | The only writer of the index: `add-func/add-file/add-doc/add-names`, `rem`, `promote`, `demote ID TEXT` / `set-condition ID TEXT` (or `--when TEXT`), `batch FILE\|-` or `batch --op OP ...`, `approach --text` (replaces `## Approach`, max 4000 characters), `report --text [--halt]`; `--lines A-B` ranges for files and docs (several per path); ops by `WDB_ROLE=gather` mark the identity `gather: agent`; each op logs a delta row in the same step; errors always print in full (also `--dry-run`), applied ops fold after 12 (`--verbose`), `--json` adds `done` and `error_text`. `--selftest`. Summary: `plan-adjust`. | D | `--help` | N |
| `slice.py expand` | Packet from the index: Approach and the other kept notes, core bodies with their why-notes, candidates with conditions. The default budget pastes the core; `--budget` still lists the rest as over budget. `--check` validates and writes nothing; `--out session-context.md`; `--only ID,...`; `--budget`. `--selftest`. Summary: `plan-expand`. | D | `--help` | Y |
| `slice.py gather-pick` | Local-model func pick. `open` runs `--chain` after start; `--seed-only` does not. A miss keeps the mechanical seed and open still launches. Names-only mode offers at most 8 scripts (task, job doc, door code-map) and asks Ollama for JSON `{"edit":[...]}` with tools off. `--chain` offers the whole door code-map, paged, with no file cap. Fresh sessions share the session plan: scout (which scripts on this page must change), mark (funcs in one file), follow (callees whose bodies must change), gap (a required behavior with no mark), trim (drop a neighbor func), review (drop a neighbor file, never one func). A pick that passes the check sets `gather: agent`. Role text is `tools/data/gather/skills/scout.md`, `tools/data/gather/skills/mark.md`, `tools/data/gather/skills/follow.md`, `tools/data/gather/skills/gap.md`, `tools/data/gather/skills/trim.md`, and `tools/data/gather/skills/review.md`. The conductor writes `slice.py adjust` between sessions. A runaway guard stops a chain that does not finish and keeps marks when a core func remains. Invalid JSON on scout or mark restores the mechanical seed (`gather: seed`). Writes no Approach. `--task`, `--model`, `--dry-run`, `--selftest` (stub model). Summary: `gather-pick`. | D | `--help` | N |
| `session.py py` | Run a one-off script from `_logs/agent-py/` (`--script PATH [args]`) and delete it after (`--keep-script` keeps it). Prefer a real tool. Summary: `agent-py`. | D | `--help` | N |
| `session.py clean` | Delete raw logs under `_logs/` (`--max-age-hours`, `--keep-raw`); `--new-week` also every stamped summary and index. Summary: `clean`. | D | `--help` | N |
| `release.py export-web` | Export the GitHub Pages build (Godot Web, no threads; runs `release.py mips` before `--import`). `--archives` adds the `_pages/` site; `--out DIR` exports to a scratch dir; `--debug --out DIR` uses preset `Web Debug` (keeps `scripts/debug/`; release `Web` excludes it). | D | `--help` | N |
| `release.py week-start` | Week start from main: seed `epoch.N.0`, branch `grok-build-w{N}` + seed commit, `grok worktree gc`, locks, logs; pins a missing closing-week row. A seed-commit failure returns `RESULT FAIL reason=seed-commit` before gc and clean. Off `main`, `RESULT FAIL reason=not-main`: check out `main` and resume at step 1; do not read the other branch to diagnose it. Build only, at a new week (`build-week-start.md`). | D | `--help` | N |
| `release.py week-pin` | Catalog row, notes, local tag: `--web N`, `--build N`, `--id`. Idempotent. | D | `--help` | N |
| `release.py ci-archive` | CI: a merge adding `design/changelog/0.N.0.md` pins web + build week N (tags, rows, docs) and pushes. `--dry-run`, `--selftest`. | D | `--help` | N |
| `release.py changelog` | Rewrite `scripts/data/changelog.json` from the current series' flat `design/changelog/*.md`. The Bot writes entries with `doc_patch`, not this. | BD | `--help` | Y |
| `release.py mips` | Turn on mipmaps for 3D world PNGs (`--dry-run`). | D | `--help` | N |
| `release.py archives` | Export pinned catalog archives into a Pages site directory | D | `--help` | N |
| `release.py pages-hash` | Hash game-affecting paths so Pages can skip a full Godot export | D | `--help` | N |
| `release.py notes-site` | Copy baked version/changelog JSON onto the Pages site as loose /data files | D | `--help` | N |
| `release.py postexport` | Stamp a Godot Web export. Cache id follows the binary, not the notes label | D | `--help` | N |
| `session.py scratch-server` | Token-protected local HTTP runner for web/chat scratch. User setup only. | WD | `--help` | N |

## Libs and data

No CLI of their own; new code goes into the owner (`tools.md` rule 6).

| File (under `tools/`) | Owns |
|---|---|
| `data/web_shell.html` | Web export HTML shell |
| `lib/slice/reference_access.py` | Task-scoped reference CLI, `slice.py references` |
| `lib/slice/reference_policy.py` | Shared CLI/hook grant validation: task, session, unit, path, content and expiry |
| `lib/slice/reference_export.py` | Native Bible cells and walk copies with source/crop provenance |
| `lib/slice/reference_access_test.py` | Synthetic grant, export and hook fixtures |
| `lib/slice/build_docs_test.py` | Build operating-doc consistency, context rule, reference guidance and size regressions; run by start selftest |
