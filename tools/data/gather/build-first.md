Slice opened by `slice.py open`: start already ran for this session ({start}). {packet} Do not run `slice.py start` again except a mid-session subcommand (--unit-done, --failed, --handoff).

Your first read: the task file{task_line}.
Your second read: session-context.md (the packet: core bodies plus candidates with their conditions). Do not re-read a core body it already includes. Open a candidate only when its condition holds (`wdb__lookup action=packet query=ID`, or `{py} tools/slice.py expand --only ID` when that MCP is not connected). Lookups use `wdb__lookup`, `wdb__check` and `wdb__protocol` when they are connected; otherwise the same jobs in `tools/` (`find.py`, `check.py`, `docs.py`, `session.py`). Change the index only with `{py} tools/slice.py adjust`, and write the four sections above the marker in session-plan.md as facts land so later post-compact turns receive the updated source context.
{warn}
