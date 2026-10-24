"""Entry-tool plumbing. Every top-level tools/*.py is a thin entry: a COMMANDS table of
(subcommand, "area/module", one line). This module puts tools/lib and each tools/lib/<area> on sys.path
(modules import each other by their unique stem), runs the chosen module as __main__, and maps a
module stem back to its entry command (`cmd`, `display`) for tools that call other tools.
"""
from __future__ import annotations

import ast
import importlib.util
import sys
from pathlib import Path

LIB = Path(__file__).resolve().parent
TOOLS = LIB.parent
DATA = TOOLS / "data"
AREAS = sorted(p for p in LIB.iterdir() if p.is_dir() and not p.name.startswith(("_", ".")) and not (p / "__init__.py").exists())
for _d in (LIB, *AREAS):
    if str(_d) not in sys.path:
        sys.path.insert(1, str(_d))

def entries(tools: Path = TOOLS) -> dict[str, list[tuple]]:
    """entry stem -> [(sub or None, "area/module", help)], read from each entry's COMMANDS / MODULE literal."""
    out: dict[str, list[tuple]] = {}
    for p in sorted(tools.glob("*.py")):
        for node in ast.parse(p.read_text(encoding="utf-8-sig")).body:
            if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name) and node.targets[0].id in ("COMMANDS", "MODULE"):
                val = ast.literal_eval(node.value)
                out[p.stem] = [tuple(r) for r in val] if node.targets[0].id == "COMMANDS" else [(None, val, "")]
    return out

def where(stem: str, tools: Path = TOOLS) -> tuple[str, str | None]:
    """Module stem -> (entry stem, subcommand or None)."""
    for e, rows in entries(tools).items():
        for sub, mod, _ in rows:
            if mod.rsplit("/", 1)[-1] == stem:
                return e, sub
    raise KeyError(f"no entry tool runs {stem}")

def cmd(stem: str, *args: str, tools: Path = TOOLS) -> list[str]:
    """argv that runs module `stem` through its entry tool: [python, tools/<entry>.py, <sub>, *args]."""
    e, sub = where(stem, tools)
    return [sys.executable, str(tools / f"{e}.py"), *([sub] if sub else []), *args]

def display(stem: str) -> str:
    """`shots.py capture` for run_shots (what docs and messages call it)."""
    e, sub = where(stem)
    return f"{e}.py" + (f" {sub}" if sub else "")

def _run(mod: str, prog: str, argv: list[str]) -> int:
    """Run tools/lib/<mod>.py as __main__ under its own module spec (so process pools can re-import it)."""
    path = LIB / f"{mod}.py"
    spec = importlib.util.spec_from_file_location(path.stem, path)
    module = importlib.util.module_from_spec(spec)
    module.__name__ = "__main__"
    sys.argv = [prog, *argv]
    sys.modules["__main__"] = module
    try:
        exec(compile(path.read_text(encoding="utf-8-sig"), str(path), "exec"), module.__dict__)
    except SystemExit as exc:
        code = exc.code
        if code is None or isinstance(code, int):
            return code or 0
        print(code, file=sys.stderr)
        return 1
    return 0

def dispatch(entry_file: str, doc: str, commands: list[tuple]) -> int:
    """`ENTRY` / `ENTRY --help` lists the subcommands; `ENTRY SUB ...` runs that module with the rest of argv."""
    name = Path(entry_file).name
    argv = sys.argv[1:]
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(f"usage: {name} SUBCOMMAND [args]   ({name} SUBCOMMAND --help for its flags)\n\n{doc.strip()}\n")
        width = max(len(s) for s, _, _ in commands)
        for sub, mod, text in commands:
            print(f"  {sub:<{width}}  {text}  [lib/{mod}.py]")
        return 0
    table = {s: m for s, m, _ in commands}
    if argv[0] not in table:
        print(f"error: unknown subcommand {argv[0]!r} (choose from: {', '.join(table)})", file=sys.stderr)
        return 2
    return _run(table[argv[0]], f"{name} {argv[0]}", argv[1:])

def forward(entry_file: str, mod: str) -> int:
    """Single-module entry: pass every argument through."""
    return _run(mod, Path(entry_file).name, sys.argv[1:])
