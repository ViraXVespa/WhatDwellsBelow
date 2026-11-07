# Review a Build startup procedure

Status: current procedure
Read when: the User asks the Bot to simulate a Build task pickup

Use a disposable fixture/worktree and the Bot's branch/PR rules; do not modify a User's active checkout or launch a Build session. A procedure review does not itself authorize gameplay, art, MCP actions or user-machine execution.

1. Inspect the task and launch/start command with supported dry-run/help modes. Confirm its area, flags and first command agree with the task header; run `docs.py task check`.
2. Walk the printed start procedure against actual commands and available capabilities. Execute only checks within the approved scope; record anything that needs a runtime or unavailable connector instead of faking it.
3. Check each implied tool call: supported kind/flags, defaults, output paths and expected evidence. Fix mechanical doc/tool errors on the Bot branch; ask before changing product design or task acceptance.
4. Read actual stdout/stderr from checks you ran. Flag misleading success, noisy output, dead paths and surprising defaults; use focused CLI/static checks without starting unapproved runtimes.
5. Report fixes/commits, remaining usability issues and unverified steps. Remove only the disposable resources this review created.
