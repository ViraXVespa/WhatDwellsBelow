#!/usr/bin/env python3
"""Stamp a Godot Web export so browsers pick up a new build without a cache wipe."""

from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys


def _git_sha(root: pathlib.Path) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(root), "rev-parse", "--short=12", "HEAD"],
            text=True,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def _label(root: pathlib.Path) -> str:
    path = root / "scripts" / "data" / "version.json"
    if not path.is_file():
        return "dev"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return "dev"
    label = str(data.get("label") or "").strip()
    return label if label else "dev"


def _build_id(root: pathlib.Path) -> str:
    label = _label(root)
    sha = _git_sha(root)
    return f"{label}-{sha}" if sha else label


def _patch_html(html: str, build_id: str) -> str:
    q = f"?v={build_id}"

    def add_q(url: str) -> str:
        if "?" in url:
            return url
        return url + q

    html = re.sub(
        r'(src=")(index\.js)(")',
        lambda m: m.group(1) + add_q(m.group(2)) + m.group(3),
        html,
        count=1,
    )
    html = re.sub(
        r'(href=")(index\.(?:manifest\.json|icon\.png|apple-touch-icon\.png|png))(")',
        lambda m: m.group(1) + add_q(m.group(2)) + m.group(3),
        html,
    )
    html = re.sub(
        r'("serviceWorker"\s*:\s*")(index\.service\.worker\.js)(")',
        lambda m: m.group(1) + add_q(m.group(2)) + m.group(3),
        html,
        count=1,
    )
    hook = (
        "<script>"
        f"window.__wdbBuildId={json.dumps(build_id)};"
        "(function(){"
        "function go(id){"
        "try{var k='wdb_reload_'+id;if(sessionStorage.getItem(k))return;sessionStorage.setItem(k,'1');}catch(e){}"
        "var done=function(){location.reload();};"
        "var wipe=function(){"
        "var p=Promise.resolve();"
        "if(window.caches){p=caches.keys().then(function(ks){return Promise.all(ks.map(function(k){return caches.delete(k);}));});}"
        "p.then(done,done);"
        "};"
        "if(navigator.serviceWorker){"
        "navigator.serviceWorker.getRegistrations().then(function(rs){"
        "return Promise.all(rs.map(function(r){return r.unregister();}));"
        "}).then(wipe,wipe);"
        "}else{wipe();}"
        "}"
        "fetch('build_id.txt?t='+Date.now(),{cache:'no-store'}).then(function(r){return r.ok?r.text():'';}).then(function(t){"
        "t=String(t||'').trim();"
        "if(t&&t!==window.__wdbBuildId)go(t);"
        "}).catch(function(){});"
        "})();"
        "</script>"
    )
    if "window.__wdbBuildId" not in html:
        if "</head>" in html:
            html = html.replace("</head>", hook + "</head>", 1)
        else:
            html = hook + html
    return html


def _patch_sw(text: str, build_id: str) -> str:
    nxt = f"WDB_{build_id}"
    patched, n = re.subn(
        r"""(const\s+CACHE_NAME\s*=\s*['"])([^'"]+)(['"])""",
        rf"\1{nxt}\3",
        text,
        count=1,
    )
    if n:
        return patched
    patched, n = re.subn(
        r"""(['"])GODOT[^'"]*(['"])""",
        rf"\1{nxt}\2",
        text,
        count=1,
    )
    return patched if n else text


def stamp(out_dir: pathlib.Path, root: pathlib.Path) -> str:
    build_id = _build_id(root)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "build_id.txt").write_text(build_id + "\n", encoding="utf-8")
    html_path = out_dir / "index.html"
    if html_path.is_file():
        html_path.write_text(
            _patch_html(html_path.read_text(encoding="utf-8"), build_id),
            encoding="utf-8",
            newline="\n",
        )
    sw_path = out_dir / "index.service.worker.js"
    if sw_path.is_file():
        sw_path.write_text(
            _patch_sw(sw_path.read_text(encoding="utf-8"), build_id),
            encoding="utf-8",
            newline="\n",
        )
    print(f"web_postexport {out_dir} -> {build_id}")
    return build_id


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: web_postexport.py <export-dir>", file=sys.stderr)
        return 2
    out_dir = pathlib.Path(sys.argv[1]).resolve()
    root = pathlib.Path(__file__).resolve().parents[1]
    stamp(out_dir, root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())