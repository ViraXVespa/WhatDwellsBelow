# Media bot (Bottie Boop)

Status: protocol  
Read when: Bottie Boop is woken for promo shots, or a media-bot trigger or rule changes  
Code: `.github/workflows/media-bot.yml`, `tools/shots.py movie --refs`, `tools/media.py clip`, `tools/data/movies.json`

Bottie Boop records before/after promo shots of `main` on the box. It picks from the scenario catalog only (`tools-media.md`, Ref compare and scenario catalog).

## Triggers

`.github/workflows/media-bot.yml` only pings; the box records (GitHub runners have no Godot). It POSTs JSON to `BOTTIE_BOOP_WEBHOOK_URL` with `Authorization: Bearer <BOTTIE_BOOP_WEBHOOK_KEY>` (repo secrets) and skips quietly while either is unset.

| `job` | Event | `refs` (A,B) |
|---|---|---|
| `week-start` | `create` of a `grok-build-wN` branch (Build pushes it after `release.py week-start`): the Web Week End | A = the merge commit of the `grok-build-w{N-1}` PR; B = `git merge-base origin/main origin/grok-build-wN` (the week's `open_commit`) |
| `week-merge` | PR from `grok-build-wN` into `main` closed as merged | A = `merge^1` (the week's base: `main` does not move during a Build week); B = the merge commit |

Payload keys: `repo`, `job`, `branch`, `sha`, `merge_sha`, `pr`, `refs`. An empty `refs` (a lookup failed, or week 1) means: work them out with the rules above. `gh pr list --state merged --head grok-build-wM --json mergeCommit` gives a week's merge commit. Never use the `archive/grok-web-w*` tags as refs; older ones do not sit at `merge^1`.

## Run

Use `python3` (no `python` on the box). Godot is found by `tools/lib/godot_lib.py` (`/workspace/godot/` or `GODOT_BIN`). One `--refs` run at a time: the box is shared, and every run makes temp worktrees and drives Godot. Start after the push the webhook reports (week start has already cleaned logs and Godot locks by then).

```
git fetch origin
python3 tools/shots.py movie --refs A,B hub-ui,dungeon-gen
```

Default sets: `hub-ui,dungeon-gen` (`python3 tools/shots.py movie --list` prints the catalog). About 35 to 40 min: about 6 min per set per ref, plus the reel. Out dir: `_logs/movie/refs-<A>-<B>-<names>/` (long names are shortened with a hash; the `RESULT` line's `out=` is the path): `reel.mp4`, `reel-x.mp4`, `reel.gif`, `contact.png` (A | B | heat per change), `compare.json`.

`RESULT ... changed=0` (every pair `no visible change`): no post. A changed scene on its own: `python3 tools/media.py clip ba BEFORE AFTER`, then `clip export IN --for x` (fails over 140 s or 512 MB) or `--for gif` (fails over 15 MB). Check `reel.gif` is at most 15 MB before using it; past runs went over.

## Rules

- Catalog only. A new shot system, view or scenario is a request to the Refactorer (Grok Bot); Bottie Boop never builds one or edits `movies.json`.
- Media stays in `_logs/` or outside the repo; never commit video, GIFs, stills or contact sheets.
- Each X post is a draft until Vira approves it. The text ends with the signoff `Bottie Boop`. Nothing posts without her approval.
- Read-only on the repo: no commits, no pushes, no branches.
