# Hub — guild, quests, banner

Status: binding design  
Read when: receptionist bust, notice errands, welcome cloth


## Guild / Quest Access
- One continuous L-shaped guild: main hall + inset east reception wing. Wing back wall is flush with the hall back wall. Wing is slightly smaller than the hall.
- Hall, wing, roofs, and awnings follow `Layout` nodes. Reception bust stays clipped to the wing south face from the wing node.
- Receptionist is a bust clipped into the painted window of `guild_reception.png` (not standing on the dirt in front of the building). Feet discard below UV.y 0.50 so they stay behind the sill.
- Notice board sits on `Layout/Spots/Board` (default to the right of the combined guild).
- Quest access via Receptionist or Notice Board. Today both kinds share one branch: `scripts/world/interact_act.gd` (`quest_board` or `receptionist` → `open_quest()` in `scripts/ui/progress_ui.gd`, built by `progress_ui_hub.gd rebuild_quest`). Prompt/title text: `interact_prompt.gd`; sprite/clerk look: `interact_fx.gd`; placement: `camp.gd` (`reception_pos`).
- Offers 3 random quests; one active at a time.
- Quests re-generated after each delve (active unfinished quest preserved).
- Quest types: defeat enemies, extract ore, retrieve item, vanquish named enemy (locks enemy spawn).
- Rewards: XP, unowned gear, gold, items.

## Planned: Receptionist rework (not built)

The Receptionist stops sharing the Notice Board's quest menu and becomes the lore and "How to Play" guide; the Notice Board keeps quests. Requested shape: menu with **Talk** (lore note, different each time the delver enters Placeholdia; seen notes tracked so none repeat until all are seen) and **Ask?** ("What would you like to know about?" → topic list → tutorial pages with screenshots; forging, XP retention, and so on).
Open questions before any build: owner door and doc for the guide (new door is propose-first); where lore and tutorial text lives and who writes it; which entry event counts as entering (see the camp entry events table); seen-note storage and Delete Save behavior; what happens when all notes are seen; screenshot count and how they ship; reach from Title or Pause; the smoke to add.

## Controls Billboard
- Shows TV-readable list of current controls (gamepad primary; keyboard/mouse equivalents).
- Reflects player bindings from Pause → Settings → Controls. Flavor text allowed; list must be accurate.
- Close with Back / B.
- Dungeon-themed / hub-themed UI.

## “Welcome to Placeholdia!” Banner
- Text printed directly on banner, clearly visible.
- Double live size for readability from crystal.
- Not interactable or floating text.
- Centered on `Layout/Spots/Banner` (default mid-path). Poles have collision; there is no invisible blocker left/right of the cloth.
