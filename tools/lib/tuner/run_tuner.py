#!/usr/bin/env python3
"""Train a linear playtester policy from decide rows, score journals, and recommend a balance config.

The default command does not launch Godot. --live is the switch that does.
--selftest uses temp files, a fake scorer, and no torch.
"""
from __future__ import annotations

import json
import math
import os
import random
import socket
import struct
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib
import agent_log  # noqa: E402

JOB = "local-ai-tuner"
ACTIONS = ["threat", "hunt", "gather", "clerk", "door", "wander"]
N_FEAT = 7
GOAL_MAP = {
    "fight": "threat",
    "threat": "threat",
    "hunt": "hunt",
    "gather": "gather",
    "gathering": "gather",
    "clerk": "clerk",
    "door": "door",
    "extract_stairs": "door",
    "wander": "wander",
}
CURRENT = {"enemy_hp_mult": 1.0, "axe_damage": 16.0, "staff_damage": 9.0}
OBJECTIVE = "mean of floor reached, plus 1 for extraction, minus 0.25 for a death or dispel"
LIVE_GRID = [
    {"enemy_hp_mult": 0.5, "axe_damage": 40.0, "staff_damage": 20.0},
    {"enemy_hp_mult": 2.0, "axe_damage": 8.0, "staff_damage": 40.0},
    {"enemy_hp_mult": 4.0, "axe_damage": 80.0, "staff_damage": 9.0},
]
FAKE_GRID = [
    {"enemy_hp_mult": 0.7, "axe_damage": 40.0, "staff_damage": 9.0},
    {"enemy_hp_mult": 1.0, "axe_damage": 16.0, "staff_damage": 9.0},
    {"enemy_hp_mult": 3.0, "axe_damage": 80.0, "staff_damage": 50.0},
]
MMAP_SIZE = 64 + 320 * 180 * 4
PIP = "pip install -r tools/requirements-tuner.txt"
OPTIONAL = (
    ("numpy", "numpy"),
    ("cv2", "cv2"),
    ("optuna", "optuna"),
    ("torch", "torch"),
    ("stable_baselines3", "stable_baselines3"),
    ("godot_rl", "godot_rl"),
)
CMDS = ("run", "doctor", "train", "eval", "cv", "speed", "tune", "loop", "export", "import")
EMPTY_GATHERS = 5


def userdata() -> Path:
    app = "What Dwells Below"
    if os.name == "nt":
        base = os.environ.get("APPDATA", "")
        return Path(base) / "Godot" / "app_userdata" / app
    return Path.home() / ".local" / "share" / "godot" / "app_userdata" / app


def db_dir(override: str) -> Path:
    if override:
        return Path(override)
    return userdata() / "playtest" / "db"


def runs_dir(db: Path) -> Path:
    if db.name == "db":
        return db.parent / "runs"
    return db.parent / "runs"


def tuner_dir(override: str) -> Path:
    if override:
        return Path(override)
    return userdata() / "playtest" / "tuner"


def policy_path() -> Path:
    return userdata() / "playtest" / "tuner" / "policy.json"


def load_module(name: str):
    import importlib
    return importlib.import_module(name)


def module_present(name: str) -> bool:
    try:
        load_module(name)
    except Exception:
        return False
    return True


def parse_seeds(text: str) -> list[int]:
    out: list[int] = []
    for part in str(text).split(","):
        part = part.strip()
        if not part:
            continue
        if not part.lstrip("-").isdigit():
            agent_log.fail(f"bad seed {part!r}")
        out.append(int(part))
    if not out:
        agent_log.fail("no seeds")
    return out


def load_rows(db: Path) -> list[dict]:
    rows: list[dict] = []
    dec = db / "decisions.jsonl"
    if dec.is_file():
        for line in dec.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(obj, dict) and obj.get("ev") == "decide":
                rows.append(obj)
    folder = runs_dir(db)
    if folder.is_dir():
        for path in sorted(folder.glob("*.json")):
            try:
                doc = json.loads(path.read_text(encoding="utf-8", errors="replace"))
            except (OSError, json.JSONDecodeError):
                continue
            events = doc.get("events") if isinstance(doc, dict) else None
            if not isinstance(events, list):
                continue
            for ev in events:
                if isinstance(ev, dict) and ev.get("ev") == "decide":
                    rows.append(ev)
    return dedupe(rows)


def row_key(row: dict) -> tuple:
    return (
        str(row.get("run_id", "")),
        str(row.get("t", "")),
        str(row.get("goal", "")),
        str(row.get("why", "")),
        str(row.get("source", "")),
    )


def dedupe(rows: list[dict]) -> list[dict]:
    seen = set()
    out = []
    for row in rows:
        key = row_key(row)
        if key in seen:
            continue
        seen.add(key)
        out.append(row)
    return out


def new_count(before: list[dict], fresh: list[dict]) -> int:
    old = {row_key(row) for row in before}
    return len({row_key(row) for row in fresh} - old)


def label_of(row: dict) -> str:
    return GOAL_MAP.get(str(row.get("goal", "")), "")


def is_human(row: dict) -> bool:
    if row.get("source") == "human" or row.get("run_id") == "human":
        return True
    return str(row.get("save_kind", "")) == "human"


def dist_feat(value) -> float:
    try:
        d = float(value)
    except (TypeError, ValueError):
        return 1.0
    if d < 0.0 or d >= 99.0:
        return 1.0
    return max(0.0, min(1.0, d / 30.0))


def feats(row: dict) -> list[float]:
    hp = row.get("hp", None)
    try:
        hp_f = 1.0 if hp is None else max(0.0, min(1.0, float(hp)))
    except (TypeError, ValueError):
        hp_f = 1.0
    ex = 1.0 if row.get("ex") else 0.0
    try:
        fl = max(0.0, min(1.0, float(row.get("fl", 1) or 1) / 10.0))
    except (TypeError, ValueError):
        fl = 0.1
    try:
        cargo = max(0.0, min(1.0, float(row.get("cargo", 0) or 0) / 20.0))
    except (TypeError, ValueError):
        cargo = 0.0
    return [dist_feat(row.get("threat_d", 99)), dist_feat(row.get("gather_d", 99)), dist_feat(row.get("clerk_d", 99)), hp_f, ex, fl, cargo]


def scripted(row: dict) -> str:
    try:
        threat = float(row.get("threat_d", 99) or 99)
    except (TypeError, ValueError):
        threat = 99.0
    try:
        gather = float(row.get("gather_d", 99) or 99)
    except (TypeError, ValueError):
        gather = 99.0
    try:
        clerk = float(row.get("clerk_d", 99) or 99)
    except (TypeError, ValueError):
        clerk = 99.0
    try:
        cargo = float(row.get("cargo", 0) or 0)
    except (TypeError, ValueError):
        cargo = 0.0
    if threat < 90.0:
        return "threat"
    if gather <= 9.0:
        return "gather"
    if clerk <= 12.0 and cargo > 0.0:
        return "clerk"
    if row.get("ex"):
        return "door"
    return "wander"


