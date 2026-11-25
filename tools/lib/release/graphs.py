"""Generate interactive dependency graphs for the game and tools.

Local: python tools/release.py graphs --out _out/graphs
CI:    called with --out site/graphs

Writes:
  index.html, game.html, tools.html
  game.json   (gdhealth graph)
  tools.json  (simple import map)
"""

import argparse
import ast
import json
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

CACHE_DIR = Path.home() / ".cache" / "wdb-graphs"
GDHEALTH_BIN = CACHE_DIR / "gdhealth"
GDHEALTH_API = "https://api.github.com/repos/q-rault/gdhealth/releases/latest"


def _download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "wdb-graphs"})
    with urllib.request.urlopen(req) as resp, open(dest, "wb") as f:
        f.write(resp.read())


def ensure_gdhealth() -> Path:
    """Download or update the latest Linux x86_64 prebuilt binary."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    version_file = CACHE_DIR / "gdhealth.version"

    try:
        req = urllib.request.Request(GDHEALTH_API, headers={"User-Agent": "wdb-graphs"})
        with urllib.request.urlopen(req) as resp:
            release = json.load(resp)
    except Exception as exc:  # noqa: BLE001
        if GDHEALTH_BIN.is_file():
            print(f"warning: could not check latest gdhealth ({exc}); using cached binary")
            return GDHEALTH_BIN
        raise SystemExit(f"could not fetch gdhealth release info: {exc}") from exc

    latest_tag = release.get("tag_name", "")
    cached_tag = version_file.read_text(encoding="utf-8").strip() if version_file.is_file() else ""

    if GDHEALTH_BIN.is_file() and cached_tag == latest_tag:
        GDHEALTH_BIN.chmod(0o755)
        return GDHEALTH_BIN

    candidates = []
    for a in release.get("assets", []):
        name = a.get("name", "").lower()
        if not any(name.endswith(ext) for ext in (".sha256", ".sig", ".txt", ".md", ".json", ".tar.gz", ".zip")):
            if "linux" in name and ("x86_64" in name or "amd64" in name or "x64" in name):
                candidates.append(a)
    if not candidates:
        for a in release.get("assets", []):
            name = a.get("name", "").lower()
            if "linux" in name and not name.endswith((".tar.gz", ".zip", ".sha256")):
                candidates.append(a)
    if not candidates:
        raise SystemExit(
            f"no suitable Linux binary found in {latest_tag}; assets: "
            + ", ".join(a.get("name", "") for a in release.get("assets", []))
        )

    asset = candidates[0]
    print(f"downloading gdhealth {latest_tag} ({asset['name']})...")
    _download(asset["browser_download_url"], GDHEALTH_BIN)
    GDHEALTH_BIN.chmod(0o755)
    version_file.write_text(latest_tag + "\n", encoding="utf-8")
    return GDHEALTH_BIN


def run_gdhealth(root: Path, out_dir: Path) -> None:
    bin_path = ensure_gdhealth()
    tmp = out_dir / "_gdhealth_tmp"
    if tmp.exists():
        shutil.rmtree(tmp)
    tmp.mkdir(parents=True)

    cmd = [
        str(bin_path),
        "graph",
        "--root",
        str(root),
        "--format",
        "emerge-html",
        "--output",
        str(tmp),
    ]
    subprocess.run(cmd, check=True, cwd=root)

    # Locate HTML
    html = None
    for candidate in (
        tmp / "index.html",
        tmp / "game.html",
        tmp / "browser" / "index.html",
        next(tmp.glob("*.html"), None),
        next(tmp.rglob("index.html"), None),
    ):
        if candidate and candidate.is_file():
            html = candidate
            break
    if html is None:
        raise SystemExit(f"gdhealth produced no HTML under {tmp}")

    # Locate graph JSON (gdhealth writes graph.json in the bundle)
    graph_json = None
    for candidate in (
        tmp / "graph.json",
        tmp / "browser" / "graph.json",
        next(tmp.rglob("graph.json"), None),
    ):
        if candidate and candidate.is_file():
            graph_json = candidate
            break

    dest_html = out_dir / "game.html"
    shutil.copy2(html, dest_html)
    if graph_json:
        shutil.copy2(graph_json, out_dir / "game.json")
        print(f"game graph -> {dest_html} + game.json")
    else:
        print(f"game graph -> {dest_html} (no graph.json found)")
    shutil.rmtree(tmp)


def _python_imports(path: Path) -> list[str]:
    """Best-effort static import extraction."""
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    except (SyntaxError, UnicodeDecodeError):
        return []
    imports: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                imports.append(alias.name)
        elif isinstance(node, ast.ImportFrom):
            if node.module:
                imports.append(node.module)
    return imports


def run_codegraph(tools_dir: Path, out_dir: Path) -> None:
    out_html = out_dir / "tools.html"
    cmd = ["codegraph", str(tools_dir), "--output", str(out_html)]
    subprocess.run(cmd, check=True)

    # Simple machine-readable import map for agents
    import_map: dict[str, list[str]] = {}
    for py in tools_dir.rglob("*.py"):
        if "__pycache__" in py.parts:
            continue
        rel = py.relative_to(tools_dir).as_posix()
        import_map[rel] = _python_imports(py)
    (out_dir / "tools.json").write_text(
        json.dumps(import_map, indent=2) + "\n", encoding="utf-8"
    )
    print(f"tools graph -> {out_html} + tools.json")


def write_index(out_dir: Path) -> None:
    (out_dir / "index.html").write_text(
        """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>What Dwells Below — Code graphs</title>
<style>
body { font-family: system-ui, sans-serif; max-width: 40rem; margin: 2rem auto; }
a { display: block; margin: 1rem 0; font-size: 1.2rem; }
</style>
</head>
<body>
<h1>Code graphs</h1>
<p>Interactive file-dependency graphs generated on each Pages deploy.</p>
<a href="game.html">Game (GDScript)</a>
<a href="tools.html">Tools (Python)</a>
<p>Machine-readable: <a href="game.json">game.json</a>, <a href="tools.json">tools.json</a></p>
</body>
</html>
""",
        encoding="utf-8",
    )


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out", type=Path, default=Path("_out/graphs"), help="Output directory")
    p.add_argument("--root", type=Path, default=Path("."), help="Project root")
    args = p.parse_args()

    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    root = args.root.resolve()

    run_gdhealth(root, out)
    run_codegraph(root / "tools", out)
    write_index(out)
    print(f"Graphs written to {out}")


if __name__ == "__main__":
    main()
