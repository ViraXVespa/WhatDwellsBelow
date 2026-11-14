# Tools: wdb MCP

Status: protocol  
Read when: using, registering or changing the repo's own MCP (Grok Build)  

Entry: `wdb_mcp.py`; code: `tools/lib/wdb_mcp/`. A read-only, progressive front-end over the real commands in the other catalogs; those stay the source of truth. Grok Build loads it from `.grok/config.toml` (server `wdb`, tools `wdb__lookup`, `wdb__check`, `wdb__protocol`) once the worktree is trusted. Install once per machine: `pip install -r tools/requirements-mcp.txt` (Python 3.10+). Check it on the PC: `grok mcp doctor wdb`, `grok inspect`.

## Contract

- A first response starts `STATUS: PASS` or `STATUS: FAIL (N)`, then `handle:` and `next:`; `shown:` when paged, `summary:` on a FAIL. `lookup` and `protocol` add one page (about 20 lines); `check` answers with the header only.
- The command runs once. A follow-up passes the handle (`action=more` the next page only, `full`, `failures`, `files`) and never re-runs it.
- Source lines already sent this epoch are elided (`... L12-40 unchanged, already shown`); after an edit only changed lines are re-sent; `fresh=true` resends. A compact or resume starts a new epoch (`.grok/hooks/wdb-epoch.json`).
- Handles last 2 hours, 64 kept; an expired one answers `STATUS: FAIL (1)` and names the call to repeat. State: `_logs/gather/`.
- Refused: commands off the caller's catalog surface (Surf; Build is D), `_logs/` paths (use `action=summary`), images, `notes/`. No tool writes repo files.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `wdb_mcp.py serve` | stdio MCP server `wdb`: `lookup` (func with `pairs` batch, xref, names, lines, doc `path#Heading`, route, scenes, facade, stat, changed, code_map, task, summary, packet), `check` (`tool_cli`, `tool_docs`, `script_cap`, `load_graph`, `gd_load`), `protocol` (`now` phase and next actions, `doc situation=`, `suggest query=`, `packet`, `list`; situations in `tools/data/mcp_protocol.json`). `--surface`, `--selftest`. | D | `--help` | N |
| `wdb_mcp.py call` | One tool call from a shell with the same state: `call lookup action=func path=P name=N`, `call lookup handle=f3`. No `mcp` package needed. Summary: `mcp-call`. | BD | `--help` | Y |

## Libs and data

| File (under `tools/`) | Owns |
|---|---|
| `lib/wdb_mcp/mcp_core.py` | Handle store, paging, epoch, no-repeat ledger, read refusals, running a real command |
| `lib/wdb_mcp/mcp_tools.py` | The three tools over the store; catalog Surf filter |
| `lib/wdb_mcp/mcp_selftest.py` | Selftest cases (serve `--selftest`) |
| `data/mcp_protocol.json` | Situation -> `doc#Heading`, phase -> next actions (no rule text) |
| `requirements-mcp.txt` | Optional `mcp` install |
