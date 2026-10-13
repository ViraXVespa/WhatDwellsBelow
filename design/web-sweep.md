# Web / chat session flow: sweep

Status: protocol
Read when: web / chat sweep flow (User names it and a goal)

For **web / chat** only. Grok Build and Grok Bot ignore it. Flows, Phase 1 and the Do-not list stay on the web door.

## Start

User names the flow and a goal (hot-path costs, setup or code-loop issues, missing caches, etc.) and the areas (or “all code-map hot paths”). The goal is the lens for the whole sweep.

## Output format (mandatory)

**Findings**  
(Full relevant body has been read. The code produces a wrong, incomplete, leaky, mismatched, or unintuitive player-visible result on a path the design contemplates. Design docs and open tasks are consulted when they exist; exclude only an explicit intentional note or an open task that already covers the exact behavior. Design silence is not a reason to withhold. Cite the function or pattern. Note “checklist remaining” if the rest of the system is unread.)

**Needs investigation**  
(Body or surrounding context not yet fully read, or the defect is not yet clear.)

**Meets requirements**  
(Full checklist body-read and no player-visible defect observed on those paths.)

## Rules

- The User-named goal is the lens for the whole sweep. Read owning docs and open tasks that touch the named areas before treating a pattern as a finding.
- A function or system is closed only after its relevant body (or the bodies that implement the goal) has been read. A code-map row, a comment, or a one-line summary is not enough.
- Coverage obligation: for every system row in `design/code-map.md` (or the areas the User named), body-read the facade plus every helper it calls on the player-visible path, including setup, present, interact, open/close, and phase/job scripts. Also body-read every prop, mesh, collision, and banner/spot builder in the hub and dungeon. “Hot-path” does not exclude setup, present, or phase files. Any file that creates a `StaticBody3D`, `CollisionShape3D`, `MeshInstance3D`, or writes a phase/timer field is in scope.
- **One system at a time.** The User names the system (or the agent takes the next open system). Do not open any file belonging to another system until the current system’s coverage checklist is empty and its failure-mode line has been emitted. Within the current system, still body-read as many remaining checklist items as the turn can hold.
- A system may not be listed under Meets requirements until its setup, present, phase, and prop-builder files have been body-read. Needs investigation stays until those files are opened. The final report must list any system whose prop or flow scripts remain unread.
- Findings: full relevant body has been read and the code produces a wrong, incomplete, leaky, mismatched, or unintuitive player-visible result on a path the design contemplates (judged from the code and surrounding context). Consult design docs and open tasks when they exist; exclude only an explicit intentional note or an open task that already covers the exact behavior. Cite the function or pattern. List under Findings as soon as the body shows the defect; note “checklist remaining” if the rest of the system is unread.
- Needs investigation when the body or surrounding context has not yet been fully read, or the defect is not yet clear. Do not promote these to findings.
- Meets requirements only for systems whose full checklist has been body-read and no player-visible defect was observed on those paths.
- On every turn, body-read as many remaining checklist items of the *current system* as the turn can hold (open in parallel). Request another turn only when no further files of that system can be opened this turn. The requesting message must still list every Finding discovered so far plus the current system’s open checklist. Do not end a turn with only “no new Findings” (or a closed system) while unread checklist items of the current system exist and more of its files could still have been opened. Do not open files from any other system until the current one’s checklist is empty and its failure-mode line is written.
- Body-reads use the current commit SHA in raw URLs (see web-session.md GitHub Read Notes) so a just-pushed protocol or code change is not masked by the branch-tip CDN cache.
- No code changes during the sweep itself. Findings can later become a task (Bot opt, Build slice, or web park).
- When working out of a grok-build branch, do not add changelog files unless the User named changelog as the specific goal of the session.

## Bug Sweep Sub-Flow

A bug sweep is a focused sub-flow of the web sweep. Use it when the goal is to flag defects for a later task rather than implement changes.

### Definition of a bug
A bug is any behavior that produces wrong player-visible results or fails to meet the intent of the system under conditions the design contemplates. Design docs are concept overviews, not exhaustive requirement lists. When the design is silent or high-level, judge from the code’s player-visible result and common-edge completeness. This includes:
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

### Risk surface (mandatory before Meets)

The eight classic failure modes are a floor, not a ceiling. Before a system may be listed under Meets requirements the agent must open the relevant bodies and cite evidence for every item below on the player-visible paths. “No such pattern” is acceptable only after the bodies are open and the proving lines are quoted. Absence of the citation keeps the system under Needs investigation.

