# Animation Browser

Status: binding design
Read when: animation browser debug page
Code: scripts/debug/, scripts/combat/debug_menu paths may be under scripts/debug/debug_menu/
See also: `design/debug.md`, `design/debug-menu.md`, `design/debug-playtest.md`, `design/debug-smokes.md`, `design/pc-offload.md`, `design/refactor.md`, `design/doc-refactor.md`, `design/README.md`

## Animation Browser (secret debug page)

Purpose: let the User review player and enemy animation states so art and facing can be checked without playing a full run.

**Phase rule**

- Phase 7: the Animation Browser control MUST exist in the secret debug menu. It MUST be labeled, gamepad-focusable, and reachable with the same tab/page navigation as other debug pages. A stub panel (“Animation Browser — implemented in Phase 9”) is acceptable.
- Phase 9 / Demo-Complete: the full viewer MUST ship. This is a vital development tool in the final product. It is deliberately *not* part of early build logic so sprite pipelines and combat can land first.

**Layout**
The Animation Browser is a full-screen page. It MUST be TV-readable and gamepad-first, and MUST open with valid initial focus.

- **Back** sits at the bottom of the screen. Activating it returns the User to the main secret debug menu. Activation methods (both required): highlight Back and press A, or press B at any time while the Animation Browser is open. B MUST work regardless of current highlight.
- **Model selection widget** at the top of the screen:
  - Left: Previous model button. LB at any time selects the previous model.
  - Middle: display-only name of the current model.
  - Right: Next model button. RB at any time selects the next model.
  - Wrapping at the ends of the model list is allowed.
  - Model list MUST include player male, player female, and every shipped enemy type including Floor Guardians and the Gate Master.
- **Preview viewport** directly beneath the model selection widget. Shows a zoomed-in view of the current model playing the current animation. Updates immediately when model, facing, or animation changes.
- **Play / Pause** sits under the preview. Default: the selected clip loops. **X** (`gear_drop` / `anim_play`) toggles play/pause from anywhere in the viewer. Highlight + A still works. Playing vs paused MUST be obvious from the couch.
- **Direction list and animation list** sit together to the right of the model widget and preview, as two sibling list widgets with the same interaction pattern. The direction list is next to the animation list.
- **Review status** sits under the lists. Shows Good / Repack / Regenerate for the current clip, or Still — no review when the clip is a single frame.
- **Notes field** sits above Back. Visible only while the current clip is Repack or Regenerate. Keyboard types into it.

**Direction list**

- Lists the eight Character Bible facings in this order: Down, Down-Left, Left, Up-Left, Up, Up-Right, Right, Down-Right. There is no Idle / None facing row. Idle clips live on each facing.
- Open focus is the current facing (Down on first open). Unselected labels are white. The selected facing is gold.
- D-pad Up / Down moves the facing highlight and writes that facing. D-pad Right moves focus to the Animation list (last highlighted clip). D-pad Left on the facing list stays there.
- **Right stick** sets facing from anywhere in the Animation Browser. Deflect past a deadzone and the nearest of the eight in-game aim octants becomes the selected facing. Releasing the stick to neutral **keeps** the last facing. Right-stick facing MUST NOT steal D-pad / keyboard focus or rebuild the facing buttons.
- Changing facing immediately rebuilds the animation list for that facing.

**Animation list**

- Lists only animations available on the current model **for the current facing**. Labels are title-cased.
- A facing lists only clips that exist for that facing (`walk`, `attack_*` / `special_*` per weapon class, `gather_pickaxe` / `gather_hatchet` falling back to `gather_*` files, `death`, “Dispel”, directional attacks, idle, and any other shipped per-facing clips). `idle_to_walk` / `walk_to_idle` are pack-only and MUST NOT appear in this list.
- If the newly selected facing or model does not have the previously selected animation, select the first available animation for that facing.
- If a facing has no clips, show an empty list and a clear empty state in the preview; do not keep a clip from the old facing.
- The list MUST refresh when the selected model or facing changes.
- LT / RT scroll the animation list up / down from any focus position. Mouse wheel does the same. Left click activates the hovered button. Right click does nothing.
- D-pad Up / Down moves the animation highlight when that list has focus. D-pad Left returns to the Facing list (last facing). D-pad Right on the animation list stays there.
- Left stick, while playing, steps playback speed (0.25 / 0.5 / 1.0 / 1.5 / 2.0). While paused, left stick steps individual frames.
- The User may also highlight an entry with normal menu navigation and confirm with A.
- The selected animation is the one currently playing in the preview.

**Review ledger**

- **Y** (live bind: `gear_tip`) cycles Good → Repack → Regenerate → Good on the current clip.
- Stills (one frame or fewer) MUST NOT accept a cycle. Idle bible stills stay unflagged.
- Session memory keeps the note text while the User toggles states. Disk write drops Good rows and drops notes on Good.
- Store: `tools/anim_review/review.json` in the live checkout. Editor-only. MUST NOT use `SaveStore` / `user://live`. Not written on web. The `tools/anim_review/` directory is gitignored.
- Key: `model_id/facing/anim` (same catalog ids as `AnimScan`).
- Offline tools that read this file are listed in `design/art-pipeline.md`. A Regenerate flag on a player clip resolves to a specific `i2v_seeds.py` MOTION key (`attack_great_axe`, not a generic `attack`). A `gather` flag writes both pickaxe and hatchet prompts. Pack accepted one-shot I2V with `tools/pack_oneshot.py`.

**Always-available gamepad chords (Animation Browser only)**

| Input | Action |
|---|---|
| LB / RB | Previous / next model |
| LT / RT | Scroll animation list up / down |
| D-pad Up / Down | Move highlight in the focused list (Facing or Animation) |
| D-pad Left / Right | Animation list ↔ Facing list |
| Left stick | Playback speed while playing; frame step while paused |
| Right stick | Set facing to that octant |
| X | Play / Pause |
| Y | Cycle review state (multi-frame clips only) |
| A | Activate highlight (direction entry, animation entry, Play/Pause, Back, review button, on-screen model buttons) |
| B | Back to main secret debug menu |

Keyboard / mouse MUST have equivalents for every action (arrow keys for list columns, Q/E or LB/RB for model, mouse wheel for the animation list, Y for review cycle, X for play/pause). Exact bindings MAY be invented at implementation time and MUST appear in the rebinding screen. Notes require a keyboard; there is no on-screen keyboard.

Exact compare-two, frame-scrubber, and bible-overlay extras MAY be invented at implementation time so long as the requirements above are met.

### Live snapshot — review chrome

- Facade: `scripts/debug/anim_browser.gd`
- Review helper: `scripts/debug/anim_browser_review.gd`
- Ledger: `scripts/debug/anim_review.gd`

