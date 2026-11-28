# Pipeline studio

Status: current plan
Read when: authoring phone studio
Code: `tools/lib/media/mobile_ui_server.py`, `tools/lib/media/studio/`, `tools/lib/media/mobile_ui/`, `python tools/media.py pipeline`

The game stays gamepad-first and web-exportable. This page is the authoring studio. No mesh, vision model, or Comfy run belongs in the game. Ship frames stay 128.

## Run

`python tools/media.py studio` serves `0.0.0.0:8189` with no login, for the LAN. Open `http://<lan-ip>:8189` on a phone. `WDB_PIPELINE_SIMULATE=1` fakes every long job with staged progress (`WDB_PIPELINE_SIM_DELAY` seconds per stage, default 0.8) in a separate store at `data/pipeline/wip/_sim`, and the page shows a SIMULATED banner. `--selftest` runs both modes on a temp repo. Jobs live on the server (`data/pipeline/wip/_studio/jobs.json`), so a reload or another phone reconnects. The old Character Studio is at `/legacy/`, with its `/api/*`, `/workflow.json`, and `/comfy/*` routes unchanged. The Comfy server still starts this page on its own thread.

Alerts: a finished job raises a browser notification only on a secure origin (https, or localhost). Plain `http://<lan-ip>` is not one, so the phone flashes the tab title and icon instead.

## Studio to build

The first screen asks what to work on. Types are character, npc, enemy, sub-boss, boss, equipment, item, projectile, decoration, resource, ui, biome, building, and vfx. The list and the new-subject form call `pipeline list` and `pipeline new --type TYPE --name NAME`. Do not default the id to female.

A subject screen shows the record from `pipeline show ID`: name, type, `dirty.hard`, `dirty.soft`, links, and section ids. Section ids and the skeleton flag live in `tools/lib/media/pipeline/store.py`. A skeleton section is a navigation shell with empty data. Hold or right-click a linked id and open that subject. `pipeline link` writes a relation.

A section screen edits that section's `data`, then writes the WIP file. Local save is the WIP subject and does not touch the game. Export save runs `pipeline export ID` for the chosen section ids. The record schema is `wdb.pipeline/1` at `data/pipeline/wip/<type>/<id>.json`. The game contract is `wdb.export/1` under `data/pipeline/export/`. Canvas is 128. The export index lists no subjects. An id missing from that index keeps today's sprite paths. `scripts/data/content_pack.gd` is the reader.

A review screen reads a review JSON under `data/pipeline/wip/review/` when one exists for the subject. It shows each check id, pass or fail, and the reason. A vision pass does not override proportion.

Generation buttons name the command they run: `review`, `correct`, `tune`, `frame`, `proportion`, `mesh`, `smooth`, `body`, and `edit ID --text TEXT`. Auto-tune is `pipeline tune`. Start-from-reference stores an upload path, an image URL, or a post URL on the subject. It does not ingest a post during the shell, and it does not start the X-post proof. Preview shows the subject's stills. An in-game capture button can wait. The shell does not launch the game.

`pipeline check` round-trips a temp store and is the safe check. A UI trial subject comes from `pipeline new`. One model family at a time. The page does not start a second Comfy. Stop Comfy only with `stop_comfyui`. Do not kill a pid. Free Comfy before a review or a tune, then stop `qwen3-vl:8b` when that call ends.

## Status

Built: type picker, new subject (with template), subject record with flags and links, section editor with autosave and save review, prompts, start-from-reference, every generation form, jobs with progress, cancel and reconnect, approve, reject or regenerate per still, compare, review checks, GLB viewer, export with hard-flag hold, coverage. Simulate runs all of it. Real mode answers 501 where Build has not wired the seam; the list is under UI gaps for Build in the task. Visuals are unverified until the User looks.

## Leave alone

Do not run `pipeline edit`, `pipeline body`, or `pipeline smooth` on id `female` while building the shell. Do not queue a mesh refine. Do not overwrite `data/pipeline/wip/gen/female-hunyuan-body.glb` (1915824 bytes). Do not present `female-hunyuan-body-digits.glb`. Do not overwrite `assets/sprites/player/female/`. Do not restore `_src/wip/modular-voxel-walk/`.
