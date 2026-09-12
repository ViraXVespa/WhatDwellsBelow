# Secret debug / balance menu

Status: binding design
Read when: secret debug menu / balance page
Code: scripts/debug/, scripts/combat/debug_menu paths may be under scripts/debug/debug_menu/
See also: `design/debug.md`, `design/debug-playtest.md`, `design/debug-anim-browser.md`, `design/debug-smokes.md`, `design/pc-offload.md`, `design/refactor.md`, `design/doc-refactor.md`, `design/README.md`

## Secret debug / balance menu

Accessed only by the following input sequence (gamepad): all four shoulder buttons (RT + RB + LT + LB) must go from pressed → released → pressed → released within a 1.5-second window. The 1.5-second timer resets after the first release so a full 1.5 seconds remains for the second press-and-release.
The menu opening itself is the sole confirmation that the sequence succeeded.
This menu contains:

- Every previously available debug / balance page (all numeric values exposed and tunable)
- Debug profile Save / Load / Delete / Rename system (unlimited named profiles, free naming/renaming, saved to files by default, persist across live-path sessions)
- Automated Playtest / AI Player system
- Animation Browser page (entry MUST exist when this menu is first implemented; full viewer MAY be a stub until Phase 9, and MUST be complete for Demo-Complete)
- Settings page for in-test system and game options that are not yet approved for general players
- All other content that was formerly under Pause → System that is not listed in the player Settings tab

Live also opens with CLI `--wdb-debug`.

### Live snapshot — menu chrome and Values

Live path: `scripts/debug/debug_menu/debug_menu.gd`. This is current chrome, not a new system.

**Pages.** Five pages in LB / RB order: Values → Settings → Profiles → Playtest → Animation Browser. Close (B) sits in the top row but is not a page. The top tab buttons are mouse-clickable and must not take gamepad focus. Title, tabs, and status stay pinned above the scroll so first-open focus cannot hide the tab labels. The active tab is tinted.

**Values (browse / edit).** Values does not use engine SpinBox focus. Tunables are grouped by category in two columns (`debug_menu_val_grid.gd`). Opening the page highlights the top-left category.

- D-pad / left-stick Up / Down move within the current category column and wrap in that column.
- D-pad / left-stick Left / Right move between the two category columns.
- **A** on a category expands that category’s variables in a single column under that category cell. Focus moves to the first variable. Navigation locks to that list (Up / Down). Left / Right do nothing in the var list.
- **A** on a variable enters edit. Up / Down then changes the value by that row’s step. The live balance value is not committed until confirm.
- **A** again writes the value and returns to the var list.
- **B** while editing restores the previous number and returns to the var list.
- **B** on the var list collapses it and returns focus to the two-column category grid.
- **B** on the category grid closes the secret menu (Values is the home page).
- Fly-out ideals still update from the highlighted variable.

**Settings.** Catch-all for in-test display and camera options. Built by `debug_menu_settings.gd`. Changes apply live and persist through `App.save_now()`.

- Camera zoom slider (`ZOOM_MIN`–`ZOOM_MAX`)
- HUD scale slider
- UI text floor slider (8–24, default 14). Applied scale is `clamp(floor / (UI_TEXT_REF × screen_per_design), 1.0, 2.5)`. Floor is saved; applied scale is recomputed on resize
- Force touch overlay toggle. Session-only. Bypasses web / mobile UA / keyboard / pad checks so desktop can preview the cluster in Placeholdia or the dungeon. Overlay still hides while `App.ui_open`
- Sprite filter cycle over all five Godot Sprite3D modes (nearest, nearest+mips, nearest+mips+aniso, linear+mips, linear+mips+aniso)
- Mip blend Sharp / Smooth (`rendering/textures/default_filters/use_nearest_mipmap_filter`)
- Mip bias slider (−2..2). Stored and persisted; Sprite3D has no lod-bias hook yet so the picture does not change
- Touch stick deadzone slider, plus reset. RT is press-and-hold only; there is no double-tap latch
- Look wheel / pinch / stick sliders, plus reset
- Grant anvil test kit (bag gear + gold / ore / root). Debug-only
- Save settings button

Linear filters MUST stay on this tab. Player Settings → Graphics uses Mipmaps / Anisotropic checkboxes (nearest implied). Linear stays here.

**Other pages.** Settings, Profiles, and Playtest still use normal button / LineEdit / slider focus. Up / Down moves among those controls.

**Animation Browser tab.** Navigating to that tab (LB / RB or mouse) only rebuilds a confirm prompt. It does not open the full-screen viewer. The first control is **Open Animation Browser**; **A** on that control launches `anim_browser.open_browser()`. **B** on the prompt returns to Values. While the viewer is open, the debug menu MUST release GUI focus and stop processing input so the viewer can take D-pad / keyboard. Debug-menu LB / RB must not steal model-cycle input. Closing the viewer restores debug-menu input and returns focus to this prompt, not to a hidden tab button.

The Phase 7 “gamepad-focusable Animation Browser control” is that Open button, not the top tab chrome.

