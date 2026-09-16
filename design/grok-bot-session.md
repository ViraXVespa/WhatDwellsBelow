# Grok Bot session door

Status: protocol  
Read when: Grok Bot path; every Grok Bot session  

This file is binding for **Grok Bot** only. Grok Build and web / chat ignore it, except they may open `design/refactor.md` when they split for the 10KB cap.

Grok Build / web splitting one file that *its own edit* pushed over 10KB is not this path — use `design/refactor.md` inside that session (recipe only; do not open this door from the recipe).


## Recognize

Use this path when the User names Grok Bot / a refactor sweep / a Bot flow below, or when a Grok Bot / Cursor desktop assistant writes via GitHub PR.

After the agents file, load **this door**, then **one** Job-table sibling. When editing GDScript, also load `design/gdscript-law.md`. The sibling starts at itself + the named recipe + one `design/code-map.md` row. Do not load the other flow files. Do not load the web/Build requires pair, the web/Build requires pair, the web path file, the Build path file, `design/sessions.md`, `design/session-log.md`, or `design/changelog/` except the one new `{label}` file at ship time. Never open `notes/`.
Second topic door: ask the User to name the owner first. If `conflicts_with` lists the pair, do not open the second door in this slice.

## Job → Open

| Job | Open |
|-----|------|
| Size sweep (over 10KB, then 5KB when whole functions can move) | `design/grok-bot-size.md` |
| Ad-hoc extract / existing-owner routing (User-gated; not the staged map) | `design/grok-bot-extract.md` |
| Staged reuse-map brief as one PR | `design/grok-bot-reuse.md` |
| Parked / named folder relocate | `design/grok-bot-relocate.md` |
| Doc facade / sibling split | `design/grok-bot-docs.md` |

If the User names more than one job, ask which flow this session is. One flow, one PR, then stop.

## Shared ship

- One open Bot PR at a time. Do not claim a write landed until the PR exists.
- Prefer one commit on the PR branch. Tell the User to **squash-merge** into `main` (not merge-commit or rebase-merge). After squash-merge: stop. CI stamps. Do not offer a post-merge stamp commit.
- One new `design/changelog/{label}.md` when the sweep is ready to land. Label math and body shape: `design/versioning-log.md`. Do not read older changelog files. Do not hand-edit `scripts/data/version.json` or `scripts/data/changelog.json`.
- Touched live `scripts/**/*.gd` must ship under 10KB. Split with `design/refactor.md` (recipe only). The under-5KB target is only `design/grok-bot-size.md`.
- Caps are on-disk UTF-8 file sizes (`Get-Item Length` / `dir`). Do not measure with `ReadAllText` + `Encoding.UTF8.GetByteCount`.
- PC offload: skill `.grok/skills/pc-offload/SKILL.md` then `design/pc-offload.md`. Prefer Length summaries over opening untouched siblings.
- New `tools/` runners: propose first; implement only after the User approves that runner this session.
- Local size sweeps: prefer checkout at `WDB_ROOT` (example: `C:\Users\Vira\source\repos\WhatDwellsBelow`). Document a `WDB_ROOT` change here only if that path itself changed. Commit locally per cluster; push the PR branch when the cluster is done.
- Minimum compile wiring on a moved line is allowed: `load()` / `preload()`, a one-line facade delegate, `host` / `pt` / `ui` / `p` on a moved `static func`, and `: Type` on a line already being moved.
- After each cluster report: PR URL, squash-merge reminder, path + bytes before/after, changelog path if shipping, what is still over cap, next cluster.

## Shared do not

- Features, tunables, new game systems, game skills, rarities, hub upgrades, co-op, art / I2V.
- Copying Imagine / I2V skills into `.cursor/skills/`.
- Invented numbers.
- Behavior changes, drive-by renames, comment rewrites, wholesale retypes, reformats.
- `Entity.gd`, a UI framework, ECS, or flattening hostify clusters back into one oversized script.
- Growing an existing owner just to avoid a new file. Treating vaguely similar features as near-identical.
- Archives pins. Copying a pinned commit into `archives/` as a project tree.
- Opening `design/reuse-map.md` except from `design/grok-bot-reuse.md` when that brief is not the empty template. Do not ignore a `design/reuse-map.md` do-not-merge row.
- Declaring the whole sweep done and then starting a second flow.
- Editing design markdown or multi-line Python via PowerShell double-quoted strings or `python -c` (use `tools/write_utf8_file.py` / `tools/run_agent_py.ps1`).
- Leaving ephemeral agent scripts outside `_logs/agent-py/` or skipping cleanup.
