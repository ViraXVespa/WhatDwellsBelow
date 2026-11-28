# Desktop window modes

Status: current plan  
Read when: borderless exclusive, saved kind, windowed  
Code: `scripts/display_mode.gd`, `scripts/display_mode/mode_web.gd`, `scripts/display_mode/mode_env.gd`

- Applies where `uses_desktop_modes()` is true: not web, not `xbox`, not Android or iOS.
- Three modes in `App.display_mode`: `windowed`, `borderless` (the default, `WINDOW_MODE_FULLSCREEN`) and `exclusive` (`WINDOW_MODE_EXCLUSIVE_FULLSCREEN`). Any other value applies as `borderless`. A fullscreen choice also writes `App.display_fs_kind`, the kind Alt+Enter returns to.
- `apply_saved()` runs at boot from `app_boot._ready`, after the save loads. `set_desktop_mode(mode, persist)` saves unless told not to.
- The Settings row and the debug row call `cycle_desktop()`: borderless, exclusive, windowed, back to borderless. `desktop_label()` names the current mode (keys `display_mode.*`).
- `handle_input` (called first from `App._input`) takes Alt+Enter (windowed goes to the saved fullscreen kind; fullscreen goes to windowed), Ctrl/Cmd+W and Ctrl/Cmd+Q, and Alt+F4. The last three call `request_quit()`, which closes the tab on web and quits the tree on desktop.
- Android and iOS builds use the web toggle in the other job, not these modes.
