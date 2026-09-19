# Grok Build session flow

Status: protocol
Read when: Grok Build (CLI) path; every CLI instance after a gap

You can write the live tree. If you cannot, use the web path file.
Second topic door: ask the User to name the owner first. If `conflicts_with` lists the pair, do not open the second door in this slice.

Concurrent CLI chats in one week: Slice, Bot notes, PC offload, Smoke tests. Do not fold another role into this thread unless the User names it here. Pins are User-only. A new CLI chat is a catch-up, not a new week.

## Read

Agents file once, then this file. Law pair only if missing. Then the named topic. Imagine: `design/isolated-media.md` before any Imagine call. Gather / change / prove: `design/build-job-cycle.md`.

Git inventory: `tools/list_changed.ps1`. One live row: `python tools/list_code_map_row.py --path <script>`. Search: `tools/list_xref.ps1`, not grep. No `python -c`. Do not start by archiving the live path. Do not resume unnamed work from git status.

## Work

First message names the area. `powershell -File tools/start_build_slice.ps1 -Door <door>` (or `-Job` / `-Area`). Change only in the FORK worktree. Red prove: RETRY line, not another patch on the guilty transcript.

Just do: helpers and APIs inside one system. Stop and propose: a new cross-system owner, a named live architecture replace, a greenfield rewrite, or copying archive scenes over live.
Web / Bot leashes do not apply here.

## Other roles in this instance

- Bot notes: park with `python tools/bot_opt.py`. Do not implement those items or open a Bot PR.
- PC offload: `design/pc-offload.md`. New runner: propose and wait.
- Smoke tests: only coverage the User named.
- I2V: this path, isolated-media gate, stay in the slice thread.

Do not measure `.gd` bytes or cap-split. Bot owns size.
Archives are pinned commits in `scripts/data/archive_catalog.json`. Do not invent pin SHAs.

## After a slice

Prefer `powershell -File tools/run_build_gate.ps1` and `_logs/build-gate/summary.txt`. Stop and report. Two reds: stop. Do not commit `_logs/`.
