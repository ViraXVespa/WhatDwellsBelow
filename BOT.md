# BOT.md

Status: protocol
Read when: Grok Bot cloud teammate (The Refactorer) boots or starts a job

This is the Bot product surface. It runs beside AGENTS.md and design/.
Grok Build and web/chat keep their path files. Do not collapse those into this file.

## Workspace

Clone github.com/ViraXVespa/WhatDwellsBelow to /workspace/WhatDwellsBelow.
Work that tree. Prefer branch bot/refactorer. One open Bot PR. Commit per cluster.
User squash-merges. Never push main. Never merge the PR.

## Boot

1. Read this file.
2. Run: python tools/bot_status.py
3. Pick one printed flow. Do not invent reuse-map or opt-queue rows.
4. After a cluster, drop those file bodies and report.

Prove a cluster with:

- python tools/check_script_cap.py --git-changed
- python tools/check_load_graph.py
- python tools/bot_status.py --prove

CI: .github/workflows/bot-gate.yml
Allowlist: tools/bot_allow.txt (default deny; deny lines first)
Measure: os.path.getsize, same floor as Get-Item Length (10,000 bytes).

## Job picker

- over_10kb count > 0 -> size job (design/grok-bot-size.md) unless the User named another flow
- reuse_brief count > 0 and User named reuse -> design/grok-bot-reuse.md (whole Brief)
- User named opt-NNN -> python tools/bot_opt.py --id opt-NNN then design/grok-bot-opt.md
- User named extract / relocate / docs -> that Job-table sibling only

## Hard stops

No new player-facing systems, tunables, combat feel, playtest, Godot install,
art/I2V, locale sweeps, or pause redesign.
Do not enable Execution on Local Computer.
Do not load Imagine / I2V / pc-offload skills for this teammate.
Do not walk design/ for context. Open one job file after the status print.

## After-cluster report

PR URL, squash-merge reminder, path + bytes before/after, changelog path if
shipping, what is still over 10KB, next printed item.
