# Grok Bot — documentation facades

Status: protocol  
Read when: Grok Bot Job table → doc facade / sibling split  

For **Grok Bot** documentation facade sweeps only. Recipe: `design/doc-refactor.md`. No change of meaning. No live `.gd` size sweep in this PR unless a touched script path in a code map row must stay accurate.

## Mandate

Split fat topic `design/*.md` files to the art_pipeline door + siblings layout, or trim them for signal-to-noise (below). Pass order and facade checklist: `design/doc-refactor.md`. Caps (Bot-only): a door stays under 4KB (Job table and rules, no live-snapshot dumps), a sibling under 8KB (one job cluster; split again if one `##` section dominates), hard stop ~12KB: do not leave a touched topic file above it if a legal split exists. Rank over ~12KB first, then over ~8KB. One facade plus its new siblings per editing focus. Show the worklist; do not edit yet.

Out of scope: rewriting `design/changelog/**` history, `docs/` Pages export, mixing this sweep into a live script size sweep without User go, inventing systems.

## Read set

1. `design/doc-refactor.md`
2. The `design/README.md` topic index row for the door
3. After inventory: that one door and only the sibling for the active job

Do not concatenate all siblings into context. Do not open the staged reuse brief. Prefer Length / heading lists over pasting whole markdown bodies.

## Pass

1. Inventory: `python3 tools/list_oversize_docs.py` (skips `design/changelog/`). Rank over ~12KB, then over ~8KB. Show worklist.
2. Split named first. Move existing prose. Fix links and README index rows. Update `design/code-map.md` only if a script path in a row must stay accurate. The Job table must cover every former top-level `##` cluster (or route to an existing sibling topic). Live snapshots travel with the matching sibling, not the door. No `See also` fields (load-graph bans them). Grep for stale "read the whole of X" wording; point at the Job table.
3. One `design/changelog/{label}.md` for the PR.
4. `python3 tools/check_tool_docs.py --stale-refs --narration` (dead paths and identifiers fail; narration lines are advisory: rewrite in present tense or delete). Prove: `BOT.md`.

## Signal-to-noise sweep

When the User asks for a trim rather than a split. Binding meaning and live rules stay; only noise goes.

1. Measure: `python3 tools/list_oversize_docs.py --boot --dupes` (sizes, boot-chain bytes per path, sentences repeated across docs; add `--over-kb 6` to widen the band).
2. Pick one canonical home per repeated rule (the file that owns the topic: `design/tools.md` for tool and gate rules, `BOT.md` for Bot rules, `design/refactor.md` for placement and owner rules). Elsewhere keep a one-line pointer or nothing.
3. Delete obsolete history prose, boilerplate headers that restate another file, empty numbered stubs. Boot-chain files (the agents file, path files, `BOT.md`) get the hardest cut: every token is paid on every cold start.
4. Rewrite CRLF/BOM files through `md_format_lib` or an editor that keeps both; compare `git diff --stat` for whole-file churn.
5. Gates once: `check_tool_docs.py --stale-refs --narration`, `check_load_graph.py`, `check_tool_docs.py`, `check_tool_cli.py` if a tool changed. Design choices that are the User's go in the PR body as numbered questions with options.
