id: open-code-skills
owner: build
status: open
done-when: All ten OpenCode skills exist under .opencode/skills/<name>/SKILL.md with correct YAML frontmatter, each skill folder also contains a focused helper Python script that provides a simplified direct interface to the relevant existing tools/ commands, the two already-created skills (task-ops and changelog-commit) have been updated to include their helpers, all skills are callable both by the user through OpenCode and programmatically by other agents via tools that make direct Ollama API calls (using the helpers where appropriate), they are wired into the relevant design docs and tooling so future Grok Build sessions know when to use them, a test suite or verification note confirms each skill works against its documented usage scenario, and the skills correctly replace the mechanical work they are intended to own.
area: tools
door: tools
job: skills

## Approach
Create the OpenCode skills that let the local gpt-oss:20b agent (with Qwen3-VL as its default eyes) reliably own the mechanical work currently done by Grok Bot and parts of Grok Build. The pre-task fixes (opt/reuse-map removal, automatic Next Steps, changelog_state helper, visual-proof log convention, and shot-flow how-to) have already landed. This task creates the skills (including a focused helper script in each skill folder), updates the two existing skills so they also have helpers, tests them, and wires them into the documentation and tooling so future sessions can use them.

Skills must be usable in two ways:
- By the user through OpenCode (description-match loading of SKILL.md).
- Programmatically by other agents via tools that make direct Ollama API calls (unload/reload rules still apply; only one model active at a time). The skill helpers are the preferred interface for the mechanical work.

Create all ten skills (and their helpers) in a single batch of file writes, then do the wiring and testing. Also fix the two skills that already exist so they include helpers. Do not run a full protocol cycle for each individual skill.

## Context the implementing agent needs
- Skills live as `.opencode/skills/<name>/SKILL.md` with YAML frontmatter (`name` + `description`). OpenCode loads them by description match.
- Each skill folder must also contain a helper Python script (e.g. `helper.py` or a clearly named script) that provides a simplified, direct interface to the relevant existing `tools/` commands. Prefer calling the existing CLI rather than reimplementing logic.
- The local agent must be able to work on a trusted Grok worktree after `slice.py open`.
- Only one Ollama model is active at a time. Unload gpt-oss:20b before loading Qwen3-VL; reload gpt-oss afterward. Qwen3-VL is the default eyes.
- Visual proof artifacts go in `_logs/visual-proof/` (see design/prove.md). Shot-flow creation must follow design/shot-flows-howto.md.
- Task creation already writes a `## Next Steps (User Only)` section when a resume value is supplied. Do not treat `resume` as a required header field.
- Changelog tool now has `changelog_state(root)` in doc_patch.py.
- Opt and reuse-map bot jobs have been removed.
- The two skills already present (task-ops and changelog-commit) must be updated to include their helpers.

## Skills to create (with usage scenarios and what they replace)

### task-ops
**Replaces:** Manual task creation/update and door/job assignment currently done by hand or by stronger agents.  
**Usage:** When a new task needs to be created or an existing one needs door/job, done-when, or Next Steps. Call from a Build session or from OpenCode.  
**Notes:** Use `docs.py task new` / `task update`. Do not invent door/job pairs.  
**Helper:** Simplified wrapper around `docs.py task new` / `task update` / `task check`.

### changelog-commit
**Replaces:** Manual changelog writing and the ad-hoc “look at git diff and write bullets” step at the end of a Build session or on an open branch.  
**Usage:** When a session needs to add or update a changelog entry, or when closing a Grok Build branch after proves.  
**Notes:** Call `changelog_state` first. Focus only on bullets + concise Summary. Can push when requested.  
**Helper:** Simplified wrapper that calls the changelog state helper then the existing changelog patch path.

### gather-assist
**Replaces:** The error-prone part of the local-model gather chain that `slice.py open` still runs via `gather-pick --chain`.  
**Usage:** Automatically invoked (or callable) during gather to improve the JSON the oss agent returns for scout/mark/follow/gap/trim/review.  
**Notes:** Return only the JSON the role expects. Operate on the trusted worktree.  
**Helper:** Thin wrapper that runs the existing gather-pick chain pieces and returns the expected JSON shape.

