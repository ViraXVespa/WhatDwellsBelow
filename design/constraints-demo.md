# Demo-complete bar

Status: current plan  
Read when: before calling the demo or build complete (self-verify against this page)

The Hard constraints stay on the constraints door; the checklist below includes them by reference.

## Success criterion

A first-time player on a couch with a gamepad can reach a successful extraction in 5–10 minutes without external guidance, understand the core risk/reward of extraction vs. death, and experience the permanent progression feedback on the recap screen — all at stable 60 FPS — using only the current live path.

**Concrete self-check proxies (MUST verify before final sign-off)**
- Simulated new-player path reaches extraction in ≤10 minutes under default settings.
- 60 FPS maintained under full enemy + particle load on deepest test floors.
- Recap XP-drain sequence and permanent fragment display function correctly.
- All three weapons remain roughly balanced per Automated Playtest Medium-bar results.

## Demo-complete checklist

A build meets the contract only when **all** of the following are true:

- Every Hard constraint above.
- The Success Criterion and its proxies, on the current live path.
- Live path at repo root is the playable shipping build. Archives remain pinned commit snapshots.
- Live path shares no runtime code, scenes, scripts, or global state with any archived build.
