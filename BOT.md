# BOT.md

Status: protocol
Read when: Grok Bot (The Refactorer) boots or starts a job

This is the only Bot constitution. Grok Build and web/chat keep their path files.
Do not collapse those into this file.
Second topic door: ask the User to name the owner first. If `conflicts_with` lists the pair, do not open the second door in this slice.

## Workspace

Clone github.com/ViraXVespa/WhatDwellsBelow to /workspace/WhatDwellsBelow.
Work that tree. Prefer branch bot/refactorer. One open Bot PR. Commit per cluster.
User squash-merges. Never push main. Never merge the PR.

## Boot

1. Read this file. If the agents file already routed you here, do not fetch it again.
2. Run: python tools/bot_status.py
3. Pick one printed flow. Do not invent reuse-map or opt-queue rows.
4. Open only that Job file. When editing GDScript, also load `design/gdscript-law.md`.
5. After a cluster, drop those file bodies and report.

| Job | Open |
|-----|------|
| Size sweep (over 10KB, then 5KB when whole functions can move) | `design/grok-bot-size.md` |
| Ad-hoc extract / existing-owner routing (User-gated; not the staged map) | `design/grok-bot-extract.md` |
| Staged reuse-map brief as one PR | `design/grok-bot-reuse.md` |
| Parked / named folder relocate | `design/grok-bot-relocate.md` |
| Doc facade / sibling split | `design/grok-bot-docs.md` |
| Named optimization item from the parked queue | `design/grok-bot-opt.md` |

If the User names more than one job, ask which flow this session is. One flow, one PR, then stop.

Prove a cluster with:

- python tools/check_script_cap.py --git-changed
- python tools/check_load_graph.py
- python tools/bot_status.py --prove

CI: .github/workflows/bot-gate.yml
Allowlist: tools/bot_allow.txt (default deny; deny lines first)
Measure: os.path.getsize, same floor as Get-Item Length (10,000 bytes).
Touched live `scripts/**/*.gd` must ship under 10KB. Split with `design/refactor.md` (recipe only).
The under-5KB target is only `design/grok-bot-size.md`.
One new `design/changelog/{label}.md` when the sweep is ready to land. Label math: `design/versioning-log.md`.
Do not hand-edit `scripts/data/version.json` or `scripts/data/changelog.json`.
Do not open `design/reuse-map.md` except from `design/grok-bot-reuse.md` when that brief is not the empty template.

New `tools/` runners: propose first; implement only after the User approves that runner this session.
Minimum compile wiring on a moved line is allowed: `load()` / `preload()`, a one-line facade delegate, `host` / `pt` / `ui` / `p` on a moved `static func`, and `: Type` on a line already being moved.

Windows desktop checkout only: pc-offload skill then `design/pc-offload.md` when measuring. Cloud VM does not load that skill.
Do not port the `.ps1` catalog to bash.

## Hard stops

No new player-facing systems, tunables, combat feel, playtest, Godot install,
art/I2V, locale sweeps, or pause redesign.
Do not enable Execution on Local Computer.
Do not load Imagine / I2V / pc-offload skills for the cloud teammate.
Do not walk design/ for context beyond this file and the one Job file.
Do not pin weeks or run week-boundary scripts.
Do not invent numbers.
Do not copy Imagine / I2V skills into `.cursor/skills/`.
Behavior changes, drive-by renames, comment rewrites, wholesale retypes, reformats
are out unless a User-named `design/grok-bot-opt.md` item lists that change.
No `Entity.gd`, UI framework, ECS, or flattening hostify clusters back into one oversized script.
Do not declare the whole sweep done and then start a second flow.

## After-cluster report

PR URL, squash-merge reminder, path + bytes before/after, changelog path if
shipping, what is still over 10KB, next printed item.