def labeled(rows: list[dict]) -> list[dict]:
    return [row for row in rows if label_of(row)]


def choose_set(rows: list[dict]) -> tuple[list[dict], str, str]:
    labs = labeled(rows)
    humans = [row for row in labs if is_human(row)]
    bots = [row for row in labs if not is_human(row)]
    if len(humans) >= 8:
        return humans, "human", ""
    if bots:
        note = ""
        if humans:
            note = f"Human decide rows: {len(humans)}. Training uses the bot rows until there are at least 8 human rows."
        return bots, "bot", note
    if humans:
        return humans, "human", "Human decide rows are under 8. Train and eval use those rows. This is not the held-out success comparison."
    return [], "bot", ""


def split_rows(rows: list[dict], seed: int = 1) -> tuple[list[dict], list[dict], str]:
    by: dict[str, list[dict]] = {}
    for row in rows:
        by.setdefault(label_of(row), []).append(row)
    usable = [row for group in by.values() for row in group]
    if len(usable) < 5:
        return usable, usable, "Fewer than 5 labeled rows. Train and eval use the same rows."
    rng = random.Random(seed)
    train: list[dict] = []
    test: list[dict] = []
    overlap = False
    for lab in sorted(by):
        group = list(by[lab])
        rng.shuffle(group)
        if len(group) < 5:
            train.extend(group)
            test.extend(group)
            overlap = True
            continue
        cut = max(1, int(len(group) * 0.2))
        test.extend(group[-cut:])
        train.extend(group[:-cut])
    note = "A label had fewer than 5 rows, so that label is in both splits." if overlap else ""
    return train, test, note


def _dot(row: list[float], feat: list[float], bias: float) -> float:
    return bias + sum(w * x for w, x in zip(row, feat))


def predict_idx(weights, bias, feat: list[float]) -> int:
    best_i = 0
    best_s = -1.0e30
    for i, row in enumerate(weights):
        score = _dot(row, feat, bias[i])
        if score > best_s:
            best_s = score
            best_i = i
    return best_i


def prototype(pairs: list[tuple[list[float], int]]):
    means = [[0.0] * N_FEAT for _ in ACTIONS]
    counts = [0] * len(ACTIONS)
    for feat, y in pairs:
        counts[y] += 1
        for i, x in enumerate(feat):
            means[y][i] += x
    weights = [[0.0] * N_FEAT for _ in ACTIONS]
    bias = [0.0] * len(ACTIONS)
    for y, count in enumerate(counts):
        if count <= 0:
            continue
        for i in range(N_FEAT):
            means[y][i] /= float(count)
            weights[y][i] = means[y][i]
        bias[y] = -0.5 * sum(v * v for v in means[y])
    return weights, bias


def softmax_train(pairs, weights, bias, epochs: int = 80, lr: float = 0.35):
    w = [list(row) for row in weights]
    b = list(bias)
    if not pairs:
        return w, b
    for _epoch in range(epochs):
        for feat, y in pairs:
            scores = [_dot(w[a], feat, b[a]) for a in range(len(ACTIONS))]
            peak = max(scores)
            exps = [math.exp(s - peak) for s in scores]
            total = sum(exps) or 1.0
            for a in range(len(ACTIONS)):
                grad = exps[a] / total - (1.0 if a == y else 0.0)
                for i in range(N_FEAT):
                    w[a][i] -= lr * grad * feat[i]
                b[a] -= lr * grad
    return w, b


def pair_hits(pairs, weights, bias) -> int:
    hit = 0
    for feat, y in pairs:
        if predict_idx(weights, bias, feat) == y:
            hit += 1
    return hit


def fit(rows: list[dict]):
    pairs = []
    for row in rows:
        lab = label_of(row)
        if lab not in ACTIONS:
            continue
        pairs.append((feats(row), ACTIONS.index(lab)))
    base_w, base_b = prototype(pairs)
    soft_w, soft_b = softmax_train(pairs, base_w, base_b)
    if pair_hits(pairs, soft_w, soft_b) >= pair_hits(pairs, base_w, base_b):
        return soft_w, soft_b
    return base_w, base_b


def as_model(weights, bias, trained_on: str, n: int) -> dict:
    return {
        "ver": 1,
        "actions": list(ACTIONS),
        "weights": [[round(float(v), 6) for v in row] for row in weights],
        "bias": [round(float(v), 6) for v in bias],
        "trained_on": trained_on,
        "n": int(n),
    }


def predict_action(model: dict, row: dict) -> str:
    idx = predict_idx(model["weights"], model["bias"], feats(row))
    actions = model.get("actions") or ACTIONS
    if idx < len(actions):
        return str(actions[idx])
    return ACTIONS[idx]


def rate(rows: list[dict], pick) -> tuple[int, int]:
    hit = 0
    for row in rows:
        if pick(row) == label_of(row):
            hit += 1
    return hit, len(rows)


def counts(rows: list[dict]) -> str:
    tally = {a: 0 for a in ACTIONS}
    for row in rows:
        lab = label_of(row)
        if lab in tally:
            tally[lab] += 1
    return " ".join(f"{k}={v}" for k, v in tally.items())


def cell_of(row: dict):
    cell = row.get("cell")
    if isinstance(cell, (list, tuple)) and len(cell) >= 2:
        try:
            return int(cell[0]), int(cell[1])
        except (TypeError, ValueError):
            return None
    return None


def cv_score(rows: list[dict]) -> tuple[float, list[dict]]:
    flags = []
    prev = None
    ordered = sorted(rows, key=lambda row: float(row.get("t", 0) or 0))
    for row in ordered:
        if prev is not None:
            try:
                dt = float(row.get("t", 0) or 0) - float(prev.get("t", 0) or 0)
            except (TypeError, ValueError):
                dt = 0.0
            try:
                threat = float(row.get("threat_d", 99) or 99)
                prev_threat = float(prev.get("threat_d", 99) or 99)
            except (TypeError, ValueError):
                threat, prev_threat = 99.0, 99.0
            goal = label_of(row) or str(row.get("goal", ""))
            if 0.0 <= dt < 0.05 and goal == "threat" and threat <= 4.0 and prev_threat >= 20.0:
                flags.append({"flag": "fast_reaction", "t": row.get("t")})
            a = cell_of(prev)
            b = cell_of(row)
            if a and b and 0.0 <= dt < 0.3:
                man = abs(a[0] - b[0]) + abs(a[1] - b[1])
                if man > 8:
                    flags.append({"flag": "cell_jump", "t": row.get("t"), "cells": man})
        prev = row
    score = 1.0 - min(1.0, len(flags) / 10.0)
    return score, flags


