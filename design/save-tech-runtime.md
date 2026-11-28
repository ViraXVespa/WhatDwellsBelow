# Save — performance, renderer

Status: current plan  
Read when: mip decode ban, Compatibility preferred

## Performance

60 FPS bar: the constraints file. Title → Play hitch work: hub. Floor streaming budget: dungeon.

`SpriteFilt.ensure_mips` must not decode a `CompressedTexture2D` into `ImageTexture` at runtime. Web export bakes mip chains via `tools/release.py mips`. Local play uses the imported texture as-is.

Measured frame time and per-function costs: benchmarks. Whenever a benchmark is rerun, add its row there with the machine it ran on; numbers compare only within one machine.

Title → Play (`scripts/app/app_flow.gd`) sync-loads a short hub list (scene, tiles, props, music) and does not insert a fake progress wait. Debug menu and Animation Browser are created on the first idle frame (immediately when a smoke / `--wdb-debug` boot needs them).

## Renderer

Compatibility renderer is preferred for the shippable build if it does not break the web export. Mobile renderer may be retained only if required for web stability.

Godot target: **4.7.2**. Main scene `res://scenes/boot.tscn`. Autoload `App = *res://scripts/app.gd`.
