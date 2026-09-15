# Grok Bot session flow

Status: protocol  
Read when: Grok Bot path; every Grok Bot / refactor-sweep session  
See also: `AGENTS.md`, `design/refactor.md`, `design/doc-refactor.md`, `design/README.md`, `design/versioning.md`, `design/pc-offload.md`

This file is binding for **Grok Bot** only. Grok Build and web / chat ignore it, except that they may open `design/refactor.md` when they split for the 10KB cap.

Grok Bot writes via **GitHub PR** (cloud agent when available, or GitHub connector). Primary job: refactor sweeps of live `scripts/**/*.gd` and topic design markdown facades (`design/doc-refactor.md`). Grok Build writes behavior features.

## Recognize

Grok Bot / Cursor desktop assistant writing via GitHub PR, **or** the User named a Grok Bot path / Grok Bot refactor sweep. If a Grok path is asked only to split one file that *its own edit* pushed over 10KB, that is not this path — use `design/refactor.md` inside the current Grok session.

## Read set

Load only:

1. `AGENTS.md`
2. This file
3. `design/refactor.md` (script splits) and/or `design/doc-refactor.md` (documentation facades) for the active sweep kind
4. The `design/README.md` **code map** or topic index row for the cluster about to be edited
5. After the inventory: only the live `.gd` files **or** design siblings in that one cluster (never the whole topic tree)
6. When authoring the PR changelog: baked `scripts/data/version.json` (for `{label}` = patch + 1) and `design/versioning.md` body shape — not the whole `design/changelog/` tree

Script sweep: do not read unrelated topic files, `design/sessions.md`, `design/session-log.md`, or older changelog entries. Doc facade sweep: open the topic **door** plus only the sibling named by its job table.

Do not read `design/protocol.md` beyond a pointer, `design/constraints.md`, `Demo_GDD.md`, `design/web-session.md`, or `design/grok-build.md` unless the User named that work.

If a move would change player-visible behavior or fight binding design, stop and ask. Do not load the corpus to invent a reason to continue.

## Mandate

Sweep the whole live script tree. Not a feature slice. Not “only these files” unless the User overrides the worklist.

**In scope:** shipping `scripts/**/*.gd` (size / extract / folder moves per `design/refactor.md`); topic `design/*.md` facade splits per `design/doc-refactor.md` (no binding-meaning change).

**Out of scope:** `scenes/`, `assets/`, `tools/` (unless a preload path update or a listed PC-offload/doc inventory runner is required), `archives/`, pinned commits, `project.godot` (unless required to register a moved script), and any file under a pinned archive. Other `design/` edits stay limited to the code map / topic index row, this protocol family, `doc-refactor.md`, and the one new `design/changelog/{label}.md` per PR.

**Refactor only.** No features, tunables, new game systems, skills, rarities, hub, co-op, or art / I2V. Rearrange existing code only. May add `: Type` on lines already moved so Godot compiles.

Size: **10KB** ship floor; under-**5KB** sweep target when whole existing functions can move. Doc soft caps: `design/doc-refactor.md`.

Prefer **NEW shared modules** when near-identical control flow spans places (renamed locals OK; not vaguely similar features). Example: tooltip placement across Anvil / Analyze / Forge / Inventory. Point at an existing owner only if it already **is** that concern **and** the addition will not blow the size cap. Never grow an owner just to avoid a new file.

Parked folder moves from `design/refactor.md` plus User-named deeper relocates are their own batches; no behavior change. Prefer `tools/move_script_cluster.ps1` / `.py`; read `_logs/move-cluster/summary.txt`.

## Inventory

Before opening bodies:

1. Scripts: `tools/list_oversize_scripts.ps1` (filesystem Length). Docs: `tools/list_oversize_docs.ps1`; skip `design/changelog/`.
2. Rank: over 10KB; over 5KB; extract candidates (near-identical spanning places → new shared module); existing-owner reuse that still fits; parked / User-named relocates; docs over ~12KB / ~8KB facade candidates.
3. Show the ranked worklist. Do not edit yet.

Files already under the relevant cap are not split “for cleanliness.”

## Pass order

1. Size — over **10KB** first, then over **5KB** when existing functions can move
2. Extract to **new shared modules**
3. Existing owners only when they already own the concern and still fit
4. Parked folder moves / User-named deeper relocates
5. Documentation facades / sibling splits

## Commits and versioning

`.github/workflows/version.yml` sets `patch` = baked patch + **count of user commits** on `main` since `scripts/data/version.json` last changed (ignores `chore: stamp …` and any `[skip ci]` subject). One push that lands **N** non-stamp commits bumps patch by **N**.