def frame_flags(prev: list[float] | None, cur: list[float]) -> list[str]:
    if not cur:
        return []
    flags = []
    mean = sum(cur) / float(len(cur))
    if mean < 1.0:
        flags.append("black")
    if prev and len(prev) == len(cur):
        diff = sum(abs(a - b) for a, b in zip(prev, cur)) / float(len(cur))
        if diff > 80.0:
            flags.append("jump")
    return flags


def score_frames(folder: str) -> str:
    if not folder:
        return ""
    path = Path(folder)
    if not path.is_dir():
        return "frame folder missing"
    try:
        cv2 = load_module("cv2")
    except Exception:
        return "frame scoring needs opencv"
    files = sorted([p for p in path.iterdir() if p.suffix.lower() in (".png", ".jpg", ".jpeg")])
    prev = None
    n_flag = 0
    for file in files:
        img = cv2.imread(str(file), cv2.IMREAD_GRAYSCALE)
        if img is None:
            continue
        flat = [float(v) for v in img.reshape(-1)]
        n_flag += len(frame_flags(prev, flat))
        prev = flat
    return f"frames={len(files)} frame_flags={n_flag}"


def mmap_roundtrip(tag: str = "wdb-tuner-selftest") -> str:
    import mmap
    if MMAP_SIZE != 230464:
        return "size"
    width, height, stride = 4, 2, 16
    pix = bytes([7, 8, 9, 10]) * (width * height)
    try:
        writer = mmap.mmap(-1, MMAP_SIZE, tagname=tag)
    except TypeError:
        return "tagname"
    except OSError:
        return "open"
    try:
        writer[:] = b"\x00" * MMAP_SIZE
        writer.seek(0)
        writer.write(b"WDBF")
        writer.write(struct.pack("<IIIIII", 1, width, height, stride, 0, 64))
        writer.seek(64)
        writer.write(pix)
        writer.seek(20)
        writer.write(struct.pack("<I", 3))
        reader = mmap.mmap(-1, MMAP_SIZE, tagname=tag)
        try:
            reader.seek(0)
            magic = reader.read(4)
            ver, w, h, st, seq, off = struct.unpack("<IIIIII", reader.read(24))
            reader.seek(64)
            got = reader.read(len(pix))
            if magic != b"WDBF" or ver != 1 or w != width or h != height or st != stride or seq != 3 or off != 64 or got != pix:
                return "mismatch"
        finally:
            reader.close()
    finally:
        writer.close()
    return ""


class MsgSock:
    def __init__(self, conn, timeout: float = 3.0):
        self.conn = conn
        self.buf = b""
        self.conn.settimeout(timeout)

    def send(self, obj: dict) -> None:
        raw = json.dumps(obj, separators=(",", ":")).encode("ascii") + b"\x00"
        self.conn.sendall(raw)

    def recv(self):
        while b"\x00" not in self.buf:
            chunk = self.conn.recv(65536)
            if not chunk:
                return None
            self.buf += chunk
        raw, _, self.buf = self.buf.partition(b"\x00")
        if not raw:
            return None
        return json.loads(raw.decode("utf-8"))


def protocol_errors() -> list[str]:
    err: list[str] = []
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.bind(("127.0.0.1", 0))
    srv.listen(1)
    srv.settimeout(3)
    port = srv.getsockname()[1]

    def server() -> None:
        try:
            conn, _addr = srv.accept()
            io = MsgSock(conn, 3.0)
            io.send({"type": "handshake", "major_version": 0, "minor_version": 1})
            env = io.recv()
            if not isinstance(env, dict) or env.get("type") != "env_info":
                err.append("env_info")
            io.send({"type": "reset"})
            reset = io.recv()
            if not isinstance(reset, dict) or reset.get("type") != "reset":
                err.append("reset")
            io.send({"type": "action", "action": [{"goal": 1}]})
            step = io.recv()
            if not isinstance(step, dict) or step.get("type") != "step":
                err.append("step")
            io.send({"type": "close"})
            conn.close()
        except Exception as exc:
            err.append("server " + type(exc).__name__)
        finally:
            try:
                srv.close()
            except OSError:
                pass

    thread = threading.Thread(target=server)
    thread.start()
    try:
        cli = socket.create_connection(("127.0.0.1", port), timeout=3)
        io = MsgSock(cli, 3.0)
        hello = io.recv()
        if not isinstance(hello, dict) or hello.get("type") != "handshake":
            err.append("handshake")
        io.send({
            "type": "env_info",
            "observation_space": {"agent_0": {"obs": {"size": [7], "space": "box"}}},
            "action_space": {"agent_0": {"goal": {"size": 6, "action_type": "discrete"}}},
            "n_agents": 1,
            "agent_policy_names": ["agent_0"],
        })
        reset = io.recv()
        if not isinstance(reset, dict) or reset.get("type") != "reset":
            err.append("client-reset")
        io.send({"type": "reset", "obs": [{"obs": [0, 0, 0, 1, 0, 0.1, 0]}]})
        action = io.recv()
        if not isinstance(action, dict) or action.get("type") != "action":
            err.append("action")
        io.send({"type": "step", "obs": [{"obs": [0, 0, 0, 1, 0, 0.1, 0]}], "reward": [0.0], "done": [False]})
        close = io.recv()
        if not isinstance(close, dict) or close.get("type") != "close":
            err.append("close")
        cli.close()
    except Exception as exc:
        err.append("client " + type(exc).__name__)
    thread.join(timeout=4)
    if thread.is_alive():
        err.append("join")
    return err


def mean(xs: list[float]) -> float:
    return sum(xs) / float(len(xs)) if xs else 0.0


def spread(xs: list[float]) -> float:
    if not xs:
        return 0.0
    return max(xs) - min(xs)


def fake_score(cfg: dict, seed: int) -> float:
    return 4.0 - abs(float(cfg["enemy_hp_mult"]) - 0.7) - abs(float(cfg["axe_damage"]) - 40.0) / 40.0 + (seed % 3) * 0.001


def _optuna_search(score_fn, trials: int, seeds: list[int], enqueue: dict | None):
    optuna = load_module("optuna")
    optuna.logging.set_verbosity(optuna.logging.WARNING)
    study = optuna.create_study(direction="maximize", sampler=optuna.samplers.TPESampler(seed=1))
    if enqueue:
        study.enqueue_trial(dict(enqueue))

    def obj(trial):
        cfg = {
            "enemy_hp_mult": trial.suggest_float("enemy_hp_mult", 0.05, 6.0),
            "axe_damage": trial.suggest_float("axe_damage", 0.5, 120.0),
            "staff_damage": trial.suggest_float("staff_damage", 0.5, 100.0),
        }
        return mean([float(score_fn(cfg, s)) for s in seeds])

    study.optimize(obj, n_trials=max(1, trials))
    best = {
        "enemy_hp_mult": float(study.best_params["enemy_hp_mult"]),
        "axe_damage": float(study.best_params["axe_damage"]),
        "staff_damage": float(study.best_params["staff_damage"]),
    }
    return best, "optuna", ""


