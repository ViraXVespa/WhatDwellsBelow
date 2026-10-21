#!/usr/bin/env python3
"""Dump a recent Grok session into one .txt and put it on the clipboard.

    python tools/session_dump.py

Opens C:\\Users\\Vira\\.grok\\sessions, lists the 10 newest sessions (skipping
wdb-iso worktrees), lets you pick 0-9, then writes a single .txt of the
diagnostic files plus every terminal/*.log and copies it to the clipboard.
"""
from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path
from urllib.parse import unquote
import re

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log

SESSIONS = Path(os.environ.get("WDB_GROK_SESSIONS") or r"C:\Users\Vira\.grok\sessions")
SKIP_PARTS = ("wdb-iso-", "wdb-iso")
USEFUL = (
    "chat_history.jsonl",
    "events.jsonl",
    "updates.jsonl",
    "usage.json",
    "prompt_context.json",
    "system_prompt.txt",
    "summary.json",
)

def label(cwd_encoded: str) -> str:
    """Text after the last %5C (the worktree or folder name)."""
    parts = cwd_encoded.split("%5C")
    return unquote(parts[-1]) if parts else cwd_encoded

def recent(n: int = 10) -> list[tuple[float, Path, str]]:
    """(mtime, session_dir, label) for the n newest sessions, skipping iso worktrees."""
    out: list[tuple[float, Path, str]] = []
    if not SESSIONS.is_dir():
        return out
    for cwd_dir in SESSIONS.iterdir():
        if not cwd_dir.is_dir():
            continue
        decoded = unquote(cwd_dir.name)
        if any(part in decoded for part in SKIP_PARTS):
            continue
        for sess in cwd_dir.iterdir():
            if not sess.is_dir():
                continue
            try:
                mtime = sess.stat().st_mtime
            except OSError:
                continue
            out.append((mtime, sess, label(cwd_dir.name)))
    out.sort(key=lambda x: x[0], reverse=True)
    return out[:n]

ENC = re.compile(r'"encrypted_content":\s*"[^"]*"')
IMG_READ = re.compile(r'^\{"type":"tool_result".*?"content":"Read image file:')
IMG_DATA = re.compile(r'"type":"image","data":')

def scrub(text: str) -> str:
    """Drop encrypted blobs and image-read tool results."""
    text = ENC.sub('"encrypted_content":""', text)
    lines = [ln for ln in text.splitlines() if not IMG_READ.match(ln) and not IMG_DATA.search(ln)]
    return "\n".join(lines)

def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""

def terminal_blob(sess: Path) -> str:
    term = sess / "terminal"
    if not term.is_dir():
        return "(no terminal/)"
    parts: list[str] = []
    for log in sorted(term.glob("*.log")):
        body = read_text(log).strip()
        if not body:
            continue
        parts.append(f"===== {log.name} =====\n{body}")
    return scrub("\n\n".join(parts)) if parts else "(no .log files)"

def _file_to_clipboard(path: Path) -> None:
    """Put path on the Windows clipboard as a file drop (CF_HDROP) so Ctrl+V pastes the file."""
    import ctypes
    from ctypes import wintypes

    CF_HDROP = 15
    GMEM_MOVEABLE = 0x0002
    DROPFILES_SIZE = 20

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    user32 = ctypes.WinDLL("user32", use_last_error=True)

    kernel32.GlobalAlloc.argtypes = [wintypes.UINT, ctypes.c_size_t]
    kernel32.GlobalAlloc.restype = ctypes.c_void_p
    kernel32.GlobalLock.argtypes = [ctypes.c_void_p]
    kernel32.GlobalLock.restype = ctypes.c_void_p
    kernel32.GlobalUnlock.argtypes = [ctypes.c_void_p]
    kernel32.GlobalFree.argtypes = [ctypes.c_void_p]
    user32.OpenClipboard.argtypes = [ctypes.c_void_p]
    user32.OpenClipboard.restype = wintypes.BOOL
    user32.EmptyClipboard.restype = wintypes.BOOL
    user32.SetClipboardData.argtypes = [wintypes.UINT, ctypes.c_void_p]
    user32.SetClipboardData.restype = ctypes.c_void_p
    user32.CloseClipboard.restype = wintypes.BOOL

    wide = str(path.resolve()) + "\0\0"
    data = wide.encode("utf-16le")
    size = DROPFILES_SIZE + len(data)

    hglobal = kernel32.GlobalAlloc(GMEM_MOVEABLE, size)
    if not hglobal:
        return
    ptr = kernel32.GlobalLock(hglobal)
    if not ptr:
        kernel32.GlobalFree(hglobal)
        return
    ctypes.memset(ptr, 0, DROPFILES_SIZE)
    ctypes.cast(ptr, ctypes.POINTER(ctypes.c_uint32))[0] = DROPFILES_SIZE
    ctypes.cast(ptr + 16, ctypes.POINTER(ctypes.c_int))[0] = 1
    ctypes.memmove(ptr + DROPFILES_SIZE, data, len(data))
    kernel32.GlobalUnlock(hglobal)

    if user32.OpenClipboard(None):
        user32.EmptyClipboard()
        user32.SetClipboardData(CF_HDROP, hglobal)
        user32.CloseClipboard()
    else:
        kernel32.GlobalFree(hglobal)

def dump(sess: Path, label_text: str) -> Path:
    chunks: list[str] = [f"session={sess}", f"label={label_text}", ""]
    for name in USEFUL:
        p = sess / name
        chunks.append(f"===== {name} =====")
        chunks.append(scrub(read_text(p)) if p.is_file() else "(missing)")
        chunks.append("")
    chunks.append("===== terminal =====")
    chunks.append(terminal_blob(sess))
    text = "\n".join(chunks)
    out = Path(tempfile.gettempdir()) / f"session-dump-{sess.name[:8]}.txt"
    out.write_text(text, encoding="utf-8")
    # clipboard
    try:
        _file_to_clipboard(out)
    except OSError:
        pass
    return out

def pick(rows: list[tuple[float, Path, str]]) -> int | None:
    print("Recent sessions (0-9 to select, q to quit):")
    for i, (mtime, sess, lab) in enumerate(rows):
        from datetime import datetime
        ts = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M")
        print(f"  {i}  {ts}  {lab}  {sess.name[:8]}")
    if os.name == "nt":
        import msvcrt
        ch = msvcrt.getwch()
    else:
        ch = sys.stdin.read(1)
    if ch in "0123456789" and int(ch) < len(rows):
        return int(ch)
    return None

def main(argv: list[str] | None = None) -> int:
    parser = agent_log.std_parser("Dump a recent Grok session to one .txt and the clipboard.")
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)
    root = agent_log.resolve_root(args)
    rows = recent()
    if not rows:
        print("no sessions found")
        return agent_log.emit_result("FAIL", None, cmd="dump", sessions=0)
    choice = pick(rows)
    if choice is None:
        print("cancelled")
        return agent_log.emit_result("PASS", None, cmd="dump", cancelled=1)
    _, sess, lab = rows[choice]
    out = dump(sess, lab)
    print(f"wrote {out}")
    print("clipboard: set")
    return agent_log.emit_result("PASS", None, cmd="dump", out=str(out), session=sess.name)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
