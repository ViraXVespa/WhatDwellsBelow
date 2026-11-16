# Start splash: platform prompt + click/tap to continue

id: splash-platform-prompt
owner: build
status: open
done-when: Start splash shows the correct platform prompt (including gamepad) and advances on click/tap; gate passes; changes are left local (not pushed to the Grok Build branch)

## Goal
Change the start splash "Enter / Esc to continue" text to the correct platform prompt and make the splash advance on click/tap.

## Constraints
- Do not push any commits to the Grok Build branch. Leave the worktree changes local for inspection.
- Stop when the change is in and the gate passes.

## Acceptance
- The splash shows the correct platform prompt for the current input method (keyboard, gamepad, or touch).
- Click or tap advances past the splash.
- The worktree is left with local changes only (nothing pushed).

## Next Steps (User Only)
python tools/slice.py open title --task splash-platform-prompt
