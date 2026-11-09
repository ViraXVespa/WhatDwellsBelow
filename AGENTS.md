# What Dwells Below — agent rules

Godot **4.7.2**. Live path must stay gamepad-first and web-exportable.

**Build slice: the first command is the one your first message names, before any memory topic or file read (`design/grok-build.md` Start or resume). A new week is not a slice: `design/build-week-start.md` only, on clean `main`, no `slice.py start`.**

**Proof rules** (`design/prove.md`). A missing or invalid required asset fails loudly; a fallback needs the User's OK. Before changing behavior, state the intended outcome in one line and prove against it (ask if unclear). Prove against intent and a reference the User confirmed, not a prior run of the same code. Report "gates pass", never "proved"; visuals and audio stay unverified until the User confirms. Fix the bug; do not drop the improvement.

## Path

| Path | Recognize | Deliver |
|------|-----------|---------|
| **Grok Build (CLI)** | You can write the checkout | `design/grok-build.md`, then the repository pc-offload skill. Same-system APIs just do; design decisions, a new cross-system owner or a named live-module replace are asked first (`ask_user_question`, even under always-allow). |
| **Web / chat** | You cannot write the repo | `design/web-session.md`. Never assume a disk write landed. |
| **Grok Bot** | Grok Bot / The Refactorer, or a named Bot / refactor sweep | `BOT.md`, then `python tools/bot_status.py`, then one printed Job file. Refactor only, plus a `tools/` runner the User approved. Smokes, shots, gates: `BOT.md`. Ship via branch + PR. |

If unsure: ask, then **web / chat**.

## Shared

Design lives in `design/`. Never open `notes/`.
Navigation is only `design/routes.yaml`. `See also:` is forbidden.

| Need | File |
|------|------|
| Plan (web / Build) | `design/protocol.md` + `design/constraints.md` |
| Bug sweep, when asked (web / chat) | `design/web-bug-sweep.md` |
| GDScript types / warnings / tabs | `design/gdscript-law.md` |
| Live code map (one system row) | `design/code-map.md` |
| New or moved script placement | `design/refactor.md` (Cluster folders section only) |
| Numbers (when they change) | `design/tunables.md` |
| Tools (which tool, rules) | `design/tools.md` |
| Prove a change (any surface); extend a tool, do not work around it | `design/prove.md` |
| Windows inventory / verify / write | pc-offload skill + `design/pc-offload.md` |

Reading: this file + the path file + (web / Build) the plan pair + the topic doc and gates whose `when` matches. **Multi-system job:** list every system and read each one's doc and code-map row before changing anything.
Do not fetch this file again. Routing work: `design/load-graph.md`.

Earlier work: `find.py changed`; `session.py summary --job JOB` reads any tool RESULT (`JOB`: its `_logs/<job>/` folder). Never open `_logs/` with a file read. Function names missing from the plan: `find.py scripts --names` or `--all-names` with one `--path`, not an xref of `^func`. A doc and its code disagree: compare history (`find.py changed --history`, `design/prove.md`), trust the newer, ask if unclear.
Imagine (Build only): `design/isolated-media.md` first; Web / chat and Grok Bot never run the isolated runner.
Ask as many questions as the job needs, in rounds. Report when done, with rough edges (`tools.md` rule 9). Build and Web may add a helpful tool (rule 5) and tell the User.
