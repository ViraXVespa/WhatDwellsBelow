---
name: review-shots-isolated
description: >
  Offload a What Dwells Below shot review to an isolated Grok session when the
  main session needs only a text answer, not the image itself.
user-invocable: true
metadata:
  short-description: Review shot PNGs in an isolated context, bring back text
---

# review-shots-isolated

Use isolated review when a text assessment is enough. For pictures the User should see, use `shots.py show`. Necessary direct visual references use the explicit task/session grant in the Build reference guide; neither path is a generation exception.

## Run

`python tools/shots.py review PNG... --question "..." [--rubric TEXT|@FILE]`

The runner stages images, full-size sources and local helpers outside the repository, verifies isolation and returns `report.md` with `VERDICT: PASS|FAIL|UNSURE`. Review only the unit being changed. Turn budget starts at 8 and rises with image count; use `--help` for options.

Text questions attempt local OCR first. Weak/fail/SKIP may use vision; ordinary shape/colour review needs no OCR. `--why REASON` is the separate logged text-review exception, not host permission or a repository image grant.

`RESULT FAIL` means no valid review happened: report the reason and do not invent a verdict. Inputs are read-only; ignored summaries/receipts may be written in the worktree. The child's outputs stay in its staged scratch.
