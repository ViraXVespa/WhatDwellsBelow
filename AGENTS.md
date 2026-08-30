# What Dwells Below — agent rules

Godot target: **4.7.2**.
Playable path must stay gamepad-first and web-exportable.

There are two separate workflows. Detect which one you are in, then follow **only** that path’s delivery rules. Shared design and live-path rules apply to both.

## Which path am I on?

| Path | How to recognize it | Delivery |
|------|---------------------|----------|
| **Grok Build (CLI / desktop)** | You can read and write the repo on disk. You are expected to apply edits in place. | Patch live files directly. Do not dump whole files into chat unless the User asks. |
| **Web / chat instance** | You cannot write the User’s repo. This conversation is the delivery channel (the interface used to produce these docs). | Never assume a disk write landed. For every edited source file, emit the **entire file** so the User can copy/paste. |

If unsure, ask once, then default to the **web / chat** path. A missed full-file emit is worse than an extra one.

## Shared rules (both paths)

### Documentation database

Design notes live in `design/`. There is no single monolithic GDD.

| Need | Read |
|------|------|
| Fresh-instance workflow | `design/protocol.md` |
| Hard constraints / demo-complete | `design/constraints.md` |
| Topic map + live code map | `design/README.md` |
| Numbers | `design/tunables.md` |

`Demo_GDD.md` is only an index into `design/`.

**Binding design** is required behavior.
**Live snapshot** sections describe current code. If they disagree with binding design, patch the live path toward the binding text or ask the User. Do not invent a third system.

### Shipping path

The shipping game is the live path at the repo root (`project.godot`, `scenes/`, `scripts/`, `assets/`).
Update that codebase in place. Do not greenfield-rewrite it.

### Mandatory first actions on a fresh instance

1. Read `design/protocol.md` and `design/constraints.md`. Then read only the `design/` topic files that match the requested work. Inspect the live tree. Do not start by archiving or rewriting.
2. Treat `archives/classic_2d/`, `archives/art_experiment/`, and `archives/full_3d_pass/` as frozen historical snapshots. Do not overwrite them. Do not copy them over the live path. Do not create a new archive unless the User explicitly asks.
3. Implement the requested change by editing live scenes, scripts, assets, and autoloads. Prefer the smallest patch that matches existing patterns.

Do not throw away, replace, or greenfield-rewrite the live path.
Do not extend, patch, or reuse archive code as if it were live unless the User asks to port a specific piece.

`design/coverage.md` is a coverage checklist against the existing live build, not a rebuild schedule.
After a requested slice of work, stop and report to the User.

### Implementation limits

- MUST implement only what the design database and the User explicitly require.
- MUST NOT invent systems, skills, rarities, hub upgrades, meta-progression, or co-op scaffolding.
- When numbers are left open, MAY invent coherent starting values, then MUST expose them in the secret debug menu and record them in `design/tunables.md`.
- If design and live code conflict, or anything is ambiguous, ask the User. Do not guess.

---

## Path 1 — Grok Build (CLI / desktop)

You are operating against a checkout on the User’s machine.

- Read the live tree from disk. Apply the change in the live files.
- Keep diffs small and consistent with surrounding style.
- Indent GDScript with **tab** characters.
- After the slice: report what changed, which files, how you verified, and anything still open.
- Do **not** paste entire file bodies into the terminal/chat as the default delivery. The User already has the files.
- Paste a full file in CLI chat only when the User asks for a copy/paste dump, or when showing a brand-new file that does not exist on disk yet.

---

## Path 2 — Web / chat instance

You are operating in this interface. You cannot write the User’s working copy.

Whenever you suggest a code or document edit, output the **entire revised text** of each touched source file.
Do not send a series of individual sections, hunks, or “replace lines 80–94” patches. That is slower for the User than one copy/paste of the whole file.

Web / chat delivery rules:

- One file at a time when files are long. Label the path clearly above the body (`## \`scripts/app.gd\``).
- Emit the complete file contents, including unchanged lines.
- Indent GDScript with **tab** characters.
- If several files change, emit every changed file in full. Do not omit a file because “only a small part changed.”
- New files: emit the full intended contents.
- Deleted files: say so in the report; do not emit a body.
- After the files, stop and report: what changed, why, and what the User should paste where.
- Do not claim you wrote the repo. The User pastes.

This full-file rule applies to `design/` notes and `AGENTS.md` the same way it applies to `.gd` / `.tscn` files.

---

## Output convention (when a full file is emitted)

When presenting a revised source file to the User, output the entire file and indent with tab characters.