# Build job cycle

Status: protocol
Read when: Grok Build gather, change, or prove

Binding for **Grok Build** only. Web / chat and Grok Bot do not load this file.

A **job** is one cycle: gather once, then change once, then prove once. Pause and report after every job.

Gather is planned `list_xref` plus planned `show_func` plus one `list_code_map_row` when a live script is in the slice. `summarize_scripts` is not gather. `list_route` and `list_changed` stay outside the gather set (`list_route` is slice boot; `list_changed` is git inventory).

Name a **planned gather list** (distinct xref patterns and show-func names) before the first catalog call. Those planned calls are one gather phase. A gather call invented after a prove summary, or the same command with the same args again, or a show-func not on the list, is a second job. Xref hits do not add `show_func` names in this job.

Change is one slice in a Grok worktree that merges into the live checkout. Prove is one import check (`tools/run_build_gate.ps1`), or one listed smoke set, or both **once**. Do not import, then smoke, then import. Do not pass `-ScriptCap` unless the User named a size job. A cap red is Bot work, not this slice.

Listed smoke set (run the runner; do not open smoke helpers just to pick the command):

| Unit | Runner |
|------|--------|
| floor map / gen silhouette / placement specs | `tools/run_dungeon_map.ps1` `-Seed 42` `-Floor 1` |
| Placeholdia to dungeon timing | `tools/run_dungeon_load_timing.ps1` |
| named phase asserts | `tools/run_smokes.ps1` `-Phases @(N)` |
| scripts compile / unnamed prove | `tools/run_build_gate.ps1` |

A new `--wdb-*-smoke` flag, new host scene, or new catalog runner is User-named or stop-and-propose. Headless screenshot postcards are parked; do not build them as prove. A red postcard ends this session's change work: stop, report the summary line, and tell the User to launch the RETRY line from `_logs/sess/<session>/slice-boot/summary.txt` (or say skip). Do not keep patching on the guilty transcript. Two reds on the same unit without a skip: stop. `--fork-session` is the return from that gather pin; do not auto-fork mid-change.

Read each job summary once via `powershell -File tools/read_summary.ps1 -Job <name>`. Preferred path is `_logs/sess/<session>/<job>/summary.txt` (session = `WDB_AGENT_SESSION` or the inferred Grok session id). Do not open the summary file directly. Catalog and this file must agree: once per job.

A second job in the same Grok Build session is allowed only when a **new field** is named first. Do not wait for the User between job 1 and job 2 when that field is named. Still pause and report after every job. The field must already be a key printed by that job's summary template, or `truncated` / crash / `busy` / wrong scene. Do not invent a key the template does not print. "Add a field so I can rerun" is invalid. The only valid same-command rerun is `truncated`, crash, `busy` lock, or wrong scene, and then the same command once.

Concurrent agents share catalog tools. They do not share summary files: each session writes under `_logs/sess/<session>/`. Pins are User-only.
