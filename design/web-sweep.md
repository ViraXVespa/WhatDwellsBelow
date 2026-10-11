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
