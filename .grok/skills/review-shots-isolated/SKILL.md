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

Use it when a text answer is enough → this; the User should see the image → `shots.py show`. Never `read_file` a PNG or JPG in the parent session. The shared gather (`slice.py open`) does not run this. The forked session whose unit needs the frames does. Turn budget rises with the image count (at least 8, +2 per image, cap 16).

## Run
`python tools/shots.py review PNG... --question "..." [--rubric "- item" | --rubric @FILE]`

- Copies the PNGs to a scratch dir outside the repo, proves isolation with `grok inspect` (no project instructions), runs one child session, and prints only its report with a `VERDICT: PASS|FAIL|UNSURE` line.
- `RESULT FAIL` means no review happened (grok missing, isolation not proven, child error, no report). Say so; do not guess a verdict or open the PNGs to replace it unless you then follow the `shots.py show` rule.
- Read-only: writes nothing in the repo.
