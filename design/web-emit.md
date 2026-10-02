# Web / chat session flow: emit, scratch and fetch

Status: protocol
Read when: web / chat Phase 4 emit, a Build co-op prompt, a scratch helper question, or fetching a live path

Binding for **web / chat** only. Grok Build and Grok Bot ignore it. Phases, flows and the Do-not list stay on the web door.

## Phase 4 — Emit

One action. Prefer one `tools/_scratch.py` for every revise/delete path and the docs in this pass. A packed pass is still one action and one scratch. New source files emit one at a time (path line, blank line, full body in one language fence) until the User says `Next`.

Revise from a fetched raw body plus the artifact byte check, or from a User paste already in this conversation. Fetch budget: one pull per path. After a failed check, do not fetch again. Do not assemble a revision from a tool-card summary. Do not put a markdown fence opener inside a fenced emit. Do not reimplement `tools/doc_patch.py`.

Scratch shape. One file, `tools/_scratch.py`. The runner imports `doc_patch` before the scratch body, so a scratch cannot repair a broken `doc_patch`. That repair is a direct `python` file.

```python
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import doc_patch as dp

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    dp.run_checker(ROOT)
    print("RESULT checker=PASS")
    sys.exit(0)


if __name__ == "__main__":
    main()
```

Callables (`replace_func`, `upsert_func`, `ensure_line`, `write_text`, `write_changelog`, `run_checker`, `dump_job`) and the matching `doc_patch.py` CLI subcommands: `doc-library.md`. If a call does not behave intuitively, fix `doc_patch` (direct `python` file), do not work around it.

A `.gd` body is tabs. `write_text` turns a leading run of four spaces into one tab, but the scratch still emits tabs. Do not prepend above `from __future__ import`. A `.py` write that does not compile, or that moves that import, is refused. `run_shots.py` stays hidden. `--show` only when the User asks to see the window.


Docs in this pass: same scratch updates topic files, one code-map row, and tunables the slice made wrong, writes `design/changelog/{label}.md` via `doc_patch.write_changelog`, and runs `tools/check_load_graph.py`. A later scratch in the same emit pass is a delta. Skip every path whose write already printed `wrote`, `deleted`, or `already applied` / `already gone`. Do not re-emit the whole Phase 3 list. Do not rewrite a file that already matches the accepted goal unless that file is why RESULT failed.

When a slice needs a visual proof, run `python3 tools/run_shots.py --mode web` and paste the clipboard image with the printed RESULT. Prove from work that landed, using only existing runners. The scratch runs the test through `doc_patch.dump_job(ROOT, job)` (or `run_checker` for the load-graph). `dump_job` returns `(rc, body)` and already prints the summary. Unpack it: `rc, body = dp.dump_job(ROOT, job)`. Never `sys.exit(dp.dump_job(...))` — a tuple exit is a false fail. After the process exits, print the summary file body only if you did not call `dump_job`, never the `Summary ->` path. Last line is `RESULT checker=PASS|FAIL` or `RESULT gate=PASS|FAIL` plus any extra marks. `sys.exit(int)` only: `sys.exit(0)` on PASS and `sys.exit(1)` on FAIL. If `dump_job` / import check reports a parse or compile error, stop; do not start a longer Godot prove.

| Work that landed | Prove | Dump |
|------|-------|------|
| design / AGENTS / routes / load-graph | `tools/check_load_graph.py` | checker line |
| GDScript / scenes / project.godot | `tools/run_build_gate.py` | gate summary |
| Title to Play load | `tools/run_load_timing.py` | load-timing summary |
| Hub to dungeon load | `tools/run_dungeon_load_timing.py` | dungeon-load-timing summary |
| Gen / map shape | `tools/run_dungeon_map.py` | dungeon-map summary |
| Named phase assert | `tools/run_smokes.py` | smokes summary |
| GDScript import / COMPILE | `tools/run_godot_import_check.py` via `dump_job(..., "godot-import-check", script="run_godot_import_check.py")` | godot-import-check summary; fail on COMPILE or clean=false |
| Postcard shot | `python3 tools/run_shots.py --mode web` from the scratch (same flags the slice named) | shots summary; User pastes the clipboard image |

A slice that only edits protocol docs does not boot Godot. If there is no runner for that work, say so and prove with the load-graph / gate only.

Any slice that creates or edits a `.py` file must prove those files in the same scratch before RESULT: `python -m py_compile` on each touched path, then a dry run of that script's real entry (`--help`, `--what-if` / no-write, or an in-process call that does not mutate live design). Compiler errors or a non-zero dry run fail the scratch. Docs-only slices with no `.py` change skip this.

## Build co-op prompts

A prompt for Grok Build is a sealed brief, not a session export. Only: named job, writer door, in-scope paths, out-of-scope one-liners, prove runner. Do not pack web protocol, park theory, hitch hypotheses, or "while you are in there." Do not echo the gather report into the brief. If a sentence would make Build invent a step the named job and door would not already require, delete it. If the brief needs a second page, it is two jobs.

## Scratch helpers

Tool catalog (what each runner is, which are web/User tools): `tools.md`. Do not reimplement doc_patch. Import it from tools/. Godot prove dumps go through `doc_patch.dump_job`; do not print `Summary ->` paths.
Reuse Brief items must be numbered `1. ` `2. ` so bot_status.parse_reuse_brief counts them. Prose under ## Brief counts as empty.
Changelog: doc_patch.write_changelog. If version.json lags the files in design/changelog/, use the next free 0.N.N label, do not reuse an existing note.
Code-map rows: `code_map.py patch` (code_map_lib), not a hand regex on the table.
Markdown bytes: md_format_lib write helpers. Always run doc_patch.run_checker and print RESULT checker=PASS|FAIL.
lint_hostify out-dir takes ROOT, not root.

## Fetching a live path

1. One page fetch of the raw GitHub file. Open the saved artifact. Use it when the tail is a complete line and API `size` equals artifact UTF-8 bytes, or API `size` equals artifact bytes + 3 (UTF-8 BOM).
2. A User paste of that path already in this conversation wins.
3. Ask for a paste only when step 1 failed and no paste is in the thread. Stop.

Do not treat a page-tool summary as the live file.