def _grid_search(score_fn, seeds: list[int], points: list[dict]):
    best = None
    best_mean = -1.0e30
    for cfg in points:
        scores = [float(score_fn(cfg, s)) for s in seeds]
        m = mean(scores)
        if m > best_mean:
            best_mean = m
            best = dict(cfg)
    return best, "grid", "Search was a grid because optuna was not installed."


def search(score_fn, trials: int, seeds: list[int], points: list[dict], enqueue: dict | None) -> dict:
    cur_scores = [float(score_fn(CURRENT, s)) for s in seeds]
    note = ""
    how = "grid"
    best = None
    if module_present("optuna"):
        try:
            best, how, note = _optuna_search(score_fn, trials, seeds, enqueue)
        except Exception as exc:
            best, how, note = _grid_search(score_fn, seeds, points)
            note = "Search was a grid because optuna failed (" + type(exc).__name__ + ")."
    else:
        best, how, note = _grid_search(score_fn, seeds, points)
    rec_scores = [float(score_fn(best, s)) for s in seeds]
    return {
        "ver": 1,
        "objective": OBJECTIVE,
        "search": how,
        "note": note,
        "current": dict(CURRENT),
        "current_mean": round(mean(cur_scores), 6),
        "current_spread": round(spread(cur_scores), 6),
        "recommended": best,
        "recommended_mean": round(mean(rec_scores), 6),
        "recommended_spread": round(spread(rec_scores), 6),
        "beats_current": mean(rec_scores) > mean(cur_scores),
        "seeds": list(seeds),
    }


def write_recommend(folder: Path, payload: dict, write: bool) -> None:
    if not write:
        return
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "recommended.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    rec = payload.get("recommended") or {}
    lines = [f"{key} = {rec[key]}" for key in ("enemy_hp_mult", "axe_damage", "staff_damage") if key in rec]
    (folder / "recommended-tunables.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_policy(path: Path, model: dict, write: bool) -> None:
    if not write:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(model, indent=2) + "\n", encoding="utf-8")


def write_report(path: Path, text: str, write: bool) -> None:
    if not write:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.rstrip() + "\n", encoding="utf-8")


def train_report(rows: list[dict], write: bool, dest: Path) -> tuple[list[str], dict | None, str]:
    lines = []
    use, kind, note = choose_set(rows)
    humans = [row for row in labeled(rows) if is_human(row)]
    lines.append(f"decide_rows={len(rows)} labeled={len(labeled(rows))} human={len(humans)} trained_on={kind}")
    if note:
        lines.append(note)
    if not use:
        lines.append("No labeled decide rows. No policy file written.")
        lines.append("Record human rows with --wdb-pt-human-log while you play. The report does not invent a human match rate.")
        return lines, None, "INFO"
    train, test, split_note = split_rows(use, 1)
    if split_note:
        lines.append(split_note)
    weights, bias = fit(train)
    model = as_model(weights, bias, "human" if kind == "human" else "bot", len(train))
    pol_hit, pol_n = rate(test, lambda row: predict_action(model, row))
    scr_hit, scr_n = rate(test, scripted)
    lines.append("labels " + counts(use))
    lines.append(f"held_out policy {pol_hit}/{pol_n} scripted {scr_hit}/{scr_n}")
    if kind == "bot":
        lines.append("This is imitation of the scripted journal, not a match rate against a person.")
        lines.append("The human comparison needs at least 8 decide rows recorded with --wdb-pt-human-log.")
    else:
        lines.append("Held-out rows are human decide rows. Both rates are counts from those rows.")
    lines.append("The scripted rate is a distance ladder, not a replay of every playtest branch.")
    lines.append("A policy file changes every playtest job that thinks. Reflexes stay scripted.")
    lines.append("A goal with no target falls through. A wander-heavy file skips the campaign stair path.")
    lines.append("Pass --wdb-pt-nopolicy, or delete the policy file, to restore the ladder.")
    write_policy(dest, model, write)
    if write:
        lines.append("policy written")
    return lines, model, "PASS"


def cv_lines(rows: list[dict], frames: str) -> list[str]:
    score, flags = cv_score(rows)
    fast = sum(1 for f in flags if f.get("flag") == "fast_reaction")
    jump = sum(1 for f in flags if f.get("flag") == "cell_jump")
    lines = [f"cv_score={score:.3f} fast_reaction={fast} cell_jump={jump} flags={len(flags)}"]
    frame_line = score_frames(frames)
    if frame_line:
        lines.append(frame_line)
    return lines


def parse_pt(text: str) -> dict:
    out = {}
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("PT:"):
            continue
        body = line[3:].strip()
        if "=" not in body:
            continue
        key, val = body.split("=", 1)
        out[key.strip()] = val.strip()
    return out


def objective_from_pt(parsed: dict):
    if "deepest" not in parsed and "end_cond" not in parsed:
        return None
    try:
        floor = float(parsed.get("deepest", "1"))
    except ValueError:
        floor = 1.0
    cond = parsed.get("end_cond", "")
    score = floor
    if cond == "extraction":
        score += 1.0
    if cond in ("death", "dispel"):
        score -= 0.25
    return score


def godot_missing() -> str:
    try:
        load_module("godot_lib").godot_exe()
    except FileNotFoundError as exc:
        return str(exc).split(":", 1)[-1].strip() or "Godot missing"
    except Exception as exc:
        return type(exc).__name__
    return ""


def launch_smoke(root: Path, extra: list[str], sec: float, log_dir: Path, timeout: int | None = None) -> tuple[str, dict]:
    godot_lib = load_module("godot_lib")
    log_dir.mkdir(parents=True, exist_ok=True)
    err_log = log_dir / "godot-err.txt"
    out_log = log_dir / "godot-out.txt"
    limit = max(90, int(sec) * 4 + 150) if timeout is None else max(30, int(timeout))
    t0 = time.perf_counter()
    res = godot_lib.run_godot(
        root,
        root,
        ["--headless", "--", *extra],
        out_log=out_log,
        err_log=err_log,
        timeout=limit,
    )
    wall = time.perf_counter() - t0
    text = ""
    if err_log.is_file():
        text = err_log.read_text(encoding="utf-8", errors="replace")
    res = dict(res)
    res["wall_s"] = wall
    return text, res


