# Display (door)

Status: current plan  
Read when: quit chord, window apply  
Code: `scripts/display_mode.gd` (`DisplayMode`, the facade) + `scripts/display_mode/` (code map row Display; gdhealth group `display`)

| Job | Open |
|-----|------|
| borderless exclusive, saved kind, windowed | `design/display-desktop.md` |
| browser gesture, PWA standalone, orientation, Esc swallow | `design/display-web.md` |

Other code calls `DisplayMode.*` and never a `scripts/display_mode/` helper. The helpers are layered: `mode_env.gd` (platform probes, fullscreen state, browser kind) and `mode_hooks.gd` (page key hooks) reach nothing; `mode_desk.gd` (browser fullscreen JS, first gesture, install prompt) reaches only those two; `mode_web.gd` (window changes, toggles, Alt+Enter, quit) sits on top. A lower file never loads the facade or an upper file.

The `xbox` feature tag turns the whole system off: no apply, no Alt+Enter, no quit chord, no gate, and the Settings display rows are hidden. The fullscreen gate card (`scripts/ui/fs_gate.gd`) is a screen of the ui title_web job; it only asks this system for gesture, state and the seen flag. Saved keys (`display_mode`, `display_fs_kind`, `web_fullscreen`) belong to save_tech persist; the Alt+Enter binding rules to input kb_mouse.
