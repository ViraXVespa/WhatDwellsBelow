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
import platform
import shutil
import ssl
import subprocess
import sys
import tarfile
import urllib.request
import urllib.error
import zipfile
from pathlib import Path

CACHE_DIR = Path.home() / ".cache" / "wdb-graphs"
GDHEALTH_API = "https://api.github.com/repos/q-rault/gdhealth/releases/latest"
GDHEALTH_TAG_API = "https://api.github.com/repos/q-rault/gdhealth/releases/tags/{tag}"
# Used only when the latest release has no binary for this OS/arch (e.g. a release whose assets are not built yet).
GDHEALTH_FALLBACK_TAG = "v0.3.7"



def _urlopen(req: urllib.request.Request):
    """urlopen that falls back to unverified SSL on Windows cert problems."""
    try:
        return urllib.request.urlopen(req)
    except urllib.error.URLError as exc:
        if "CERTIFICATE_VERIFY_FAILED" in str(exc):
            print("warning: SSL verification failed; retrying without verification")
            ctx = ssl._create_unverified_context()
            return urllib.request.urlopen(req, context=ctx)
        raise

def _download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "wdb-graphs"})
    with _urlopen(req) as resp, open(dest, "wb") as f:
        f.write(resp.read())


def _platform_asset(assets: list[dict]) -> dict | None:
    """Pick the release asset that matches the current OS/arch."""
    system = platform.system().lower()
    machine = platform.machine().lower()

    if machine in ("x86_64", "amd64"):
        arch = "x86_64"
    elif machine in ("aarch64", "arm64"):
        arch = "aarch64"
    else:
        arch = machine

    prefer = []
    if system == "windows":
        prefer = [f"{arch}-pc-windows", "windows"]
    elif system == "linux":
        prefer = [f"{arch}-unknown-linux", "linux"]
    elif system == "darwin":
        prefer = [f"{arch}-apple-darwin", "darwin", "macos"]

    for needle in prefer:
        for a in assets:
            name = a.get("name", "").lower()
            if needle in name and name.endswith((".tar.gz", ".zip", ".tgz")):
                return a
    return None


def _extract_binary(archive: Path, dest_bin: Path) -> None:
    """Extract the gdhealth binary from a tar.gz or zip into dest_bin."""
    if archive.name.endswith(".zip"):
        with zipfile.ZipFile(archive) as zf:
            for info in zf.infolist():
                if info.filename.endswith("gdhealth") or info.filename.endswith("gdhealth.exe"):
                    zf.extract(info, archive.parent)
                    extracted = archive.parent / info.filename
                    dest_bin.parent.mkdir(parents=True, exist_ok=True)
                    shutil.move(str(extracted), dest_bin)
                    return
    else:
        with tarfile.open(archive, "r:gz") as tf:
            for member in tf.getmembers():
                if member.name.endswith("gdhealth") or member.name.endswith("gdhealth.exe"):
                    tf.extract(member, archive.parent)
                    extracted = archive.parent / member.name
                    dest_bin.parent.mkdir(parents=True, exist_ok=True)
                    shutil.move(str(extracted), dest_bin)
                    return
    raise SystemExit(f"no gdhealth binary found inside {archive.name}")