def speed_lines(root: Path, sec: float, seed: int, work: Path) -> tuple[list[str], str]:
    missing = godot_missing()
    if missing:
        return [missing], "FAIL"
    text, res = launch_smoke(root, [
        "--wdb-playtest-live-smoke",
        f"--wdb-pt-sec={sec}",
        f"--wdb-seed={seed}",
        "--wdb-pt-weapon=great_axe",
        "--wdb-pt-nopolicy",
    ], sec, work)
    parsed = parse_pt(text)
    try:
        sim = float(parsed.get("duration", ""))
    except ValueError:
        sim = None
    wall = float(res.get("wall_s") or 0.0)
    lines = [f"godot={res.get('status')} wall_s={wall:.2f}"]
    if sim is None or wall <= 0.0:
        lines.append("No PT duration. Speed was not measured.")
        return lines, "FAIL"
    lines.append(f"sim_s={sim:.2f} sim_per_wall={sim / wall:.3f}")
    lines.append("The rate includes boot. The run passed --wdb-pt-nopolicy.")
    return lines, "PASS"


def live_score(root: Path, cfg: dict, seed: int, sec: float, work: Path):
    trial = work / f"trial-{seed}.json"
    trial.write_text(json.dumps(cfg), encoding="utf-8")
    text, res = launch_smoke(root, [
        "--wdb-playtest-live-smoke",
        f"--wdb-pt-sec={sec}",
        f"--wdb-seed={seed}",
        "--wdb-pt-weapon=great_axe",
        "--wdb-pt-nopolicy",
        f"--wdb-pt-trial={trial.resolve()}",
    ], sec, work / f"s{seed}")
    return objective_from_pt(parse_pt(text)), str(res.get("status"))


def tune_live(root: Path, trials: int, seeds: list[int], sec: float, work: Path, write: bool, dest: Path) -> tuple[list[str], str]:
    missing = godot_missing()
    if missing:
        return [missing], "FAIL"

    def score_fn(cfg, seed):
        value, _status = live_score(root, cfg, seed, sec, work)
        if value is None:
            return -1.0e6
        return value

    payload = search(score_fn, trials, seeds, LIVE_GRID, None)
    lines = recommend_lines(payload)
    write_recommend(dest, payload, write)
    if payload["current_mean"] <= -1.0e5:
        lines.append("Headless runs did not report a floor.")
        return lines, "FAIL"
    return lines, "PASS" if payload["beats_current"] else "INFO"


def recommend_lines(payload: dict) -> list[str]:
    lines = [
        "objective: " + OBJECTIVE,
        f"search={payload.get('search')}",
    ]
    if payload.get("note"):
        lines.append(str(payload["note"]))
    lines.append(
        f"current_mean={payload['current_mean']} current_spread={payload['current_spread']} "
        f"recommended_mean={payload['recommended_mean']} recommended_spread={payload['recommended_spread']} "
        f"beats_current={str(payload['beats_current']).lower()}"
    )
    rec = payload.get("recommended") or {}
    lines.append(
        "recommended enemy_hp_mult={enemy_hp_mult} axe_damage={axe_damage} staff_damage={staff_damage}".format(**rec)
    )
    lines.append("The recommend file is not applied to the live defaults, the tunables docs, or the save slot.")
    return lines


class LinearPolicy:
    def __init__(self, seed: int = 1):
        self.rng = random.Random(seed)
        self.w = [[0.0] * N_FEAT for _ in ACTIONS]
        self.b = [0.0] * len(ACTIONS)
        self.eps = 0.2
        self.lr = 0.05
        self.n = 0

    def act(self, feat: list[float]) -> int:
        if self.rng.random() < self.eps:
            return self.rng.randrange(len(ACTIONS))
        return predict_idx(self.w, self.b, feat)

    def learn(self, feat: list[float], act: int, reward: float) -> None:
        for i, x in enumerate(feat):
            self.w[act][i] += self.lr * reward * x
        self.b[act] += self.lr * reward
        self.n += 1

    def model(self) -> dict:
        return as_model(self.w, self.b, "bot", self.n)


def obs_of(msg) -> list[float]:
    if not isinstance(msg, dict):
        return [0.0] * N_FEAT
    obs = msg.get("obs")
    if isinstance(obs, list) and obs:
        one = obs[0]
        if isinstance(one, dict):
            one = one.get("obs", [])
        if isinstance(one, list):
            out = []
            for i in range(N_FEAT):
                try:
                    out.append(float(one[i]) if i < len(one) else 0.0)
                except (TypeError, ValueError):
                    out.append(0.0)
            return out
    return [0.0] * N_FEAT


def rl_episode(conn, policy: LinearPolicy, steps_cap: int) -> dict:
    io = MsgSock(conn, 30.0)
    io.send({"type": "handshake", "major_version": 0, "minor_version": 1})
    env = io.recv()
    if not isinstance(env, dict) or env.get("type") != "env_info":
        return {"steps": 0, "error": "no env_info"}
    io.send({"type": "reset"})
    reset = io.recv()
    feat = obs_of(reset)
    steps = 0
    while steps < steps_cap:
        act = policy.act(feat)
        io.send({"type": "action", "action": [{"goal": act}]})
        step = io.recv()
        if not isinstance(step, dict) or step.get("type") != "step":
            break
        reward_row = step.get("reward") or [0.0]
        done_row = step.get("done") or [False]
        try:
            reward = float(reward_row[0])
        except (TypeError, ValueError, IndexError):
            reward = 0.0
        policy.learn(feat, act, reward)
        feat = obs_of(step)
        steps += 1
        if done_row and bool(done_row[0]):
            break
    try:
        io.send({"type": "close"})
    except OSError:
        pass
    return {"steps": steps, "error": ""}


def live_rl(root: Path, port: int, sec: float, seed: int, work: Path, write: bool, dest: Path) -> tuple[list[str], str]:
    missing = godot_missing()
    if missing:
        return [missing], "FAIL"
    holder: dict = {}
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        srv.bind(("127.0.0.1", port))
    except OSError as exc:
        return [type(exc).__name__ + " on port " + str(port)], "FAIL"
    srv.listen(1)
    srv.settimeout(max(30.0, sec + 90.0))

    def accept_and_play() -> None:
        try:
            conn, _addr = srv.accept()
            policy = LinearPolicy(seed)
            holder["result"] = rl_episode(conn, policy, 400)
            holder["policy"] = policy
            conn.close()
        except Exception as exc:
            holder["error"] = type(exc).__name__
        finally:
            try:
                srv.close()
            except OSError:
                pass

    thread = threading.Thread(target=accept_and_play)
    thread.start()
    _text, res = launch_smoke(root, [
        "--wdb-playtest-live-smoke",
        "--wdb-pt-rl",
        f"--wdb-pt-rl-port={port}",
        f"--wdb-pt-sec={sec}",
        f"--wdb-seed={seed}",
        "--wdb-pt-weapon=great_axe",
    ], sec, work)
    thread.join(timeout=20)
    lines = [f"godot={res.get('status')}"]
    if holder.get("error"):
        lines.append("bridge " + str(holder["error"]))
        return lines, "FAIL"
    result = holder.get("result") or {"steps": 0, "error": "no client"}
    if result.get("error"):
        lines.append(str(result["error"]))
        return lines, "FAIL"
    steps = int(result.get("steps") or 0)
    lines.append(f"rl_steps={steps}")
    policy = holder.get("policy")
    if policy is None or steps <= 0:
        lines.append("The bridge recorded no steps. No policy file written.")
        return lines, "INFO"
    model = policy.model()
    write_policy(dest, model, write)
    lines.append("policy written from the live bridge (trained_on=bot)")
    return lines, "PASS"


