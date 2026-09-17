#!/usr/bin/env python3
"""Stamp a Godot Web export. Cache id follows the binary, not the notes label."""

from __future__ import annotations

import hashlib
import json
import pathlib
import re
import sys

NOTES_SCRIPT = '<script src="data/notes.js"></script>'
DATA_FETCH = (
    "self.addEventListener('fetch',event=>{"
    "const u=event.request.url;"
    "if(u.includes('/data/')){"
    "event.respondWith(fetch(event.request).catch(()=>caches.match(event.request)));"
    "}});\n"
)


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


def _binary_id(out_dir: pathlib.Path) -> str:
    digest = hashlib.sha256()
    found = False
    for name in ("index.pck", "index.wasm", "index.js"):
        path = out_dir / name
        if not path.is_file():
            continue
        digest.update(name.encode("utf-8"))
        digest.update(path.read_bytes())
        found = True
    if found:
        return digest.hexdigest()[:16]
    return _label(pathlib.Path(__file__).resolve().parents[1])


def _assign_build_id(build_id: str) -> str:
    return "window.__wdbBuildId=%s;" % json.dumps(build_id)


def _ensure_notes_script(html: str) -> str:
    if "data/notes.js" in html:
        return html
    hook = NOTES_SCRIPT
    if "</head>" in html:
        return html.replace("</head>", hook + "</head>", 1)
    return hook + html


def _patch_html(html: str, build_id: str) -> str:
    q = "?v=%s" % build_id

    def add_q(url: str) -> str:
        if "?" in url or url.startswith("data/"):
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
        r'(\"serviceWorker\"\s*:\s*\")(index\.service\.worker\.js)(\")',
        lambda m: m.group(1) + add_q(m.group(2)) + m.group(3),
        html,
        count=1,
    )
    assign = _assign_build_id(build_id)
    html, n = re.subn(
        r"window\.__wdbBuildId\s*=\s*(?:\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*')\s*;",
        assign,
        html,
        count=1,
    )
    if not n:
        hook = "<script>" + assign + "</script>"
        if "</head>" in html:
            html = html.replace("</head>", hook + "</head>", 1)
        else:
            html = hook + html
    return _ensure_notes_script(html)


def _patch_sw(text: str, build_id: str) -> str:
    nxt = "WDB_%s" % build_id
    patched, n = re.subn(
        r"(const\s+CACHE_NAME\s*=\s*['\"])([^'\"]+)(['\"])",
        r"\1%s\3" % nxt,
        text,
        count=1,
    )
    if not n:
        patched, n = re.subn(
            r"(['\"])GODOT[^'\"]*(['\"])",
            r"\1%s\2" % nxt,
            text,
            count=1,
        )
        if n:
            text = patched
    else:
        text = patched
    if "/data/" not in text:
        text = DATA_FETCH + text
    return text


def stamp(out_dir: pathlib.Path, root: pathlib.Path, notes_only: bool = False) -> str:
    out_dir.mkdir(parents=True, exist_ok=True)
    html_path = out_dir / "index.html"
    if notes_only:
        if html_path.is_file():
            html_path.write_text(
                _ensure_notes_script(html_path.read_text(encoding="utf-8")),
                encoding="utf-8",
                newline="\n",
            )
        print("web_postexport notes-only %s" % out_dir)
        return "notes"
    build_id = _binary_id(out_dir)
    (out_dir / "build_id.txt").write_text(build_id + "\n", encoding="utf-8")
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
    print("web_postexport %s -> %s" % (out_dir, build_id))
    return build_id


def main() -> int:
    args = [a for a in sys.argv[1:] if a]
    notes_only = False
    if "--notes-only" in args:
        notes_only = True
        args.remove("--notes-only")
    if not args:
        print("usage: web_postexport.py [--notes-only] <export-dir>", file=sys.stderr)
        return 2
    out_dir = pathlib.Path(args[0]).resolve()
    root = pathlib.Path(__file__).resolve().parents[1]
    stamp(out_dir, root, notes_only=notes_only)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
