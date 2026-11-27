# Content pipeline

Status: current plan
Read when: sprite frames, paper plates, sheet harvest
Code: `python tools/media.py pipeline`

This file is the door. New art goes through this pipeline until it is complete. Do not run `bible-prompt`, `i2v-seeds`, `pack-loco`, `pack-oneshot`, `pack-turntable`, `plate-remap`, `comfy-character`, or an Imagine character, tile, UI, or I2V call for new game art. The strips already in the game stay. A fail is not presented.

| Job | Open |
|-----|------|
| pipeline subjects, proportion bands, clause checks | `design/content-pipeline.md` |
| hunyuan trellis pixal hi3d | `design/content-pipeline-mesh.md` |
| authoring phone studio | `design/content-pipeline-ui.md` |

One command covers a kind of change. Do not add a script per body part, prop, or enemy. Counts and measures live on the subject. A missing list fails. Do not default a subject id.

Ship frames stay 128. Generate larger, then integer-downscale. The game reads an exported pack. No mesh, vision model, or Comfy run belongs in the game.
