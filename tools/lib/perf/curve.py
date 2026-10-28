#!/usr/bin/env python3
"""Local playtest curve. Reads the JSONL spool and, after --sqlite, curve.sqlite.

Prints four slices plus the level-gap histogram. --sqlite imports the spool and
then deletes runs.jsonl and decisions.jsonl. weapon_band.json stays. A failed
import leaves the spool. --cleanup and a successful --sqlite drop decision rows
older than --keep-days and VACUUM. Run rows stay. Refuses to write inside the repo.
"""
from __future__ import annotations

import hashlib
import json
import os
import sqlite3
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import agent_log  # noqa: E402

COMBAT = frozenset({
    "dmg", "def", "hp", "crit_chance", "crit_dmg", "move_spd",
    "atk_spd", "atk_range", "hp_on_hit", "hp_on_kill",
})
SKILL = {"great_axe": "axe", "staff": "staff", "longbow": "bow"}
DAY = 86400.0


def default_dir() -> Path:
    name = "What Dwells Below"
    if sys.platform == "win32":
        base = os.environ.get("APPDATA") or str(Path.home() / "AppData" / "Roaming")
        return Path(base) / "Godot" / "app_userdata" / name / "playtest" / "db"
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "Godot" / "app_userdata" / name / "playtest" / "db"
    return Path.home() / ".local" / "share" / "godot" / "app_userdata" / name / "playtest" / "db"


