#!/usr/bin/env python3
"""Pipeline studio: the phone UI for the art and content pipeline, on 0.0.0.0:8189.

    python tools/media.py studio
    WDB_PIPELINE_SIMULATE=1 python tools/media.py studio      (fake long jobs, separate store)
    python tools/media.py studio --selftest

Open http://<lan-ip>:8189 on a phone on the same network. The closed Character Studio is at /legacy/.
WDB_PIPELINE_SIM_DELAY sets the seconds per simulated stage (default 0.8).
"""
from __future__ import annotations

import socket
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib
import boot  # noqa: E402,F401

import agent_log
from media import mobile_ui_server as server_mod


def _lan_ip() -> str:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def _serve(root: Path, host: str, port: int) -> int:
    sim = server_mod.simulate_on()
    try:
        server = server_mod.make_server(host, port, root)
    except OSError as exc:
        print(f"error: port {port}: {exc}", file=sys.stderr)
        return 2
    mode = "SIMULATED (store data/pipeline/wip/_sim)" if sim else "real store"
    print(f"Pipeline studio on http://{_lan_ip()}:{port}  {mode}")
    print("Ctrl+C stops it.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return agent_log.emit_result("INFO", summary="stopped", port=port, simulated=int(sim))


def _gaps(root: Path, check: bool) -> int:
    from media.studio import gaps, registry
    problems = registry.check()
    stale = gaps.write(root, check=check)
    for line in problems:
        print("REGISTRY", line)
    for path in stale:
        print(("STALE " if check else "WROTE ") + path)
    bad = problems + (stale if check else [])
    print(f"RESULT {'FAIL' if bad else 'PASS'} problems={len(bad)} summary=studio-gaps")
    return 1 if bad else 0


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Pipeline studio server: phone UI and JSON API on port 8189.")
    ap.add_argument("--port", type=int, default=server_mod.UI_PORT, help="Port (default 8189).")
    ap.add_argument("--host", default="0.0.0.0", help="Bind address (default 0.0.0.0, the LAN).")
    ap.add_argument("--selftest", action="store_true", help="Run both backends against a temp store and exit.")
    ap.add_argument("--gaps", action="store_true", help="Write the Build gap list (task section and ref file) from the studio registry.")
    ap.add_argument("--check", action="store_true", help="With --gaps: fail if the written list is stale instead of writing.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if args.gaps:
        return _gaps(root, args.check)
    if args.selftest:
        from media.studio import selftest
        return selftest.run(root)
    return _serve(root, args.host, args.port)


if __name__ == "__main__":
    raise SystemExit(main())
