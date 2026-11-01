# Local AI: two models, a playtester and a balance tuner (recommend-only, runs on Vira's PC)

id: local-ai-tuner
owner: bot
status: open
done-when: Phase 1 of both parts landed (each slice meets its measure) plus the one-command runner Vira launches herself.
resume: python tools/docs.py task show local-ai-tuner, then start only after Vira says go.

## Intent
Tooling only, approved by Vira. There are TWO separate local models.
Dependency: the tuner is only as good as the playtester. It tunes against the playtester's runs, so part 1 comes first.

## 1. Playtester model
Makes the automated playtester play more like real players, and play better over time, by learning from playtest data and recordings.
Phase 1 slice: survey the existing playtester (the debug playtest job, `tools/perf.py`), then train a first model on the recorded runs that exist and swap it in for one decision (for example target or path choice).
Success: on held-out recordings, its choices match the real player's more often than the scripted playtester's do. Report both rates.

## 2. Balance tuner
Tunes the game-balance tunables (weapons, affixes, and so on). It may go beyond the slider ranges. It scores configs with playtester runs.
It only recommends configs: a ranked report plus a tunables file to try. It never commits or applies balance changes.
Phase 1 slice: measure headless sim speed (sim seconds per wall second) on the box, then a minimal Optuna run (a few tunables, short headless runs) that outputs one recommended config.
Success: the recommended config beats the current config on the stated objective across repeat seeds, with the spread reported.

## Where it runs
Long runs happen on Vira's own dedicated PC. She launches them herself with one command (a runner script added in phase 1). Bot never runs anything on Vira's machines. Bot only builds, tests short slices on the box, and documents. A lean design doc covers the objective, the search space, the data captured and the runner for both parts.

## Hold
Blocked: wait until Vira finishes this week's recording and playtesting tweaks with Grok Build and says go. (Status stays open with this hold: `blocked` needs a task id and the wait is on Vira.)