1. Resource hot paths — any `ImageTexture.create_from_image`, `SurfaceTool.commit`, `.mesh =`, or `.texture =` on a frame or event path. Show the assignment line and the free or reuse of the previous object. Unpaired create/assign is a Finding. Second extract required (see below).
2. Static or shared caches that hold Nodes or are keyed only by position/count/frame. Show `is_instance_valid` on every read path, including flush and deferred. Shared statics that can outlive the node are Findings unless full lifetime is proven.
3. Item / UID removal and multi-step economy (extract, restock, forge, loadout, drop). Show whether a miss re-adds the item or can silently drop. Show whether partial state (charges, stacks, locks) is top-up/merge or full overwrite. Show that cancel, tab change, payment failure, or deferred rebuild leaves phase/item/resource fields consistent.
4. Forced position pins after physics (`global_position.y = 0` or equivalent after `move_and_slide`). Show they do not fight lift, hop, fly, or knock on the same node.
5. Bounds and indexing (threat, travel, grid, distance arrays). Show the bounds check before every index use.
6. Animation and clip fallbacks. Show that an empty or missing clip does not leave a blank sprite and does not collapse diagonals.
7. Interact-group lifetime and prompt resolution (`interact`, `gates`, `boss_door`). Show remove-or-free on open/spent/hidden/used and that the prompt string is a correct spent/used string.
8. Presentation and feel (facing, vertical motion, feedback, focus/status clear on mode change). Show the actual result path.
9. Incomplete happy-path edges the design contemplates. Show the common failure cases are handled or explicitly deferred.
10. Collision/visual bounds (any file that emits both a visual node and a collision shape). Compute the visual’s world-space bounds (for a `Sprite3D`: `pixel_size * texture size` plus position/centering; for a mesh: its AABB) and the collision’s world-space bounds (shape size + any position offset). Cite both calculations. A mismatch of feet, height, or lateral span is a Finding unless an explicit design note justifies the offset.

### High-signal re-validation (mandatory every sweep)

Even if a system looks clean, body-read these files (or their current equivalents) and cite the proving lines:
`near_interact.gd`, `extract.gd`, `projectile.gd` (flush/lock path), `restock.gd`, `enemy_present.gd` (Y-pin), `threat.gd`, animation direction and clip fallback helpers, `hp_bar.gd`, `telegraph.gd`, and any forge/extract multi-step job script.

### Evidence rule

A system may be listed under Meets requirements only with a one-line citation of the proving code for each risk-surface item that applies. “Cleared” or “no such pattern” without the line is not enough.

### Depth-first continue

A turn may not open a new top-level system until every currently open high-signal path has either a Finding or an evidence-cited clear. Request another turn only when no further high-signal files can be opened this turn. The requesting message must still list every Finding discovered so far plus the current open checklist and coverage ledger.

### Second-extract rule

Any file that creates or assigns a mesh or texture, or that performs a multi-step resource write, must be pulled a second time with the instruction “show the exact assignment, free, and early-return lines.” The first extract is structure only.

### Coverage ledger

Every report ends with a short ledger: every directory touched, every high-signal file opened, and status (Finding / evidence-clear / still open). This is the substitute for an external tracker.

### Reporting
Use the mandatory Findings / Needs investigation / Meets requirements format.

- **Findings**: Full relevant body has been read. The code produces a wrong, incomplete, leaky, mismatched, or unintuitive player-visible result on a path the design contemplates, judged from the code and surrounding context. Design docs and open tasks are consulted when they exist; exclude only an explicit intentional note or an open task that already covers the exact behavior. Cite the function or pattern. List as soon as the body shows the defect; note “checklist remaining” if the rest of the system is unread.
- **Needs investigation**: Body or surrounding context not yet fully read, or the defect is not yet clear.
- **Meets requirements**: Full checklist body-read (including Failure-mode scan) and no player-visible defect observed on those paths. Report must include the one-line Failure modes citation.

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
- [ ] Failure-mode scan (static caches, UID/silent-drop, overwrite-vs-top-up, mesh/texture assignment, Y-pin, bounds, empty-clip, interact-group lifetime, collision/visual bounds)

Source of the list: `python tools/code_map.py sweep --system <Name>` (or with no `--system` for all). A one-line summary or a comment is not a body read. The agent must open the file.

The report must include the current open checklist (only the active system → remaining unchecked items). A system stays under Needs investigation until its checklist is empty. On each turn body-read as many remaining items of the active system as the turn can hold; request another turn only when no further files of that system can be opened. “Continue” means open the next unchecked items of the current system, not sample another system’s facade.

The collision and multi-step items on the checklist exist because those are the paths that previously produced player-visible defects when left unread.
