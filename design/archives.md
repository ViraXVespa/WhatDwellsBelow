# Archived builds

Status: binding design
Read when: touching Archives UI, presentation switcher, or anything under `archives/`
Code: `scripts/ui/archives_ui.gd`, `scripts/ui/present.gd`
See also: `design/protocol.md`, `design/save-tech.md`

## Core rule

`archives/classic_2d/`, `archives/art_experiment/`, and `archives/full_3d_pass/` are frozen historical snapshots.

- Do not overwrite them.
- Do not copy them onto the live path.
- Do not back-port live changes into them.
- Do not create a new archive unless the User explicitly asks.

`archives/development_documents/` is historical design scratch, not the live database.

## Selectable builds

| Id | Label | Meaning |
|----|-------|---------|
| live | live | Shipping path at repo root |
| classic_2d | classic_2d | Isolated archive |
| art_experiment | art_experiment | Isolated archive |
| full_3d_pass | Full 3D Pass | Snapshot of the previous live path |

Selecting **Play** from live UI always launches live.
Selecting an archive launches that snapshot as its own instance.
No hybrid mode. No shared runtime state, scenes, scripts, or saves.

Each archive uses its own save path or versioned prefix.

## Creating a new archive (User-ordered only)

1. Freeze the current live project state.
2. Copy the relevant project contents into a new named folder under `archives/`.
3. Strip live-only systems that did not exist at that moment.
4. Launch the archive independently and confirm zero shared runtime with live. Report to the User.

Never overwrite the three existing snapshots.

## Archives browser UI

Opened from Pause → System.

- Left: vertical list of archives.
- Right: info panel for the highlighted row — description, Video (disabled if missing), Documents (disabled if missing), Play.

List MUST include classic_2d, art_experiment, and Full 3D Pass.
Videos do not exist yet; the Video button stays disabled until they do.