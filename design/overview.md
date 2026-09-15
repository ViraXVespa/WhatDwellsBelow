# Overview, scope, and lore

Status: binding design  
Read when: scoping a feature, writing player-facing copy, deciding whether something is in the demo  
Code: `README.md`, `scripts/data/tunables.gd` (`ONE_LINER`), `scripts/app.gd`  
See also: `design/hub.md`

`See also:` is not a read list. Open hub only when the work is Placeholdia / Floor Crystal / enter-wake. Do not open constraints from this file; that file is already on the Shared boot when this topic is in play.

## 1. Overview and vision

**Game Title**
What Dwells Below

**One-line Public Description**
A gamepad-first dungeon crawler where you pilot disposable spirit avatars, mail loot home, and slowly remember the skills you earned in the dark.

**Core Fantasy**
You are a dungeon delver employed by a known and trusted guild. You repeatedly descend into a shifting underground complex from a temporary surface camp called Placeholdia, fight, gather, and attempt to extract resources and gear. Death loses almost everything you were carrying; successful extraction banks permanent progress. The surface is slightly absurd and hopeful; the depths are dangerous and increasingly hostile.

**Demo Goal**
A complete, production-ready vertical slice that can ship as a free demo. Every system included MUST be polished enough that the identical code can carry forward into the full game with only content and expansion added on top.

**Primary Loop**
1. Placeholdia hub
2. Loadout selection at the Floor Crystal (including character type, starting weapon, and tool type)
3. Confirm enter → consciousness-transfer VFX → dungeon at chosen floor
4. Explore, fight, gather, interact
5. Extract via Extraction Gate or die / voluntarily “Dispel”
6. Recap screen
7. Return to Placeholdia with wake-up sequence and permanent gains (or losses)

## 2. Scope, pillars, non-goals, and acceptance

Hard constraints, demo-complete bar, and the full in-scope contract: `design/constraints.md`. Topic doors for the systems that contract names: `design/README.md`.

**Explicit Non-Goals (MUST NOT appear)**
- Co-op / multiplayer / split-screen
- Any skill beyond the eleven listed in `design/skills.md`
- Rarity higher than blue
- Hub upgrades, currency sinks beyond vendor/anvil, or meta progression systems
- Stealth, mounts, fishing, or other side systems
- Story cutscenes or mandatory dialogue trees beyond short flavor lines

**Design Pillars**
1. Combat is readable, weighty, and juiced (telegraphs, hit-stop, knockback, crits, Adrenaline Rush, clear range and active indicators on every player attack).
2. Extraction is meaningful — the tension of what to keep vs. what to risk is the heart of every run.
3. Permanent progression is visible and satisfying after a single good run.
4. Floors feel expansive enough to support the target times and multiple points of interest.
5. Tone is light and slightly irreverent on the surface, serious in the depths, never grimdark.

**Acceptance Criteria**
- A fresh Grok Build instance can continue and complete the demo from this database + the live repository path.
- All numeric values are exposed in the debug menu and treated as tunable.
- The demo runs at a consistent 60 FPS (higher allowed) on target hardware.
- Every system that ships is considered production/Gold and will not be rewritten for the full game.
- Player-facing UI and HUD use dungeon theming. Default / unskinned engine controls MUST NOT appear on the playable path. The secret debug menu is exempt.

## 3. Core fantasy and lore (demo-visible only)

**Player Role**
The player character is a dungeon delver working for a known and trusted guild that operates out of the temporary surface settlement Placeholdia. The guild’s purpose is the recovery of resources, artifacts, and knowledge from the shifting underground complex known only as “Below.” Most delvers do not return.

**Surface vs. Depths Tone**
- Placeholdia is safe, temporary, slightly absurd, and mildly hopeful. Flavor text, the dumpster, the notice board, and the ghost shop reinforce a light, irreverent tone.
- The dungeon is dangerous, reactive, and oppressive. Lighting, enemy density, audio, and recap copy grow darker with depth.
- The contrast is intentional and MUST be preserved.

**Information the Player Receives**
No mandatory intro cutscene or long exposition is required. The player learns the fantasy through:
- Short environmental flavor text on signs and the notice board.
- Receptionist lines (kept minimal). Extraction Gates have no NPC dialogue.
- Recap screen titles, subtitles, and special case lines (including verge and empty-run variants).
- The mechanical consequences of death versus successful extraction.
- Consciousness-transfer VFX when leaving Placeholdia and a wake-up sequence when returning.

**Specific Locked Flavor**
- Empty floor-1 death/“Dispel” recap MUST include the line: “They lived just to die. What a waste.”
- Credit splash MUST show the word “Proudly” crossed out and the word “Shamelessly” written above it in graffiti style so the phrase reads as vandalized: “Shamelessly Vibecoded with Grok.”
- The dungeon music track is titled “Bitter”. Links and loop rule: `design/audio-visual.md`.
- Player-facing UI, pause menu, recap, and prompts MUST write the voluntary exit action as **“Dispel”** (quotation marks included) for the locked humorous tone. Internal code identifiers MAY omit the quotes.
