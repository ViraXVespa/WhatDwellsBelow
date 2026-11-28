# Skills, XP, and combat level

Status: current plan
Read when: XP, forging, formula
Code: `scripts/data/progress_combat.gd` (facade) + `scripts/data/progress_combat/`, `scripts/data/progress_forge.gd` (facade) + `scripts/data/progress_forge/` (code map row Skills; gdhealth group `skills`). Callers read skills through `App.prog` (`scripts/data/progress.gd`) or the two facades. Live numbers: the tunables gate.

This file is the door. Open the Job-table sibling only when that row matches.

| Job | Open |
|-----|------|
| eleven mandatory ids, permanent fragment, hitpoints stacking | `design/skills-gain.md` |
| style averages, highest-style rounding, calibration example | `design/skills-cl.md` |
| survivability, smith craft beat, noticeable power | `design/skills-effects.md` |