def ensure_gdhealth() -> Path:
    """Download or update the latest prebuilt binary for the current platform."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    version_file = CACHE_DIR / "gdhealth.version"
    bin_name = "gdhealth.exe" if platform.system().lower() == "windows" else "gdhealth"
    dest_bin = CACHE_DIR / bin_name

    try:
        req = urllib.request.Request(GDHEALTH_API, headers={"User-Agent": "wdb-graphs"})
        with _urlopen(req) as resp:
            release = json.load(resp)
    except Exception as exc:  # noqa: BLE001
        if dest_bin.is_file():
            print(f"warning: could not check latest gdhealth ({exc}); using cached binary")
            return dest_bin
        raise SystemExit(f"could not fetch gdhealth release info: {exc}") from exc

    latest_tag = release.get("tag_name", "")
    cached_tag = version_file.read_text(encoding="utf-8").strip() if version_file.is_file() else ""

    if dest_bin.is_file() and cached_tag == latest_tag:
        if platform.system().lower() != "windows":
            dest_bin.chmod(0o755)
        return dest_bin

    asset = _platform_asset(release.get("assets", []))
    if asset is None:
        fallback = GDHEALTH_FALLBACK_TAG
        print(
            f"notice: gdhealth {latest_tag} has no binary for {platform.system()} {platform.machine()} "
            f"(assets: {', '.join(a.get('name', '') for a in release.get('assets', [])) or 'none'}); "
            f"falling back to pinned {fallback}"
        )
        if dest_bin.is_file() and cached_tag == fallback:
            if platform.system().lower() != "windows":
                dest_bin.chmod(0o755)
            return dest_bin
        try:
            req = urllib.request.Request(GDHEALTH_TAG_API.format(tag=fallback), headers={"User-Agent": "wdb-graphs"})
            with _urlopen(req) as resp:
                release = json.load(resp)
        except Exception as exc:  # noqa: BLE001
            raise SystemExit(f"could not fetch gdhealth {fallback} release info: {exc}") from exc
        latest_tag = release.get("tag_name", fallback)
        asset = _platform_asset(release.get("assets", []))
        if asset is None:
            raise SystemExit(
                f"no suitable binary for {platform.system()} {platform.machine()} in {latest_tag} (pinned fallback); assets: "
                + ", ".join(a.get("name", "") for a in release.get("assets", []))
            )

    print(f"downloading gdhealth {latest_tag} ({asset['name']})...")
    archive = CACHE_DIR / asset["name"]
    _download(asset["browser_download_url"], archive)
    _extract_binary(archive, dest_bin)
    archive.unlink(missing_ok=True)
    if platform.system().lower() != "windows":
        dest_bin.chmod(0o755)
    version_file.write_text(latest_tag + "\n", encoding="utf-8")
    return dest_bin


def run_gdhealth(root: Path, out_dir: Path) -> None:
    """Run gdhealth health (default bundle location) and copy all artifacts."""
    bin_path = ensure_gdhealth()
    default_bundle = root / "reports" / "code-health"

    # Clean any previous run
    if default_bundle.exists():
        shutil.rmtree(default_bundle)

    cmd = [str(bin_path), "health", "--root", str(root)]
    subprocess.run(cmd, check=True, cwd=root)

    if not default_bundle.is_dir():
        raise SystemExit(f"gdhealth health did not produce {default_bundle}")

    # Copy the entire bundle into out_dir/game/
    game_dir = out_dir / "game"
    if game_dir.exists():
        shutil.rmtree(game_dir)
    shutil.copytree(default_bundle, game_dir)

    # Surface the main HTML at the top level for the index link.
    html = None
    for candidate in (
        game_dir / "browser" / "index.html",
        game_dir / "index.html",
        next(game_dir.rglob("index.html"), None),
        next(game_dir.glob("*.html"), None),
    ):
        if candidate and candidate.is_file():
            html = candidate
            break
    if html:
        shutil.copy2(html, out_dir / "game.html")
    else:
        # Fallback: generate the emerge-html viewer separately.
        html_tmp = out_dir / "_gdhealth_html"
        if html_tmp.exists():
            shutil.rmtree(html_tmp)
        html_tmp.mkdir(parents=True)
        subprocess.run(
            [
                str(bin_path),
                "graph",
                "--root",
                str(root),
                "--format",
                "emerge-html",
                "--output",
                str(html_tmp),
            ],
            check=True,
            cwd=root,
        )
        for candidate in (
            html_tmp / "index.html",
            html_tmp / "browser" / "index.html",
            next(html_tmp.rglob("*.html"), None),
        ):
            if candidate and candidate.is_file():
                shutil.copy2(candidate, out_dir / "game.html")
                break
        shutil.rmtree(html_tmp)

    # Remove the default bundle so we don't leave reports/ in the repo.
    shutil.rmtree(default_bundle)
    print(f"game health bundle -> {game_dir} (and game.html)")


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
    """Tools graph via py-code-visualizer (interactive HTML) + simple import JSON."""
    out_html = out_dir / "tools.html"
    # --max-nodes keeps the view usable; raise if you want more detail.
    cmd = [
        "py-code-visualizer",
        "visualize",
        str(tools_dir),
        "-o",
        str(out_html),
        "--max-nodes",
        "200",
    ]
    subprocess.run(cmd, check=True)

    # Simple machine-readable import map for agents (unchanged)
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
<p>Machine-readable:</p>
<ul>
  <li><a href="game/graph.json">game/graph.json</a> (and the rest of the health bundle under game/)</li>
  <li><a href="tools.json">tools.json</a></li>
</ul>
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
