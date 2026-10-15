# Hub bench — performance logging + automated walker

id: hub-bench
owner: build
status: open
done-when: HitchLog accepts a runtime multiplier via CLI, hub systems call HitchLog.mark with useful reasons, a --wdb-hub-bench CLI walker runs ~60 s of natural-play movement covering all walk facings/anims and the listed interactables, the resulting hitch JSONL (threshold lowered) is readable with diagnostic context, and the follow-up hub-perf-fix task has been created/updated with any concrete findings from the first run. Logging is working; diagnosis/fixes are the next task.
resume: python tools/open_slice.py debug --task hub-bench
area: debug
door: debug
job: playtest
units: 
done: 

## Intent
Give an agent the same kind of hitch/context data the dungeon already produces, plus a one-shot automated hub walker that can surface sub-60 FPS frames. At the end of this task, create/update the blocked hub-perf-fix task so the next session can start from real logs.

## Hitch threshold
CLI-only. Add a public setter (e.g. HitchLog.set_mult) that the bench calls at start so the threshold can drop from the default 4× (~66.7 ms) to 1× (~16.7 ms) or any other value. No debug-menu control in this task.

## Hub mark() calls
Hub systems should call HitchLog.mark(reason, origin) on the events that are expensive or variable in the camp, mirroring how dungeon code already annotates. Suggested starting points (trim or expand as the code reveals):
- Light-bake / RT publish or rebuild
- Layout realization, ensure_tree(), Generated bucket work
- Interactable open/close (Floor Crystal loadout, Anvil, Vendor, Guild/receptionist UI)
- Animation state changes that matter for cost (idle↔walk, facing flips)
- Any other heavy frame the implementer finds while reading the hub

## Extra context (optional but useful)
If easy to attach to the existing hitch row or a parallel hub-perf JSONL:
- Player world position / cell
- Current anim name + facing
- Active UI panel names
- Counts of active lights / meshes / generated nodes

## Bench walker
- New CLI arg (e.g. --wdb-hub-bench), parsed like the existing playtest args.
- Fully automated, ~60 s, no loop, clean exit.
- Simulates natural play (pathing, idle/walk transitions, aim/facing changes) while guaranteeing coverage of:
  - All 8 walk facings / walk cycles (and the idle↔walk transitions at some point)
  - Interactables: Floor Crystal, Anvil, Vendor Stall, Guild notice/receptionist, striking dummy
- Lives in the existing debug/playtest machinery so the live path is untouched.
- Leaves the hitch JSONL (threshold lowered for the run) ready for the next session.

## Handoff
When the logging + bench are working, create or update design/tasks/hub-perf-fix.md (owner: build, needs: hub-bench) with any concrete findings from the first bench run (worst frames, recurring why tags, locations, etc.) so the diagnosis session can start immediately.
