# Hitch log

Status: current plan
Read when: spike jsonl, localhost
Code: `scripts/debug/hitch_log.gd` (facade) + `scripts/debug/hitch_log/` (rows, session, file, web post, present)

Hitch log is `scripts/debug/hitch_log.gd`. On editor, desktop, and localhost web it is on by default. GitHub Pages does not hook it. A frame at least four times the 60 FPS budget appends one JSONL line to `user://hitch/hitch.jsonl`. Newest 256 hitch rows are kept. Session and hitch rows stamp `ver` from `scripts/data/version.json`. Debug chrome can copy or clear the file. On localhost web each row is also POSTed (fire-and-forget) to `/_wdb/hitch`; `tools/perf.py hitch` and `perf.py web` append it to `_logs/web-perf/hitch.jsonl`. Not part of the playtest journal. To log smaller frames in a normal localhost web session, serve a `Web Debug` export with `perf.py hitch` and open `index.html?wdb-hitch-mult=1` (URL args reach `CliArgs`; `HitchLog.begin` reads `--wdb-hitch-mult`). The 256-row cap stays, and outside the bench each row is its own POST.
