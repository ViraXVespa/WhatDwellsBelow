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

### Script size cap (10KB)

Every live file under `scripts/**/*.gd` MUST stay under **10,000 bytes**.
This is a hard readability rule for GitHub and for this chat path. Do not leave a live script over the cap.

When an edit would push a file over 10KB, or you find one already over:

1. Split by responsibility into a sibling helper (`*_act.gd`, `*_view.gd`, `*_boot.gd`, `*_text.gd`, etc.).
2. Keep the original path as a facade or host so public callers do not change (`App.playtest`, `PauseInv.build`, `Gen.generate`, `EnemyAI.tick`, `SmokeLate.p7`).
3. Prefer `static func` helpers that take `host` / `pt` / `ui` / `p` as the first argument.
4. Do not create circular `preload()` chains. If two helpers need each other, use `load()` on one side or put shared state on the host script.
5. Godot 4 analyzes a parent script by itself. A base script MUST NOT call methods that exist only on a child. Call helper modules directly from the parent.
6. Never split or rewrite anything under `archives/`.
7. After a split, emit every new and revised file in full (web path) or apply them on disk (CLI path).
8. If several files are over the cap, split the largest first and stop after a batch so the User can paste and compile.

Do this proactively. Do not wait for the User to notice a 12KB file.

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

### Live files before you emit

Web pulls of GitHub raw files and long tool summaries often truncate. Do not invent the missing tail.

- If a source file is truncated, incomplete, or you are not sure it matches the User’s working copy, **stop and ask the User to paste the live file**.
- Prefer the User’s pasted live file over a GitHub fetch whenever they have already provided it, or whenever the fetch looks short, cut off, or older than the conversation.
- Do not emit a “revised” file assembled from a truncated pull. Wait for the live body.
- You may still emit a short file you fully retrieved, then ask for the remaining live files one at a time.

### Delivery shape

- One file at a time when files are long. Label the path clearly above the body (`## \`scripts/app.gd\``) except for markdown documents (see below).
- Emit the complete file contents, including unchanged lines.
- Indent GDScript with **tab** characters.
- If several files change, emit every changed file in full, still one file per message unless the User asks otherwise. Do not omit a file because “only a small part changed.”
- New files: emit the full intended contents.
- Deleted files: say so in the report; do not emit a body.
- After the files, stop and report: what changed, why, and what the User should paste where — unless the just-emitted file is a markdown document that must be copy-clean (see below). In that case put the report in a **following** message, not around the markdown body.
- Do not claim you wrote the repo. The User pastes.

This full-file rule applies to `design/` notes and `AGENTS.md` the same way it applies to `.gd` / `.tscn` files.

### Markdown copy format (Path 2 only)

`.md` files (`AGENTS.md`, `design/*.md`, and any other markdown the User will paste) MUST be emitted as raw copy-ready text:

- Do **not** wrap the file in a markdown fence (` ``` `, ` ```markdown `, or similar).
- Do **not** put a leading or trailing chat message in the same reply as the file body. No “here is the file,” no recap, no next-file note on that same turn.
- The reply that carries a markdown file should be **only** the file contents, so a select-all / copy lands a valid document.
- Path labels, “next file,” and change reports for markdown work go in a separate message before or after that clean emit.
- Code files (`.gd`, `.tscn`, and other non-markdown sources) may still use a fenced block plus a path heading so syntax highlighting stays usable.

---

## Output convention (when a full file is emitted)

When presenting a revised source file to the User, output the entire file and indent with tab characters.