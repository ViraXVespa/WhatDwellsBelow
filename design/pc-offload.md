# Build runner habits on the User PC

Status: protocol
Read when: Build inventories files, runs a local tool, reads a summary or writes through PowerShell

The existing repository `pc-offload` skill is the default for every Build task; load it once after startup and reuse it. This does not grant local execution or runtime permission. These are project workflow conventions, not platform security permissions. The cloud Bot follows BOT.md instead. Commands and flags belong to the tools catalog; `--help` is authoritative.

## Find and read

- The opening gather for a named door or job is `session-plan.md` at the worktree root. Read that file. It is gitignored and it is not under `_logs/`. Use `find.py func`, `find.py xref`, `find.py scripts --names` and `docs.py code-map row` only for a gap the plan does not cover, then trim the plan. Function and const names are `find.py scripts --names` or `--all-names` with one `--path`, not an xref of `^func`.
- Use `find.py route`, `find.py xref`, `find.py func`, `find.py changed` and `docs.py code-map row` rather than tree dumps, whole-file inventories or raw git output. Read the code actually being edited, not untouched siblings for size information; use `find.py stat` or filesystem Length for sizes.
- After a distinct planned run, read `python tools/session.py summary JOB` once. Do not read raw `_logs/` files. Filters (`--section`, `--match`, `--jsonl --where`) are documented in the lookup catalog. `summary JOB --files` lists the log's other files; `--files --read` prints their text. Quote PowerShell globs and headings; use `key=ge:N`, not an unquoted `>` which redirects output.
- Images default to isolated review. A necessary direct reference needs the task/session grant; shell readers are not an alternative. Image access and text OCR-first are separate rules.

The repository hook enforces these defaults. Do not disguise a command, change cwd or use arbitrary inline Python to avoid it. An explicit reference grant changes only selected direct image reads, not generation or host controls.

## Write and run

Write permanent edits to their real paths. For multiline Python/Markdown in PowerShell, use a single-quoted here-string into `python tools/docs.py patch write FILE`, then run the saved file. Double-quoted strings can mangle backticks and escapes; do not use `python -c` as a workaround.

A one-off script may run with `session.py py --script _logs/agent-py/FILE`; it is deleted afterward unless `--keep-script` is set. Even then it is ignored, not a next-session tool. Reusable work belongs under the owning `tools/` command with a catalog row. Cleanup may not target outside `_logs/agent-py/`.

Use the repository Godot runners: they select display/audio/locks and handle redirected Steam exit codes. Real screenshots need a renderer; headless smokes need the runner's headless settings. Keep ASCII hyphens in output and PowerShell strings.

## Finish and maintenance

Run the checks required by the change, not every catalog command. Design/agent-doc edits require `check.py load-graph`; `.gd` work requires the Build checks. Summaries and logs stay ignored; runners retain stamped summaries and an index, while `session.py clean` removes disposable logs.

A dedicated catalog-maintenance session changes the named runner/catalog optimization, not game behavior, media, week pins or unrelated smoke coverage. Extend an existing tool before adding another. New generic writers or broad skill changes need scope approval. Report the command, benefit and remaining rough edges.
