# Hub bake, prop shadows, lamps, light leaks, desktop shading

id: hub-bake-lights
owner: web
status: open
done-when: Prop shadows present for fence/banner/anvil/dumpster; no bottom-face light leaks; torch VFX + light on guild lamp positions; ground shading matches web on Desktop. Full bake + stamp committed.
resume: (web) start by naming this task in a web session; no open_slice command.

## Intent
Bake registration, torch lights, light-leak fix, and desktop/web shading parity. Scratch runs run_bake_camp.py.

## Refs
Drop missing-shadow and leak examples in design/refs/hub-bake-lights/.

## Refs
- red-wall-shadow.jpg — missing / incorrect shadow on a wall face (bake registration example)
