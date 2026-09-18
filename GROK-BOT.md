# Set up Grok Bot (The Refactorer)

Human setup for the cloud teammate. The Bot itself reads BOT.md, not this file.

## What you are creating

One Bot named Refactorer. Junior maintenance only: size, extract, reuse-map Brief,
relocate, doc facades, named opt ids, catalog/tooling.

It works on the shared Grok Bot Linux VM and ships through one GitHub PR.
It does not use your Steam Godot box. Do not turn on Execution on Local Computer.

## App and account

1. Install the Grok Bot desktop app (macOS / Windows / Linux).
2. Sign in with the Cursor or SuperGrok plan that includes Grok Bot.
3. New → Create new Bot.
4. Name: Refactorer
5. Label: WDB junior maintenance
6. Paste the profile below into Edit Profile → Description.

## Profile to paste

You are The Refactorer, junior programmer on github.com/ViraXVespa/WhatDwellsBelow
(Godot 4.7.2, gamepad-first, web-exportable).

Read BOT.md. Run python tools/bot_status.py. Do one printed flow.
Workspace /workspace/WhatDwellsBelow. Branch bot/refactorer. One open Bot PR.
Commit per cluster. Never squash-merge or push main. User squash-merges.

Sources of truth are git and the design queues, not memory.
Live scripts/**/*.gd must ship under 10KB.
No new player-facing systems, tunables, combat feel, playtest/Godot, art/I2V,
locale sweeps, or pause redesign. Do not invent reuse-map or opt-queue rows.

## Account settings

- Marketplace → GitHub. Confirm: Using the GitHub connector, which user am I signed in as?
- Execution on Local Computer: Never
- Auto-review Ask first: push to main, gh pr merge, force-push, deletes outside the cluster
- Auto-review Allow: git status / diff in /workspace/WhatDwellsBelow
- Do not connect extra apps unless every Bot on this account should see those logins
- Imagine / I2V / pc-offload skills stay off this teammate

## First messages

Boot:

Clone https://github.com/ViraXVespa/WhatDwellsBelow to /workspace/WhatDwellsBelow
if missing. Read BOT.md. Run python tools/bot_status.py. Stop and report branch,
whether a Bot PR is open, over_10kb count, reuse_brief count, pending opt ids.
Do not walk the game tree.

Then one job, for example:

Work the over_10kb list top-down. Do not ask permission per file.

or

Implement the whole current design/reuse-map.md Brief on the open Bot PR.

After two good clusters, save a skill from that method. Do not schedule a
routine that commits.

## How you land work

- Branch bot/refactorer, one standing PR
- You squash-merge when you choose
- CI bot-gate: cap on changed scripts, load-graph, allowlist on bot/* branches
- Do not treat two Bots as disk isolation. They share the VM.

## Where the rules live

- This file — you
- BOT.md — the Bot
- python tools/bot_status.py — punch list
- design/grok-bot-session.md — Cursor/PR agents
- design/reuse-map.md and design/grok-bot-opt.md — queues (markdown only)
