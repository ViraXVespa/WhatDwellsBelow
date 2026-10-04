# Hard constraints and demo-complete bar

Status: binding design  
Read when: every fresh instance; before adding a system; before calling the demo complete  

These constraints are **product scope**. They do not ban Grok Build from adding helpers, same-system APIs, or local module shape. Code-architecture rules for Build stay on the Build path file. “System” in this file means a player-facing game system, not a code module.


## Hard constraints (non-negotiable)

- Solo play only; no co-op scaffolding left active in the live path.
- Exactly eleven_skills_listed_on_the_skills.
- White, green, and blue rarity only (blue is boss-only).
- Repeating 5-floor structure with Floor Guardians (1–4) and Gate Master (5).
- Hit-based gathering system for both mining and woodcutting.
- Artifact collections / sets required (exactly eight, run-only; inventory door).
- Player animations: 8-dir Bible layout and male/female parity (art-pipeline door). Each character type has its own complete voice-over set (player door).
- All numeric values exposed and tunable in the secret debug menu.
- Production / Gold quality on every system that ships.
- Consistent 60 FPS minimum on target hardware.
- No systems, skills, rarities, hub upgrades, or meta-progression beyond what this database explicitly requires.
- The secret debug menu (including Save/Load profiles, Automated Playtest / AI Player system with weapon-balance awareness, telemetry, impact coefficients, baseline coefficients, and recommended configurations) MUST ship but remains hidden behind the documented input sequence.
- The Automated Playtest / AI Player system exists so simulation, telemetry hooks, and recommended-config application are implemented *inside* the same live systems the player uses (combat, inventory, extraction, save, debug values). It is an integration requirement, not a parallel “AI game.” Keep programmatic impact low: one code path wherever practical. Medium bar uses capped_telemetry_set_on_the_debug (no open-ended analytics product).
- The Animation Browser is a shipping debug page. Its *controls* MUST exist in the secret debug menu from the first debug-menu implementation (Phase 7). The *full viewer* is a late-stage (Phase 9) Demo-Complete item and MUST ship in the final product.

## Demo-complete bar

Success criterion, self-check proxies and the Demo-complete checklist: `constraints-demo.md`. Open it before calling the build complete, and not before.
