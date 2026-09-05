# Copilot session flow

Status: protocol  
Read when: Copilot path; every Copilot / refactor-sweep session  
See also: `AGENTS.md`, `design/refactor.md`, `design/README.md`

This file is binding for **Copilot** only. Grok Build and web / chat ignore it, except that they may open `design/refactor.md` when they split for the 10KB cap.

Copilot writes the checkout. Copilot’s only job is a periodic full-repo refactor sweep of live `scripts/**/*.gd`. Grok writes behavior.

## Recognize

The User named a Copilot / refactor sweep, or this agent is Copilot. If a Grok path is asked only to split one file that *its own edit* pushed over 10KB, that is not this path — use `design/refactor.md` inside the current Grok session.

## Read set

Load only:

1. `AGENTS.md`
2. This file
3. `design/refactor.md`
4. The `design/README.md` **code map** row for the cluster about to be edited
5. After the inventory: the live `.gd` files in that one cluster

Do not read `design/protocol.md` beyond a pointer, `design/constraints.md`, topic design files, `design/sessions.md`, `design/changelog/`, `Demo_GDD.md`, `design/web-session.md`, or `design/grok-build.md`.

If a move would change player-visible behavior or fight binding design, stop and ask. Do not load the corpus to invent a reason to continue.

## Mandate

Sweep the whole live script tree. Not a feature slice. Not “only these files” unless the User overrides the worklist.

**In scope:** `scripts/**/*.gd` that ship.  
**Out of scope:** `scenes/`, `assets/`, `tools/`, `design/`, `archives/`, pinned commits, `project.godot`, and any file under a pinned archive.

Two passes, in this order:

1. **Size** — files over **10,000 bytes** first, then files over **5,000 bytes** that can shrink by moving existing code.
2. **Reuse** — duplicated logic that already has an owner (`scripts/ui/menu_pad.gd`, `scripts/ui/prompt_view.gd`, and other existing shared scripts). Point the copies at that owner.

Do not create `scripts/util/` or any other new shared module. If nothing existing owns the copy, leave it and report it.

## Inventory

Before opening bodies:

1. List every live `scripts/**/*.gd` with UTF-8 byte size only.
2. Rank:
   - over 10KB
   - over 5KB
   - reuse candidates that span two facades / folders and already have an owner
3. Show the ranked worklist. Do not edit yet.

Files already under 5KB are not size targets. Do not split them “for cleanliness.”

## Batch

One **cluster** per batch. A cluster is one facade plus the siblings involved in that split, or one existing shared owner plus the call sites that start using it.

1. Open only that cluster.
2. Apply `design/refactor.md`.
3. Size goal for this path: each resulting live `.gd` in the cluster should be under **5KB** when existing functions can move to do that. If a single existing function is itself over 5KB, leave that function whole and report it.
4. 10KB remains the ship floor. Never leave a touched file over 10KB if a legal split can fix it.
5. Stop. Do not start the next cluster.

## Report

After each cluster, tell the User:

- files changed (path + bytes before / after)
- new sibling helpers created (moved code only)
- reuse call sites now pointing at an existing owner
- what is still over 10KB, still over 5KB, or still duplicated with no owner
- the next cluster on the ranked list

Write the same notes to `_logs/copilot-sweep.md` (repo root). That folder is gitignored and must not be committed. Overwrite or append in that one file. Do not write `design/sessions.md` or `design/changelog/`.

Then ask whether to take the next cluster. Do not continue until the User says yes.

## Allowed

- Move existing functions into a new sibling helper because of size
- Add the minimum wiring so the project compiles: `load()` / `preload()`, a one-line facade delegate, `host` / `pt` / `ui` / `p` on a moved `static func`
- Change call sites to use an **existing** shared function
- Add `: Type` on a line already being moved so Godot can compile (`AGENTS.md` → GDScript types)
- Update the `design/README.md` code map row when a split adds a sibling the map must list

## Forbidden

- Features, tunables, new systems, skills, rarities, hub work, co-op, art / I2V
- New helper APIs, new shared modules, new autoloads
- New methods on an existing owner “so the copies can share”
- Behavior changes, drive-by renames, comment rewrites, wholesale retypes, reformats
- Reading or updating `design/sessions.md`
- Archives pins
- Declaring the whole sweep done and then starting a second kind of task

## End

The sweep is finished when the User says so, or when the worklist has no remaining legal size/reuse cluster. Report that. Stop. The next goal is a new session.