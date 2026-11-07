# Build job cycle

Status: protocol
Read when: Grok Build understands, changes, verifies or finishes a task

A **slice** is the User-opened worktree/session; a **unit** is one piece of its task. A route **door** owns a system, and `door.job` selects one part. **Q0** in older cards means the opening questions about look, reference and bounds, not a mandatory questionnaire.

## 1. Understand

- Read the named task and route's docs. Identify every system touched and read its code-map row before changing it.
- Use public commands: `find.py xref TEXT` for uses, `find.py func PATH NAME` for a function, `docs.py code-map row --path PATH` for ownership. A route card or file inventory is navigation, not source review. Do not repeat unchanged lookups.
- State the observable outcome and how to measure it. For a bug or performance miss, distinguish a reproduction from evidence of its cause. If the cause is not identified, instrument it before attempting a fix.

An answered task needs no repeated opening questionnaire. Ask only for missing look/reference/bounds or a discovery that changes an earlier answer. Do not shoot unrelated screens or read another session's memory inbox.

## 2. Prepare and implement

Add the cheapest missing signal, gated like existing debug/bench instrumentation so shipping behavior is unchanged. If blocked or awaiting design, update the task and stop that work.

Implement the named outcome, not a guessed cause. New systems need an agreed owner, design doc, save/entry behavior and smoke coverage before code. Helpers inside one system are Build decisions; a new cross-system owner, live-module replacement or greenfield rewrite needs approval. Update mapped smoke assertions for behavior you change. Add a phase or runner only when existing coverage cannot express the requirement.

For game work, follow the start card's load/import steps. Run `gate.py gd-load` when the unit's `.gd` edits are complete: an import or smoke alone does not establish that all changed scripts load. Tool/doc-only work does not need a gameplay run merely to obtain a screenshot.

## Context breaks (authoritative rule)

When context is above 120K, compact at the next good stopping point. Finish the coherent operation already in progress; do not interrupt a mutation, test or tool call halfway through. Save the task state and a short resume note: outcome, decisions, changed files, open questions, running job identifiers and latest result/log paths. Keep these through compaction; discard raw exploratory output. Use guided compact if available, otherwise print that keep-list and stop for the User to compact. Resume in the same session. This is not a fixed step before verification and does not create a new session or survey handoff.

## Permissions and questions

Permission to access a tool/file is not approval of a design choice. Ask before changing behavior, scope, looks or cross-system ownership the task does not settle. Use `ask_user_question` when available; otherwise ask in text and stop. Dismissal or timeout is not approval. Offer useful alternatives; do not recommend a look/feel as if it were a technical necessity.

Before each question, send the facts it depends on: current result, relevant paths, proposed change and unknowns. Name new assets/fonts/dependencies and their alternatives/size; confirm required access before use. Disclose assumptions and shared effects, including other screens found by `find.py xref`. After rejection, clarify before editing; after a second rejection offer a reference rather than another guess.

Put failed steps first as `Did not work: COMMAND REASON`. `slice.py start --failed` supplies actual failed results since the last ask; do not reconstruct them from memory. A step intentionally absent from the task is not a failure. Report outside-worktree writes and temporary/reverted changes when they affect the work; do not claim none without checking.

## 3. Verify

Use the cheapest check that would fail if this outcome were wrong. The prove standard owns recipes and evidence requirements; tool flags live in the catalogs, not internal module names.

- `.gd`: `python tools/gate.py gd-load`, mapped smoke coverage, then `python tools/gate.py build --batch`.
- A screen change: its own shot flow and UI load check; `--visual door.job` includes the mapped flows in the build gate. Create a missing flow first. Never use a door's unrelated screenshots as the job's baseline.
- No play-camera job: use its specified check, without `--visual` or an invented flow. A keyed still uses `media.py rekey-preview` and the source plate.
- Docs/routing: `check.py load-graph` must pass before calling the doc change done. Tools also need CLI/catalog checks and focused regression tests.

A failed/stale baseline or one with script errors is not evidence: fix the cause and capture again. Review the wide view first, then details; compare against accepted intent/reference and main, not merely a previous run of the same code. Isolated reviews return text; direct references require the scoped grant. OCR is for text, not shapes. Gates passing does not establish visual or audio acceptance.

Read each run's result and summary once through `session.py summary JOB`; filters are in the lookup catalog. Do not call unread errors harmless. A same-command retry is for truncation, timeout, crash, a busy lock or wrong scene, once. Prove is final verification, not another diagnostic loop: one small corrective edit and one rerun; still red, stop and report the log path. Retries stay in the session that ran the check. The tools door owns overall rerun limits.

## 4. Finish

1. Update affected docs, code-map rows and any changed tunable documentation. Close the task only when its acceptance is met (`docs.py task done ID`); otherwise save results and the exact remaining work. Unit queues use `slice.py start --unit-done` and continue in this session when the remaining request fits.
2. Revoke any temporary reference grant. Commit with `python tools/slice.py commit`, then plain `git push origin grok-build-wN`. Resolve conflicts without overwriting another session's work; never force or push main. The User's main checkout pulls the week branch; there is no manual merge-back step.
3. If the gate never ran, use `--gate-skipped WHY`; if it ran red, use `--red-gate LOGPATH`. These preserve the failure, not a green result. Do not wait for another approval just to commit/push authorized work.
4. Report outcomes, commands/results, rough edges and evidence. For visuals, `shots.py show` presents before/after together, one sheet per area; report what is on them and the required playtest confirmation. Then stop. Unfinished/red work stays in the same task for the next User-opened session.

Temporary one-off scripts belong under `_logs/agent-py/` and run with `session.py py`; reusable code belongs in the owning tool with a catalog row. Commit messages may use `_logs/commit-msg.txt`. Never commit logs or edit `version.json` by hand.
