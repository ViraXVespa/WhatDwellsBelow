# Build job cycle

Status: protocol
Read when: Grok Build gather, change, or prove

For **Grok Build** only. Web / chat and Grok Bot do not load this file.

Intent: Vira owns design; Build implements it and defers to her on design, asking whenever that helps; the docs are the living plan, not a fixed route (`grok-build.md`).

A **job** is one cycle: gather, change, prove. Report when the work is done. Ask as many questions as the job needs, in as many rounds as it needs, and ask again whenever a discovery changes what the User will see or what was assumed. No limit on count or rounds. **Multi-system job:** before the first change, list every system it touches and read each one's doc and `code_map.py row`.

Gather is planned `list_xref` plus planned `show_func` plus one `code_map.py row` when a live script is in the slice. `summarize_scripts` is not gather. `list_route` and `list_changed` stay outside the gather set (`list_route` is slice boot; `list_changed` is git inventory).

Name a **planned gather list** (distinct xref patterns and show-func names, as long as the systems need) before the first catalog call. Those planned calls are one gather phase; add to the list when a new system turns up. Do not repeat the same command with the same args.

Change is one slice in a Grok worktree cut from the week branch `grok-build-w{N}`. The User starts it with `python tools/open_slice.py [AREA]`, which runs `grok --worktree=NAME --ref grok-build-w{N}` (a NEW session whose directory is the worktree). Gather and change run in that session; it starts with `start_build_slice.py` (IN A WORKTREE). Fallback from a main-checkout session: `start_build_slice.py` prints the START lines (worktree, then `cd` + `grok`), the User runs them and that session stops with nothing else done. Do not edit the main checkout. A worktree the User already named is the slice. When gather is done, `python tools/start_build_slice.py --checkpoint` saves this session's id (`$GROK_SESSION_ID`) as the checkpoint. **Only `open_slice.py`, run by the User, launches grok; Build never does** (no fork, no headless run, no `--prompt-file`, no `--max-turns`; the isolated-media runner is the one exception). No brief or prompt for another session or process may forbid questions, and Build sets no run limits (turns, permissions) for one.

**Restate first.** A visual job first shoots and OPENS the baseline picture of the screen it will change (no flow for that screen yet: the flow is step 0, below), then writes in its own words what was asked and what would be visible or observable if it worked, then asks. Ask the User about anything unclear, including look, layout, material or texture and what counts as done (hers to decide); you write the questions, then wait for the answers, and ask again when an answer or a discovery changes what she will see. A word the User used (a name, a metaphor) is not yet an answer to what it means here. Until answered change nothing, except shot-flow files (`tools/shot-flows/`) and the `routes.yaml` mapping: creating them is part of the work.

**Every stop-and-ask message** carries two short lists for her to overrule: "Decisions I made that were yours" (each with the alternative) and "Assumptions carried from memory or docs". It says whether the baseline PNG is the screen being changed and sends that PNG path with the ask.

**Step 0, a missing shot flow.** `start_build_slice.py` prints a STEP 0 note for a visual job with no flow mapped to it (exit 0; not a stop). Creating or adjusting the flow for the exact screen is the first job step (`shot-flows.md`, New UI state checklist); a job never borrows its door's flows as if they were its own. The end gates stay: the after-shot must exist and be opened, no missing or stale frame, and a new uncovered UI state needs a flow before the prove passes.

**Visual unit.** Baseline first (`run_shot_flow.py --flow N`; `--save-baseline DIR` keeps it), opened. Change one unit or screen. Open the before and after PNGs and say what is on each. Then stop and ask the User, giving the PNG paths. Do not start the next unit. After a rejection the next step is a question about what was wrong, not an edit. Iterating one unit with the User is exempt from the rerun counts (`tools.md` rule 10).

**Every pass.** After each small batch of edits (a few files, never a sweep), run `python tools/check_gd_load.py`: it loads every changed and untracked `.gd` inside the project with its autoloads, so a stray `)` or a bad reference fails. The import check, a smoke and a standalone `--script` parse do not load every script, so none of them is evidence that the scripts compile. A multi-line splice gets its own check before the next edit.

**Read what you run.** Open stderr and every check result before you describe it; output you did not read is not harmless, and a passing check that does not cover the claim is not evidence of it. The playtest confirm is asked only after the compile check passed, the output is read, and (visual) the frames are opened and described. The question carries a short summary of what changed.

