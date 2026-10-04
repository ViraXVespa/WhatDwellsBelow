# Load graph

Status: protocol
Read when: the User names routing work

Not a boot file. Not a topic index. See also is forbidden.
Never open `notes/`.

## Edges

AGENTS.md
    web   -> design/web-session.md -> protocol.md and constraints.md
            -> phase pages only at their phase: discuss (2), plan (3), emit (4), test (5)
            -> constraints-demo.md only before calling the build complete
            -> default brainstorm after boot; directed-goal only when the User asks
            -> present-User picture-read uncapped in design/ and the live thread tree
            -> docs/routing may open this file and the topic index; write stays one door
    build -> design/grok-build.md -> protocol.md and constraints.md
            -> design/build-job-cycle.md when gathering, changing, or proving
            -> listed runner from that cycle table when proving; do not invent a flag
            -> next unit is User-named
    bot   -> BOT.md -> exactly one Job sibling

Then, only if the User named work:
    one topic door -> one Job sibling (if that door has a Job table)
    graphics jobs are env, ground, volume, buffer, actor (not a boot path)
    grid carve / hall segments -> dungeon then gen
    gen publishes a cleaned 1 m maze, and hall runs; stream instances those runs; volume skins provided runs only; buffer occupancy reads the cleaned grid and mounts on interior faces; outline bake is the gen job
    (second door only when the User names the owner; conflicts_with is a load ban)
    and one design/code-map.md system row when live files are needed
    and design/tunables.md iff a number changes
    and design/versioning-log.md iff shipping a label
    and design/versioning.md iff the User named a pin or archive
    and design/isolated-media.md iff Grok Build is about to call Imagine
    and design/gdscript-law.md iff editing GDScript
    and design/tools.md iff running, adding, or documenting a tool (sibling tools-lint.md; Build-only siblings tools-build.md, tools-shims.md, tools-media.md)
    and design/doc-library.md iff editing docs by script or changing doc_patch / md_format_lib
    and design/pc-offload.md iff inventory, verify, Windows write, or a new local runner

Imagine tool calls use the isolated-media **gate** only. Do not also open art_pipeline to generate.
Build repo skills live at `.grok/skills/` (Imagine / I2V / pc-offload). They are not the Grok Bot skill library.
Imagine / I2V skills cite the isolated-media gate only and stay Build-only.
The pc-offload skill cites the pc-offload catalog for Grok Build on the User PC.
Types / warnings / tabs / 10KB live in `design/gdscript-law.md`, not the agents file.
Art Bible / pack / review / I2V unit prompt use design/art-pipeline.md then one sibling.

Recipes (never boot): design/refactor.md, design/doc-refactor.md.
Path files name recipes. Recipes do not name path files.
PC offload is a gate (`inventory_verify_or_windows_write`), not a recipe. The pc-offload skill may cite that gate.

## Do not load from here

Path session files do not point back at AGENTS as a fetch.
Topic siblings do not point at path files.
topics index and design/code-map.md do not point at each other.
Callers link a facade, never an art / UI / input / inventory / debug / hub / dungeon / save-tech / archives sibling.
conflicts_with is a load ban: do not open the second door in the pair unless the User names the owner.
See also is never a read list.
The checker fails leftover relic-index names and `notes/<file>` cites.

## 10/10 checks

1. Boot is at most AGENTS + path file + (web/Build) protocol + constraints, and each boot file stays under its `boot_bytes` budget in `routes.yaml` (the checker fails above it). Lower a budget after a trim; raise one only on a User go.
2. Bot boot is BOT.md + one Job sibling (the agents file only if Cursor already loaded it).
3. No mutual See also.
4. One job phrase belongs to one door.
5. Doors with a Job table stay thin.
6. Path files never appear on topic See also.
7. Versioning / changelog body is ship-only.
8. Opening this file happens when the User names routing work, or on a web docs/routing pass. Open design/parked-tasks.md only when the User names a parked task or resume parked.
9. Topic job siblings name no other `design/*.md` paths.
10. Opening the topic table is not a boot step.
11. README and code-map are human indexes, not boot files.
12. Door and job files start with an H1.

Machine-readable edges: `design/routes.yaml`. This file is the human sketch only.
