# Report Bug client

Status: current plan  
Read when: relay upload, crash marker, install id, state report  
Code: `scripts/app/bug_report/bug_send.gd`, `scripts/app/bug_report/bug_state.gd`, `scripts/app/bug_report/crash_mark.gd`, `scripts/data/bug_doors.gd`, `scripts/data/bug_doors.json`

- `bug_send.gd`: the stable install id (`user://install_id.txt`), the payload (summary, door, job, kind, details, email, opt-in, crash log) and the POST to `RELAY_URL` under `App`, so it survives the pause menu closing. The game holds no token. The email goes only in the `email` field. `capture` hides the menu layer for two drawn frames and returns the view as base64 JPEG.
- `bug_state.gd`: the game's own state report. Only the relay's state keys: version label and week commit, platform, build kind, door context of where the player is, loadout. No logs, names or paths.
- `crash_mark.gd`: a session marker in `user://` written at boot and removed on a clean exit. Still there at the next boot means the last session crashed; the tail of its rotated log, scrubbed of machine paths, is offered as an opt-in attachment. Skipped on web and in smokes. It ships in release builds.
- Categories: `bug_doors.gd` / `bug_doors.json` are generated from the routes doors and jobs by `node tools/relay/gen-doors.mjs`, together with the relay's own list. The relay refuses a category it does not know, so regenerate them together and redeploy the relay in the same change; never edit the generated files.
- Proof: smoke P1 `bug_report_ok`; shots `camp-pause-pages`, `settings-report*`.