**Size sweeps (over-10KB then over-5KB) ship as one PR** for the whole size worklist. Keep one branch; squash-merge once when the User says the size sweep is complete. One changelog and one code-map pass at end. Extract / new-module clusters remain User-gated and can be separate PRs later.

Every Grok Bot PR MUST:

1. Prefer **one commit** on the PR branch when tools allow; multiple branch commits are OK if the User **squash-merges** once.
2. Tell the User to **squash-merge** into `main` (not merge-commit or rebase-merge).
3. Include **one** new `design/changelog/{label}.md` when the sweep is ready to land. `{label}` = baked `version.json` `label` with patch + 1. First player-facing heading MUST be `## {label}`. MUST NOT use `# {label}`. Body shape: `design/versioning.md`. Do not hand-edit `changelog.json` or `version.json`.
4. Agent-visible protocol/doc changes also get a changelog entry.

After squash-merge, **stop**. CI stamps and tags. Do not create, amend, or offer a post-merge stamp commit. One open Bot PR at a time. Do not claim a write landed until the PR exists.

## Local checkout (preferred for size sweeps)

When the User has authorized a local checkout:

- Prefer that checkout over per-file GitHub API patches.
- Root path: user env var `WDB_ROOT` (example: `C:\Users\Vira\source\repos\WhatDwellsBelow`). Document any change to that path here.
- Commit locally on the size-sweep branch as you go. **Push to the PR branch only after a phase's updates are finished**, unless the User says otherwise.
- Use the GitHub connector mainly for PR remote sync / status.
- Cloud Agents remain optional; if the plan blocks them, local checkout + Steam Godot headless is the compile path.

## Size measurement

Shared catalog: `design/pc-offload.md`. Prefer those runners; read only `_logs/*/summary.txt`. Windows body writes: `tools/write_utf8_file.py` + ephemeral `tools/run_agent_py.ps1` (auto-deletes under `_logs/agent-py/`). Never `python -c` for multi-line patches.

Preferred: `powershell -File tools/list_oversize_scripts.ps1` (optional `-OverKb 5` or `10`) → `_logs/oversize/summary.txt`. Func / split planning: `tools/summarize_scripts.ps1` → `_logs/script-summary/summary.txt`. Facade siblings: `tools/list_facade_cluster.ps1 -Facade scripts/.../foo.gd` → `_logs/facade-cluster/summary.txt`. Cap check: `tools/check_script_cap.ps1` → `_logs/script-cap/summary.txt`.

Inventory and before/after sizes use **filesystem byte length** (`Get-Item Length`, `dir`). Do **not** `ReadAllText` + `Encoding.UTF8.GetByteCount` just to measure. The 10KB / 5KB caps are on-disk UTF-8 file sizes.

## Headless compile check

After facade / helper splits (or when the User asks), run Godot against the local checkout **the way the editor reloads scripts**. Plain game boot is not enough.

- Binary (Steam tools build): `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe` (also referenced from `tools/export_web.ps1`).
- **Required check:** `--headless --editor --import --path <WDB_ROOT> --quit` — runs `first_scan_filesystem` and catches GDScript parse errors (including `:=` inference) that plain `--path ... --quit` can miss.
- Preferred: `powershell -File tools/run_godot_import_check.ps1` (optional `-TimeoutSec 180`) → `_logs/godot-import-check/summary.txt`.
- Phase smokes: after import is clean, `--headless --display-driver headless --audio-driver Dummy --path <WDB_ROOT> -- --wdb-phaseN-smoke` per `design/debug.md`. Plain `--headless` without those drivers can hang under redirected IO. Do not treat smoke stderr as the editor-clean bar, or a plain `--quit` boot as a smoke pass.
- Preferred smokes: `powershell -File tools/run_smokes.ps1` (optional `-Phases 1,2,6`, `-TimeoutSec 120`) → `_logs/smokes/summary.txt`.
- Preferred post-split gate: `powershell -File tools/run_post_split_gate.ps1` (optional `-WithSmokes`, `-Phases 1,2,6`, `-Force`) → `_logs/post-split-gate/summary.txt`. Refuses if Godot is already running unless `-Force`.
- Advisory hostify lint: `tools/lint_hostify.ps1` / `python tools/lint_hostify.py` → `_logs/hostify-lint/summary.txt`. Always exits 0; read `RESULT hits=`. Catches `SHADOW_HOST`, `INFER_LOAD`/`INFER_FAC`/`INFER_GET`, unqualified `MOTION_MODE_*` on non-CharacterBody helpers, corrupt `str(n)ame`, trailing `host, )`. Not a compile substitute.
- Capture stdout and stderr (GUI-subsystem exe: `Start-Process -RedirectStandardOutput/-RedirectStandardError`). Clean bar: import check exit 0 **and** empty stderr.
- Cascade tip: `Could not resolve class "res://.../foo.gd"` often means **foo** (or a preload it owns) failed to parse. A load-probe that `load()`s each dependency in order surfaces the real error first.
- Autoload `App` may look "missing" when loading scripts via `--script` outside a full project boot; prefer the editor import check.

