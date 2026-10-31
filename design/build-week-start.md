# Build week start

Status: protocol  
Read when: Grok Build runs in the main checkout (repo root, not a worktree) and the User says it is a new week  

No slice: there is no `slice.py start` line. Do not read the plan pair, door docs, or game scripts for this routine. The routine ends only at the step 4 report. A user reply that fixes a stop or a retired path is a step inside the routine. After that fix is committed, continue at the next unfinished step.

1. **Start the week.** Clean tree on `main`: `git pull --ff-only`, then `python tools/release.py week-start --dry-run`. Read that stdout. One `python tools/session.py summary --job week-start` if the file is needed; do not open `_logs/` yourself. Then run it without `--dry-run`. It branches `grok-build-wN` from `main`, seeds `version.json`, pins a missing closing-week row, commits on the new branch, cleans logs (Week sequence, `versioning.md`). Changelog files stay flat. Push what its `push=` line names (`git push -u origin grok-build-wN`, plus any catch-up tags). Nothing is committed on `main`. Do not dry-run week-start from the week branch; that plans the next week.

   **Stop.** The first stdout line that starts with `RESULT FAIL` ends the turn. Report that line, and the `seed commit failed` line above it when it is there. No further tool call: do not open the summary, do not inspect git, do not search for the cause, do not hand-fix. The tool returns at a seed-commit failure. It does not print `push=`, and it does not gc, delete locks, or clean logs.

2. **Review.** `python tools/find.py changed --head --log-count 40` for last week's commits. Open a door doc only when a changed path is that door's files; otherwise `python tools/find.py route --digest` is the route read. Then review memory in this session (workspace `topics/*.md` under `~/.grok/memory-v2/`). Edit the topic files now: correct or delete each stale note (a moved tool, a renamed command, a retired rule, a new door or flow) and anything that would slow work down. `/dream` and `/flush` are user commands. This routine does not queue them and does not leave the review for them. An inbox note this session has superseded is not folded. Never edit `MEMORY.md`. Memory holds working habits; design lives in `design/`. Do not read `archive_catalog.json` or a game script to do this review.

3. **Fix docs.** While reading, note where docs disagree with the code, each other or the routes, and run `python tools/check.py load-graph`, `python tools/check.py tool-docs --stale-refs` and `python tools/docs.py task check`. `python tools/gate.py gd-load` only when a `.gd` file changed. This routine does not run `gate.py build`, a rekey, or a Godot import. Fix what only brings a doc in line with the code or another doc (paths, commands, names, routing). Anything that changes what the game, a flow or a rule does is a suggestion, not an edit.

   A commit that retires a directory searches for that path with `python tools/find.py xref --pattern <path>`. A hit stays only when it is a historical pin path in `scripts/data/archive_catalog.json` (those open with `git show` at the pinned commit).

   Commit on `grok-build-wN` and push (never `main`, never force).

4. **Report** (ends the routine; not a question). The routine is unfinished while step 2 has not edited or explicitly kept each topic:
   - Week start: branch, version, pins, anything it warned about.
   - Changed: memory topics updated and doc fixes, with commits.
   - Suggestions: doc gaps (what your memory knows that no doc says), then game ideas.
   - Open Build tasks: `python tools/docs.py task list --owner build` (id, status, title), or none. The User opens one with its `resume:` line; you never run it.
