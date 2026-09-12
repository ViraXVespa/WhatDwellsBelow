# Grok Bot session flow

Status: protocol  
Read when: Grok Bot path; every Grok Bot / refactor-sweep session  
See also: `AGENTS.md`, `design/refactor.md`, `design/README.md`, `design/versioning.md`

This file is binding for **Grok Bot** only. Grok Build and web / chat ignore it, except that they may open `design/refactor.md` when they split for the 10KB cap.

Grok Bot writes via **GitHub PR** (cloud agent when available, or GitHub connector). Grok Bot’s primary job is refactor sweeps of live `scripts/**/*.gd`. Grok Build writes behavior features.

## Recognize

Grok Bot / Cursor desktop assistant writing via GitHub PR (cloud agent when available, or GitHub connector), **or** the User named a Grok Bot path / Grok Bot refactor sweep. If a Grok path is asked only to split one file that *its own edit* pushed over 10KB, that is not this path — use `design/refactor.md` inside the current Grok session.

## Read set

Load only:

1. `AGENTS.md`
2. This file
3. `design/refactor.md`
4. The `design/README.md` **code map** row for the cluster about to be edited
5. After the inventory: the live `.gd` files in that one cluster
6. When authoring the PR changelog: baked `scripts/data/version.json` (for `{label}` = patch + 1) and `design/versioning.md` changelog body shape — not the whole `design/changelog/` tree

Do not read topic design files, `design/sessions.md`, `design/session-log.md`, or older changelog entries for a pure refactor sweep. Do not read `design/protocol.md` beyond a pointer, `design/constraints.md`, `Demo_GDD.md`, `design/web-session.md`, or `design/grok-build.md`.

If a move would change player-visible behavior or fight binding design, stop and ask. Do not load the corpus to invent a reason to continue.

## Mandate

Sweep the whole live script tree. Not a feature slice. Not “only these files” unless the User overrides the worklist.

**In scope:** `scripts/**/*.gd` that ship.  
**Out of scope:** `scenes/`, `assets/`, `tools/` (unless a preload path update is required by a legal move), `archives/`, pinned commits, `project.godot` (unless required to register a moved script), and any file under a pinned archive. `design/` updates are limited to the code map row, this protocol family, and the one new `design/changelog/{label}.md` per PR.

**Refactor only:**

- No features, tunables, new game systems, skills, rarities, hub, co-op, art / I2V
- Rearrange existing code only
- Auto-manage live `scripts/**/*.gd` sizes via facade / helper splits per `design/refactor.md`
- **10KB** is the ship floor; under-**5KB** is the sweep target when whole existing functions can move
- Prefer **NEW shared modules** when near-identical behavior spans places (example: tooltip placement / behavior across Anvil / Analyze / Forge / Inventory). Prefer a new shared module over growing an existing owner.
- Point at an existing owner only if it already **is** that concern **and** the addition will not blow the size cap. Never grow an owner just to avoid a new file.
- Near-identical = same control flow (renamed locals OK), not vaguely similar features
- Parked folder moves from `design/refactor.md` plus User-named deeper relocates are their own batches; no behavior change
- May add `: Type` on lines already moved so Godot compiles

## Inventory

Before opening bodies:

1. List every live `scripts/**/*.gd` with UTF-8 byte size only.
2. Rank:
   - over 10KB
   - over 5KB
   - extract candidates (near-identical control flow spanning places → new shared module)
   - existing-owner reuse that fits without blowing the owner’s size cap
   - parked folder moves / User-named deeper relocates
3. Show the ranked worklist. Do not edit yet.

Files already under 5KB are not size targets. Do not split them “for cleanliness.”

## Pass order

1. Size — over **10KB** first, then over **5KB** when existing functions can move
2. Extract to **new shared modules** (near-identical spanning places)
3. Existing owners only when they already own the concern and still fit under the cap
4. Parked folder moves / User-named deeper relocates

## Commits and versioning

`.github/workflows/version.yml` sets `patch` = baked patch + **count of user commits** on `main` since `scripts/data/version.json` last changed (ignores `chore: stamp …` and any `[skip ci]` subject). One push that lands **N** non-stamp commits bumps patch by **N**.

Therefore every Grok Bot PR MUST:

