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
    aim = read("scripts/combat/aim_line.gd")
    assert "[origin, dir, length, width, opacity, on, App.weapon]" in aim
    assert "_last_aim" not in read("scripts/world/player/player_combat.gd")
    gem = read("scripts/ui/hud/hud_act.gd")
    assert 'set_meta("pulse_tween", null)' in gem and 'Color(col.r, col.g, col.b, alpha)' in gem
    torch = read("scripts/graphics/torch_bill.gd")
    assert torch.index("add_child(_flame)") < torch.index("_set_facing_once()", torch.index("add_child(_flame)"))
    assert 'func _process(' not in torch and 'func _aim_flame' not in torch
    class GDMap(dict):
        def erase(self, key): self.pop(key, None)
        def is_empty(self): return not self
    meta = {}
    app = NS(get_meta=lambda k, default: meta.get(k, GDMap()), set_meta=lambda k, v: meta.__setitem__(k, v))
    note = function(read("scripts/app/app_run.gd"), "note_enemy_fighting", {"App": app}, "enemy, on")
    a, b = NS(get_instance_id=lambda: 1), NS(get_instance_id=lambda: 2)
    note(a, True); note(a, True); note(b, True)
    assert len(meta["enemy_fighters"]) == 2 and meta["enemy_fighting"]
    note(a, False); assert meta["enemy_fighting"]
    note(b, False); note(b, False); assert not meta["enemy_fighting"]
    enemy = read("scripts/combat/enemy.gd")
    assert enemy.count("_report_fighting()") >= 4 and "func _exit_tree()" in enemy
    assert 'not dead and state >= ST_CHASE and state <= ST_REC' in enemy
    assert 'note_fighting' not in read("scripts/combat/enemy/enemy_ai.gd")
    progress = read("scripts/data/progress.gd")
    assert 'ceili(food_t) != ceili(v)' in progress and 'camp_hint_changed.emit()' in progress
    assert 'camp_hint_changed.connect(_refresh_hint)' in camp and 'NOTIFICATION_TRANSLATION_CHANGED' in camp
    assert 'if interact_prompt == v:' in read("scripts/app.gd")
    volume = read("scripts/world/crystal/net.gd")
    assert 'area.collision_mask = 4' in volume and 'weakref(body)' in volume
    assert 'bool(crystal.get("crystal_on")) and not _is_pursuing(body)' in volume
    assert 'area.body_entered.disconnect' not in volume
    pursuing = function(volume, "_is_pursuing", {"int": int}, "e")
    assert [pursuing(NS(get=lambda key, n=n: n)) for n in range(8)] == [False, True, True, False, True, True, True, False]
    plate = read("scripts/world/interact.gd")
    assert 'kind != "plate" or' in plate and 'area.collision_mask = 2' in plate
    assert plate.count('_ensure_plate_area()') >= 3
    assert 'host.reveal_cells' in dungeon and 'static var _visited' not in dungeon
    assert 'Vector3i(t.x, t.y, int(App.bal.fog_radius))' in dungeon
    crystal = read("scripts/world/floor_crystal.gd")
    assert 'prompt_locked = not clear' in crystal
    interact = crystal.split('func interact(', 1)[1]
    assert interact.index('if not CrystalNet.volume_clear(self):') < interact.index('if not crystal_on:')
    panel = read("scripts/ui/progress_ui.gd")
    assert panel.count('set_process(open or forge_t > 0.0)') == 3
    audio = read("scripts/audio/sfx.gd")
    assert 'loop_player.finished.connect(_restart_adrenaline)' in audio and 'func _process' not in audio
    assert 'App.adrenaline and adrenaline_loop' in audio
    assert 'App.Boot.release_focus_once(App)' in read("scripts/ui/ui_session.gd")
    assert 'if not OS.has_feature("debug"):' in read("scripts/app/dbg.gd")
    assert 'if floor_on:' in dungeon and 'floor_on = false' in dungeon
    smoke = read("scripts/debug/smoke/smoke_process.gd")
    assert 'p.set("aim_line", saved_line)' in smoke
    assert 'adrenaline_audio_gated=true' not in smoke and 'torch_facing_once=' not in smoke
    assert 'not a physics-overlap proof' in smoke and 'assert(not ui.is_processing())' in smoke
    minimap = read("scripts/world/dungeon/minimap.gd")
    needs_map = function(minimap, "needs_redraw", {"Vector2i": lambda x, y: (x, y), "int": int}, "host")
    m = NS(fog_dirty=False, player=NS(global_position=NS(x=2.0, z=3.0)), get_meta=lambda k, d: (2, 3))
    assert not needs_map(m)
    m.player.global_position.x = 4.0; assert needs_map(m)
    m.fog_dirty = True; assert needs_map(m)
    m.fog_dirty = False; m.player = None; assert not needs_map(m)
    assert minimap.index('CrystalNet.paint(host)') < minimap.index('host.map_tex.update(host.map_img)')
    assert 'viewport.size_changed.connect(host._redraw_map)' in minimap
    assert 'host.fog_dirty or (host.map_layer' not in dungeon
    assert 'host.fog_dirty = true' in read("scripts/world/dungeon/dungeon_cells.gd")
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