def _num_row(row, n: int) -> bool:
    if not isinstance(row, list) or len(row) != n:
        return False
    return all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in row)


def policy_ok(model) -> bool:
    if not isinstance(model, dict) or int(model.get("ver", 0)) != 1:
        return False
    if list(model.get("actions") or []) != list(ACTIONS):
        return False
    weights = model.get("weights")
    if not isinstance(weights, list) or len(weights) != len(ACTIONS):
        return False
    if not _num_row(model.get("bias"), len(ACTIONS)):
        return False
    return all(_num_row(row, N_FEAT) for row in weights)


def policy_from_text(text: str):
    try:
        obj = json.loads(text)
    except json.JSONDecodeError:
        return None
    if not isinstance(obj, dict):
        return None
    inner = obj.get("policy") if obj.get("kind") == "wdb-playtest-policy" else obj
    if not policy_ok(inner):
        return None
    return inner


def bundle_text(policy: dict) -> str:
    return json.dumps({"kind": "wdb-playtest-policy", "ver": 1, "policy": policy}, indent=2) + "\n"


def held(model, rows: list[dict]) -> tuple[int, int]:
    if not policy_ok(model):
        return 0, 0
    use, _kind, _note = choose_set(rows)
    if not use:
        return 0, 0
    _train, test, _split_note = split_rows(use, 1)
    if not test:
        return 0, 0
    return rate(test, lambda row: predict_action(model, row))


def accept_model(new_hit: int, new_n: int, old_hit: int, old_n: int) -> bool:
    if new_n <= 0:
        return False
    if old_n <= 0:
        return True
    return new_hit / float(new_n) >= old_hit / float(old_n)


def read_policy(path: Path):
    if not path.is_file():
        return None
    try:
        model = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not policy_ok(model):
        return None
    return model


def consider(rows: list[dict], dest: Path, write: bool) -> list[str]:
    lines, model, _status = train_report(rows, False, dest)
    if model is None:
        return lines
    new_hit, new_n = held(model, rows)
    current = read_policy(dest)
    old_hit, old_n = held(current, rows) if current else (0, 0)
    lines.append(f"candidate {new_hit}/{new_n} current {old_hit}/{old_n}")
    if accept_model(new_hit, new_n, old_hit, old_n):
        write_policy(dest, model, write)
        lines.append("policy written" if write else "dry-run: policy not written")
    else:
        lines.append("kept the current policy")
    return lines


def append_log(path: Path, text: str, write: bool) -> None:
    if not write:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(text.rstrip() + "\n")


def loop_flags(rows: int) -> list[str]:
    flags = [
        "--wdb-pt-campaign",
        "--wdb-pt-fast",
        "--wdb-pt-scale=6",
        "--wdb-pt-until-death",
    ]
    if rows > 0:
        flags.append(f"--wdb-pt-gather={int(rows)}")
    return flags


def do_loop(args, root: Path) -> int:
    import tempfile
    if args.rows < 0:
        agent_log.fail("--rows must be 0 or more")
    if args.wait < 30:
        agent_log.fail("--wait must be at least 30 seconds")
    missing = godot_missing()
    if missing:
        return finish(args, root, [missing], "FAIL", cmd="loop")
    db = db_dir(args.dir)
    dest_dir = tuner_dir(args.out)
    policy = dest_dir / "policy.json"
    log_path = dest_dir / "loop-log.txt"
    write = not args.dry_run
    lines: list[str] = []

    def note(msg: str) -> None:
        print(msg, flush=True)
        lines.append(msg)
        append_log(log_path, msg, write)

    note("loop campaign until death, then train. Ctrl+C stops.")
    note(f"policy {policy}")
    cap = "none" if args.rows == 0 else str(int(args.rows))
    note(f"until_death row_cap {cap} wait_s {args.wait}")
    note("The campaign slot stays as it is. Acting scale is 6 while the fast flag is set.")
    empty = 0
    cycle = 0
    try:
        while True:
            cycle += 1
            before_rows = load_rows(db)
            work = Path(tempfile.mkdtemp(prefix="wdb-tuner-loop-"))
            try:
                text, res = launch_smoke(
                    root, loop_flags(int(args.rows)), float(args.wait), work, timeout=int(args.wait)
                )
            except Exception as exc:
                if type(exc).__name__ in ("GodotBusy", "FileNotFoundError"):
                    note(str(exc).split("\n", 1)[0])
                    return finish(args, root, lines, "FAIL", cmd="loop")
                raise
            status = str(res.get("status", ""))
            fresh = load_rows(db)
            added = new_count(before_rows, fresh)
            stop = parse_pt(text).get("campaign_stop", "")
            tail = f" stop={stop}" if stop else ""
            note(f"cycle={cycle} godot={status} added={added} labeled={len(labeled(fresh))}{tail}")
            if status.startswith("COMPILE"):
                note("Godot reported a compile error. The loop stopped.")
                return finish(args, root, lines, "FAIL", cmd="loop")
            if added <= 0:
                empty += 1
                note("No new decide rows.")
                if empty >= EMPTY_GATHERS:
                    note(f"Stopped after {EMPTY_GATHERS} gathers with no new decide rows.")
                    return finish(args, root, lines, "FAIL", cmd="loop")
                continue
            empty = 0
            for part in consider(fresh, policy, write):
                note(part)
    except KeyboardInterrupt:
        note("Stopped.")
        note(f"policy {policy}")
        return finish(args, root, lines, "INFO", cmd="loop")


def do_export(args, root: Path) -> int:
    if not args.file:
        agent_log.fail("--file is required")
    src = tuner_dir(args.out) / "policy.json"
    model = read_policy(src)
    if model is None:
        return finish(args, root, ["No policy file to export."], "INFO", cmd="export")
    path = Path(args.file)
    if not args.dry_run:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(bundle_text(model), encoding="utf-8")
    return finish(args, root, [f"exported {path}"], "PASS", cmd="export")


def do_import(args, root: Path) -> int:
    if not args.file:
        agent_log.fail("--file is required")
    path = Path(args.file)
    if not path.is_file():
        return finish(args, root, [f"No bundle at {path}"], "FAIL", cmd="import")
    model = policy_from_text(path.read_text(encoding="utf-8", errors="replace"))
    if model is None:
        return finish(args, root, ["Bundle is not a ver 1 goal policy."], "FAIL", cmd="import")
    dest = tuner_dir(args.out) / "policy.json"
    write_policy(dest, model, not args.dry_run)
    lines = [f"imported {dest}"]
    if args.dry_run:
        lines.append("dry-run: policy not written")
    else:
        lines.append("The next playtest that thinks reads this file.")
    return finish(args, root, lines, "PASS", cmd="import")


