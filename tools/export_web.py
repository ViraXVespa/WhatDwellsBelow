#!/usr/bin/env python3
"""Export the GitHub Pages build (Godot Web, no threads). Windows/Steam Godot or $GODOT_BIN.

    python3 tools/export_web.py [--archives] [--out DIR] [--godot PATH]
Live-only writes docs/. --archives writes a combined site to _pages/ (gitignored); archive pins are
best-effort, cached under .archive_export_cache/. Logs: _logs/export-web/. Old spelling: -Archives.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import godot_lib

TOOLS = Path(__file__).resolve().parent


def py(*a: str) -> int:
    return subprocess.run([sys.executable, *a]).returncode


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Export the Web build to docs/ (or _pages/ with --archives).", json_out=True)
    ap.add_argument("--archives", "-Archives", action="store_true", help="Also export catalog archives into _pages/.")
    ap.add_argument("--godot", default="", help="Godot executable (default: GODOT_BIN / Steam / bot pin).")
    ap.add_argument("--out", default="", help="Export here instead of docs/ (scratch dir for web_perf; not committed).")
    ap.add_argument("--timeout-sec", "-TimeoutSec", type=int, default=900, help="Godot export timeout in seconds (default 900).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    exe = godot_lib.godot_exe(args.godot)
    out_dir = Path(args.out).resolve() if args.out else root / ("_pages" if args.archives else "docs")
    out_html = out_dir / "index.html"
    out_dir.mkdir(parents=True, exist_ok=True)
    body, fail = [f"root=. out={agent_log.rel(root, out_dir)} archives={args.archives}"], ""

    def step(name: str, code: int) -> bool:
        body.append(f"{name} exit={code}")
        return code == 0

    def godot(name: str, *ga: str) -> bool:
        print(name)
        r = godot_lib.run_godot(root, root, list(ga), agent_log.run_path("export-web", root, f"{name}.out.log"), agent_log.run_path("export-web", root, f"{name}.err.log"), args.timeout_sec,
                                exe=str(exe))
        body.append(f"{name} status={r['status']} ms={r['ms']}")
        return not r["timed_out"] and r["exit_code"] == 0

    print("Enabling 3D texture mipmaps on import...")
    steps = [lambda: step("texture_mips", py(str(TOOLS / "enable_texture_mips.py"), "--root", str(root))),
             lambda: godot("godot-import", "--headless", "--path", str(root), "--import"),
             lambda: godot("godot-export", "--headless", "--path", str(root), "--export-release", "Web", str(out_html)),
             lambda: step("postexport", py(str(TOOLS / "web_postexport.py"), str(out_dir)))]
    ok = True
    for i, s in enumerate(steps):
        if not s():
            ok, fail = False, ["texture_mips", "godot-import", "godot-export", "postexport"][i]
            break
    if ok:
        (out_dir / ".nojekyll").touch()
        if args.archives:
            print("Exporting catalog archives (cached, best-effort)...")
            ok = step("archives", py(str(TOOLS / "export_archives.py"), "--root", str(root), "--site", str(out_dir), "--godot",
                                     str(exe), "--cache", str(root / ".archive_export_cache"), "--worktrees",
                                     str(root / ".archive_worktrees")))
            fail = "" if ok else "archives"
    files = sorted(f"{p.name} {p.stat().st_size}" for p in out_dir.iterdir() if p.is_file()) if out_dir.is_dir() else []
    body += ["", "files:"] + files
    return agent_log.finish("export-web", root, "\n".join(body), "PASS" if ok else "FAIL", args=args, failed_step=fail or None,
                            out=agent_log.rel(root, out_dir))


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
