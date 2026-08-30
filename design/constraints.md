# Hard constraints and demo-complete bar

Status: binding design
Read when: every fresh instance; before adding a system; before calling the demo complete
See also: `design/overview.md`, `design/coverage.md`, `design/feel.md`

## Hard constraints (non-negotiable)

- Solo play only; no co-op scaffolding left active in the live path.
- Exactly the eleven skills listed in `design/skills.md`.
- White, green, and blue rarity only (blue is boss-only).
- Repeating 5-floor structure with Floor Guardians (1–4) and Gate Master (5).
- Hit-based gathering system for both mining and woodcutting.
- Artifact collections / sets required (exactly eight, see `design/inventory.md`).
- Player animations use exactly 8 directions (matching the Character Bible layout) with full male/female parity. Each character type has its own complete voice-over set.
- All numeric values exposed and tunable in the secret debug menu.
- Production / Gold quality on every system that ships.
- Consistent 60 FPS minimum on target hardware.
- No systems, skills, rarities, hub upgrades, or meta-progression beyond what this database explicitly requires.
- The secret debug menu (including Save/Load profiles, Automated Playtest / AI Player system with weapon-balance awareness, telemetry, impact coefficients, baseline coefficients, and recommended configurations) MUST ship but remains hidden behind the documented input sequence.
- The Automated Playtest / AI Player system exists so simulation, telemetry hooks, and recommended-config application are implemented *inside* the same live systems the player uses (combat, inventory, extraction, save, debug values). It is an integration requirement, not a parallel “AI game.” Keep programmatic impact low: one code path wherever practical.
- The Animation Browser is a shipping debug page. Its *controls* MUST exist in the secret debug menu from the first debug-menu implementation (Phase 7). The *full viewer* is a late-stage (Phase 9) Demo-Complete item and MUST ship in the final product.

## Success criterion

A first-time player on a couch with a gamepad can reach a successful extraction in 5–10 minutes without external guidance, understand the core risk/reward of extraction vs. death, and experience the permanent progression feedback on the recap screen — all at stable 60 FPS — using only the current live path.

**Concrete self-check proxies (MUST verify before final sign-off)**
- Simulated new-player path reaches extraction in ≤10 minutes under default settings.
- 60 FPS maintained under full enemy + particle load on deepest test floors.
- Recap XP-drain sequence and permanent fragment display function correctly.
- All three weapons remain roughly balanced per Automated Playtest Medium-bar results.

## Demo-complete checklist (true non-negotiables)

A build meets the contract only when **all** of the following are true:
- The Success Criterion above is achieved on the current live path.
- Live path at repo root is the playable shipping build. Archives remain frozen snapshots.
- Live path shares no runtime code, scenes, scripts, or global state with any archived build.
- Exactly the eleven skills listed in `design/skills.md`.
- Exactly eight artifact sets (run-only).
- Hit-based gathering for mining and woodcutting.
- Repeating 5-floor structure with Floor Guardians (1–4) and Gate Master (5).
- White / green / blue rarity only (blue is boss-only).
- Player animations use exactly 8 directions with full male/female parity. Each character type has its own complete voice-over set.
- Secret debug menu (including Medium-bar Automated Playtest) ships but remains hidden.
- Automated Playtest Medium bar ships, hidden behind the documented sequence, using the capped telemetry set in `design/debug.md` (no open-ended analytics product).
- Secret debug menu includes a focusable Animation Browser entry from Phase 7 onward, and the full Animation Browser viewer ships by Demo-Complete (Phase 9).
- Every shipping system is Production / Gold quality and fully exposed to the debug menu.
- Consistent 60 FPS minimum.
- Solo play only; no co-op scaffolding.
- No systems, skills, rarities, hub upgrades, or meta-progression beyond what this database explicitly requires.