# Overview, scope, and lore

Status: binding design
Read when: scoping a feature, writing player-facing copy, deciding whether something is in the demo
Code: `README.md`, `scripts/data/tunables.gd` (`ONE_LINER`), `scripts/app.gd`
See also: `design/constraints.md`, `design/hub.md`

## 1. Overview and vision

**Game Title**
What Dwells Below

**One-line Public Description**
(Use the exact wording currently on the public GitHub Pages / title screen; treat it as locked unless later changed.)

Live locked line in `tunables.gd`:
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

**In-Scope for Demo (MUST be fully implemented and polished)**
- Solo play only
- Placeholdia hub with all listed interactables (including quest access via the guild, a Controls Billboard, buildings with actual depth, and the Floor Crystal as the sole loadout / enter-dungeon interactable)
- Procedural dungeon floors in a repeating 5-floor structure that continues indefinitely until death
- Floor Guardians (floors 1–4) and Gate Master (floor 5) with boss doors and locked stairs
- Complete combat system (Great Axe, Lightning Staff, Longbow, weapon-specific specials on LT, Dash, target-lock, critical hits, Adrenaline Rush) with clear range telegraphs and active-attack indicators on every attack
- Aim-line indicator (tunable, dungeon-only, System-tab toggle + opacity, persisted)
- Hit-based gathering system for both mining (pickaxe) and woodcutting (hatchet)
- Eleven skills (Great Axe, Staff, Longbow, Strength, Magic, Ranged, Defense, Hitpoints, Mining, Woodcutting, Smithing) with permanent XP fragments
- Inventory, equipment slots (including single Tool slot locked to one type per run), forged holds (max 3 per slot), extraction via Extraction Gates
- Artifact collections / sets (exactly eight sets, run-only, bonuses displayed under descriptions)
- Male and female player characters (selectable on first load, switchable later from pause menu) with full animation parity, each with its own complete voice-over set, and exactly 8 directional animations
- Ghost shop, shrine, campfire, breakables, puzzle elements, stairs, floor crystal
- Named monsters, enemy bases, and expanded enemy variety (≥12 normal types, ≥5 types per floor)
- Idle / pressure enemy spawns outside safe rooms
- Quest system (3 random choices, 1 active at a time)
- Distinct food (heal-over-time) and potion (instant heal) rules
- Consciousness-transfer VFX on dungeon enter and wake-up sequence on return to Placeholdia
- Full HUD, pause menu (with System tab containing aim-line controls), all interaction UIs, recap screen — all dungeon-themed; no default / unskinned player-facing UI
- Secret debug / balance menu (shoulder-button sequence) containing all tunable values, profile Save/Load, the Automated Playtest / AI Player system, and the Animation Browser
- Save / load with backup, Archives browser (pinned commits including Full 3D Pass), 60 FPS minimum
- Debug menu that exposes every balance and generation value
- Gamepad-first design for all controls, gameplay, and interfaces (every menu opens with valid initial focus)

**Explicit Non-Goals (MUST NOT appear)**
- Co-op / multiplayer / split-screen
- Any skill beyond the eleven listed
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
- The dungeon music track is titled “Bitter”. Authoritative links:
  - YouTube: https://youtu.be/b3Cq_-ymFVU?si=YHZRCFmxf88BXmHW
  - Spotify: https://open.spotify.com/track/5ronKOeupSInit9Y21z80f?si=WB-zeKUGQO6V31dPEITdRA&utm_source=copy-link&context=spotify%3Atrack%3A5ronKOeupSInit9Y21z80f
- Player-facing UI, pause menu, recap, and prompts MUST write the voluntary exit action as **“Dispel”** (quotation marks included) for the locked humorous tone. Internal code identifiers MAY omit the quotes.