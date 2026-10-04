# Build job cycle

Status: protocol
Read when: Grok Build gather, change, or prove

For **Grok Build** only. Web / chat and Grok Bot do not load this file.

Intent: Vira owns design, Build implements it with little friction; the docs are the living plan, not a fixed route (`grok-build.md`).

A **job** is one cycle: gather, change, prove. Chain related jobs without stopping, and report when the work is done or a question needs the User. **Multi-system job:** before the first change, list every system it touches and read each one's doc and `code_map.py row`.

Gather is planned `list_xref` plus planned `show_func` plus one `code_map.py row` when a live script is in the slice. `summarize_scripts` is not gather. `list_route` and `list_changed` stay outside the gather set (`list_route` is slice boot; `list_changed` is git inventory).

Name a **planned gather list** (distinct xref patterns and show-func names, as long as the systems need) before the first catalog call. Those planned calls are one gather phase; add to the list when a new system turns up. Do not repeat the same command with the same args.

Change is one slice in a Grok worktree cut from the week branch `grok-build-w{N}`. The shell starts in the main checkout. Do not edit there. A worktree the User already named is the slice. Do not cut another.

A visual restyle asks, then waits: what the surface is made of, which one screen is first, and what must stay. The first code is that one screen. Prove matches the change, once. A UI, theme, or other visual change is that screen's shot flow, opened and described, plus that door's UI load check. If the frames are the old widgets with new colors, the prove fails. Do not sweep the other surfaces. An import check or an unrelated smoke set is for a code change that can fail compile. Do not run both for a theme pass, and do not import, then smoke, then import.

Smokes at prove: the phases mapped to the door or job in `routes.yaml` `smokes` (printed by `list_route` and `start_build_slice`; `run_smokes.py --door D` or `--job door.job` runs them). A system the slice implements or changes gets its asserts updated in the mapped phase helper (`debug-smokes.md`), or a new assert there, in the same change job. Unit runners (run the runner; do not open smoke helpers just to pick the command):

| Unit | Runner |
|------|--------|
| floor map / gen silhouette / placement specs | `tools/run_dungeon_map.py` `--seed 42 --floor 1` |
| Placeholdia to dungeon timing | `tools/run_dungeon_load_timing.py` |
| named phase asserts | `tools/run_smokes.py` `--door D` / `--job door.job` / `--phases N` |
| scripts compile / unnamed prove | `tools/run_build_gate.py` |
| exported web build load, frame time, heap, asset sizes (advisory) | `tools/web_perf.py` (`--flow`, `--baseline`) after `export_web.py --out DIR` (`--site DIR`, baseline `tools/web-perf-baseline.json`) |

A new numbered phase, `--wdb-*-smoke` flag, or host scene is allowed only when the feature is new and no mapped phase fits (add it with the feature; name it in the report). A new catalog runner is fine when it would reasonably help future tasks (`tools.md` rule 5). A postcard or shot flow (`shot-tool.md`) is a deliverable or a visual check, not the build gate or a smoke; the headless flow asserts (`bot_smokes.py --flows`) may be named in the prove step. When a task needs a picture the tool cannot stage, extend the tool inside the change job (`shot-flows.md` gap process); do not hand-drive Godot or edit a PNG. A red postcard (`fail` band) gets one same-command rerun only for `truncated`, timeout or `busy`; otherwise fix the tool or script.

## Red prove and merge-back

**Retry** (one diagnosis, one fix: `tools.md` rule 10). The gather session is the point a retry returns to: `start_build_slice.py` saves its id (`--session` or `$GROK_SESSION_ID`). A red prove prints a RETRY block with the fork command `grok --cwd <this worktree> -r <gather session> --fork-session` (same worktree, new session id, gather context kept; not `--worktree`, which with `-r` opens a new worktree) and a paste-ready prompt: which prove failed, the red output in a line or two, the files in `git diff grok-build-w{N}...HEAD` to look at first, and the ask for one diagnosis and one fix. The forked session does not re-gather: it reads only the changed files, diagnoses once, fixes once and reruns once. No saved session matches this worktree (grok names the folder, so START's name may not match): the block lists the saved ones to pick from, or says there is none, and starts nothing; ask the User in a question prompt. Still red: stop and report. The worktree's git history holds the code.

**Merge-back** on a green prove: commit in the worktree (its HEAD is detached; there is no branch), then `git merge --no-ff <that commit>` in the checkout that holds `grok-build-w{N}` (never main), with a short note in the commit message; resolve conflicts yourself. Anything the User would check by hand (game balance, audio, visuals / art, controls) first needs a question prompt asking whether the playtest looks good; wait for approval before the merge. Refactors, tools, docs and tests merge automatically on green. Build writes no changelog files (the week-close `0.N.0.md` is a web session's: `versioning.md`).

Read each job summary once via `python tools/read_summary.py --job <name>` (index first, newest run). Do not open summary files directly.

A same-command rerun is valid only for `truncated`, crash, `busy` lock, or wrong scene, and then the same command once. A follow-up job with a new field named from a summary key is fine without waiting for the User.

Proof recipes by change kind: `prove.md`. A proof that needs a check no tool does: extend the library (`imglib`, shot tools) in the change job and add the recipe there; do not work around it.

Concurrent agents share catalog tools. They do not share logs: each worktree has its own `_logs/`, cleared weekly.