1. Prefer **one commit** on the PR branch for the whole cluster (amend or squash locally before opening / updating the PR when tools allow).
2. Tell the User to **squash-merge** into `main` (not “Create a merge commit” or “Rebase and merge”) so `main` gains exactly one user commit for that PR.
3. Include **one** new `design/changelog/{label}.md` in that same PR. `{label}` is baked `scripts/data/version.json` `label` with patch + 1 (same rule as web Phase 7). Body shape is in `design/versioning.md`. Do not hand-edit `scripts/data/changelog.json` or `version.json`.
4. Agent-visible protocol/doc changes also get a changelog entry (player note can say agent workflow changed).

Do not claim a write landed until the PR exists.

## Flow

1. Orient (Recognize + Read set).
2. Inventory (UTF-8 sizes; rank; show; don’t edit yet).
3. **Size** clusters may auto-chain while anything over 10KB remains (User can override). **Extract** / new-module / parked-move / deeper-relocate clusters always wait for User go.
4. One cluster per PR via branch + PR (single commit preferred; squash-merge required). Never paste-emit.
5. Include `design/changelog/{label}.md` for that PR.
6. Report after each cluster.
7. Update `design/README.md` code map when siblings / shared modules appear. Pure refactor: no `design/sessions.md`, no `design/session-log.md`.
8. End when the User stops or the worklist is empty.

## Batch

One **cluster** per batch (and per PR). A cluster is one facade plus the siblings involved in that split, one new shared module plus the call sites that start using it, one existing owner plus fitting call sites, or one parked / named relocate set.

1. Open only that cluster.
2. Apply `design/refactor.md` (including the Grok Bot shared-module rules).
3. Size goal for this path: each resulting live `.gd` in the cluster should be under **5KB** when existing functions can move to do that. If a single existing function is itself over 5KB, leave that function whole and report it.
4. 10KB remains the ship floor. Never leave a touched file over 10KB if a legal split can fix it.
5. Ship the cluster as a branch + PR (with changelog). Stop. Do not start the next cluster until the flow rules say so.

## Report

After each cluster, tell the User:

- PR URL (required before claiming the write landed)
- Reminder to **squash-merge**
- files changed (path + bytes before / after)
- changelog path (`design/changelog/{label}.md`)
- new sibling helpers or new shared modules created (moved code only)
- reuse call sites now pointing at an existing owner (only when that owner fit)
- what is still over 10KB, still over 5KB, extract candidates still open, or still duplicated with no fit
- the next cluster on the ranked list

Optional: write the same notes to `_logs/grok-bot-sweep.md` (repo root). That folder is gitignored and must not be committed. Overwrite or append in that one file. Do not write `design/sessions.md` or `design/session-log.md`.

Then ask whether to take the next cluster when the flow requires a User go. Do not continue extract / relocate clusters until the User says yes.

## Allowed

- Move existing functions into a new sibling helper because of size
- Create a **new shared module** when near-identical control flow spans places; move the copies into it
- Add the minimum wiring so the project compiles: `load()` / `preload()`, a one-line facade delegate, `host` / `pt` / `ui` / `p` on a moved `static func`
- Change call sites to use an existing shared function **only** when that owner already is the concern and stays under the size cap
- Add `: Type` on a line already being moved so Godot can compile (`AGENTS.md` → GDScript types)
- Update the `design/README.md` code map row when a split adds a sibling or shared module the map must list
- Parked folder moves and User-named deeper relocates as their own batches (preload updates as required)
- Author one `design/changelog/{label}.md` per shipping PR

## Forbidden

- Features, tunables, new game systems, skills, rarities, hub work, co-op, art / I2V
- Growing an existing owner just to avoid a new file
- Treating vaguely similar features as near-identical
- Behavior changes, drive-by renames, comment rewrites, wholesale retypes, reformats
- Reading or updating `design/sessions.md` or `design/session-log.md` on a pure refactor sweep
- Shipping a PR without `design/changelog/{label}.md` when the goal lands on `main`
- Landing multiple user commits on `main` for one PR (no merge-commit / rebase-merge of a multi-commit branch)
- Archives pins
- Paste-emitting bodies instead of branch + PR
- Claiming a write landed before the PR exists
- Hand-editing `scripts/data/version.json` or `scripts/data/changelog.json` as the ledger
- Declaring the whole sweep done and then starting a second kind of task

## End

The sweep is finished when the User says so, or when the worklist has no remaining legal size / extract / reuse / relocate cluster. Report that. Stop. The next goal is a new session.