### visual-proof
**Replaces:** Manual before/after capture, montage creation, and visual-diff steps currently done by hand or by stronger models.  
**Usage:** Before any code changes (capture + record args), after changes (re-capture), then montage + diff. Later phases read `_logs/visual-proof/`.  
**Notes:** Qwen3-VL is the default eyes. Threshold for no-change: `--max-ratio 0.001`.  
**Helper:** Simplified interface to the existing `shots.py` capture / inspect / montage commands, writing under `_logs/visual-proof/`.

### prove-inventory
**Replaces:** The “figure out which gates this task needs and run them” step that stronger agents currently do.  
**Usage:** When a Build session needs to know if the work is proved, or when a task asks for a prove report. Also notes whether the documented prove steps actually prove the work.  
**Notes:** Follow the change-kind table in design/prove.md.  
**Helper:** Wrapper that reads the task + prove.md table and runs the relevant existing gate commands.

### warnscan-fix
**Replaces:** Manual warning triage and the trivial fixes currently done by hand after `gate.py warnscan`.  
**Usage:** After a change that may have introduced warnings, or as a cleanup step.  
**Notes:** Only the trivial fixes listed in design/gdscript-law.md.  
**Helper:** Wrapper around `gate.py warnscan` plus the mechanical fix patterns from gdscript-law.md.

### code-map-sync
**Replaces:** Manual code-map updates after adding/moving/deleting .gd files.  
**Usage:** After any change that affects the set of live scripts.  
**Notes:** Use `docs.py code-map check` and its update paths.  
**Helper:** Direct wrapper around the existing code-map check/update commands.

### bot-mechanical
**Replaces:** The remaining mechanical Grok Bot sweeps (size, extract, docs, relocate) after opt and reuse-map were removed.  
**Usage:** When a Bot sweep is requested or as part of a scheduled mechanical pass.  
**Notes:** Follow the current bot job files. Stop if judgment is required.  
**Helper:** Simplified runner for the remaining mechanical bot jobs.

### github-issue-triage
**Replaces:** Manual conversion of GitHub issues into routed task files.  
**Usage:** When open issues need to become design/tasks/ entries, or on a periodic triage pass.  
**Notes:** Prefer issues that already have door/job labels or in-game report data. Use `gh` + `docs.py task new`.  
**Helper:** Wrapper that uses `gh` to fetch issues and then calls the task-ops helper.

### shots-flow-manager
**Replaces:** Manual creation and repair of shot flows and video capture scenes.  
**Usage:** When an existing flow fails to capture correctly, or when a new thing needs to be captured.  
**Notes:** Follow design/shot-flows-howto.md. Use MCP + Qwen3-VL. Prefer editing existing flows. Write notes to `_logs/visual-proof/`.  
**Helper:** Interface to existing `shots.py flow` commands plus file editing of the JSON under tools/data/shot-flows/.

## Wiring and testing requirements
- Add a short section to the relevant design docs (prove.md, BOT.md, tasks/README.md, shot-flows-howto.md, or a new routed design page for these skills) that lists each skill, when a future Grok Build session should call it, and how to invoke it programmatically (preferring the skill helpers).
- Ensure each skill can be invoked by a thin tool wrapper that makes a direct Ollama API call (so other agents can use them without going through OpenCode). The helpers should be the preferred way to do the mechanical work.
- Update the two already-created skills (task-ops and changelog-commit) so they also contain their focused helpers.
- Provide a verification note or small test that exercises each skill against its usage scenario (at least the happy path) and confirms the documented replacement behavior.
- Update any Grok Build or Bot protocol docs so they point at the skills (and their helpers) instead of describing the mechanical steps inline.

## Units
- skills-batch
- wire-and-test

## Next Steps (User Only)
python tools/slice.py open tools.skills --task open-code-skills