#!/usr/bin/env python3
"""Export the GitHub Pages build (Godot Web, no threads). Windows/Steam Godot or $GODOT_BIN.

    python tools/export_web.py [--archives] [--out DIR] [--godot PATH] [--debug --out DIR]
Release (preset Web) excludes scripts/debug/; --debug (preset Web Debug, debug template) keeps it, scratch --out only.
Live-only writes _out/web/ (untracked; Pages builds in CI). The mip flip (enable_texture_mips.py) and the import only touch the export workspace: tracked
.import files that were clean before the export are restored after it (any you were already editing are left alone).
--archives writes a combined site to _pages/ (gitignored); archive pins are
best-effort, cached under .archive_export_cache/. Logs: _logs/export-web/.
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
    ap = agent_log.std_parser("Export the Web build to _out/web/ (or _pages/ with --archives).", json_out=True)
    ap.add_argument("--archives", action="store_true", help="Also export catalog archives into _pages/.")
    ap.add_argument("--godot", default="", help="Godot executable (default: GODOT_BIN / Steam / bot pin).")
    ap.add_argument("--out", default="", help="Export here instead of _out/web/ (scratch dir for web_perf; not committed).")
    ap.add_argument("--debug", action="store_true", help="Debug export (preset 'Web Debug': debug template + scripts/debug/). Needs --out; _out/web/ is release only.")
    ap.add_argument("--timeout-sec", type=int, default=900, help="Godot export timeout in seconds (default 900).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if args.debug and (not args.out or args.archives):
        agent_log.fail("--debug needs --out DIR (scratch); _out/web/ and _pages/ ship the release export only")
    exe = godot_lib.godot_exe(args.godot)
    out_dir = Path(args.out).resolve() if args.out else root / ("_pages" if args.archives else "_out/web")
    out_html = out_dir / "index.html"
    out_dir.mkdir(parents=True, exist_ok=True)
    body, fail = [f"root=. out={agent_log.rel(root, out_dir)} archives={args.archives} mode={'debug' if args.debug else 'release'}"], ""

    def step(name: str, code: int) -> bool:
        body.append(f"{name} exit={code}")
        return code == 0

    def godot(name: str, *ga: str) -> bool:
        print(name)
        r = godot_lib.run_godot(root, root, list(ga), agent_log.run_path("export-web", root, f"{name}.out.log"), agent_log.run_path("export-web", root, f"{name}.err.log"), args.timeout_sec,
                                exe=str(exe))
        body.append(f"{name} status={r['status']} ms={r['ms']}")
        return not r["timed_out"] and r["exit_code"] == 0

    dirty = set(godot_lib.modified_imports(root))
    print("Enabling 3D texture mipmaps on import...")
    steps = [lambda: step("texture_mips", py(str(TOOLS / "enable_texture_mips.py"), "--root", str(root))),
             lambda: godot("godot-import", "--headless", "--path", str(root), "--import"),
             lambda: godot("godot-export", "--headless", "--path", str(root), *(("--export-debug", "Web Debug") if args.debug else ("--export-release", "Web")), str(out_html)),
             lambda: step("postexport", py(str(TOOLS / "web_postexport.py"), str(out_dir)))]
    ok = True
    for i, s in enumerate(steps):
        if not s():
            ok, fail = False, ["texture_mips", "godot-import", "godot-export", "postexport"][i]
            break
    put_back = [p for p in godot_lib.modified_imports(root) if p not in dirty]
    godot_lib.restore_imports(root, put_back)
    body.append(f"import sidecars restored={len(put_back)} kept_dirty={len(dirty)}")
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