def _inside_repo(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
    except ValueError:
        return False
    return True


def _read_jsonl(path: Path) -> list[dict]:
    if not path.is_file():
        return []
    rows: list[dict] = []
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        text = line.strip()
        if not text:
            continue
        item = json.loads(text)
        if isinstance(item, dict):
            rows.append(item)
    return rows


def _connect(folder: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(folder / "curve.sqlite")
    conn.execute(
        "CREATE TABLE IF NOT EXISTS runs (run_id TEXT PRIMARY KEY, body TEXT NOT NULL)"
    )
    conn.execute(
        "CREATE TABLE IF NOT EXISTS decisions ("
        "hash TEXT PRIMARY KEY, run_id TEXT, wall REAL NOT NULL, body TEXT NOT NULL)"
    )
    return conn


def _import_spool(folder: Path, keep_days: int) -> int:
    folder.mkdir(parents=True, exist_ok=True)
    runs = _read_jsonl(folder / "runs.jsonl")
    decisions = _read_jsonl(folder / "decisions.jsonl")
    conn = _connect(folder)
    try:
        conn.execute("BEGIN")
        for row in runs:
            run_id = str(row.get("run_id", ""))
            if run_id == "":
                continue
            conn.execute(
                "INSERT OR REPLACE INTO runs (run_id, body) VALUES (?, ?)",
                (run_id, json.dumps(row, sort_keys=True)),
            )
        for row in decisions:
            body = json.dumps(row, sort_keys=True)
            digest = hashlib.sha256(body.encode("utf-8")).hexdigest()
            conn.execute(
                "INSERT OR IGNORE INTO decisions (hash, run_id, wall, body) VALUES (?, ?, ?, ?)",
                (digest, str(row.get("run_id", "")), float(row.get("wall", 0)), body),
            )
        _drop_old(conn, keep_days)
        conn.commit()
    except (sqlite3.Error, TypeError, ValueError) as exc:
        conn.rollback()
        conn.close()
        print(f"error: {exc}", file=sys.stderr)
        return 1
    try:
        conn.execute("VACUUM")
    except sqlite3.Error as exc:
        conn.close()
        print(f"error: {exc}", file=sys.stderr)
        return 1
    conn.close()
    for leaf in ("runs.jsonl", "decisions.jsonl"):
        path = folder / leaf
        if path.is_file():
            path.unlink()
    return 0


def _drop_old(conn: sqlite3.Connection, keep_days: int) -> None:
    cutoff = time.time() - float(keep_days) * DAY
    conn.execute("DELETE FROM decisions WHERE wall < ?", (cutoff,))


def _cleanup(folder: Path, keep_days: int) -> int:
    db_path = folder / "curve.sqlite"
    if not db_path.is_file():
        return 0
    conn = _connect(folder)
    try:
        conn.execute("BEGIN")
        _drop_old(conn, keep_days)
        conn.commit()
        conn.execute("VACUUM")
    except sqlite3.Error as exc:
        conn.rollback()
        conn.close()
        print(f"error: {exc}", file=sys.stderr)
        return 1
    conn.close()
    return 0


def _load_runs(folder: Path) -> list[dict]:
    rows: dict[str, dict] = {}
    db_path = folder / "curve.sqlite"
    if db_path.is_file():
        conn = sqlite3.connect(db_path)
        try:
            for run_id, body in conn.execute("SELECT run_id, body FROM runs"):
                item = json.loads(body)
                if isinstance(item, dict):
                    rows[str(run_id)] = item
        finally:
            conn.close()
    for item in _read_jsonl(folder / "runs.jsonl"):
        run_id = str(item.get("run_id", ""))
        if run_id != "" and run_id not in rows:
            rows[run_id] = item
    return list(rows.values())


def _decision_count(folder: Path) -> int:
    total = 0
    seen: set[str] = set()
    db_path = folder / "curve.sqlite"
    if db_path.is_file():
        conn = sqlite3.connect(db_path)
        try:
            total = int(conn.execute("SELECT COUNT(*) FROM decisions").fetchone()[0])
            for (digest,) in conn.execute("SELECT hash FROM decisions"):
                seen.add(str(digest))
        finally:
            conn.close()
    for item in _read_jsonl(folder / "decisions.jsonl"):
        body = json.dumps(item, sort_keys=True)
        digest = hashlib.sha256(body.encode("utf-8")).hexdigest()
        if digest not in seen:
            total += 1
            seen.add(digest)
    return total


class _Agg:
    def __init__(self) -> None:
        self.runs = 0
        self.deaths = 0
        self.duration = 0.0
        self.dmg = 0.0

    def add(self, death: bool, duration: float, dmg: float) -> None:
        self.runs += 1
        if death:
            self.deaths += 1
        self.duration += duration
        self.dmg += dmg


def _is_death(row: dict) -> bool:
    return str(row.get("end_cond", "")) in ("death", "dispel")


def _floors(row: dict) -> list[dict]:
    raw = row.get("floors")
    if isinstance(raw, list) and raw:
        return [item for item in raw if isinstance(item, dict)]
    deaths = 1 if _is_death(row) else 0
    return [{
        "n": row.get("deepest", 1),
        "dt": row.get("duration", 0),
        "dmg_taken": row.get("dmg_taken", 0),
        "deaths": deaths,
    }]


def _weapon_ilvl(row: dict) -> int:
    gear = row.get("gear")
    if isinstance(gear, list):
        for piece in gear:
            if isinstance(piece, dict) and str(piece.get("slot", "")) == "weapon":
                return int(piece.get("ilvl", 0))
    return 0


def _fmt(agg: _Agg) -> str:
    rate = agg.deaths / float(agg.runs) if agg.runs else 0.0
    mean_t = agg.duration / float(agg.runs) if agg.runs else 0.0
    mean_d = agg.dmg / float(agg.runs) if agg.runs else 0.0
    return f"{agg.runs} {rate:.3f} {mean_t:.3f} {mean_d:.3f}"


def _lines(title: str, header: str, rows: list[tuple]) -> list[str]:
    out = [title, header]
    for key, agg in rows:
        cells = " ".join(str(part) for part in key)
        out.append(f"{cells} {_fmt(agg)}")
    return out


def _sorted_aggs(groups: dict) -> list[tuple]:
    return sorted(groups.items(), key=lambda item: item[0])


def render(runs: list[dict]) -> str:
    floor_cycle: dict[tuple, _Agg] = {}
    weapon_skill: dict[tuple, _Agg] = {}
    weapon_floor: dict[tuple, _Agg] = {}
    affix_band: dict[tuple, _Agg] = {}
    gaps: dict[str, int] = {}
    death_gaps: dict[str, int] = {}
    for row in runs:
        dead = _is_death(row)
        duration = float(row.get("duration", 0))
        dmg = float(row.get("dmg_taken", 0))
        cycle = int(row.get("cycle", 0))
        weapon = str(row.get("start_weapon", ""))
        ilvl = _weapon_ilvl(row)
        skill = SKILL.get(weapon, weapon if weapon else "none")
        for floor in _floors(row):
            n = int(floor.get("n", 0))
            floor_dead = int(floor.get("deaths", 0)) > 0
            floor_dt = float(floor.get("dt", 0))
            floor_dmg = float(floor.get("dmg_taken", 0))
            floor_cycle.setdefault((cycle, n), _Agg()).add(floor_dead, floor_dt, floor_dmg)
            weapon_floor.setdefault((weapon, n, ilvl), _Agg()).add(floor_dead, floor_dt, floor_dmg)
        weapon_skill.setdefault((skill, ilvl), _Agg()).add(dead, duration, dmg)
        gear = row.get("gear")
        if isinstance(gear, list):
            for piece in gear:
                if not isinstance(piece, dict):
                    continue
                piece_lv = int(piece.get("ilvl", 0))
                affixes = piece.get("affixes")
                if not isinstance(affixes, list):
                    continue
                for affix in affixes:
                    if not isinstance(affix, dict):
                        continue
                    affix_id = str(affix.get("id", ""))
                    if affix_id not in COMBAT:
                        continue
                    affix_band.setdefault((affix_id, piece_lv), _Agg()).add(dead, duration, dmg)
        raw_gaps = row.get("kill_delta")
        if isinstance(raw_gaps, dict):
            for key, count in raw_gaps.items():
                gaps[str(key)] = gaps.get(str(key), 0) + int(count)
        if "death_delta" in row and row.get("death_delta") is not None:
            key = str(int(row.get("death_delta")))
            death_gaps[key] = death_gaps.get(key, 0) + 1
    parts = [
        _lines("slice floor_cycle", "cycle floor runs death_rate mean_duration mean_dmg", _sorted_aggs(floor_cycle)),
        _lines("slice weapon_skill", "skill ilvl runs death_rate mean_duration mean_dmg", _sorted_aggs(weapon_skill)),
        _lines("slice weapon_floor", "weapon floor ilvl runs death_rate mean_duration mean_dmg", _sorted_aggs(weapon_floor)),
        _lines("slice combat_affix", "affix ilvl runs death_rate mean_duration mean_dmg", _sorted_aggs(affix_band)),
    ]
    gap_lines = ["level_gap", "gap kills"]
    for key in sorted(gaps, key=lambda item: int(item) if item.lstrip("-").isdigit() else 0):
        gap_lines.append(f"{key} {gaps[key]}")
    gap_lines.append("death_delta value runs")
    for key in sorted(death_gaps, key=lambda item: int(item) if item.lstrip("-").isdigit() else 0):
        gap_lines.append(f"{key} {death_gaps[key]}")
    parts.append(gap_lines)
    flat: list[str] = []
    for block in parts:
        flat.extend(block)
        flat.append("")
    return "\n".join(flat).rstrip() + "\n"


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser(
        "Local playtest curve from the debug-desktop spool (user://playtest/db).",
        json_out=False,
    )
    ap.add_argument("--dir", default="", help="Spool directory. Default: the AppData user://playtest/db folder.")
    ap.add_argument("--sqlite", action="store_true", help="Import the JSONL spool into curve.sqlite, then delete runs.jsonl and decisions.jsonl.")
    ap.add_argument("--cleanup", action="store_true", help="Drop decision rows older than --keep-days and VACUUM. A successful --sqlite does this too.")
    ap.add_argument("--keep-days", type=int, default=30, help="How many days of decision rows to keep (default 30).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    folder = Path(args.dir) if args.dir else default_dir()
    if (args.sqlite or args.cleanup) and _inside_repo(folder, root):
        print("error: refuse to write inside the repo", file=sys.stderr)
        return 2
    if args.sqlite:
        code = _import_spool(folder, args.keep_days)
        if code != 0:
            return code
    elif args.cleanup:
        code = _cleanup(folder, args.keep_days)
        if code != 0:
            return code
    runs = _load_runs(folder)
    decisions = _decision_count(folder)
    body = render(runs) + f"db runs={len(runs)} decisions={decisions}\n"
    return agent_log.finish("playtest-curve", root, body, "PASS", args=args, runs=len(runs), decisions=decisions)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
