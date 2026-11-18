# Changelog

One flat file per build: `design/changelog/{epoch}.{series}.{patch}.md`.

Week start (`tools/release.py week-start`) deletes every `*.md` in this directory except this README so the new series starts clean. Finished notes remain in git history.

Grok Build does not write changelogs.
