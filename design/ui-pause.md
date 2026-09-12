# Pause menu

Status: binding design
Read when: pause menu layout / tabs / behavior
See also: `design/ui.md`, `design/ui-theme.md`, `design/ui-title-web.md`, `design/ui-hud.md`, `design/ui-run-flow.md`, `design/ui-gear-entry.md`, `design/gear-ui.md`, `design/hub.md`, `design/input.md`, `design/doc-refactor.md`

## Pause menu

Opened with Menu / Start / Esc. Freezes gameplay.
Every menu (including this one) MUST open with valid initial focus so it is immediately navigable by gamepad.

On web, Esc MUST still open this menu while the page is fullscreen. Esc MUST NOT call `document.exitFullscreen`. Leaving web fullscreen is Pause → Settings → Graphics display toggle or Alt+Enter only (`design/input.md`).

Menu bindings are shared through `scripts/ui/menu_pad.gd` (`design/input.md`):
- A / Enter confirms the focused control. A second A confirms a pending prompt.
- B / Esc backs out of a nested layer (re-equip list, Settings detail column, pending prompt). At root, close the menu.
- LB / RB (or `[` / `]`) cycle the three pause tabs. They MUST NOT page the inventory stats card.
- **I** / D-pad Right open pause on Inventory from gameplay only. They MUST NOT jump tabs while pause or any other menu is already open. In menus D-pad Right stays `ui_right`.

Select / Back render in a footer strip at the bottom-right of the menu panel via `PromptView.footer`. Button captions stay verbs only. Tab chips and gear page glyphs MUST follow the last-used scheme as soon as the scheme changes; do not wait for a tab change or a new focus owner.

The current pause tab MUST read as selected at a glance: same lighter fill and brighter border as a hovered tab, but keep the darker tan label. Mouse over the already-selected tab uses a second, brighter hover so hover is still visible.

Exactly three tabs, in this order, navigable with LB/RB or equivalent:
1. Settings – default tab when pause opens. Shared two-column split (`split_menu.gd` + `split_menu_view.gd`). Left list, right page or leaf copy. Pages: Gameplay, Audio, Graphics, Controls. Leaves: Patreon, Dispel (dungeon) or Main Menu (Placeholdia / hub), Quit (hidden on Xbox). Leaf rows have no chevron; the right pane shows a short description and stays undimmed. Hover does not change an open submenu. Click a different page while detail is open switches to that page. Click the already-open page returns focus to the left list.
2. Inventory – shared paper-doll gear board (`design/gear-ui.md`), 7-column bag grid, flyout tooltips, paged stats. Stats pages use **Q / LT** and **E / RT**. LMB / RMB never page the stats card. Use / consume / drop / equip as specified there, including mid-run weapon changes from the bag. Active artifact set bonuses appear on the Artifact sets stats page and in item flyouts. No extra Close row; B / Esc closes pause.
3. Skills – list of the eleven skills with current level, XP bar to next level, and permanent XP total. Flyouts are right-aligned and MUST sit above the prompt footer when they would overlap it. No extra Close row.

Settings pages MUST contain:

Gameplay
- Character type switch (male / female)
- Target lock checkbox (centered)
- “Delete Save Data” with a separate confirm popup (`confirm_dlg.gd`). Confirm wipes and returns to the title screen as a fresh boot.

Audio
- Master / Music / SFX volume sliders

Graphics
- “Sprite filtering” label, then Mipmaps and Anisotropic on one centered row. Anisotropic is disabled while Mipmaps is off. Nearest is implied. Linear modes MUST NOT appear here. Default is nearest + mips + aniso.
- Camera zoom slider (1.0–4.0, default 1.75). MUST apply live; no restart.
- HUD scale slider. MUST apply live.
- Display mode. Desktop: cycle Windowed / Borderless fullscreen / True fullscreen. Fresh default is borderless. Web and native mobile: Fullscreen on/off. Hidden when `OS.has_feature("xbox")`. MUST apply live from the tap. Alt+Enter is the keyboard equivalent (`design/input.md`).
- Aim-line toggle and opacity slider

Controls
- Pool selector at the top (Keyboard / Gamepad). It wraps both ways. D-pad / arrows are discrete; left-stick X switches once per push. Changing it rebuilds the list for that pool.
- Reset Controls asks `confirm_dlg.gd` first, then restocks that pool only. Menu actions are not rebindable.
- Two slots per action. Conflict inside the same pool swaps. Move / aim sticks are locked on gamepad. Look mode is pad-only. Move directions are keyboard-only.
- Bind name left, glyphs right. Player-facing labels, not action ids.

Leaves
- Patreon opens the campaign URL in the system browser.
- Dispel / Main Menu / Delete Save Data / Reset Controls use `confirm_dlg.gd`. Quit does not.
- Confirm dialogs carry their own Select + Back strip. B / Esc / Cancel closes the prompt and restores the control that opened it.

There is no presentation-mode switcher. Archives is title-only (`design/archives.md`).

The full debug / balance menu is **no longer** present in the Pause Menu. In-test display options that are not approved for players live on the secret debug **Settings** tab (`design/debug.md`). The touch stick deadzone slider lives there too. The player display-mode control is mirrored on that Settings tab.

Placeholdia inventory (same board, opened outside a run) MUST use Loadout option sources: starters, holds, and non-white bank items. Dungeon inventory MAY only list the equipped piece plus bag items of that slot.

