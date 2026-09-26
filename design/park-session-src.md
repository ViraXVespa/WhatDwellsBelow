# Park: session src harvest

Status: parked
Read when: resume parked session_src, harvest stills, _src/sessions

Not a boot file.

## Goal

Harvest Grok session stills and clips into local `_src/sessions/<id>/` plus a small manifest (id, source path, dest path, mtime). Run before a log wipe. Do not rekey. Do not write assets/. Do not delete ~/.grok/sessions. Not a Bot job.

Rekey stays a later pass from `_src` into live sprites.