Prove matches the change, once at the end: the compile check each pass; a visual change adds its door's shot flow (opened and described) and that door's UI load check; then `run_build_gate.py --batch`. Do not import, then smoke, then import.

Smokes at prove: the phases mapped to the door or job in `routes.yaml` `smokes` (printed by `list_route` and `start_build_slice`; `run_smokes.py --door D` or `--job door.job` runs them). A system the slice implements or changes gets its asserts updated in the mapped phase helper (`debug-smokes.md`), or a new assert there, in the same change job. Unit runners (run the runner; do not open smoke helpers just to pick the command):

| Unit | Runner |
|------|--------|
| floor map / gen silhouette / placement specs | `tools/run_dungeon_map.py` `--seed 42 --floor 1` |
| Placeholdia to dungeon timing | `tools/run_dungeon_load_timing.py` |
| named phase asserts | `tools/run_smokes.py` `--door D` / `--job door.job` / `--phases N` |
| changed `.gd` load with autoloads (every pass) | `tools/check_gd_load.py` (`--files`, `--all`, `--base REF`) |
| import + load graph + names / unnamed prove | `tools/run_build_gate.py` |
| exported web build load, frame time, heap, asset sizes (advisory) | `tools/web_perf.py` (`--flow`, `--baseline`) after `export_web.py --out DIR` (`--site DIR`, baseline `tools/web-perf-baseline.json`) |

A new numbered phase, `--wdb-*-smoke` flag, or host scene is allowed only when the feature is new and no mapped phase fits (add it with the feature; name it in the report). A new catalog runner is fine when it would reasonably help future tasks (`tools.md` rule 5). A postcard or shot flow (`shot-tool.md`) is a deliverable or a visual check, not the build gate or a smoke; the headless flow asserts (`bot_smokes.py --flows`) may be named in the prove step. When a task needs a picture the tool cannot stage, extend the tool inside the change job (`shot-flows.md` gap process); do not hand-drive Godot or edit a PNG. A red postcard (`fail` band) gets one same-command rerun only for `truncated`, timeout or `busy`; otherwise fix the tool or script.

## Red prove and merge-back

**Retry** (one diagnosis, one fix: `tools.md` rule 10). The checkpoint (the worktree's gather session) is the point a retry returns to. A red prove prints a RETRY block: the command `grok -r <checkpoint> --fork-session` for the User to run from the worktree directory (a fork keeps the directory of the session it forks, which is the worktree; no `--cwd`, never `--worktree`; gather context kept), and a paste-ready prompt: which prove failed, the red output in a line or two, the files in `git diff grok-build-w{N}` (working tree, so uncommitted edits show; untracked files are listed too) to look at first, and the ask for one diagnosis and one fix. The forked session does not re-gather: it reads only the changed files, diagnoses once, fixes once and reruns once. No checkpoint saved for this worktree: the block says so and forks nothing; run `--checkpoint` in the gather session, or ask the User for its id (`grok sessions list` in the worktree). Still red: stop and report. The worktree's git history holds the code.

**Merge-back** on a green prove: commit in the worktree (its HEAD is detached; there is no branch), then `git merge --no-ff <that commit>` in the checkout that holds `grok-build-w{N}` (never main), with a short note in the commit message; resolve conflicts yourself. Anything the User would check by hand (game balance, audio, visuals / art, controls) first needs a question prompt asking whether the playtest looks good, with the change summary (and PNG paths); wait for approval before the merge. Refactors, tools, docs and tests merge automatically on green. Build writes no changelog files (the week-close `0.N.0.md` is a web session's: `versioning.md`).

Read each job summary once via `python tools/read_summary.py --job <name>` (index first, newest run). Do not open summary files directly.

A same-command rerun is valid only for `truncated`, crash, `busy` lock, or wrong scene, and then the same command once. A follow-up job with a new field named from a summary key does not need a User wait; questions still follow the rules above.

Proof recipes by change kind: `prove.md`. A proof that needs a check no tool does: extend the library (`imglib`, shot tools) in the change job and add the recipe there; do not work around it.

Concurrent agents share catalog tools. They do not share logs: each worktree has its own `_logs/`, cleared weekly.
