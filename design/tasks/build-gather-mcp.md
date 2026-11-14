# Build gather agent and wdb MCP: live verification (P6) and rollout

id: build-gather-mcp
owner: bot
status: open
done-when: A real slice launched through slice.py open --review then --launch, with its main-session tokens and turns compared to recent slices
resume: Bot: after Vira runs the P6 steps below and reports her output

## Decisions (locked, Vira 2026-11-14: defaults)

- One read-only repo MCP, `wdb` (`tools-mcp.md`): `lookup`, `check` (incl. `gate.py gd-load`), `protocol`; thin wrappers over `find.py` / `check.py` / `docs.py` / `session.py`; first page about 20 lines inline, handles for the rest, no line re-sent per epoch (PostCompact / resume bump it).
- Gather in `slice.py open` (`tools-build.md`): start runs for the main session (`grok -s SID`), seed, cheap agent `grok-build-0.1` under `WDB_ROLE=gather`, open's own `expand --check`, `session-context.md`. Crash or timeout: seed only plus WARN, then launch. Halt or a failed check: no launch. `--review` / `--launch WT` / `--no-gather`.
- `session-plan.md` is the single source of truth; `slice.py adjust` is its only writer and logs `_logs/gather/delta.jsonl`; `plan --refresh` replays it.
- A next unit in the same session uses the seed only. The `_src/wip/.../session-plan.md` copy stays.
- Success metric: main-session tokens and turns against recent slices; the gather cost is reported apart.

## P6 (live; needs Vira, spends tokens)

1. On her PC: `grok models` (is `grok-build-0.1` listed? else set `MODEL` in `tools/lib/slice/gather_agent.py`) and `python -m pip install -r tools/requirements-mcp.txt`.
2. `python tools/slice.py open <small task> --review`: the agent runs, the report prints, Build does not launch.
3. `python tools/slice.py open --launch <WT>` for one real slice; compare tokens and turns. Tune `tools/data/gather/gather-prompt.md`.
4. Rollout: the next week start.
