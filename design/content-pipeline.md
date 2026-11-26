# Unified content pipeline

Status: current plan
Read when: staged generators, wip subjects
Code: `python tools/media.py pipeline`, `data/pipeline/`, `scripts/data/content_pack.gd`, `tools/lib/media/pipeline/store.py`

WIP under `data/pipeline/wip/` stays local. Export JSON and the sheets it names are the commit. The game reads an exported id through `scripts/data/content_pack.gd`. An id that is not in the export index stays on today's hardcoded sprite paths. No mesh, vision model, or Comfy run belongs in the game.

## This PC

RTX 3080 Laptop, 16384 MiB. One model family at a time. Comfy is the headless server on `127.0.0.1:8188`. Stop that server with `stop_comfyui`, not by killing a pid. Measure notes live in `data/pipeline/wip/measure/notes.md`.

## Staging order

1. Stills. Qwen Image 2.1 int8. The text encoder on the GPU peaked at 7713 MiB. The staged sample (encoder on CPU, int8 UNET plus VAE on the GPU, 1024, 2 steps) peaked at 8024 MiB. Do not keep the encoder and the UNET on the GPU together.
2. Mesh. Pixal3D multiview is the primary reconstructor. A 32-grid, 2-step fit test peaked at 4580 MiB. TRELLIS.2 is the single-view fallback at 3620 MiB. Hunyuan3D 2.1 also fits at 7494 MiB (latent length 3072, octree 64). All three gray-view fit tests wrote a 1-vertex mesh. A real still has to be the view before a mesh counts as usable.
3. Vision. Ollama `qwen3-vl:8b` runs only after Comfy is freed. The fit call peaked at 15261 MiB. Unload it before the next generator. `python tools/media.py pipeline review` sends one image and a checklist role to that model and writes pass/fail with a reason per check. `pipeline correct` turns one failed locked-image review into a prompt retry or a mesh rebuild. `pipeline tune` repeats that review and a local Comfy regeneration until the checklist passes or `--turns` is hit (default 4). A repeated miss drops a bible reference, then lowers guidance. At the limit it writes a progress report that includes each in-between image. A fail is not handed to the user. Eyebrows, the nose, and the mouth are later customizations on the player mannequin. Block feet fail the mannequin check.
4. Motion. MotionBricks SOMA FP16 ONNX, file `data/pipeline/wip/motionbricks/mmm_v6_soma_fp16.onnx` (380327058 bytes). ONNX Runtime 1.32.0 CPU execution provider. Load about 1.9 seconds, one run about 0.1 seconds, GPU stayed at 518 MiB. Zero poses come back as NaN. Small real-valued poses come back finite, shape `[1, 64, 366]`. A GPU execution provider is not installed.
5. Sound. Stable Audio 3. The checkpoint has no text encoder. Load `t5gemma_b_b_ul2.safetensors` with `CLIPLoader` type `stable_audio` on CPU. `EmptyLatentAudio` is 64 channels. This build's SA3 VAE is 256 channels, so encode audio through that VAE. The 1-second fit test peaked at 1830 MiB and wrote a flac.

Ship frames stay 128. Generate larger, then integer-downscale. Sub-boss draw scale is 2. Boss draw scale is 4.
