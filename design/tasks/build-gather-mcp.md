# Build gather agent and wdb MCP: live verification (P6) and rollout

id: build-gather-mcp
owner: bot
status: open
done-when: A real slice launched through slice.py open --review then --launch, with its main-session tokens and turns compared to recent slices

## Decisions (locked, Vira 2026-11-14: defaults)

- One read-only repo MCP, `wdb` (`tools-mcp.md`): `lookup`, `check` (incl. `gate.py gd-load`), `protocol`; thin wrappers over `find.py` / `check.py` / `docs.py` / `session.py`; first page about 60 lines inline (`all=true` the whole result, `lookup reads=[...]` several reads in one reply), handles for the rest (one file each, safe across sessions); no shown-line tracking (Vira, 2026-11-14).
- Gather in `slice.py open` (`tools-build.md`): start runs for the main session (`grok -s SID`), seed, cheap agent `grok-build-0.1` under `WDB_ROLE=gather`, open's own `expand --check`, `session-context.md`. A gather that stops unfinished (compact, crash, timeout, or no report) does not launch. Halt or a failed check: no launch. `--review` / `--launch WT [--review]` / `--seed-only` / `--in WT`. `--no-gather` turns gathering off: none of that runs, and the main session gets the pre-gather command.
- `session-plan.md` is the single source of truth. `slice.py adjust` is the only writer of the index and of `## Approach` (`--lines` ranges, `batch --op`, `approach --text`, cap 4000) and logs `_logs/gather/delta.jsonl`. `plan --refresh` replays index ops and keeps the Approach text. The other kept sections are written in place as facts land.
- A next unit in the same session uses the seed only, and that session closes the seed (index and Approach) before editing. The `_src/wip/.../session-plan.md` copy stays.
- Success metric: main-session tokens and turns against recent slices; the gather cost is reported apart.
- 2026-11-16: the gather walks the edit to a closed func set and writes the Approach into the packet (why-notes on core headings). `action=packet` with no budget returns the whole packet; other lookups stay on the 60-line page. The main session's code read is that one packet. A missing symbol is one lookup plus `slice.py adjust` in the same turn. The 2026-11-16 map-rework and playtest slices spent the gather on a menu (about 50–60 cheap calls) and the main session on the lookups (about 400 calls, about 12× the gather cost). P6 still compares live tokens; this decision does not close the task.
- 2026-11-18: a local OpenCode gather (`ollama/qwen3-coder:30b`) did not produce a packet that inlines the edit. Splash trials pointed at the wrong file, exited before any adjust, or removed the seed and left only the docs plus a thin Approach. `slice.py open` no longer runs that agent. It writes the mechanical seed; the main session closes the index and writes the Approach.

## P6 (live; needs Vira, spends tokens)

1. The local-agent comparison is dropped. Do not start OpenCode from `slice.py open`.
2. A real slice's main session closes the seed (funcs in, seed candidates out) and writes the Approach before editing.

## Next Steps (User Only)
Bot: after Vira runs the P6 steps below and reports her output

