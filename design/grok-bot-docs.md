# Grok Bot — documentation facades

Status: protocol  
Read when: Grok Bot Job table → doc facade / sibling split  

For **Grok Bot** documentation facade sweeps only. Recipe: `design/doc-refactor.md`. No change of meaning. No live `.gd` size sweep in this PR unless a touched script path in a code map row must stay accurate.

## Mandate

Split fat topic `design/*.md` files to the art_pipeline door + siblings layout, or trim them for signal-to-noise (below). Pass order and facade checklist: `design/doc-refactor.md`. Caps (Bot-only): a door stays under 4KB (Job table and rules), a sibling under 8KB (one job cluster; split again if one `##` section dominates), hard stop ~12KB: do not leave a touched topic file above it if a legal split exists. Rank over ~12KB first, then over ~8KB. One facade plus its new siblings per editing focus. Show the worklist; do not edit yet.

Scope (in / out): `design/doc-refactor.md`. No inventing systems.

## Read set

1. `design/doc-refactor.md`
2. The `design/README.md` topic index row for the door
3. After inventory: that one door and only the sibling for the active job

Do not concatenate all siblings into context. Do not open the staged reuse brief. Prefer Length / heading lists over pasting whole markdown bodies.

## Pass

1. Inventory: `python tools/check.py docs-size` (skips `design/changelog/`), ranked as above. Show worklist.
2. Split named first, per the `design/doc-refactor.md` pass order and facade checklist.
3. One `design/changelog/{label}.md` for the PR (always; `versioning-log.md` rule).
4. `python tools/check.py tool-docs --stale-refs --narration` (dead paths and identifiers fail; narration lines are advisory: rewrite in present tense or delete). Prove: `BOT.md`.

## Signal-to-noise sweep

When the User asks for a trim rather than a split. Binding meaning and live rules stay; only noise goes.

1. Measure: `python tools/check.py docs-size --boot --dupes` (sizes, boot-chain bytes per path, sentences repeated across docs; add `--over-kb 6` to widen the band).
2. Pick one canonical home per repeated rule (the file that owns the topic: `design/tools.md` for tool and gate rules, `BOT.md` for Bot rules, `design/refactor.md` for placement and owner rules). Elsewhere keep a one-line pointer or nothing.
3. Delete obsolete history prose, boilerplate headers that restate another file, empty numbered stubs. Boot-chain files (the agents file, path files, `BOT.md`) get the hardest cut: every token is paid on every cold start.
4. Rewrite CRLF/BOM files through `md_format_lib` or an editor that keeps both; compare `git diff --stat` for whole-file churn.
5. Gates once: `check.py tool-docs --stale-refs --narration`, `check.py load-graph`, `check.py tool-docs`, `check.py tool-cli` if a tool changed. Design choices that are the User's go in the PR body as numbered questions with options.
