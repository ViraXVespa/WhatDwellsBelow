#!/usr/bin/env python3
"""Local static server for an exported web build that also takes the game's hitch rows.

  python tools/hitch_sink.py [--site DIR] [--port N]

Serves DIR (default _out/web) on 127.0.0.1. On localhost the game (scripts/debug/hitch_log.gd) POSTs each hitch-log row to
/_wdb/hitch (fire-and-forget fetch); they are appended to _logs/web-perf/hitch.jsonl. web_perf.py uses the same handler and
tags each row with its flow run (`wp_run`). Other static servers just refuse the POST; the game ignores that.
"""
from __future__ import annotations

import functools
import http.server
import json
import sys
import threading
from pathlib import Path

PATH = "/_wdb/hitch"
REL = "_logs/web-perf/hitch.jsonl"
STATE = {"run": "", "file": None}
_LOCK = threading.Lock()

class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_POST(self):
        if self.path.split("?")[0] != PATH or STATE["file"] is None:
            self.send_error(404)
            return
        raw = self.rfile.read(min(int(self.headers.get("Content-Length") or 0), 65536))
        try:
            row = json.loads(raw.decode("utf-8"))
        except ValueError:
            self.send_error(400)
            return
        if STATE["run"]:
            row["wp_run"] = STATE["run"]
        with _LOCK, open(STATE["file"], "a", encoding="utf-8") as fh:
            fh.write(json.dumps(row, sort_keys=True) + "\n")
        self.send_response(204)
        self.end_headers()

class _Server(http.server.ThreadingHTTPServer):
    def handle_error(self, request, client_address):  # the browser closing mid-download is not news
        pass

def serve(site: Path, root: Path, port: int = 0) -> http.server.ThreadingHTTPServer:
    out = root / REL
    out.parent.mkdir(parents=True, exist_ok=True)
    STATE["file"] = str(out)
    srv = _Server(("127.0.0.1", port), functools.partial(Handler, directory=str(site)))
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv

def rows(root: Path, run: str) -> list[dict]:
    p = root / REL
    if not p.is_file():
        return []
    out = []
    for ln in p.read_text(encoding="utf-8").splitlines():
        try:
            r = json.loads(ln)
        except ValueError:
            continue
        if r.get("wp_run") == run:
            out.append(r)
    return out

def main(argv: list[str] | None = None) -> int:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import agent_log

    ap = agent_log.std_parser(__doc__.splitlines()[0])
    ap.add_argument("--site", default="_out/web", help="Web export folder to serve (default _out/web).")
    ap.add_argument("--port", type=int, default=8060, help="HTTP port (default 8060).")
    a = ap.parse_args(argv)
    root = agent_log.resolve_root(a)
    srv = serve(root / a.site, root, a.port)
    print("http://127.0.0.1:%d/index.html  hitch rows -> %s" % (srv.server_address[1], REL))
    try:
        threading.Event().wait()
    except KeyboardInterrupt:
        srv.shutdown()
    return agent_log.emit_result("PASS", rows=REL)

if __name__ == "__main__":
    sys.exit(main())
