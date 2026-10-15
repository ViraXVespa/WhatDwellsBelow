# review-shots-isolated

Isolate What Dwells Below shot review so the main Build session never carries raw PNG data.

## When to use
Before any visual prove step that would otherwise open PNGs in the main session
(`show_png.py`, direct image view, or reading shot-flow output).

## Rules
- Load this skill first.
- Do not view the PNGs yourself in the main session.
- Call `python tools/review_shots.py PATH1 PATH2 ...` (or paste the paths into a fresh isolated chat).
- Bring only the printed text report back.
- The runner never writes game files, assets, or docs.
- The main session uses the text report for the verification ask (after commit/push).

## Isolation
Same pattern as imagine-isolated: the review lives in its own context. The main
session stays lean.
