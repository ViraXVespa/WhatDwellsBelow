# Mesh models

Status: current plan
Read when: hunyuan trellis pixal hi3d
Code: `python tools/media.py pipeline body`, `python tools/media.py pipeline edit ID --text TEXT`

## On disk

Qwen Image 2.1 int8 writes the still. Hunyuan3D 2.1 (`hunyuan_3d_v2.1.safetensors`) builds the body from one front still. Its shape graph is image-only. There is no text field. Pixal3D int8 and Pixal3D multiview int8 are on disk. TRELLIS.2 int8, its shape VAE, and its texture VAE are on disk. Pixal and TRELLIS rebuild a mesh from images. They copy the plate. A mitten plate stays a mitten.

`pipeline body` uses one front still and the Hunyuan 2.1 blueprint: latent 4096, octree 256, 30 steps, cfg 5, surface net. A fit failure retries latent 3072 and octree 128 once. A fragmented mesh stops. Do not load Hunyuan in the edit graph.

The kept female body is `data/pipeline/wip/gen/female-hunyuan-body.glb`, prompt `bb26c107`, 52936 vertices, one piece, 1915824 bytes, span 1.9659. Front head 1.11, thigh 0.44, calf 0.30. Side head 1.74, thigh 0.74, calf 0.42. Do not overwrite it. A new mesh gets a new file. A pass is not a look approval. A small bump at the back of the jaw can stay until ears are a piece. Do not start Blender. Do not save the open blend. Hidden meshes stay hidden.

The subject's front plate is `data/pipeline/wip/gen/female-mannequin-tpose-front-slimcalf.png` (calf factor 0.70). It has mitten hands and one-mass feet. Do not pass it as an edit reference. The backup `female-hunyuan-body-c5f67d50.glb` stays as it is.

## Closed prompts

Do not resubmit or present these:

- Neck gap or pillar: `918e696e`, `5b5de309`, `d3e0b159`, `fcc6c199`, `004e9412`, `ffec9ef8`.
- Aligned structure and its standing shape: `a89468e1`, `1e889747`. A mesh-gate pass on `a89468e1` only allows a shape stage.
- Fragment cloud: `07176358`.
- Lumpy square head, flat front plane, ears, missing breasts: `ef7de895`.
- Bind pose rejected (bent arms, thighs together, feet together, thick abdomen): `75f81c41`.
- T-pose kept and scale rejected: `c5f67d50`.
- Proportion miss, review copies only: `2e90b57c`, `c855bdf0`, `45195711`.
- Rod fingers: `female-hunyuan-body-digits.glb`.

The painted mannequin mesh failed block feet. Do not present it.

## Text edits

No local model takes a mesh plus a text prompt and returns an edited mesh. `pipeline edit ID --text TEXT` turns that text into a Qwen still of the whole body, then Hi3D refines a copy of the kept mesh from that still. The new file is `{id}-hunyuan-body-edit.glb`. The kept body file stays. Hi3D does not read the prompt. It will not invent fingers the still does not show. One command covers later tweaks. Do not add a generator per part.

Hi3D v1.0 is the refiner on this card. The node is `ComfyUI-Hi3D`. The shared Comfy models root has `checkpoints/hi3d_v1_int8.safetensors` (4320712680 bytes), `clip_vision/dinov2-large.safetensors` (1217522888), and `clip_vision/clip-vit-large-patch14.safetensors` (1710540580). Those encoders are public DINOv2 Large and CLIP ViT-L/14. The default chain is 512, then 1024, then 1536, 25 steps. A fit failure retries 512 alone. The reference is the whole body with the change visible. A hand crop would pull the whole mesh toward a hand. Generated meshes can ship. The Hi3D weights stay on this machine. UltraShape is the same image-refine job and is not on this card. Cloud editors are not this path.

The female edit still in review is `data/pipeline/wip/review/female-edit-head.png`. Proportion is in band: front head 0.736, thigh 0.386, calf 0.243, with the front head minimum at 0.73. The checklist failed the separated-fingers sentence, the head-width sentence, and the lines "Ears are a later piece", "visible ear", "A-pose", and "idle stance". The toes sentence passed. The T-pose role checks passed. Do not queue Hi3D on this still. Do not present it. `female-hunyuan-body-edit.glb` does not exist. The change text on that still is one thumb and four separated fingers with a gap, a toe shape on each foot, and the whole figure in frame, appended to the front T-pose prompt. The workflow is text-only.

Direct3D-V3 INT8 shape weights for stage 1536 are on disk. Its image encoder is Meta DINOv3. Access is awaiting author review. Leave that node unloaded. Do not rerun its setup into the login prompt.

## Fit

A gray view is not a usable mesh. A real still is the view. One model family at a time. Order on an edit: the still, then vision and proportion, then Hi3D, then `pipeline mesh` and `pipeline proportion`. Wan 2.2 14B stays out.
