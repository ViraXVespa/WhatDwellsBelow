# Hub — Floor Crystal and wake-up

Status: binding design  
Read when: consciousness-transfer VFX, Dispel wake-up, deepest row


## Floor Crystal
- Only enter-dungeon interactable.
- Opens Loadout UI: select holds per slot (fallback to starter Great Axe + pickaxe or hatchet + potion), choose starting weapon, tool type (pickaxe or hatchet — locked for run), starting floor, **Enter dungeon**.
- Character type set in Pause → Settings → Gameplay.
- Floor row: `Floor: [−] [selected] [+] (Deepest floor: n)`. Only reached floors; `−` dies at 1; `+` dies at deepest.
- First focus: **Enter dungeon**. B / Esc / Close leaves Placeholdia.
- On enter: play **consciousness-transfer VFX** before dungeon loads.
- UI must be clean, TV-readable, dungeon-themed, consistent with other UIs.
- Live camp position: between the combined guild and the vendor stall, on the north–south path (`16.475, 0, 10.2` in `camp.gd`).

## Return / Wake-up
- After death or “Dispel”, play short **wake-up sequence** (animation + VFX/SFX).
- Extract-wake does **not** run the title-Play hub warmup overlay. Do not add one unless the User asks.
