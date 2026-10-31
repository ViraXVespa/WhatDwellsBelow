# Local AI playtester + balance tuner (recommend-only, runs on Vira's PC)

id: local-ai-tuner
owner: bot
status: open
done-when: Phase 1 landed: survey, measured headless sim speed, lean design doc, minimal Optuna slice and a one-command runner Vira launches herself.
resume: python tools/docs.py task show local-ai-tuner, then start only after Vira says go.

## Intent
Tooling only, approved by Vira: a self-improving playtester plus a balance tuner trained on playtest data. The tuner may set tunables beyond their slider ranges. It only recommends configs (a ranked report plus a tunables file to try); it never commits or applies balance changes.

## Where it runs
Long runs happen on Vira's own dedicated PC, which she launches herself through one command (a runner script added in phase 1). Bot never runs anything on Vira's machines; Bot only builds, tests short slices on the box, and documents.

## Phase 1
1. Survey the existing playtester and sim (debug playtest job, `tools/perf.py`, tunables).
2. Measure headless sim speed (sim seconds per wall second) on the box.
3. Write a lean design doc (objective, search space, data captured, runner).
4. Minimal Optuna slice: a few tunables, short headless runs, one recommended config out.

## Hold
Blocked: wait until Vira finishes this week's recording and playtesting tweaks with Grok Build and says go. (Status stays open with this hold: `blocked` needs a task id and the wait is on Vira.)
