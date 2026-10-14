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

## Bug sweep

If the User asks for a bug sweep (or “flag defects”, “sweep for bugs”), stop and read `design/web-bug-sweep.md`. Follow that file instead of this one.
