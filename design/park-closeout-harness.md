# Park: closeout harness

Status: parked
Read when: resume parked closeout_harness, worktrees, Godot lock, pc-offload hooks, Imagine deny


## Goal

Implement Grok Build / runner harness so concurrent sessions and smokes do not share one dirty tree, do not kill the User editor, and do not ingest fat logs. This park is the mandate. Do not require the brainstorm chat.

Session path: web, then Grok Build / tools. Not Grok Bot feature work.


## Worktrees

Concurrent Build sessions each get their own git worktree. Do not share one live checkout across 5-7 sessions.

Disk is acceptable. Week-start cleanup removes stale worktrees from the last cycle.

Worktrees still load AGENTS.md. They are not Imagine isolation.


## Godot

No shared godot serve.

One Godot process at a time. Enforce with a lock file, not Get-Process godot* | Stop-Process.

Never kill the User's editor or game instance.

Smoke / gate runners wait on the lock. Waiting on the process does not burn model tokens. The next model turn that reads a raw log does.


## pc-offload

Keep the catalog skill.

Add a short always-on rule (AGENTS or Build path): tree search is list_xref, not the grep tool; read summary.txt not raw logs.

Add hooks that deny grep / list_dir-of-scripts and deny reading large Godot logs. Skill English is not enough.


## Imagine

Hook denies Imagine / I2V tool use when cwd is the game repo.

Isolated runner (scratch cwd outside the repo, isolated-media gate) is unchanged and is not blocked by that hook.


## Prove and smokes

Running smokes is a script (run_smokes.ps1, run_build_gate.ps1, load-timing). Not a general session in the middle.

Postcard only: RESULT line / summary.txt. The change session does not parse p7-err.log.

When adding bands: good / warn / fail on measurable marks (load ms). Exit codes documented. Numbers live next to the runner, not in a prompt.

Headless screenshots need a real rendering driver, not dummy. Map objects, shoot, crop, optional downscale, write _logs/shots. Do not attach PNGs to a fat session by default.


## Session physics

The API resends the whole transcript each turn. Sessions do not talk to each other except through disk (_logs summaries, queues, lock files).

The CLI does not auto-fork from a pin. A week script or user command may pass --fork-session.

Do not implement the week pin state machine in this park unless the User also opened park-build-week.md.
