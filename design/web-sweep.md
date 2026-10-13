# Web / chat session flow: sweep

Status: protocol
Read when: web / chat sweep flow (User names it and a goal)

For **web / chat** only. Grok Build and Grok Bot ignore it. Flows, Phase 1 and the Do-not list stay on the web door.

## Start

User names the flow and a goal (hot-path costs, setup or code-loop issues, missing caches, etc.) and the areas (or “all code-map hot paths”). The goal is the lens for the whole sweep.

## Output format (mandatory)

**Findings**  
(Full relevant body has been read. The behavior is clearly wrong, incomplete on a common edge, a resource/lifetime problem on a frequent path, an unintuitive flow, a collision/visual mismatch, an interact-group node that is never removed on the open/spent/hidden path, a multi-step flow that can leave phase/item/resource fields inconsistent, or an unpaired free/hide, judged from the code and surrounding context. Design docs and open tasks are consulted when they exist; anything that matches an open task or an explicit “intentional” note is excluded. Cite the function or pattern.)

**Needs investigation**  
(Body or surrounding context not yet fully read, or the defect is not yet clear.)

**Meets requirements**  
(Body has been read and the behavior is correct under the system’s intent.)

## Rules

- The User-named goal is the lens for the whole sweep. Read owning docs and open tasks that touch the named areas before treating a pattern as a finding.
- A function or system is closed only after its relevant body (or the bodies that implement the goal) has been read. A code-map row, a comment, or a one-line summary is not enough.
- Coverage obligation: for every system row in `design/code-map.md` (or the areas the User named), body-read the facade plus every helper it calls on the player-visible path, including setup, present, interact, open/close, and phase/job scripts. Also body-read every prop, mesh, collision, and banner/spot builder in the hub and dungeon. “Hot-path” does not exclude setup, present, or phase files. Any file that creates a `StaticBody3D`, `CollisionShape3D`, `MeshInstance3D`, or writes a phase/timer field is in scope.
- A system may not be listed under Meets requirements until its setup, present, phase, and prop-builder files have been body-read. Needs investigation stays until those files are opened. The final report must list any system whose prop or flow scripts remain unread.
- Findings: full relevant body has been read and the behavior is clearly wrong, incomplete on a common edge, a resource/lifetime problem on a frequent path, or an unintuitive flow (judged from the code and surrounding context). Consult design docs and open tasks when they exist; exclude anything that matches an open task or an explicit intentional note. Cite the function or pattern.
- Needs investigation when the body or surrounding context has not yet been fully read, or the defect is not yet clear. Do not promote these to findings.
- Meets requirements when the body has been read and the behavior is correct under the system’s intent.
- Stop and request another turn as long as any code-map row still has an unchecked checklist item. Do not declare the sweep complete, and do not move a system to Meets, while any checklist item remains open. On each continuation the next action is the next unchecked file from `code_map.py sweep`, not a new system.
- No code changes during the sweep itself. Findings can later become a task (Bot opt, Build slice, or web park).
- When working out of a grok-build branch, do not add changelog files unless the User named changelog as the specific goal of the session.

## Bug Sweep Sub-Flow

A bug sweep is a focused sub-flow of the web sweep. Use it when the goal is to flag defects for a later task rather than implement changes.

### Definition of a bug
A bug is any behavior that produces wrong player-visible results or fails to meet the intent of the system under conditions the design contemplates. Design docs are concept overviews, not exhaustive requirement lists. This includes:
- Incorrect calculations, fallbacks, or state transitions (even if non-crashing)
- Incomplete implementations of the happy path (common edges fail)
- Feel and presentation defects (wrong vertical motion, missing feedback, incorrect facing, visual leaks)
- Progression and economy gaps (overwrite instead of top-up, silent drops, off-by-one)
- Input and state lifetime issues (locks, cooldowns, or armed flags that do not decay or clear as designed)
- Resource and lifecycle problems (mesh/texture leaks, repeated loads, missing cleanup on frequent paths)
- Unexpected behavior (UI focus issues, unnecessary menu steps, unintuitive flows)
- Collision/visual mismatch (shape center or offset does not match the visual node’s feet or bounds)
- Interact-group lifetime (node added to `"interact"`, `"gates"`, or `"boss_door"` and never removed or freed on the open/spent/hidden path)
- Multi-step flow desync (forge job, extract, restock, loadout enter, etc. can leave phase, item, or resource fields inconsistent after cancel, tab change, payment failure, or deferred rebuild)
- Unpaired free/hide (visual or collision created in one helper, matching free/hide in another, and the two are not paired)

Do **not** treat the following as bugs:
- Missing defensive null/validity checks on paths whose construction order and invariants guarantee the node or value exists
- Silent fallbacks or early returns on missing assets when prove.md applies only to test/proof scripts
- Behavior that matches an open task’s stated rules or an explicit design note
- Persistence or idle states that the owning doc or code comments describe as intentional

### Reporting
Use the mandatory Findings / Needs investigation / Meets requirements format.

- **Findings**: Full relevant body has been read. The behavior is clearly wrong, incomplete on a common edge, a resource/lifetime problem on a frequent path, or an unintuitive flow, judged from the code and surrounding context. Design docs and open tasks are consulted when they exist; anything that matches an open task or an explicit “intentional” note is excluded. Cite the function or pattern.
- **Needs investigation**: Body or surrounding context not yet fully read, or the defect is not yet clear.
- **Meets requirements**: Body has been read and the behavior is correct under the system’s intent.

If an item cannot be definitively concluded, list it under Findings and add a short “Needs more information” note at the end of the report.

### Coverage checklist (mandatory per code-map row)

Before a system may be moved to Meets requirements or dropped from the open set, every item below must be body-read or explicitly marked “no such file”:

- [ ] Facade (`*.gd` named in the code-map row)
- [ ] Setup / ready / boot / spawn builders
- [ ] Present / tick / physics / process
- [ ] Phase / job / multi-step state machines (forge, extract, loadout, restock, stream jobs, etc.)
- [ ] Prop / mesh / collision / banner / spot builders (any file that constructs `StaticBody3D`, `CollisionShape3D`, `MeshInstance3D`, or places a named layout spot)
- [ ] Interact / open / close / hide / free pairs
- [ ] Owning design doc (if one exists for the system)

Source of the list: `python tools/code_map.py sweep --system <Name>` (or with no `--system` for all). A one-line summary or a comment is not a body read. The agent must open the file.

The report must include the current open checklist (system → remaining unchecked items). A system stays under Needs investigation until its checklist is empty. “Continue” means open the next unchecked item on the oldest open system, not sample another facade.

The collision and multi-step items on the checklist exist because those are the paths that previously produced player-visible defects when left unread.


