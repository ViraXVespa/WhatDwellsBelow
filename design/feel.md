# Balancing, feel, and polish targets

Status: binding design
Read when: tuning difficulty, time-to-extract, weapon parity, or polish bar
See also: `design/constraints.md`, `design/tunables.md`, `design/debug.md`

## Time targets

- A brand-new player SHOULD be able to achieve their first successful extraction in 5–10 minutes.
- A competent player SHOULD be able to reach and clear floor 6 in roughly 5–10 hours of total play. This is a feel target, not a hard cap.
- Skilled play SHOULD support significantly longer continuous runs.

## Death and learning curve

- A competent player SHOULD reach consistent clears of the early loop within roughly 20–30 total dives. Exact number is a feel target, not a hard metric.
- Death MUST always feel like a fair consequence of player decisions or execution rather than randomness or hidden information.

## Difficulty progression

- Difficulty scales with floor number and with each completed 5-floor cycle.
- The jump from floor 1 to later floors MUST be noticeable but not punitive.

## Visible power gain

After one successful extraction and return to Placeholdia the player MUST be able to clearly notice either:
- a few permanent skill levels, or
- at least one new usable piece of forged gear
(or both). This is a required psychological reward. Concrete proxy: the change MUST be visible on the hub screens without external guidance.

## Weapon balance

The three weapons (Great Axe, Lightning Staff, Longbow) MUST remain balanced with one another so that no single weapon type is clearly stronger. The Automated Playtest system actively monitors and supports this constraint.

## Accessibility (mandatory)

- Full control rebinding for gamepad and keyboard/mouse.
- Independent HUD scale control.
- Aim-line toggle and opacity.
- Gamepad-first design with valid initial focus on every menu.
- These features are required for the demo ship. Additional accessibility options may be added but are not mandatory.

## Polish bar

Every system that appears in the demo is considered production / Gold. No “temp” or “programmer art will do” exceptions are allowed for systems that ship. Placeholder assets are permitted only under the explicit policy in `design/audio-visual.md` and MUST be replaced before release.
Player-facing UI and HUD MUST be dungeon-themed. Default / unskinned engine controls MUST NOT appear on the playable path. The secret debug menu is exempt.

The Automated Playtest / AI Player system (secret debug menu) exists to generate telemetry and recommended configurations from the capped set in `design/debug.md` so the demo can meet the targets above without a parallel simulation stack or an unbounded metrics product.