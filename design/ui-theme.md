# UI theme

Status: current plan  
Read when: playable surface theme tokens  


## UI theme (playable surfaces)

Every player-facing UI and HUD element in the live path MUST be designed with dungeon theming and MUST NOT ship as a default, unskinned, or engine-debug control. This includes the gauntlet strip, pause menu, Extraction Gate UI, Ghost Shop, anvil, Floor Crystal loadout UI, quest UI, Controls Billboard, recap, maps, toasts, title / credit flow, the web fullscreen gate, confirmation prompts, the title “what’s new” overlay, the web touch overlay, and any other surface a normal player can open.

The secret debug menu (including Automated Playtest, profiles, Animation Browser chrome, Settings tab, and raw value editors) MAY use default or lightly skinned engine controls. Appearance there is not a Demo-Complete art requirement. Its plate stays the plain dark board. Shared buttons may follow the player skin.

## Field journal

Player surfaces use one skin: warm paper, dark ink, and a thin brown rule. Corners are soft. Focus is an ink underline along the bottom of the control, with a deeper paper fill. There is very little gold.

Three control weights:

- Primary: deeper paper, a stronger rule, ink type. The commit on that screen (Play, Enter dungeon, Forge, Confirm, buy, send, accept).
- Secondary: paper, a quiet rule, softer ink. Lists, Back, Leave, Cancel, Updates, Archives.
- Danger: paper, a dried-ink red rule and red type. Dispel, Main Menu, Quit, Delete Save, Reset Controls, pawn, abandon, and the Confirm button on those prompts.

The selected pause or anvil tab uses the deeper paper and the ink underline. Hover on that tab lifts the paper so the pointer is still visible. Rarity washes stay green and blue. At-risk plates keep a red rule. Gameplay meter fills (health, potion, dash, special, boss) stay their own colors. Text that sits on the world, outside a paper chip, stays light.

## Binder

The pause container keeps the journal materials: leather, paper fiber, dark ink, bookmark tabs. It does not have to be one open book with a binding down the middle. Treat it as a binder that holds separate documents. A settings page, a skill list, a confirm slip, and the inventory sheet are papers in that binder. Each document is sized to what it has to say, so a control row is never split by a gutter.

The pause is not one open book. Settings is two sheets, the left one shorter than the right. Inventory is two even sheets. Skills is two sheets split right of center. A confirm is a slip on top. Inventory, as approved on the field-journal commit, stays the material and type reference. Do not throw that look away. A document is one sheet, two sheets, or a slip on top, whichever lets the controls sit cleanly.

Words, gamepad order, and what each control does stay unless a later answer changes them. Debug screens stay plain.
