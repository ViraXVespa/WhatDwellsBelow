# Build week start

Status: protocol  
Read when: Grok Build runs in the main checkout (repo root, not a worktree) and the User says it is a new week  

No slice: there is no `slice.py start` line. The session is one turn and ends with the report.

1. **Start the week.** Clean tree on `main`: `git pull --ff-only`, then `python tools/release.py week-start --dry-run`; read it, then run it without `--dry-run`. It branches `grok-build-wN` from `main`, seeds `version.json`, parks changelogs, pins a missing closing-week row, commits on the new branch, cleans logs (Week sequence, `versioning.md`). Push what its `push=` line names (`git push -u origin grok-build-wN`, plus any catch-up tags). Nothing is committed on `main`. A `RESULT FAIL` stops the session: report the line, hand-fix nothing.
2. **Review.** Read the boot docs (`design/routes.yaml` `boot`, `requires`) and the doors this week's work touched; read last week's commits: `python tools/find.py changed --head --log-count 40`, then `git show --stat` on the ones that matter. Then review memory (memory-v2, `~/.grok/memory-v2/`, workspace scope): run `/flush` if captures are pending, fold `observations/_inbox/` into topics (`/dream`), then read and edit the workspace `topics/*.md` (`/memory` browses): correct or delete each stale note (a moved tool, a renamed command, a retired rule, a new door or flow) and anything that would slow work down. Never edit `MEMORY.md` (a generated index). Memory holds working habits; design lives in `design/`.
3. **Fix docs.** While reading, note where docs disagree with the code, each other or the routes, and run `python tools/check.py load-graph`, `python tools/check.py tool-docs --stale-refs` and `python tools/docs.py task check`. Fix what only brings a doc in line with the code or another doc (paths, commands, names, routing). Anything that changes what the game, a flow or a rule does is a suggestion, not an edit. Commit on `grok-build-wN` and push (never `main`, never force).
4. **Report** (ends the turn; not a question):
   - Week start: branch, version, pins, anything it warned about.
   - Changed: memory topics updated and doc fixes, with commits.
   - Suggestions: doc gaps (what your memory knows that no doc says), then game ideas.
   - Open Build tasks: `python tools/docs.py task list --owner build` (id, status, title), or none. The User opens one with its `resume:` line; you never run it.
