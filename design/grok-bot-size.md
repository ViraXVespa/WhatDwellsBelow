# Grok Bot — size sweep

Status: protocol  
Read when: Grok Bot Job table → size sweep  

## Size split quick path

Read only this file, `BOT.md`, and `design/refactor.md` rules 1-7 (skip the reuse, extract, and doc-split sections). Run `python tools/bot_status.py` (prints only the over-10KB list; `check.py script-cap --sweep` lists the 5-10KB rows). Per file:

1. Baseline: `gate.py warnscan --areas <areas that load it> --save-baseline PATH`, plus `gate.py bot-smokes --phases 1,2,6,<relevant>`. Run both in the background while reading the file.
2. Plan: `python tools/lint.py split FILE --list` (sizes, uses, outside callers). `lint.py split` writes new helpers into the facade's stem folder with trimmed unique names (refactor.md, Cluster folders). Keep public funcs and shared consts on the facade; group whole underscore funcs with the statics they own into siblings (static-helper pattern, refactor.md rule 4). Shared consts go in a small leaf helper. Write `plan.json` (`{helper_stem: [names]}`), then `--plan plan.json --dry-run`. Node (instance) funcs move too: they become `static func f(host: <the facade's extends type>, ...)` and the facade keeps a delegate.
3. `lint.py split FILE --plan plan.json` writes helpers, delegates and preloads, runs `lint.py requal` (rewrite + `--check`), and prints missing=0 and sizes. Then import for `.uid` (BOT.md Smokes), the static `--non-leak-diff` (compile check; the import does not compile scripts), smokes, then `--non-leak-diff PATH` with the same `--areas`. Check BOM/CRLF kept with `find.py stat`.
4. Changelog entry and code-map row via `docs.py patch` / `docs.py code-map patch` (design/tools.md), prove per BOT.md (Prove list), commit, push.
5. Rough edges: per BOT.md (After-cluster report), fix them in the same PR before the next file.

## Scope

Live `.gd` size only: `scripts/**` and `tools/data/**` (`gd_lib.LIVE_GD_DIRS`; debug code included, no folder exempt). Not a feature slice, not the staged reuse brief. No behavior change.

- Floors live in `BOT.md` (Caps). Ship floor: every touched live script under **10KB**; never leave a touched file over it if a legal split can fix it. Sweep target: under **5KB** when whole functions can move; a single function over 5KB stays whole and is reported. Files already under the relevant cap are not split "for cleanliness."
- Over-10KB scripts left on `main` by Grok Build are expected input, not a missed Build split.
- Out of scope: `scenes/`, `assets/`, `tools/` (unless a preload path must change), `archives/`, pinned commits, `project.godot` unless a moved script must be registered.

## Read set

This file, `design/refactor.md` (recipe only), one `design/code-map.md` system row for the cluster about to be edited, then only that cluster's live `.gd` files. Do not open the staged reuse brief, `design/doc-refactor.md`, or the other Bot flow siblings.

## Pass

Inventory first, no edits: `python tools/check.py script-cap` plus `bot_status.py`; rank over 10KB, then over 5KB where whole functions can move (optional `python tools/find.py scripts --over-kb 5 --top-funcs 3`). Show the ranked list. Sizes use `os.path.getsize`.
Split every over-10KB script first (each to under 10KB), then over-5KB files only when whole functions can move. One size PR may batch both; no extract, relocate or reuse-map work in it. Stale design-doc lines that name moved symbols: flag them in the PR body (`BOT.md` Prove). Do not add allowlist rows. Each new `.gd` needs a `.uid` sidecar (`BOT.md` Smokes).
