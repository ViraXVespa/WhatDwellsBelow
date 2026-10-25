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

## Catalog fixes
- Put `f1-fight` in a set.
- `hub-overhead` is the name of both a movie and a view. Rename one, and update every reference (`check.py tool-docs --stale-refs`).

## New movies
- Combat specials: mana cost (now 20) and the recovery (1.5 s).
- Recap: the drain, then Continue.
- The quest poster lifting into the pause Quest tab.
- Title/menu: hover and navigation.
- Phone-viewport versions of the views (portrait or small-screen size).

## Where it stands
Not started. All the time went to the hub fixes.