def transfer_selftest() -> list[str]:
    import tempfile
    bad = []
    if accept_model(3, 8, 4, 8):
        bad.append("accepted a worse rate")
    if not accept_model(4, 8, 4, 8):
        bad.append("rejected a tie")
    if not accept_model(1, 2, 0, 0):
        bad.append("rejected a first policy")
    if accept_model(0, 0, 1, 2):
        bad.append("accepted an empty score")
    rows = synth_rows()
    blank = as_model([[0.0] * N_FEAT for _ in ACTIONS], [5.0, 0.0, 0.0, 0.0, 0.0, 0.0], "bot", 1)
    if not policy_ok(blank):
        bad.append("blank policy shape")
    if policy_from_text("{") is not None:
        bad.append("parsed broken json")
    if policy_from_text(json.dumps({"ver": 1})) is not None:
        bad.append("parsed a short policy")
    if policy_from_text(bundle_text(blank)) != blank:
        bad.append("bundle roundtrip")
    if policy_from_text(json.dumps(blank)) != blank:
        bad.append("raw policy roundtrip")
    with tempfile.TemporaryDirectory(prefix="wdb-tuner-xfer-") as tmp:
        dest = Path(tmp) / "policy.json"
        write_policy(dest, blank, True)
        snap = dest.read_text(encoding="utf-8")
        consider([], dest, True)
        if dest.read_text(encoding="utf-8") != snap:
            bad.append("empty spool wrote a policy")
        consider(rows, dest, True)
        got = read_policy(dest)
        if not policy_ok(got):
            bad.append("replaced policy shape")
        new_hit, new_n = held(got, rows)
        old_hit, old_n = held(blank, rows)
        if new_n == 0 or new_hit < old_hit:
            bad.append(f"replace rate {new_hit}/{new_n} vs {old_hit}/{old_n}")
        write_policy(dest, got, True)
        frozen = dest.read_text(encoding="utf-8")
        consider(rows, dest, False)
        if dest.read_text(encoding="utf-8") != frozen:
            bad.append("dry-run wrote")
    plain = loop_flags(0)
    if "--wdb-pt-until-death" not in plain or any(item.startswith("--wdb-pt-gather=") for item in plain):
        bad.append("loop flags row cap")
    if "--wdb-pt-gather=200" not in loop_flags(200):
        bad.append("loop flags keep cap")
    old_row = {"ev": "decide", "run_id": "a", "t": 1, "goal": "hunt", "why": "near"}
    new_row = {"ev": "decide", "run_id": "b", "t": 1, "goal": "door", "why": "stairs"}
    if new_count([old_row], [new_row]) != 1:
        bad.append("new decide hidden by a shorter spool")
    if new_count([old_row], []) != 0:
        bad.append("pruned spool counted as new")
    if new_count([old_row], [old_row]) != 0:
        bad.append("same spool counted as new")
    return bad


def finish(args, root: Path, lines: list[str], status: str, **kv) -> int:
    body = "\n".join(lines)
    echo_rows = lines[:12]
    echo = "\n".join(echo_rows)
    if len(lines) > 12:
        echo += f"\n... {len(lines) - 12} more lines in the summary"
    return agent_log.finish(JOB, root, body, status, args=args, echo=echo, **kv)


def do_doctor(args, root: Path) -> int:
    present = []
    missing = []
    for label, mod in OPTIONAL:
        if module_present(mod):
            present.append(label)
        else:
            missing.append(label)
    lines = ["present " + (" ".join(present) if present else "none")]
    lines.append("missing " + (" ".join(missing) if missing else "none"))
    lines.append(PIP)
    status = "PASS" if not missing else "INFO"
    return finish(args, root, lines, status, cmd="doctor", missing=len(missing))


def do_offline(args, root: Path, rows: list[dict], write_policy_file: bool) -> tuple[list[str], str]:
    dest = tuner_dir(args.out) / "policy.json"
    lines, _model, status = train_report(rows, write_policy_file and not args.dry_run, dest)
    lines.extend(cv_lines(rows, args.frames))
    return lines, status


def synth_rows() -> list[dict]:
    rows = []
    for i in range(20):
        rows.append({
            "ev": "decide", "t": float(i), "goal": "wander", "threat_d": 4, "gather_d": 20,
            "clerk_d": 99, "source": "human", "fl": 1, "cargo": 0, "cell": [0, 0],
        })
        rows.append({
            "ev": "decide", "t": float(100 + i), "goal": "gather", "threat_d": 99, "gather_d": 3,
            "clerk_d": 99, "source": "human", "fl": 1, "cargo": 0, "cell": [1, 0],
        })
    return rows


