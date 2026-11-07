# Build week start

Status: protocol
Read when: the User requests a new week from the main checkout

Use the default repository pc-offload skill once. This is a release routine, not a slice. Do not run `slice.py start`, load gameplay topics or launch Godot. Finish the steps below; a User repair resumes at the unfinished step.

1. On clean `main`, `git pull --ff-only`, then `python tools/release.py week-start --dry-run`. Read the plan; run without `--dry-run` only when correct. The tool creates/seeds the week branch, pins a missing closing-week row and cleans old locks/logs. Push only the branch/tags named by its `push=` line. Never commit on main or dry-run again from the new week branch.
2. On `RESULT FAIL`, stop and report it, including any seed-commit failure. Do not manually continue cleanup or improvise a repair; the failure may have interrupted the routine.
3. Review the prior week with `find.py changed --head --log-count 40`. Use route summaries; open a topic only when a changed path requires it. Correct stale Build memory topics now or explicitly keep them; do not edit `MEMORY.md`, fold superseded inbox notes or queue `/dream`/`/flush` as substitutes.
4. Reconcile plain doc/path/command discrepancies. Run `check.py load-graph`, `check.py tool-docs --stale-refs` and `docs.py task check`. A changed game/flow/policy behavior is a proposal, not routine cleanup. Do not import, bake, rekey or run the game gate for this routine; a `.gd` edit would require its own compile check.
5. Commit/push authorized corrections on the new week branch. Report branch/version/pins, memory decisions, doc fixes/commits, remaining suggestions and `docs.py task list --owner build`. The User chooses and launches the next task. This report ends the routine.
