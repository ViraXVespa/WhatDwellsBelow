# Build job cycle

Status: protocol
Read when: Grok Build gather, change, or prove

Binding for **Grok Build** only. Web / chat and Grok Bot do not load this file.

A **job** is one cycle: gather once, then change once, then prove once. Pause and report after every job.

Gather is planned `list_xref` plus planned `show_func` plus one `code_map.py row` when a live script is in the slice. `summarize_scripts` is not gather. `list_route` and `list_changed` stay outside the gather set (`list_route` is slice boot; `list_changed` is git inventory).

Name a **planned gather list** (distinct xref patterns and show-func names) before the first catalog call. Those planned calls are one gather phase. A gather call invented after a prove summary, or the same command with the same args again, or a show-func not on the list, is a second job. Xref hits do not add `show_func` names in this job.

Change is one slice in a Grok worktree that merges into the live checkout. Prove is one import check (`tools/run_build_gate.py`), or one listed smoke set, or both **once**. Do not import, then smoke, then import. Do not pass `--script-cap` unless the User named a size job. A cap red is Bot work, not this slice.

Smokes at prove: the phases mapped to the door or job in `routes.yaml` `smokes` (printed by `list_route` and `start_build_slice`; `run_smokes.py --door D` or `--job door.job` runs them). A system the slice implements or changes gets its asserts updated in the mapped phase helper (`debug-smokes.md`), or a new assert there, in the same change job. Unit runners (run the runner; do not open smoke helpers just to pick the command):

| Unit | Runner |
|------|--------|
| floor map / gen silhouette / placement specs | `tools/run_dungeon_map.py` `--seed 42 --floor 1` |
| Placeholdia to dungeon timing | `tools/run_dungeon_load_timing.py` |
| named phase asserts | `tools/run_smokes.py` `--door D` / `--job door.job` / `--phases N` |
| scripts compile / unnamed prove | `tools/run_build_gate.py` |
| exported web build load, frame time, heap, asset sizes (advisory) | `tools/web_perf.py` (`--flow`, `--baseline`) after `export_web.py --out DIR` (`--site DIR`, baseline `tools/web-perf-baseline.json`) |

A new numbered phase, `--wdb-*-smoke` flag, or host scene is allowed only when the feature is new and no mapped phase fits (add it with the feature; name it in the report). A new catalog runner is stop-and-propose. A postcard or shot flow (`shot-tool.md`) is a deliverable or a visual check, not the build gate or a smoke; the headless flow asserts (`bot_smokes.py --flows`) may be named in the prove step. When a task needs a picture the tool cannot stage, extend the tool inside the change job (`shot-flows.md` gap process); do not hand-drive Godot or edit a PNG. A red postcard (`fail` band) gets one same-command rerun only for `truncated`, timeout or `busy`; otherwise fix the tool or script. Two reds on the same unit: stop and report the RETRY line from `_logs/slice-boot/summary.txt`; do not keep patching on the guilty transcript. `--fork-session` is the return from that gather pin; do not auto-fork mid-change.

Read each job summary once via `python3 tools/read_summary.py --job <name>`. The path is `_logs/<job>/summary.txt`. Do not open the summary file directly. Catalog and this file must agree: once per job.

A second job in the same Grok Build session is allowed only when a **new field** is named first. Do not wait for the User between job 1 and job 2 when that field is named. Still pause and report after every job. The field must already be a key printed by that job's summary template, or `truncated` / crash / `busy` / wrong scene. Do not invent a key the template does not print. "Add a field so I can rerun" is invalid. The only valid same-command rerun is `truncated`, crash, `busy` lock, or wrong scene, and then the same command once.

Concurrent agents share catalog tools. They do not share summary files: each session writes under `_logs/`. Pins are User-only.
