# Content pipeline

Status: current plan
Read when: unified content, export contract, asset types
Code: game reader `scripts/data/content_pack.gd` + `scripts/data/content_pack/` (code map row Content pipeline; gdhealth group `content_pipeline`); tools `python tools/media.py pipeline`, `python tools/media.py studio`, `tools/lib/media/pipeline/`, `tools/lib/media/studio/`; contract `data/pipeline/export/`, schemas `data/pipeline/schemas/`

This file is the door. New art goes through this pipeline until it is complete. Do not run `bible-prompt`, `i2v-seeds`, `pack-loco`, `pack-oneshot`, `pack-turntable`, `plate-remap`, `comfy-character`, or an Imagine character, tile, UI, or I2V call for new game art. The strips already in the game stay. A fail is not presented.

| Job | Open |
|-----|------|
| pipeline subjects, proportion bands, clause checks | `design/content-pipeline-subjects.md` |
| hunyuan trellis pixal hi3d | `design/content-pipeline-mesh.md` |
| authoring phone studio | `design/content-pipeline-ui.md` |
| rekey manifests, shipped sprite sheets, retired generators | `design/content-pipeline-legacy.md` |

One command covers a kind of change. Do not add a script per body part, prop, or enemy. Counts and measures live on the subject. A missing list fails. Do not default a subject id.

Ship frames stay 128. Generate larger, then integer-downscale. The game reads an exported pack. No mesh, vision model, or Comfy run belongs in the game.

The unified content pipeline (the studio plus `media.py pipeline`, standing task `unified-content-pipeline`) replaces the old art pipeline. The old tools are the legacy job: in use for the art already shipped, closed for new art, each mapped to where it lands. Adoption is subject by subject: `content_pack.gd` has no game caller yet, and each game reader switches to it only when its subject id is in `data/pipeline/export/index.json`; until then it keeps its `assets/sprites/` path. No bulk switch.
