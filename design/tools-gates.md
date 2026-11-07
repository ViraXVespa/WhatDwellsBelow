# Tools: prove, gates, smokes and warnings

Status: protocol  
Read when: proving a change before a commit or push, running a gate, smoke or warning sweep, committing a Build slice, or a task file  

Choose checks that cover the task. Read their actual `RESULT` and `session.py summary JOB`; preserve red/skipped status. The tools door owns rerun limits and the prove standard owns evidence requirements.

Entries here: `gate.py`, `slice.py`, `bot_status.py`, `local-ai-tuner.py`, `check.py`, `docs.py`, `bake.py`; their code: `tools/lib/bake/`, `tools/lib/checks/`, `tools/lib/docs/`, `tools/lib/gates/`, `tools/lib/slice/`, `tools/lib/tuner/`.

## Jobs

- **Build slice prove (User PC):** `python tools/gate.py gd-load` (read every error) -> `python tools/gate.py build --batch` (`--visual door.job` for a visual change) -> `python tools/slice.py commit`. Red: one corrective edit, one re-run (`tools.md` rule 10).
- **Bot prove:** `check.py prove` (BOT.md Prove).
- **Nightly selftests:** `.github/workflows/selftests-nightly.yml` (08:00 UTC + manual) runs `check.py selftests` on every branch head; one open `tooling-selftests` issue lists failing branch, sha and selftests, closed when all pass. GITHUB_TOKEN only.
- **Docs or routing changed:** `check.py load-graph`. Tool rows or doc paths: `check.py tool-docs`, then `check.py tool-docs --stale-refs`.
- **A tool changed:** `check.py tool-cli --only STEM --smoke-run` (default: every uncommitted or unpushed tool).
- **Smokes:** PC `gate.py smokes --door D` (or `--job door.job`, `--phases 1 2`). Bot box `gate.py bot-smokes --phases 1,2,6` (or `--door D`); `gate.py bot-smokes --for FILE` names the covering phases without running (from `tools/data/phase_loads.json`, what each phase really loaded; `--record-loads` re-records it after code moves between phases).
- **Compile or import errors:** `gate.py gd-load` (`--files A.gd B.gd`, `--all`); editor import and script reload: `gate.py import`.
- **Warnings before/after a change:** `gate.py warnscan --save-baseline B --areas A1,A2`, change, then `gate.py warnscan --non-leak-diff B --areas A1,A2`. In one gate call: `gate.py build --batch --warnscan-baseline B --areas A1,A2`.
- **Release build safety:** `gate.py release` (`--pck DIR` / `--pck-debug DIR` on an export).
- **Task files:** `docs.py task list`, `docs.py task show ID`, `docs.py task new ID --owner build --title T --done-when D --resume R`, `docs.py task update ID --status S`, `docs.py task done ID`.
- **Local playtester and recommend-only tuner:** `python tools/local-ai-tuner.py` trains from decide rows and writes a report. `python tools/local-ai-tuner.py --selftest` needs no Godot. `python tools/local-ai-tuner.py doctor` prints the pip line and does not install. `python tools/local-ai-tuner.py loop` launches the campaign playtest, trains when that delve ends in death, and repeats until stopped. `python tools/local-ai-tuner.py export` and `python tools/local-ai-tuner.py import` move the policy file.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `gate.py build` | Batch gate: import, routing, script names, stripped-release check and bake checks; `--visual JOB` adds mapped flows. Red Build results print retry instructions. Summary: `build-gate`. | BWD | `--help` | Y |
| `gate.py gd-load` | Load changed/untracked scripts with project autoloads. Supports explicit files/base or all scripts; imports first if needed. `--selftest`. Summary: `gd-load-check`. | D | `--help` | N |
| `gate.py import` | Editor import/reload followed by static compilation of live scripts/scenes. Import alone parses no script. Summary: `godot-import-check`. | WD | `--help` | N |
| `slice.py commit` | Require a gate newer than edits, or explicitly record `--gate-skipped WHY` / `--red-gate LOGPATH`. Ignores import churn, takes a message file and never pushes. `--selftest`. | D | `--help` | N |
| `gate.py smokes` | Run PC smoke phases mapped to a door/job or explicitly numbered. Reports shot gaps; the batch gate enforces them. Summary: `smokes`. | D | `--help` | N |
| `gate.py bot-smokes` | Box headless smoke phases; `--for FILE` reports coverage without running. Optional flows/release checks. Fails script errors, smoke failures and false assertions. Setup/import rules remain in BOT.md. | B | `--help` | Y |
| `gate.py release` | Check title/hub/dungeon in release and debug-stripped scratch copies, or inspect export PCKs. Debug scripts must not enter release. `--selftest`. Summary: `release-smoke`. | BD | `--help` | Y |
| `gate.py warnscan` | Warnings by area, with baseline/non-leak comparison. Only areas actually rerun may be marked fixed; new leaks fail. Supports changed scope and real-renderer checks. Summary: `warnscan`. | B | `--help` | Y |
| `bot_status.py` | Bot queues/sizes; `--prove` adds local scope, routing, duplicates, tunables, code-map and relevant doc/drift/text checks. Bot/CI only. | B | `--help` | Y |
| `local-ai-tuner.py` | Recommend-only trainer. `doctor` reports dependencies; live/loop modes launch a playtest. `--selftest` needs no Godot. Policy import/export is explicit. | D | `--help` | N |
| `check.py script-cap` | Duplicate script-name/placement checks. Additional Bot-only checks require `--bot` (BOT.md). | BWD | `--help` | Y |
| `check.py load-graph` | Validate routed docs, phase/flow mappings and references; `--bot` also checks boot budgets. `--selftest`. | BWD | `--help` | Y |
| `docs.py code-map` | Read/patch a system row or check live-script coverage. Missing or newly unmapped scripts fail. | BD | `--help` | Y |
| `check.py tool-cli` | Validate help, output/RESULT contract and flag naming for changed tools. `--only` narrows scope; `--full` checks all; `--smoke-run` runs configured fixture cases. | BWD | `--help` | Y |
| `check.py tool-docs` | Validate catalog ownership/permissions. `--stale-refs` checks dead paths, links, members, flags and branch/skill command drift. Narration findings are advisory. | BD | `--help` | Y |
| `check.py prove` | Plan/run checks from an explicit comparison or the unpushed diff. Detect removed APIs still referenced, unsupported claims and stale descriptions. Use `--plan` before execution; `--base`/`--head` preserve scope. | B | `--help` | Y |
| `check.py selftests` | Run selected or all tool selftests, with timeouts and explicit missing-dependency SKIPs. Requires an unchanged checkout afterward; all-tests may launch runtimes. Summary: `selftests`. | B | `--help` | Y |
| `bake.py check` | Check source/stamp consistency and leak constraints. `--rebake` actually renders a scratch bake; `--record` changes recorded inputs and is not a substitute for a required bake. Summary: `hub-bake`. | BWD | `--help` | Y |
| `check.py load-audit` | Audit a Build session's reads before its first question. Bot/CI only; `--selftest`. | B | `--help` | Y |
| `docs.py task` | List, show, create, update, finish, index and lint task files. Finishing deletes/unblocks the task; do not use it merely because implementation was pushed. | BWD | `--help` | Y |

## Libs and data

No CLI of their own; new code goes into the owner (`tools.md` rule 6). `local-ai-tuner.py` is `tools/lib/tuner/`. Optional packages are `requirements-tuner.txt`. `python tools/local-ai-tuner.py doctor` prints `pip install -r tools/requirements-tuner.txt` and does not install them.

| File (under `tools/`) | Owns |
|---|---|
| `lib/checks/prove_graph.py`, `lib/checks/prove_selftest.py` | `check.py prove` change set, reference graph, drift; its selftest repo |
| `bot_allow.txt` | Local Bot scope: the paths the Bot may change. Deny lines first; the former GitHub bot-gate consumer is retired. |
| `data/release_smoke/` | `release_drive.gd`: the autoload `gate.py release` adds to its scratch project copy (never in the game) |
| `data/prove_rules.json` | Change-to-check selection rules for exploratory proof |
| `lib/checks/stale_cmds.py` | Tool/API/branch command drift checks for the catalog validator |