def run_selftest(args, root: Path) -> int:
    import tempfile
    bad = []
    before = policy_path()
    before_m = before.stat().st_mtime_ns if before.is_file() else None
    rows = synth_rows()
    use, kind, _note = choose_set(rows)
    if kind != "human" or len(use) != 40:
        bad.append("split set")
    train, test, _split_note = split_rows(use, 1)
    weights, bias = fit(train)
    model = as_model(weights, bias, "human", len(train))
    pol_hit, pol_n = rate(test, lambda row: predict_action(model, row))
    scr_hit, scr_n = rate(test, scripted)
    if pol_n == 0 or scr_n == 0 or pol_hit / float(pol_n) <= scr_hit / float(scr_n):
        bad.append(f"rates policy {pol_hit}/{pol_n} scripted {scr_hit}/{scr_n}")
    events = [
        {"t": 0.0, "goal": "wander", "threat_d": 30, "cell": [0, 0]},
        {"t": 0.02, "goal": "threat", "threat_d": 4, "cell": [0, 0]},
        {"t": 0.10, "goal": "wander", "threat_d": 30, "cell": [0, 0]},
        {"t": 0.20, "goal": "wander", "threat_d": 30, "cell": [20, 0]},
    ]
    _score, flags = cv_score(events)
    names = {f.get("flag") for f in flags}
    if "fast_reaction" not in names or "cell_jump" not in names:
        bad.append("cv flags " + ",".join(sorted(str(n) for n in names)))
    if frame_flags([0.0, 0.0], [0.0, 0.0]) != ["black"]:
        bad.append("black frame")
    if "jump" not in frame_flags([0.0], [255.0]):
        bad.append("frame jump")
    bad.extend(transfer_selftest())
    mmap_err = mmap_roundtrip()
    if mmap_err:
        bad.append("mmap " + mmap_err)
    for item in protocol_errors():
        bad.append("protocol " + item)
    with tempfile.TemporaryDirectory(prefix="wdb-tuner-") as tmp:
        folder = Path(tmp)
        payload = search(fake_score, 3, [1, 2], FAKE_GRID, FAKE_GRID[0])
        write_recommend(folder, payload, True)
        got = json.loads((folder / "recommended.json").read_text(encoding="utf-8"))
        if not got.get("beats_current"):
            bad.append("recommend did not beat current")
        if got.get("recommended_mean", 0) <= got.get("current_mean", 0):
            bad.append("recommend mean")
        if not (folder / "recommended-tunables.txt").is_file():
            bad.append("tunables snippet")
        if set(got.get("recommended", {})) < {"enemy_hp_mult", "axe_damage", "staff_damage"}:
            bad.append("recommend keys")
    after_m = before.stat().st_mtime_ns if before.is_file() else None
    if before_m != after_m:
        bad.append("policy.json touched")
    status = "FAIL" if bad else "PASS"
    lines = bad if bad else [
        f"selftest policy {pol_hit}/{pol_n} scripted {scr_hit}/{scr_n}",
        "cv mmap protocol recommend",
    ]
    return finish(args, root, lines, status, cmd="selftest", problems=len(bad))


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser(
        "Local playtester trainer and recommend-only balance tuner. "
        "Default run does not launch Godot. --live does. --selftest needs no Godot and no torch.",
        writes=True,
    )
    ap.add_argument("--selftest", action="store_true", help="Offline checks. No Godot and no torch. Ignores cmd.")
    ap.add_argument("cmd", nargs="?", default="run", help="run (default), doctor, train, eval, cv, speed, tune, loop, export, or import.")
    ap.add_argument("--mode", default="bc", choices=["bc", "rl"], help="bc clones decisions. rl uses the live bridge when --live is set.")
    ap.add_argument("--live", action="store_true", help="Launch headless Godot for speed, tune, or the rl bridge.")
    ap.add_argument("--dir", default="", help="Decision spool directory. Default: the game user://playtest/db folder.")
    ap.add_argument("--out", default="", help="Tuner output directory. Default: user://playtest/tuner.")
    ap.add_argument("--trials", type=int, default=3, help="Search trials for tune.")
    ap.add_argument("--seeds", default="1,2", help="Comma-separated run seeds.")
    ap.add_argument("--sec", type=float, default=8.0, help="Acting seconds for one headless run.")
    ap.add_argument("--port", type=int, default=11008, help="TCP port for the rl bridge.")
    ap.add_argument("--frames", default="", help="Folder of frames for the pixel check. Empty skips it. Needs opencv.")
    ap.add_argument("--rows", type=int, default=0, help="Optional decide-row cap before each train. 0 waits until the delve ends in death. loop only.")
    ap.add_argument("--wait", type=int, default=14400, help="Seconds to wait for one campaign gather. loop only.")
    ap.add_argument("--file", default="", help="Policy bundle path for export and import.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if args.selftest:
        return run_selftest(args, root)
    cmd = args.cmd or "run"
    if cmd not in CMDS:
        agent_log.fail(f"unknown subcommand {cmd!r} (choose from: {', '.join(CMDS)})")
    if cmd == "doctor":
        return do_doctor(args, root)
    if cmd == "loop":
        return do_loop(args, root)
    if cmd == "export":
        return do_export(args, root)
    if cmd == "import":
        return do_import(args, root)
    write = not args.dry_run
    seeds = parse_seeds(args.seeds)
    lines: list[str] = []
    status = "PASS"
    if cmd in ("run", "train", "eval", "cv") and not (cmd == "run" and args.mode == "rl"):
        rows = load_rows(db_dir(args.dir))
        if cmd == "cv":
            lines.extend(cv_lines(rows, args.frames))
            if not rows:
                status = "INFO"
        elif cmd == "eval":
            path = tuner_dir(args.out) / "policy.json"
            if not path.is_file():
                lines.append("No policy file. Nothing to eval.")
                status = "INFO"
            else:
                try:
                    model = json.loads(path.read_text(encoding="utf-8"))
                except json.JSONDecodeError:
                    lines.append("Policy file is not JSON.")
                    status = "FAIL"
                    model = None
                if model:
                    use, kind, note = choose_set(rows)
                    if note:
                        lines.append(note)
                    _train, test, split_note = split_rows(use, 1) if use else ([], [], "")
                    if split_note:
                        lines.append(split_note)
                    if not test:
                        lines.append("No labeled decide rows.")
                        status = "INFO"
                    else:
                        pol_hit, pol_n = rate(test, lambda row: predict_action(model, row))
                        scr_hit, scr_n = rate(test, scripted)
                        lines.append(f"held_out policy {pol_hit}/{pol_n} scripted {scr_hit}/{scr_n} trained_on={kind}")
                        if kind != "human":
                            lines.append("This is imitation of the scripted journal, not a match rate against a person.")
        else:
            part, status = do_offline(args, root, rows, cmd in ("run", "train"))
            lines.extend(part)
    if cmd == "run" and args.mode == "rl" and not args.live:
        lines.append("The rl bridge starts with --live. This command did not launch Godot.")
        status = "INFO"
    if args.live and args.mode == "rl" and cmd == "run":
        import tempfile
        work = Path(tempfile.mkdtemp(prefix="wdb-tuner-rl-"))
        part, st = live_rl(root, args.port, args.sec, seeds[0], work, write, tuner_dir(args.out) / "policy.json")
        lines.extend(part)
        status = st
    if cmd == "speed" or (cmd == "run" and args.live and args.mode == "bc"):
        if not args.live:
            lines.append("Pass --live to launch Godot for the speed measurement.")
            status = "INFO"
        else:
            import tempfile
            part, st = speed_lines(root, args.sec, seeds[0], Path(tempfile.mkdtemp(prefix="wdb-tuner-speed-")))
            lines.extend(part)
            if st == "FAIL":
                status = "FAIL"
    if cmd == "tune" or (cmd == "run" and args.live and args.mode == "bc"):
        if not args.live:
            lines.append("Pass --live to launch Godot for the balance search.")
            if status != "FAIL":
                status = "INFO"
        else:
            import tempfile
            part, st = tune_live(
                root, args.trials, seeds, args.sec,
                Path(tempfile.mkdtemp(prefix="wdb-tuner-tune-")),
                write, tuner_dir(args.out),
            )
            lines.extend(part)
            if st == "FAIL":
                status = "FAIL"
            elif st == "INFO" and status != "FAIL":
                status = "INFO"
    if not lines:
        lines.append("Nothing to do.")
        status = "INFO"
    report = tuner_dir(args.out) / "report.txt"
    if cmd in ("run", "train", "eval", "cv", "speed", "tune"):
        write_report(report, "\n".join(lines), write)
    return finish(args, root, lines, status, cmd=cmd)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
