# Pipeline subjects

Status: current plan
Read when: subject records, size bands, and the prompt checklist
Code: `python tools/media.py pipeline`, `data/pipeline/`, `scripts/data/content_pack.gd`

WIP under `data/pipeline/wip/` stays local until export. Subject JSON, generations, and meshes stay off Git. Export JSON under `data/pipeline/export/` and the sheets it names are the game contract. Schemas and the tool code are the system. An id missing from the export index stays on today's sprite paths. The export index lists no subjects. `scripts/data/content_pack.gd` reads an exported id. Live sprites stay on their old paths until a caller asks for one.

## Hardware

RTX 3080 Laptop, 16384 MiB. One model family at a time. Comfy is `127.0.0.1:8188`. Stop it with `stop_comfyui`. Do not kill a pid. A headless start passes `--extra-model-paths-config` for the shared `wdb-model-paths.yaml` beside the Comfy install. Qwen3-VL runs only after Comfy is freed, then `ollama stop qwen3-vl:8b`. One Ollama model at a time. Do not change `OLLAMA_CONTEXT_LENGTH`.

Qwen Image int8 and its int8 text encoder do not stay on the GPU together. Stage the encoder on CPU. Measured peaks: Qwen staged still 8024 MiB, Pixal3D 4580, TRELLIS.2 3620, Hunyuan3D 2.1 7494, Qwen3-VL 15261 with Comfy unloaded, Stable Audio 3 1830. A gray two-step mesh is one vertex and is not a usable mesh. Review calls set `num_ctx` 65536 and `num_predict` 16384 on `qwen3-vl:8b` only. Wan 2.2 14B stays out.

## Subject

Measures, shape text, and digit counts live on the subject, in `sections.body.data` for a character and `sections.model.data` for an enemy, or whichever section carries `measures`. The tool does not assume a female body. A missing measure list fails. Do not default the id. Breasts and an hourglass are optional checks the subject opts into.

The female record is local WIP, id `female`. Her bands, while that record is the one open: front head 0.73–1.20, thigh max 0.50, calf max 0.32; side head 0.90–1.90, thigh max 0.95, calf max 0.72. Deltas: head 0.15, thigh 0.12, calf 0.10. Digits on that record: 4 fingers, a thumb, 2 toes. Do not copy those numbers into the tool.

The character root is a clean mannequin in a shared T-pose: arms out, feet apart, simple eyes. Brows, nose, mouth, and ears are later pieces. Eyes may stay. Feet are feet, not blocks. A square head, a flat plane on the torso, and a lumpy voxel surface fail. Bent elbows, thighs together, feet together, a thick abdomen, and a missing hourglass fail on a subject that opts into those checks. Idle is a later animation. A thumb, fingers, and a toe shape belong on the 3D source.

The clothed look is reference only: `data/pipeline/wip/gen/female-pixal-4view-tex_00001_.glb` (hair, neckband, maroon coat, dark pants, brown boots). Do not pose it as the root. Hair, a short green neckband with no tail, coat, pants, and boots come after the body. A little of the band may show at the nape. Do not call the neckband a scarf. Female Up does not mention it. Do not resume hair job `1cc4698a`.

The T-pose prompt does not say chibi or short legs. The negative does not ban realistic proportions. The head line stays "only a little wider than the ribcage." The kept mesh was generated before that wording. Do not rebuild it only to drop a word.

## Locks

The pixel lock is `data/pipeline/wip/gen/female-mannequin-front.png` (prompt `43a41238`): blank front, eyes may stay, feet passed. Do not copy prompt `64a7baac` over it. The back and both sides passed their checklists. Do not regenerate the blank front, the back, or those two sides. `pipeline frame` keeps the largest opaque mass. The framed plates match at solid height about 930. Those stills are the pixel lock. They are not the mesh source. The walk comparison is `assets/sprites/player/female/walk_DIRECTION_N.png`. Do not overwrite `assets/sprites/player/female/` until that walk is accepted.

## Commands

`pipeline check` round-trips a temp store and does not touch the real WIP.
`pipeline status`, `list`, `show`, `new`, `link`, `mark`, `coverage`, and `prompts` read and write the store. `new` takes `--type` and `--name`.
`pipeline export ID` writes the game contract for the named sections. Default is every section. The export index is empty.
`pipeline review` asks Qwen3-VL (`qwen3-vl:8b`) whether each positive sentence is visible and each comma-separated negative tag is absent. Four clauses at a time. A role checklist is also four checks at a time. The review context is 65536. The reply cap is 16384. Role about and allow stay on `data/pipeline/prompts/vision-checks.json` and are not sent. Roles: `mannequin-front`, `mannequin-side`, `mannequin-back`, `mannequin-mesh`, `mannequin-smooth`, `mannequin-tpose-side`, `mannequin-tpose-back`. A sentence that calls a feature a later piece, or that says eyes may stay, is not a visibility check. A vision pass does not override proportion. A review JSON object in the think trace is used when the content has none.
`pipeline correct` turns a miss into a prompt change. It does not run Comfy.
`pipeline tune` reviews, patches, and regenerates until the checklist passes or `--turns` (default 4). At the limit it writes the in-between images under `data/pipeline/wip/review/`. A repeated miss drops a bible reference, then lowers guidance. A fail is not a handoff.
`pipeline proportion ID` measures the measures that subject lists. Head, thigh, calf, and ears are body measures. Aspect is a general one. A `mannequin-tpose-back` still uses only measures listed for the back view. When ears are the only front miss, those lobes are clipped and measured again.
`pipeline frame` keeps the largest opaque mass.
`pipeline mesh` reads a glb. An empty height band fails. The largest piece under 60 percent of the vertices fails. A pass is not a look approval.
`pipeline smooth ID` tunes four text-only T-pose stills and builds the body from the front only if it passes.
`pipeline body ID` builds that mesh from the passing front still. The shape graph is image-only.
`pipeline edit ID --text TEXT` draws that change on one whole-body still, then refines a copy of the kept mesh. The kept body file stays. A failed mesh is not presented.
`pipeline digits` is on the CLI. It is not how fingers are made. Do not present `female-hunyuan-body-digits.glb`.

Report gates pass. Visuals stay unverified until the User confirms.

## Order

Stills, then vision and proportion on the still, then the mesh, then motion, then sound. MotionBricks SOMA FP16 is at `data/pipeline/wip/motionbricks/mmm_v6_soma_fp16.onnx` (380327058 bytes). The pipeline does not call it. Zero poses are NaN. Stable Audio was measured and is not the character path. Pixel finish is a post step. Voxelization stays paused. The 32-grid structure path stays paused.

Ship frames stay 128. Sub-boss draw scale is 2. Boss draw scale is 4. Proof order is the female 8-direction walk, presented for review, then the X-post character.
