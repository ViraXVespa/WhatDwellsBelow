# Hub perf fix - diagnose and clear sub-60 FPS on the bench

id: hub-perf-fix
owner: build
status: open
done-when: On Vira's machine (env `build-pc`), `python tools/run_hub_bench.py --leg web` prints PASS (fps_pct >= 99) on two consecutive cold runs. Desktop already passes and is not re-scored. Docs and code-map updated if ownership or tunables changed.
resume: python tools/open_slice.py debug.playtest --task hub-perf-fix
area: debug
door: debug
job: playtest
needs: none

## Intent
Both legs walk a full 30 s. Eight facings, the stations, one strike on the dummy, then an out-and-back walk on each facing until the play clock reaches 30 s. The window closes when that clock ends. `fps_pct` counts only while the hub is visible: camp is showing and the loader bar is down. 99% of those frames at or above 60 FPS is the bar. 100% is the aim.

## Where it stands
Desktop `20261016`, fullscreen 1920x1080: fps_pct 99.7 to 99.8, p50 and p95 8.3 ms. Not re-run this session.

Web, capped Edge, vsync on, 1920x1080. Standing at the dummy (first launch, `--layers`): every hidden layer stayed at p50 and p95 16.7 ms, base draw 68. Fence, ground, buildings, sprites, light marks, and the HUD are not the still-camera cost. The full walk (second launch): fps_pct 77.0, frames 1236, slow 284, p50 16.7, p95 41.7, worst 144.8, ok 1. The sustained miss is the ending fill only (266 slow frames, median 38.9 ms, west-arm cells, phys about 2-4 ms, draw 48-78). The station walk is not that run. Uncapping (`--disable-frame-rate-limit` / `--disable-gpu-vsync`) bugchecked this GPU; `run_hub_bench.py` refuses both, and only `web_perf.py`'s headless SwiftShader (software GL) runs uncapped. A per-frame hitch-log scene walk still latches the whole bench; do not put that back.

The single-sheet yard from e4c632f was reverted. The ground is the week-7 band planes again. The blocky look is on main too, so it is not a branch regression and not this task.

## Next
The walk stays. Still at the dummy is one refresh; the fill walk there is two to three refreshes the whole time. The next fix is whatever the moving fill adds on top of that still camera. Do not spend the web leg on the light tap: textureLod and the four texelFetches both sat near fps_pct 75. Do not stack a second path plane on the dirt. Do not sample `hub_light.png` with `texture()`. `--layers` (`run_hub_bench.py --leg web --layers`) is the still-camera split; it does not score the 99% bar.

## Notes from Vira
That hitching on web during that last walk phase looks like a similar issue I've seen happening on the web builds but wasn't able to track down or reproduce. I've gotten it to occur in other places in the hub and without attacking the dummy. That's something I'd really like to get out of the game ASAP. I don't know if the logging is failing to catch whatever's causing it, but do whatever you need to do to diagnose and solve that issue.

## Known non-signals
Settled; do not re-investigate: hub FPS below dungeon FPS is this same web fill tail; the blocky/grainy ground is on main and not this task; vsync stays on (uncapping is refused).
- GLES quit leaks (N5GLES34MeshE / N5GLES37TextureE leaked at exit, and the raw Texture with GL ID / Buffer with GL ID leaked N bytes lines) are Compatibility-renderer artifacts on web exit. They are not the fail.
- Desktop hub-bench already clears the 99% bar (99.7-99.8%, p50/p95 8.3 ms).
- Web is refresh-paced (vsync=1 paced=1). fps_pct stuck mid-70s, dt_p50_ms ~17, dt_p95_ms ~44, worst 100-140. The fail is that tail.
- One diagnosis, one fix, then run_hub_bench.py --leg web once. Do not open shader or mesh files because a quit-leak line named a texture or buffer.
- Attack does not clear the walk cache. ensure_loco and ensure_attack fill separate dictionaries and return once the key is present. The only clear is load_sprites at init.
- Preloading every facing in warmup (ensure_loco + ensure_attack, then apply_tex) did not move the web number. Still fps_pct 76.8.
- A warm Edge process can report 99 %. That is not the cold number the task measures.
- Chrome task-manager lines (fallback_task_provider) are Edge internals, not the fail.
