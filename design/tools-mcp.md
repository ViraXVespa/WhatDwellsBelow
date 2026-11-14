# Tools: wdb MCP

Status: protocol  
Read when: using, registering or changing the repo's own MCP (Grok Build)  

Entry: `wdb_mcp.py`; code: `tools/lib/wdb_mcp/`. A read-only, progressive front-end over the real commands in the other catalogs; those stay the source of truth. Grok Build loads it from `.grok/config.toml` (server `wdb`, tools `wdb__lookup`, `wdb__check`, `wdb__protocol`) once the worktree is trusted. Install once per machine: `pip install -r tools/requirements-mcp.txt` (Python 3.10+). Check it on the PC: `grok mcp doctor wdb`, `grok inspect`.

## Contract

- Replies start `STATUS: PASS` or `STATUS: FAIL (N)`, plain text. A cut one adds `page: A-B of N; more: handle=H` (pages of about 60 lines, `budget=N`); `check` replies `summary:` and `handle:` only.
- `all=true` on a first `lookup` or `check` call returns the whole result in that one reply (no handle). `lookup reads=[{action, path, ...}, ...]` answers several independent reads (any action but `more` / `full`) in one reply, in order; a bad read fails only itself and `STATUS: FAIL (N)` counts them.
- The command runs once; a follow-up passes the handle (`action=more` the rest, `full`, `failures`, `files`).
- Handles last 2 hours, one file each in `_logs/gather/mcp/` (safe for several servers). Build runs a check at most 3 times per target per worktree; an explicit `--surface` (Grok Bot) has no limit.
- Refused: commands off the caller's catalog surface (Surf; Build is D), `_logs/` paths (use `action=summary`), images, `notes/`. No tool writes repo files.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `wdb_mcp.py serve` | stdio MCP server `wdb`: `lookup` (`all=true`, `reads=[...]` batch; func with `pairs`, xref, names (every declared function), lines, doc `path#Heading` or no heading for the outline with line spans, route, scenes, facade, stat, changed, code_map, task, summary, packet), `check` (`tool_cli`, `tool_docs`, `script_cap`, `load_graph`, `gd_load`; `all=true`), `protocol` (`now` phase and next actions, `doc situation=`, `suggest query=`, `packet`, `list`; situations in `tools/data/mcp_protocol.json`). `--surface`, `--selftest`. | D | `--help` | N |
| `wdb_mcp.py call` | One tool call from a shell with the same state: `call lookup action=func path=P name=N`, `call lookup handle=f3a9c1`, `reads='[...]'` as JSON. No `mcp` package needed. Summary: `mcp-call`. | BD | `--help` | Y |

## Libs and data

| File (under `tools/`) | Owns |
|---|---|
| `lib/wdb_mcp/mcp_core.py` | Handle files, paging, rerun counts, read refusals, running a real command |
| `lib/wdb_mcp/mcp_tools.py` | The three tools over the store; catalog Surf filter |
| `lib/wdb_mcp/mcp_read.py` | File reads for `lookup`: line ranges, doc sections and outlines, Python names |
| `lib/wdb_mcp/mcp_selftest.py` | Selftest cases (serve `--selftest`) |
| `data/mcp_protocol.json` | Situation -> `doc#Heading`, phase -> next actions (no rule text) |
| `requirements-mcp.txt` | Optional `mcp` install |
