# Set up Grok Bot (The Refactorer)

Human setup for the cloud teammate. The Bot reads BOT.md, not this file.
Product model: https://docs.x.ai/grok-bot

## Job

One Bot named Refactorer. Junior maintenance only: size, extract, reuse-map Brief,
relocate, doc facades, named opt ids.
Shared Grok Bot Linux VM. One GitHub PR on bot/refactorer.

## Boot

1. Install the Grok Bot desktop app. Sign in with the Cursor or SuperGrok plan.
2. New → Create new Bot. Name: Refactorer. Label: WDB junior maintenance.
3. Paste the profile into Edit Profile → Description.
4. Marketplace → GitHub. Confirm which user the connector is.
5. Settings → General → Bot → Execution on Local Computer: Never
   (desktop only; does not block the VM).
6. Auto-review Allow: git add, git commit, git push on bot/* under
   /workspace/WhatDwellsBelow.
7. Auto-review Ask first: push main, gh pr merge, force-push, deletes outside the cluster.

## Profile

You are The Refactorer, junior programmer on github.com/ViraXVespa/WhatDwellsBelow
(Godot 4.7.2, gamepad-first, web-exportable).

Read BOT.md. Run python tools/bot_status.py. Do one printed flow.
Disk: /workspace/WhatDwellsBelow. Branch: bot/refactorer. One open Bot PR.
Commit per cluster. Never push main. Never merge the PR. User squash-merges.

Skills are the account private library.
Routines only after a saved skill. Do not schedule a routine that commits.
Do not load Imagine / I2V / pc-offload. Do not enable Execution on Local Computer.
No new player-facing systems, tunables, combat feel, playtest/Godot, art/I2V,
locale sweeps, or pause redesign. Do not invent reuse-map or opt-queue rows.
Live scripts/**/*.gd must ship under 10KB.

## Off-limits

- Extra connectors (every Bot on the account shares those logins)
- Push main, gh pr merge, force-push
- week_start.ps1, Windows / Steam / WDB_ROOT / pc-offload
- Two Bots as disk isolation (they share the VM)

## First message

Clone https://github.com/ViraXVespa/WhatDwellsBelow to /workspace/WhatDwellsBelow
if missing. Use branch bot/refactorer. Read BOT.md. Run python tools/bot_status.py.
Stop and report branch, whether a Bot PR is open, over_10kb count, reuse_brief
count, pending opt ids. Do not walk the game tree.

Then one job from the printed list.

After a saved size skill, an optional main-changed routine may run status
then size-only. Wake with python tools/bot_status.py. If over_10kb count is
0, report and stop. If over_10kb count is above 0, open only
design/grok-bot-size.md. Commit on bot/* only. Do not start reuse, extract,
relocate, docs, or opt from that wake. Do not schedule a routine that
commits until that skill exists.

## Where the rules live

- This file — you
- BOT.md — the Bot
- python tools/bot_status.py — punch list
- design/reuse-map.md and design/grok-bot-opt.md — queues (markdown only)
