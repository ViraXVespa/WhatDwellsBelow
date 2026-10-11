# Recap screen skills-page style

id: ui-recap-skills-style
title: Recap matches skills page chrome
owner: build
status: open
done-when: recap uses skills-page two-sheet layout (split right of center), tooltips for skill stats, keeps two columns and the XP-drain animation, and preserves every mandatory sequence step and locked flavor line; Vira has seen it
area: ui
door: ui
job: recap
units: ui.recap
done:

Your first command, before any file read or memory topic: python tools/start_build_slice.py --door ui --job recap --from-task ui-recap-skills-style

## Intent
Match the look of the skills page (two sheets, split right of center so the list is the wide sheet). Tooltips for skill stats. Keep the two-column layout and the XP-drain animation. All existing mandatory sequence and locked flavor lines stay.

## Files
- scripts/ui/recap/rebuild.gd
- scripts/ui/recap/recap_ui.gd
- scripts/ui/recap.gd

## Art survey
- Header plaque + page frame: now a cream box with 22 identical rows. Plaque 600x96 transparent; page 9-slice 128. Med. Rows stay code. Ref camp-recap_01-recap.png. Ref shots: Bot survey of grok-build-w7 on 2026-10-11 (not committed; /workspace/png-survey/shots on the box).
