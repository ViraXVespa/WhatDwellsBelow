#!/usr/bin/env python3
"""Source-level combat regression (--selftest); not a Godot runtime or animation proof.

Execute the primitive control flow of the production functions with stubbed effects.
Only typed locals and GDScript boolean literals are translated. Engine integration
and rendered animation still need the normal game verification.
"""
from pathlib import Path
from types import SimpleNamespace as NS
import re
import argparse

ROOT = Path(__file__).resolve().parents[3]

def function(source, name, env):
    match = re.search(r"^static func " + name + r"\([^\n]*\n(.*?)(?=^static (?:func|var)|\Z)", source, re.M | re.S)
    assert match, name
    body = re.sub(r"\bvar (\w+)(?:: [\w]+)?(?::)? =", r"\1 =", match[1])
    for old, new in (("true", "True"), ("false", "False"), ("null", "None")):
        body = re.sub(r"\b" + old + r"\b", new, body)
    args = {"advance_attack": "p, delta", "cooldowns": "host, delta", "basic_duration": ""}.get(name, "p")
    exec(compile("def " + name + "(" + args + "):\n" + body.expandtabs(4), name, "exec"), env)
    return env[name]

def selftest(read=None):
    read = read or (lambda path: (ROOT / path).read_text())
    combat = read("scripts/world/player/player_combat.gd")
    act = read("scripts/world/player/player_act.gd")
    balance = read("scripts/data/balance/vars_combat.gd")
    values = {k: float(v) for k, v in re.findall(r"^var (\w+) := ([0-9.]+)$", balance, re.M)}
    held = {"ai": set(), "pad": set()}
    app = NS(ui_open=False, bal=NS(**values), weapon="great_axe", gear=lambda key: 0.0,
             pad_held=lambda key: key in held["pad"], tel=None,
             prog=NS(mana=100, spend_mana=lambda amount: True))
    env = {"App": app, "maxf": max, "float": float,
           "_setup": lambda: NS(ensure_combat_fx=lambda p: None)}
    funcs = {n: function(combat, n, env) for n in ("try_special", "try_basic", "advance_attack", "basic_duration")}
    cool = function(act, "cooldowns", env)
    scenarios = 0
    for weapon in ("great_axe", "staff", "longbow"):
        for speed in (0.0, 0.5):
            for input_kind in ("ai", "pad"):
                app.weapon = weapon
                app.gear = lambda key, speed=speed: speed
                dur = funcs["basic_duration"]()
                held["ai"].clear(); held["pad"].clear()
                p = NS(ATK_NONE=0, ATK_BASIC=1, ATK_WIND=2, ATK_ACT=3, ATK_REC=4,
                       atk_state=0, atk_t=0.0, special_cd=0.0, special_held=False,
                       dash_t=0.0, dash_cd=0.0, iframe=0.0, interact_lock=0.0,
                       telegraph=None, hit_done=False, _ai_held=lambda key: key in held["ai"],
                       _special_point=lambda: None, _draw_special_tele=lambda hit: None,
                       _draw_basic_tele=lambda hit: None, _apply_special=lambda: None,
                       _apply_basic=lambda: None, _basic_duration=lambda: dur, _hit_norm=lambda: 0.4)
                held[input_kind].add("special")
                funcs["try_special"](p); assert p.atk_state == p.ATK_WIND
                funcs["advance_attack"](p, values["special_windup"])
                assert p.atk_state == p.ATK_ACT
                funcs["advance_attack"](p, 0.16)
                assert p.atk_state == p.ATK_REC
                assert p.special_cd == values["special_recovery"]
                cool(p, dur - 0.00001); funcs["advance_attack"](p, dur - 0.00001)
                assert p.atk_state == p.ATK_REC
                cool(p, 0.00002); funcs["advance_attack"](p, 0.00002)
                assert p.atk_state == p.ATK_NONE and p.special_cd > 0
                # A fresh special press fails, while a held normal attack starts.
                held[input_kind].clear(); funcs["try_special"](p)
                held[input_kind].add("special"); funcs["try_special"](p)
                assert p.atk_state == p.ATK_NONE
                held[input_kind].add("attack"); funcs["try_basic"](p)
                assert p.atk_state == p.ATK_BASIC
                cool(p, dur - 0.00001); funcs["advance_attack"](p, dur - 0.00001)
                assert p.atk_state == p.ATK_BASIC
                cool(p, 0.00002); funcs["advance_attack"](p, 0.00002)
                assert p.atk_state == p.ATK_NONE
                # Holding a rejected special is not newly buffered when cooldown ends.
                remaining = p.special_cd
                cool(p, remaining - 0.00001); assert p.special_cd > 0
                cool(p, 0.00002); assert p.special_cd == 0
                funcs["try_special"](p); assert p.atk_state == p.ATK_NONE
                held[input_kind].remove("special"); funcs["try_special"](p)
                held[input_kind].add("special"); funcs["try_special"](p)
                assert p.atk_state == p.ATK_WIND
                scenarios += 1
    hud = read("scripts/ui/hud/hud_act.gd")
    assert 'player.get("special_cd")' in hud and "spec = minf(spec," in hud
    anim = read("scripts/world/player/anim_loco.gd")
    assert "host.atk_state == host.ATK_REC" in anim and "host.atk_state == host.ATK_NONE" in anim
    assert "var special_cd := 0.0" in read("scripts/world/player.gd")
    tick = read("scripts/world/player/player_tick.gd")
    assert tick.index("cooldowns(") < tick.index("try_special(") < tick.index("try_basic(")
    print(f"RESULT PASS combat recovery source-level scenarios={scenarios}; Godot/visual verification not run")
    return 0

if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--selftest", action="store_true", help="Run source-level regressions without Godot.")
    args = ap.parse_args()
    if not args.selftest:
        ap.error("use --selftest")
    raise SystemExit(selftest())
