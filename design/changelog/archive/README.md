# Prior-series changelogs

Live authoring stays flat: `design/changelog/{label}.md` for the **current** series only.

When `epoch.series` advances, run:

`python tools/archive_prior_changelogs.py`

That moves non-current `{epoch}.{series}.*.md` files into `design/changelog/archive/{epoch}.{series}/`. CI runs the same tool on stamp / Pages. See `design/versioning.md`.
