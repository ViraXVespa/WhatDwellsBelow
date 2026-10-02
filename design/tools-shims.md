# Tools catalog: PowerShell shims

Status: binding  
Read when: running a `.ps1` twin of a Python tool (User PC / Build only)  

Rules, the CLI contract and the surface key are in `tools.md`. Each `.ps1` forwards its arguments to the `.py` twin; the old `-Flag` spellings work. `check_tool_docs.py` reads this file too.

### PowerShell shims (kept one release)

Each forwards its arguments to the Python twin, so CI and muscle memory keep working; new work uses `python tools/X.py`. Windows proof of the shims is pending a User run.

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `agent_log.ps1` | Shim -> `agent_log.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/agent_log.ps1` | N |
| `archive_prior_changelogs.ps1` | Shim -> `archive_prior_changelogs.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/archive_prior_changelogs.ps1` | N |
| `check_script_cap.ps1` | Shim -> `check_script_cap.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/check_script_cap.ps1` | N |
| `clean_agent_logs.ps1` | Shim -> `clean_agent_logs.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/clean_agent_logs.ps1` | N |
| `export_web.ps1` | Shim -> `export_web.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/export_web.ps1` | N |
| `file_stat.ps1` | Shim -> `file_stat.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/file_stat.ps1` | N |
| `godot_lock.ps1` | Shim -> `godot_lib.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/godot_lock.ps1` | N |
| `invoke_godot.ps1` | Shim -> `godot_lib.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/invoke_godot.ps1` | N |
| `lint_hostify.ps1` | Shim -> `lint_hostify.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/lint_hostify.ps1` | N |
| `list_changed.ps1` | Shim -> `list_changed.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/list_changed.ps1` | N |
| `list_facade_cluster.ps1` | Shim -> `list_facade_cluster.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/list_facade_cluster.ps1` | N |
| `list_oversize_docs.ps1` | Shim -> `list_oversize_docs.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/list_oversize_docs.ps1` | N |
| `list_oversize_scripts.ps1` | Shim -> `list_oversize_scripts.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/list_oversize_scripts.ps1` | N |
| `list_route.ps1` | Shim -> `list_route.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/list_route.ps1` | N |
| `list_scenes.ps1` | Shim -> `list_scenes.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/list_scenes.ps1` | N |
| `list_xref.ps1` | Shim -> `list_xref.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/list_xref.ps1` | N |
| `move_script_cluster.ps1` | Shim -> `move_script_cluster.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/move_script_cluster.ps1` | N |
| `pack_grok_sessions.ps1` | Shim -> `pack_grok_sessions.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/pack_grok_sessions.ps1` | N |
| `read_summary.ps1` | Shim -> `read_summary.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/read_summary.ps1` | N |
| `report_grok_sessions.ps1` | Shim -> `report_grok_sessions.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/report_grok_sessions.ps1` | N |
| `run_agent_py.ps1` | Shim -> `run_agent_py.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_agent_py.ps1` | N |
| `run_bake_camp.ps1` | Shim -> `run_bake_camp.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_bake_camp.ps1` | N |
| `run_build_gate.ps1` | Shim -> `run_build_gate.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_build_gate.ps1` | N |
| `run_dungeon_load_timing.ps1` | Shim -> `run_dungeon_load_timing.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_dungeon_load_timing.ps1` | N |
| `run_dungeon_map.ps1` | Shim -> `run_dungeon_map.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_dungeon_map.ps1` | N |
| `run_dungeon_map_sweep.ps1` | Shim -> `run_dungeon_map_sweep.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_dungeon_map_sweep.ps1` | N |
| `run_godot_import_check.ps1` | Shim -> `run_godot_import_check.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_godot_import_check.ps1` | N |
| `run_load_timing.ps1` | Shim -> `run_load_timing.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_load_timing.ps1` | N |
| `run_post_split_gate.ps1` | Shim -> `run_post_split_gate.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_post_split_gate.ps1` | N |
| `run_smokes.ps1` | Shim -> `run_smokes.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_smokes.ps1` | N |
| `start_build_slice.ps1` | Shim -> `start_build_slice.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/start_build_slice.ps1` | N |
| `summarize_scripts.ps1` | Shim -> `summarize_scripts.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/summarize_scripts.ps1` | N |
| `week_start.ps1` | Shim -> `week_start.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/week_start.ps1` | N |

