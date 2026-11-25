id: open-code-skills
owner: build
status: open
done-when: The remaining eight OpenCode skills exist as SKILL.md files under .opencode/skills/ with correct YAML frontmatter, all ten skills load by description match, they are callable both by the user through OpenCode and programmatically by other agents via tools that make direct Ollama API calls, they are wired into the relevant design docs and tooling so future Grok Build sessions know when to use them, a test suite or verification note confirms each skill works against its documented usage scenario, and the skills correctly replace the mechanical work they are intended to own.
area: tools

## Approach
Create the remaining OpenCode skills that let the local gpt-oss:20b agent (with Qwen3-VL as its default eyes) reliably own the mechanical work currently done by Grok Bot and parts of Grok Build. The pre-task fixes (opt/reuse-map removal, automatic Next Steps, changelog_state helper, visual-proof log convention, and shot-flow how-to) have already landed. task-ops and changelog-commit already exist under .opencode/skills/ and have functional Ollama wrappers in tools/lib/skills_wrappers.py. This task creates the other eight skills, tests all ten, and wires them into the documentation and tooling so future sessions can use them.

Skills must be usable in two ways:
- By the user through OpenCode (description-match loading of SKILL.md from .opencode/skills/).
- Programmatically by other agents via tools that make direct Ollama API calls (unload/reload rules still apply; only one model active at a time). Match the call style already used in skills_wrappers.py and gather_pick.py.

Create the remaining skills in a single batch of file writes, then do the wiring and testing. Do not run a full protocol cycle for each individual skill.

## Context the implementing agent needs
- Skills live as SKILL.md files with YAML frontmatter (`name` + `description`) under `.opencode/skills/<name>/SKILL.md`.
- The local agent must be able to work on a trusted Grok worktree after `slice.py open`.
- Only one Ollama model is active at a time. Unload gpt-oss:20b before loading Qwen3-VL; reload gpt-oss afterward. Qwen3-VL is the default eyes.
- Visual proof artifacts go in `_logs/visual-proof/` (see design/prove.md). Shot-flow creation must follow design/shot-flows-howto.md.
- Task creation already writes a `## Next Steps (User Only)` section when a resume value is supplied. Do not treat `resume` as a required header field.
- Changelog tool now has `changelog_state(root)` in doc_patch.py.
- Opt and reuse-map bot jobs have been removed.
- task-ops and changelog-commit already exist and have working wrappers.

## Skills that already exist
- task-ops
- changelog-commit

## Skills still to create (with usage scenarios and what they replace)

### gather-assist
**Replaces:** The error-prone part of the local-model gather chain that `slice.py open` still runs via `gather-pick --chain`.  
**Usage:** Automatically invoked (or callable) during gather to improve the JSON the oss agent returns for scout/mark/follow/gap/trim/review.  
**Notes:** Return only the JSON the role expects. Operate on the trusted worktree.

### visual-proof
**Replaces:** Manual before/after capture, montage creation, and visual-diff steps currently done by hand or by stronger models.  
**Usage:** Before any code changes (capture + record args), after changes (re-capture), then montage + diff. Later phases read `_logs/visual-proof/`.  
**Notes:** Qwen3-VL is the default eyes. Threshold for no-change: `--max-ratio 0.001`.

### prove-inventory
**Replaces:** The “figure out which gates this task needs and run them” step that stronger agents currently do.  
**Usage:** When a Build session needs to know if the work is proved, or when a task asks for a prove report. Also notes whether the documented prove steps actually prove the work.  
**Notes:** Follow the change-kind table in design/prove.md.

### warnscan-fix
**Replaces:** Manual warning triage and the trivial fixes currently done by hand after `gate.py warnscan`.  
**Usage:** After a change that may have introduced warnings, or as a cleanup step.  
**Notes:** Only the trivial fixes listed in design/gdscript-law.md.

### code-map-sync
**Replaces:** Manual code-map updates after adding/moving/deleting .gd files.  
**Usage:** After any change that affects the set of live scripts.  
**Notes:** Use `docs.py code-map check` and its update paths.

### bot-mechanical
**Replaces:** The remaining mechanical Grok Bot sweeps (size, extract, docs, relocate) after opt and reuse-map were removed.  
**Usage:** When a Bot sweep is requested or as part of a scheduled mechanical pass.  
**Notes:** Follow the current bot job files. Stop if judgment is required.

### github-issue-triage
**Replaces:** Manual conversion of GitHub issues into routed task files.  
**Usage:** When open issues need to become design/tasks/ entries, or on a periodic triage pass.  
**Notes:** Prefer issues that already have door/job labels or in-game report data. Use `gh` + `docs.py task new`.

### shots-flow-manager
**Replaces:** Manual creation and repair of shot flows and video capture scenes.  
**Usage:** When an existing flow fails to capture correctly, or when a new thing needs to be captured.  
**Notes:** Follow design/shot-flows-howto.md. Use MCP + Qwen3-VL. Prefer editing existing flows. Write notes to `_logs/visual-proof/`.

## Wiring and testing requirements
- Add a short section to the relevant design docs (prove.md, BOT.md, tasks/README.md, shot-flows-howto.md, or a new design/open-code-skills.md) that lists each skill, when a future Grok Build session should call it, and how to invoke it programmatically.
- Extend the existing skills_wrappers.py (or add sibling wrappers) so every skill can be invoked by a thin tool that makes a direct Ollama API call.
- Provide a verification note or small test that exercises each skill against its usage scenario (at least the happy path) and confirms the documented replacement behavior.
- Update any Grok Build or Bot protocol docs so they point at the skills instead of describing the mechanical steps inline.

## Units
- skills-batch
- wire-and-test

## Next Steps (User Only)
python tools/slice.py open tools --task open-code-skills
