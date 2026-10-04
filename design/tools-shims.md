# Tools catalog: PowerShell shims

Status: protocol  
Read when: running a `.ps1` twin of a Python tool (User PC / Build only)  

Rules, the CLI contract and the surface key: `tools.md`. Each `.ps1` forwards its arguments to the `.py` twin (old `-Flag` spellings work), is kept one release, and is run as `powershell -File tools/<name>.ps1`; new work uses `python tools/X.py`. Windows proof of the shims is pending a User run. `check_tool_docs.py` reads this file too.

### PowerShell shims

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `agent_log.ps1` | Shim -> `agent_log.py` | D | - | N |
| `archive_prior_changelogs.ps1` | Shim -> `archive_prior_changelogs.py` | D | - | N |
| `check_script_cap.ps1` | Shim -> `check_script_cap.py` | D | - | N |
| `clean_agent_logs.ps1` | Shim -> `clean_agent_logs.py` | D | - | N |
| `export_web.ps1` | Shim -> `export_web.py` | D | - | N |
| `file_stat.ps1` | Shim -> `file_stat.py` | D | - | N |
| `godot_lock.ps1` | Shim -> `godot_lib.py` | D | - | N |
| `invoke_godot.ps1` | Shim -> `godot_lib.py` | D | - | N |
| `lint_hostify.ps1` | Shim -> `lint_hostify.py` | D | - | N |
| `list_changed.ps1` | Shim -> `list_changed.py` | D | - | N |
| `list_facade_cluster.ps1` | Shim -> `list_facade_cluster.py` | D | - | N |
| `list_oversize_docs.ps1` | Shim -> `list_oversize_docs.py` | D | - | N |
| `list_route.ps1` | Shim -> `list_route.py` | D | - | N |
| `list_scenes.ps1` | Shim -> `list_scenes.py` | D | - | N |
| `list_xref.ps1` | Shim -> `list_xref.py` | D | - | N |
| `move_script_cluster.ps1` | Shim -> `move_script_cluster.py` | D | - | N |
| `pack_grok_sessions.ps1` | Shim -> `pack_grok_sessions.py` | D | - | N |
| `read_summary.ps1` | Shim -> `read_summary.py` | D | - | N |
| `report_grok_sessions.ps1` | Shim -> `report_grok_sessions.py` | D | - | N |
| `run_agent_py.ps1` | Shim -> `run_agent_py.py` | D | - | N |
| `run_bake_camp.ps1` | Shim -> `run_bake_camp.py` | D | - | N |
| `run_build_gate.ps1` | Shim -> `run_build_gate.py` | D | - | N |
| `run_dungeon_load_timing.ps1` | Shim -> `run_dungeon_load_timing.py` | D | - | N |
| `run_dungeon_map.ps1` | Shim -> `run_dungeon_map.py` | D | - | N |
| `run_dungeon_map_sweep.ps1` | Shim -> `run_dungeon_map_sweep.py` | D | - | N |
| `run_godot_import_check.ps1` | Shim -> `run_godot_import_check.py` | D | - | N |
| `run_load_timing.ps1` | Shim -> `run_load_timing.py` | D | - | N |
| `run_post_split_gate.ps1` | Shim -> `run_post_split_gate.py` | D | - | N |
| `run_smokes.ps1` | Shim -> `run_smokes.py` | D | - | N |
| `start_build_slice.ps1` | Shim -> `start_build_slice.py` | D | - | N |
| `summarize_scripts.ps1` | Shim -> `summarize_scripts.py` | D | - | N |
| `week_start.ps1` | Shim -> `week_start.py` | D | - | N |

