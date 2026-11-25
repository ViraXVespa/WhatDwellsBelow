---
name: changelog-commit
description: Add or update a changelog entry. Call changelog_state first to learn whether to create or append, then supply new bullets and a concise Summary. Can push after proves when requested. Callable from OpenCode or via direct Ollama API.
---

# changelog-commit

Update the changelog using the existing tool to create friendly, human readable data about changes made to the repo.

## Rules
- First call the changelog state helper (doc_patch.changelog_state or the --state flag) to learn if this is a new file or an append.
- If append, receive the existing bullets and write a complete Summary that covers everything.
- Focus only on adding new/missing outcome bullets and a concise Summary. No version-number or branch-name logic.
- Do not include file names in the bullets.
- Make sure the bullets are summaries of the work accomplished and not a list of changed files. Every change should have an explanation of what was changed, not just list that a change was made.
- Do not use any non‑ASCII characters or fancy punctuation (e.g. ‘–’, ‘—’, ‘…’, ‘’’, ‘“”’) in the changelog text. Use plain ASCII equivalents.
- Ensure every change is tracked in the changelog. If multiple files were adjusted to accomplish a single change, report that resulting change in the bullets, not the changed files.
- Describe the effects of the changes, not solely that a file or system was changed. Say what changed.
- Use the existing docs.py patch changelog path.
- When requested, push after any necessary proves (especially on a Grok Build branch).

## Output
- Whether the file was created or appended
- Path of the changelog file
- The Summary line written