Document new split-induced failure modes under `design/refactor.md` (Hostify pitfalls) when they are not already listed. When a split introduced an error/warning, stop to record **why** and **how to prevent it** before continuing.

## Flow

1. Orient (Recognize + Read set).
2. Inventory (Length sizes; rank; show; don’t edit yet).
3. **Size** clusters may auto-chain on one branch / one PR while anything over 10KB remains, then over 5KB. **Extract** / new-module / parked-move / deeper-relocate clusters always wait for User go.
4. After each size cluster: run the editor import check. If the split introduced any SCRIPT ERROR, parse error, or new actionable warning, stop — fix it and record the prevention under `design/refactor.md`. Do not continue past a red import check.
5. Include `design/changelog/{label}.md` once when the size sweep is ready to land.
6. Report after each cluster / push batch.
7. Code-map pass once at end of the size sweep. Pure refactor: no `design/sessions.md`, no `design/session-log.md`.
8. End when the User stops or the worklist is empty.

## Batch

**Size:** one facade plus siblings per editing focus; same branch / same PR until over-10KB then over-5KB are clear. If a single existing function is itself over 5KB, leave that function whole and report it. Never leave a touched file over 10KB if a legal split can fix it.

**Extract / relocate:** one cluster per batch, User-gated.

1. Open only that cluster’s bodies.
2. Apply `design/refactor.md` (including shared-module rules).
3. Push to the shared size-sweep branch and update the one PR, or stop for User go on extract / relocate.

## Report

After each cluster, tell the User:

- PR URL (required before claiming the write landed)
- Reminder to **squash-merge** (CI stamps afterward; Bot does not)
- files changed (path + bytes before / after)
- changelog path (`design/changelog/{label}.md`)
- new sibling helpers or new shared modules (moved code only)
- reuse call sites now pointing at an existing owner (only when that owner fit)
- what is still over 10KB, still over 5KB, extract candidates still open, or still duplicated with no fit
- the next cluster on the ranked list

Optional: `_logs/grok-bot-sweep.md` (gitignored). Do not write `design/sessions.md` or `design/session-log.md`.

Ask before extract / relocate clusters.

## Allowed

- Move existing functions into a new sibling helper because of size
- Create a **new shared module** when near-identical control flow spans places
- Add the minimum wiring so the project compiles: `load()` / `preload()`, a one-line facade delegate, `host` / `pt` / `ui` / `p` on a moved `static func`
- Change call sites to an existing shared function **only** when that owner already is the concern and stays under the cap
- Add `: Type` on a line already being moved (`AGENTS.md` → GDScript types)
- Update the `design/README.md` code map row when a split adds a sibling or shared module
- Parked folder moves and User-named deeper relocates as their own batches
- Author one `design/changelog/{label}.md` per shipping PR

## Forbidden

- Features, tunables, new game systems, skills, rarities, hub work, co-op, art / I2V
- Growing an existing owner just to avoid a new file; treating vaguely similar features as near-identical
- Behavior changes, drive-by renames, comment rewrites, wholesale retypes, reformats
- Reading or updating `design/sessions.md` or `design/session-log.md` on a pure refactor sweep
- Shipping a PR without `design/changelog/{label}.md` when the goal lands on `main`
- Starting that changelog with `# {label}` instead of `## {label}`
- Landing multiple user commits on `main` for one PR
- Archives pins; paste-emitting bodies; claiming a write landed before the PR exists
- Hand-editing `scripts/data/version.json` or `scripts/data/changelog.json`; offering a post-merge stamp commit
- Editing design markdown or multi-line Python via PowerShell double-quoted strings or `python -c` (use `tools/write_utf8_file.py` / `tools/run_agent_py.ps1`)
- Leaving ephemeral agent scripts outside `_logs/agent-py/` or skipping cleanup for files under that folder
- Declaring the whole sweep done and then starting a second kind of task

## End

The sweep is finished when the User says so, or when the worklist has no remaining legal size / extract / reuse / relocate cluster. Report that. Stop. The next goal is a new session.
