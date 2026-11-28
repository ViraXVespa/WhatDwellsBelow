# Player avatar, movement, and facing

Status: current plan
Read when: movement, collision, character select, eight-dir body
Code: `scripts/world/player.gd` (facade) + `scripts/world/player/`, `scripts/world/facing.gd`, `scripts/world/bow_mode.gd` (code map row Player; gdhealth group `player`)

This file is the door. Open the Job-table sibling only when that row matches.

Other code calls the facade (`player.gd` methods) or the public files `facing.gd` and `bow_mode.gd`, never a `scripts/world/player/` helper. Dash i-frames and trail VFX: combat.

Movement MUST feel responsive and weighty on both gamepad and keyboard.

| Job | Open |
|-----|------|
| male or female pick, matching voiceover, silhouette bounds | `design/player-avatar.md` |
| Bow mode, LT steer, RT shoots | `design/player-bow.md` |
| 8-way facing, stride start and stop, lead foot, seppuku collapse, lazy loads | `design/player-anim.md` |
