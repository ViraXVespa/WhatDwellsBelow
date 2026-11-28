---
name: changelog-commit
description: Create a human‑friendly changelog entry for the current repository state (uncommitted and/or on‑branch).
---
## Purpose
The *changelog‑commit* skill orchestrates a set of small helper scripts that an agent can call in sequence to generate a changelog.

### Available helper scripts
1. **diff.py** – Runs `git diff` against a base (default `origin/main`) and writes the result as `diff.json`.
2. **commits.py** – Runs `git log` to get commit messages for the current branch and writes them as `commits.json`.
3. **add_bullet.py** – Accepts a bullet string as a command‑line argument and appends it to `bullets.txt`.
4. **write_summary.py** – Accepts a summary string as a command‑line argument and writes it to `summary.txt`.
5. **cleanup_and_patch.py** – Reads `summary.txt` and `bullets.txt`, constructs the correct `tools/docs.py patch changelog` command with `--summary` and `--bullet` flags, executes it, and then removes the temporary `diff.json`, `commits.json`, `summary.txt`, and `bullets.txt` files.

## Step‑by‑Step Guide for an Agent
1. **Gather diff data**
   ```bash
   python .opencode/skills/changelog-commit/diff.py
   ```
   This creates `diff.json`.
2. **Gather commit messages**
   ```bash
   python .opencode/skills/changelog-commit/commits.py
   ```
   This creates `commits.json`.
3. **Read the data** - read the `diff.json` and `commits.json` to ingest the relevant info for creating the summary and bullets.
4. **Add bullets** – Bullets are generic bulletpoints for each noteable change. Bullets are not info about what files were changed. Bullets are summations of what those changes accomplished. File names must never appear in bullets.
   for each bullet the agent calls
   ```bash
   python .opencode/skills/changelog-commit/add_bullet.py "{Bullet content without a leading '- '}"
   ```
   Repeat as needed; each call appends a line to `bullets.txt`.
5. **Create a summary** – the agent determines a concise human‑readable sentence that captures all of the overall changes made.
   ```bash
   python .opencode/skills/changelog-commit/write_summary.py "{Summary Goes Here}"
   ```
   This writes `summary.txt`.
6. **Patch the changelog** – finally run
   ```bash
   python .opencode/skills/changelog-commit/cleanup_and_patch.py
   ```
   This will:
   * Read `summary.txt` and `bullets.txt`.
   * Call `tools/docs.py patch changelog --summary "…" --bullet "…" --bullet "…"`.
   * Remove the temporary `diff.json`, `commits.json`, `summary.txt`, and `bullets.txt`.

