# Save — display, performance, renderer

Status: binding design  
Read when: borderless exclusive, mip decode ban, Compatibility preferred


## Display apply

- Desktop applies saved `display_mode` at boot via `DisplayMode.apply_saved()`.
- Web cannot enter fullscreen except from a user gesture. `web_fullscreen` is the preference; the pre-splash gate, Settings → Graphics toggle, and Alt+Enter are the gestures.
- Esc on web MUST NOT exit fullscreen. Pause → Settings → Graphics and Alt+Enter do.
- `screen.orientation.lock("landscape")` is attempted from those same enter gestures. iPhone Safari tabs may ignore it; Home Screen / PWA launches use the manifest orientation.
- Custom feature tag `xbox` hides the Settings Quit / display rows and skips apply / Alt+Enter / the gate.

## Performance

60 FPS bar: the constraints file. Title → Play hitch work: hub. Floor streaming budget: dungeon.

`SpriteFilt.ensure_mips` must not decode a `CompressedTexture2D` into `ImageTexture` at runtime. Web export bakes mip chains via `tools/enable_texture_mips.py`. Local play uses the imported texture as-is.

Title → Play (`scripts/app_flow.gd`) sync-loads a short hub list (scene, tiles, props, music) and does not insert a fake progress wait. Debug menu and Animation Browser are created on the first idle frame (immediately when a smoke / `--wdb-debug` boot needs them).

## Renderer

Compatibility renderer is preferred for the shippable build if it does not break the web export. Mobile renderer may be retained only if required for web stability.

Godot target: **4.7.2**. Main scene `res://scenes/boot.tscn`. Autoload `App = *res://scripts/app.gd`.
