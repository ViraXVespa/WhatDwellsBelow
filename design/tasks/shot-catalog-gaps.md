# Bottie Boop shot-catalog gaps: views, set/name fixes, new movies

id: shot-catalog-gaps
owner: bot
status: open
done-when: Every listed view and movie renders once via tools/shots.py and is eyeballed, f1-fight is in a set, the hub-overhead clash is renamed, full bot prove PASSes, Bottie Boop told
resume: python tools/docs.py task show shot-catalog-gaps, then python tools/shots.py flow --help

## When
Bot session on Saturday, Oct 31, 2026 (Vira's wrap-up of Oct 25 vendor-fixes).

## Intent
Fill the shot-catalog gaps that Bottie Boop (the promo-shot bot) listed. Extend what already exists rather than building anything parallel:
- scenario catalog and views: `tools/data/shot-recipes.json`, the `shots.py` views and sets
- shot flows: `tools/data/shot-flows/*.json`
- movies: `tools/data/movies.json`

Each new view and movie must render once and be checked by eye. Do not commit media. When it is pushed, tell Bottie Boop through Vira or the parent bot.

## Views to add (scenario@view)
- camp-pause-pages@pause-quest
- camp-recap@recap
- camp-receptionist-menu@talk-line, ask-open, page-forging
- camp-gear-popups@anvil-tip, anvil-forge-pick, loadout-pick
- camp-npc-panels@loadout
- dungeon-map-crystal@crystal-root
- camp-billboard-controls@controls
- the ghost-shop focus ring
- title-menu@title-updates, title-card
- vendor-stall@overhead, low-front, side-post
- a welcome-banner close-up
- dungeon-hud-states@hud-low-mana
- report-bug (camp-pause-pages@settings-report-open): added, rendered and checked

## Catalog fixes
- Put `f1-fight` in a set.
- `hub-overhead` is the name of both a movie and a view. Rename one, and update every reference (`check.py tool-docs --stale-refs`).

## New movies
- Combat specials: mana cost (now 20) and the special-reuse cooldown (1.5 s).
- Recap: the drain, then Continue.
- The quest poster lifting into the pause Quest tab.
- Title/menu: hover and navigation.
- Phone-viewport versions of the views (portrait or small-screen size).
- vendor-stall-close (stall close-up, 2.6x to 3.4x while the player walks up): added, rendered and checked

## Where it stands
Done on grok-build-w11 (7e85d605): every listed view (22 new, phone viewports included) and movie (combat-special, recap-drain, quest-take, title-nav) rendered once and eyeballed; hub-overhead still renamed hub-overhead-still; f1-fight and combat-special in sets. recap-drain stops before Continue (Continue changes scene and restarts the flow).

Open: done-when needs a full bot prove PASS. 2026-11-09 prove (vs main) is red on items outside this task: P6 smoke TIMEOUT (smoke_escape loses its scene at deep_loadout; bisected to 006b19cc present.gd headless wait_painted), a load-graph boot-file issue in AGENTS.md (48aea042), and bot_status over_10kb (actor_lit.gd, outline.gd, mesh_span.gd). Bottie Boop not told yet (goes through Vira).
