# Hub perf fix — diagnose and clear sub-60 FPS on the bench

id: hub-perf-fix
owner: build
status: open
done-when: The hub-bench walker reports 99 % of frames at or above 60 FPS (threshold 1×) across two full ~30 s runs, with the causes of the previous sub-60 frames fixed and the hitch log clean of recurring major hits. Design docs and code-map updated if ownership or tunables changed.
resume: python tools/start_build_slice.py --door debug --job playtest --task hub-perf-fix
area: debug
door: debug
job: playtest
units:
needs: none

## Intent
Both legs walk a full 30 s. Eight facings, the stations, one strike on the dummy, then an out-and-back walk on each facing until the play clock reaches 30 s. The window closes when that clock ends. `fps_pct` counts only while the hub is visible: camp is showing and the loader bar is down. 99% of those frames at or above 60 FPS is the bar. 100% is the aim.

## Where it stands
Desktop `20261016`, fullscreen 1920x1080: fps_pct 99.7 to 99.8, p50 and p95 8.3 ms. That leg still passes.

Web, capped Edge, vsync on, same window: the ending fill is still the miss, about fps_pct 75 to 77, fill median about 43 ms, cells on the west arm. Standing still at the dummy was 70.5. Hiding the hall and wing was 77.0. The fill cost is not the guild meshes and not the walk cycle. Draw stayed about 70. Fill physics was about 4 ms. Do not pass `--disable-frame-rate-limit` or `--disable-gpu-vsync`. A per-frame hitch-log scene walk still latches the whole bench; do not put that back.

The inner yard is one plane. The path uses its own repeat. The hub light tap is LOD 0 because `hub_light.png` has no mip chain (`texture()` repainted the yard and, when the shader failed, took the ground and the baked shadows with it). Vira looked at the desktop window: the path scale looks right, and the ground and shadows are back.

## Next
The walk stays. Web at that west-arm camera still presents at about two to three refreshes with the hall gone and while standing. Do not stack a second path plane on the dirt. Do not sample `hub_light.png` with `texture()`. The next probe is whatever else that camera is paying for. Desktop at the same spot stays at 8.3 ms.

## Notes from Vira
That hitching on web during that last walk phase looks like a similar issue I've seen happening on the web builds but wasn't able to track down or reproduce. I've gotten it to occur in other places in the hub and without attacking the dummy. That's something I'd really like to get out of the game ASAP. I don't know if the logging is failing to catch whatever's causing it, but do whatever you need to do to diagnose and solve that issue.

## Known non-signals
- GLES quit leaks (N5GLES34MeshE / N5GLES37TextureE leaked at exit, and the raw Texture with GL ID / Buffer with GL ID leaked N bytes lines) are Compatibility-renderer artifacts on web exit. They are not the fail.
- Desktop hub-bench already clears the 99% bar (99.7-99.8%, p50/p95 8.3 ms).
- Web is refresh-paced (vsync=1 paced=1). fps_pct stuck mid-70s, dt_p50_ms ~17, dt_p95_ms ~44, worst 100-140. The fail is that tail.
- One diagnosis, one fix, then run_hub_bench.py --leg web once. Do not open shader or mesh files because a quit-leak line named a texture or buffer.
