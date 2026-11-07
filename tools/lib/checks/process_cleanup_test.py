#!/usr/bin/env python3
"""Source-level process migration regression; does not run Godot or prove device/visual input."""
from pathlib import Path
from types import SimpleNamespace as NS
import sys
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/lib"))
import agent_log
from combat_recovery_test import function

def selftest(root):
    read = lambda p: (root / p).read_text()
    calls = []
    scene = NS(has_method=lambda n: n == "toggle_map", toggle_map=lambda: calls.append("map"))
    tree = NS(current_scene=scene)
    host = NS(_in_world=lambda: True, _menu_loading=False, ui_open=False,
              debug=None, recap=None, get_tree=lambda: tree,
              pause_menu=NS(toggle=lambda: calls.append("pause")))
    boot = read("scripts/app/app_boot.gd")
    dispatch = function(boot, "world_action", {}, "host, action")
    dispatch(host, "pause"); dispatch(host, "map_view")
    assert calls == ["pause", "map"]
    for field in ("_menu_loading", "ui_open"):
        setattr(host, field, True); dispatch(host, "pause"); setattr(host, field, False)
        assert calls == ["pause", "map"]
    for field in ("debug", "recap"):
        setattr(host, field, NS(get=lambda key: True)); dispatch(host, "pause"); setattr(host, field, None)
        assert calls == ["pause", "map"]
    host._in_world = lambda: False
    dispatch(host, "pause"); assert calls == ["pause", "map"]
    host._in_world = lambda: True
    tree.current_scene = NS(has_method=lambda n: False)
    dispatch(host, "map_view"); assert calls == ["pause", "map"]
    dispatch(host, "pause"); assert calls[-1] == "pause" and len(calls) == 3
    # Actual pause edge function: keyboard, pad/touch edge, web Escape and held-close suppression.
    state = NS(key=False, edge=False, web=False, open=False)
    env = {"App": NS(pause_menu=NS(get=lambda k: state.open)),
           "Disp": NS(consume_web_esc=lambda: state.web), "eat_pause": False,
           "Input": NS(is_action_pressed=lambda k: False, is_action_just_pressed=lambda k: state.key),
           "just": lambda k: state.edge}
    pause = function(read("scripts/input/pad.gd"), "pause_just", env, "")
    for kind in ("key", "edge", "web"):
        setattr(state, kind, True); assert pause()
        env["eat_pause"] = True; assert not pause(); env["eat_pause"] = False
        state.open = True; assert not pause(); state.open = False
        setattr(state, kind, False); assert not pause()
    pad = read("scripts/input/pad.gd")
    assert 'App.world_action.emit("pause")' in pad and 'App.world_action.emit("map_view")' in pad
    assert 'host.world_action.connect' in boot
    dungeon = read("scripts/world/dungeon/dungeon_boot.gd")
    assert 'App.pause_just()' not in dungeon and 'Input.is_action_just_pressed("map_view")' not in dungeon
    camp = read("scripts/world/camp.gd")
    assert 'func _on_pause' not in camp
    assert camp.index('Hud._hud(self)') < camp.index('_connect_hud()', camp.index('Hud._hud(self)'))
    touch = read("scripts/ui/touch_hud.gd")
    assert 'func _process' not in touch and '_refresh_queued' in touch
    for producer in ('size_changed', 'scene_changed', 'joy_connection_changed', 'input_changed', 'InputEventScreenDrag'):
        assert producer in touch, producer
    assert 'PROCESS_MODE_ALWAYS' in boot and 'PROCESS_MODE_ALWAYS' in read("scripts/ui/pause_menu/pause_menu_view.gd")
    assert 'event.is_action_pressed("pause")' in read("scripts/ui/menu_pad.gd")
    print("process migration: pause routing/edge/suppression and coalesced redraw source fixtures passed")
    return 0

if __name__ == "__main__":
    ap = agent_log.std_parser(__doc__)
    ap.add_argument("--selftest", action="store_true", help="Exercise source-level event migration fixtures without Godot.")
    args = ap.parse_args()
    if not args.selftest:
        ap.error("use --selftest")
    result = selftest(agent_log.resolve_root(args))
    raise SystemExit(agent_log.emit_result("PASS" if result == 0 else "FAIL", runtime="not-run"))
