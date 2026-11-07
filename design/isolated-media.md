# Isolated media generation

Status: protocol
Read when: Grok Build generates a still or I2V clip
Code: `tools/media.py grok`

## Start

1. Choose the media kind and its art job. Load the required Build media skill; this guide is the generation policy, not a replacement for the art specification.
2. Use `python tools/media.py grok --kind KIND --brief "..." --out DIR`. The runner stages a scratch directory outside the git tree and verifies isolation with `grok inspect` before generation.
3. Review the result through the owning art job before installing it. Keep sources under `_src/` and reusable processing in the existing tools.

The repository hook denies in-repo Imagine/I2V. Attached images, a missing runner or an instruction to stay in-session do not constitute an implemented hook exception. If the supported runner cannot start, report the blocker; do not move cwd, rename tools or generate around the denial. Necessary direct reference reads have a separate task-scoped opt-in; it does not enable generation. Blender modeling is a different task workflow, not an Imagine kind. Web/chat and the Bot do not run this generator.

## Kind routing

The runner bundles the skills needed by the selected kind. The child reads only that kind's specialist reference.

| `--kind` | Bundled skills | Imagine tool | WDB job |
|---|---|---|---|
| `tile` | `imagine`, `game-assets` (`tilesets.md`) | `image_gen` once | World tile / roof / ground / wall. Seamless. The child reads `tilesets.md` only. It does not retry or composite. The parent runs the 2×2 seam check. |
| `character` | `imagine`, `game-assets` (`characters.md`) | `image_gen` for a new Bible / style candidate; `image_edit` after lock | Character still, facing variant, overlay-on-body. After lock, edit-chain from the locked Bible or body frame. |
| `i2v` | `imagine`, `game-assets` (`animation.md`) | `image_to_video` from the staged seed; walk pins that seed as `first_frame` and `last_frame` via `reference_to_video` | One unit. The child reads `animation.md`. Prompt and seed from `tools/media.py i2v-seeds`. No fixed 6s/10s clock. Child does not harvest or pack. |
| `ui` | `imagine`; style from the staged `ui-style.md` (the ui style doc's Generated art look section) and the refs it names, plus `--copy` refs | `image_gen` / `image_edit` | Generic UI still: menu, screen, panel, HUD, mockup or ref; text allowed. Default `ui.png`; `--dest-name` may hold a subfolder (`mockups/title.png`), kept under `--out`. `--no-ui-style` skips the style. A small icon is a `ui` job whose brief says no text. Input glyphs stay `tools/media.py glyphs`. `--edit` with one `--copy` is an `image_edit` of that file (do not pass `--aspect`). Without `--edit`, one `--copy` plus `--aspect` tells the child to `image_gen` and to treat the copy as a loose reference. |
| `npc` | `imagine`, `game-assets` (`characters.md`) | `image_gen` | NPC sprite redesign from `--brief`; `--copy` the old sprite for framing, pose and size only (no identity lock). Opaque #FF00FF plate, default `npc.png`. Then the pack doc's NPC redesign rekey. |
| `still` | `imagine`, `game-assets` (`assets.md`) | `image_gen` / `image_edit` | Fallback only. Prefer a tighter kind. The child reads `assets.md` only, not `animation.md`. |

Locked Bibles (`assets/sprites/player/bible_locked_male.png`, `bible_locked_female.png`) are the style / identity source for later generation. `gdd_reference_bible.jpg` is layout-only. For `tile` / `ui` / `still` (with `--bible-style`), Bibles are read-only style sheets — do not draw the character into the asset. For `character`, they are the identity lock.

Do not copy bundled skill bodies into the repository.

## Scratch, references and reuse

Scratch must resolve outside the git tree; a copied worktree still loads project rules and is not isolation. A successful inspect reports `inspect=ok instructions=0`; otherwise generation is refused. `--dry-run` performs inspect but not generation.

Without reusable references the runner uses OS temp; `--keep` retains it and `--no-reuse` forces a fresh job. With references it defaults to a durable directory under the user's Grok home, `wdb-iso/work/<ref_key>`. The catalog key combines kind, reference names and hashes, not the brief. `--bible-style` stages the locked Bibles.

First use ingests the images, then generates. Reuse forks from that cached ingest, not a large implementation conversation. The CLI has no rewind or invented `--no-memory` flag. One child performs one media call and copies its output; it does not retry, harvest, pack or composite. Copied results exclude staged inputs. The runner owns child flags and permission behavior; do not expand them manually.

For `--kind i2v`, produce `--seed` and `--prompt-file` with the existing seed tool first. The parent owns unit selection, packing, seam/key checks, acceptance and any authorized retry. Keep one unit per review gate. Place durable sources under `_src/` at the corresponding live-relative path; never install an unreviewed result as a fallback.
