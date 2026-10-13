# Web / chat session flow: sweep

Status: protocol
Read when: web / chat sweep flow (User names it and a goal)

For **web / chat** only. Grok Build and Grok Bot ignore it. Flows, Phase 1 and the Do-not list stay on the web door.

## Start

User names the flow and a goal (hot-path costs, setup or code-loop issues, missing caches, etc.) and the areas (or “all code-map hot paths”). The goal is the lens for the whole sweep.

## Output format (mandatory)

**Findings**  
(Only items where the owning requirement was read and is unmet. Cite the function or doc.)

**Needs investigation**  
(Patterns whose owning requirement, control flow, or constraint has not yet been fully read. Do not turn these into findings.)

**Meets requirements**  
(Items where the owning requirement was read and is met.)

A progress bar may appear in the header once the sweep is underway (rough % of identified hot-path bodies opened at the required depth).

## Rules

- A frame or physics-tick function is closed only after its body has been read for repeated lookups, full-list walks, and unconditional work. “No while/for,” “delegates,” or “code-map row exists” is not enough.
- Two-question test for any hot-path body already opened:
  1. Does the owning requirement force this exact work (the full list walk, the per-action event scan, the repeated lookup)?
  2. If not, is there repeated or unconditional work that could be cached or narrowed without violating the requirement?
- Findings only when (1) is no and (2) is yes. Cite the line or pattern.
- Leave under Needs investigation if you cannot yet tell whether the requirement forces the work.
- Meets requirements only when the work that remains is required by the owning constraint.
- Owning docs are read before a pattern is moved from Needs to Findings or Meets.
- Stop and ask for another turn whenever the next body needs to be opened. Do not declare the review complete until the User says so or every named area is closed.
- No code changes during the sweep itself. Findings can later become a task (Bot opt, Build slice, or web park).
- When working out of a grok-build branch, do not add changelog files unless the User named changelog as the specific goal of the session.

## Bug Sweep Sub-Flow

A bug sweep is a focused sub-flow of the web sweep. Use it when the goal is to flag defects for a later task rather than implement changes.

### Definition of a bug
A bug is any behavior that fails to meet an owning requirement or produces wrong player-visible results under conditions the design contemplates. This includes:
- Incorrect calculations, fallbacks, or state transitions (even if non-crashing)
- Incomplete implementations of stated design (happy path works, common edges do not)
- Feel and presentation defects (wrong vertical motion, missing feedback, incorrect facing, visual leaks)
- Progression and economy gaps (overwrite instead of top-up, silent drops, off-by-one)
- Input and state lifetime issues (locks, cooldowns, or armed flags that do not decay or clear as designed)
- Resource and lifecycle problems (mesh/texture leaks, repeated loads, missing cleanup on frequent paths)
- Unexpected behavior (UI focus issues, unnecessary menu steps, unintuitive flows)

Do **not** treat the following as bugs:
- Missing defensive null/validity checks on paths whose construction order and invariants guarantee the node or value exists (extra checks add hot-path overhead for unreachable cases)
- Silent fallbacks or early returns on missing assets when prove.md applies only to test/proof scripts
- Behavior that matches an open task’s stated rules or an explicit design note
- Persistence or idle states that the owning doc or code comments describe as intentional (e.g. lock remains armed between combats)

### Required reads before flagging
- Owning design doc for the system under examination
- Open tasks in `design/tasks/` that touch the same area
- Full function bodies (not partial summaries) for any logic that looks suspicious
- Construction and lifetime paths that establish invariants

### Reporting
Use Findings / Needs investigation / Meets requirements. Only keep an item in Findings when the owning requirement is unmet **and** a realistic path to the bad state exists under normal play. Mark items that need design confirmation as Needs investigation. Drop or move to Meets when the full read shows the behavior is intended or covered by an open task.

### Session artifacts
Accumulate findings across turns. On completion, write a task that lists confirmed issues and notes that a second-pass sweep (broader categories above) may append more. Do not treat the first pass as exhaustive.

