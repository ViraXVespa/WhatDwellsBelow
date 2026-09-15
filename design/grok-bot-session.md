# Grok Bot session door

Status: protocol  
Read when: Grok Bot path; every Grok Bot session  
See also: `AGENTS.md`, `design/refactor.md`, `design/doc-refactor.md`

`See also:` is an index, not a read list. Do not open those files unless this file’s Job table, that file’s `Read when`, or the User names that work.

This file is binding for **Grok Bot** only. Grok Build and web / chat ignore it, except they may open `design/refactor.md` when they split for the 10KB cap.

Grok Build / web splitting one file that *its own edit* pushed over 10KB is not this path — use `design/refactor.md` inside that session.

## Recognize

Use this path when the User names Grok Bot / a refactor sweep / a Bot flow below, or when a Grok Bot / Cursor desktop assistant writes via GitHub PR.

After `AGENTS.md`, load **this door**, then **one** Job-table sibling. Do not load the other flow files. Do not load `design/protocol.md`, `design/constraints.md`, `Demo_GDD.md`, `design/web-session.md`, `design/grok-build.md`, `design/sessions.md`, `design/session-log.md`, or `design/changelog/` except the one new `{label}` file at ship time.

## Job → Open

| Job | Open |
|-----|------|
| Size sweep (over 10KB, then 5KB when whole functions can move) | `design/grok-bot-size.md` |
| Ad-hoc extract / existing-owner routing (User-gated; not the staged map) | `design/grok-bot-extract.md` |
| Staged reuse-map brief as one PR | `design/grok-bot-reuse.md` |
| Parked / named folder relocate | `design/grok-bot-relocate.md` |
| Doc facade / sibling split | `design/grok-bot-docs.md` |

If the User names more than one job, ask which flow this session is. One flow, one PR, then stop.

## Shared ship

- One open Bot PR at a time. Do not claim a write landed until the PR exists.
- Prefer one commit on the PR branch. Tell the User to **squash-merge** into `main` (not merge-commit or rebase-merge).
- One new `design/changelog/{label}.md` when the sweep is ready to land. `{label}` = baked `scripts/data/version.json` `label` with patch + 1. First heading MUST be `## {label}` (never `# {label}`). Body shape: `design/versioning.md`. Do not hand-edit `scripts/data/version.json` or `scripts/data/changelog.json`.
- Agent-visible protocol/doc changes get a changelog entry.
- After squash-merge: stop. CI stamps and tags. Do not create, amend, or offer a post-merge stamp commit.
- Touched live `scripts/**/*.gd` must ship under 10KB. Split with `design/refactor.md`. The under-5KB target is only `design/grok-bot-size.md`.
- PC offload catalog: `design/pc-offload.md`. Prefer Length summaries over opening untouched siblings.

## Shared do not

- Features, tunables, new game systems, skills, rarities, hub upgrades, co-op, art / I2V.
- Invented numbers.
- Behavior changes, drive-by renames, comment rewrites, wholesale retypes, reformats.
- `Entity.gd`, a UI framework, ECS, or flattening hostify clusters back into one oversized script.
- Growing an existing owner just to avoid a new file. Treating vaguely similar features as near-identical.
- Archives pins. Copying a pinned commit into `archives/` as a project tree.
- Opening `design/reuse-map.md` except from `design/grok-bot-reuse.md` when that brief is not the empty template.
- Declaring the whole sweep done and then starting a second flow.
- Editing design markdown or multi-line Python via PowerShell double-quoted strings or `python -c` (use `tools/write_utf8_file.py` / `tools/run_agent_py.ps1`).
- Leaving ephemeral agent scripts outside `_logs/agent-py/` or skipping cleanup.
