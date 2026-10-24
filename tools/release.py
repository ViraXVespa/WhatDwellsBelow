#!/usr/bin/env python3
"""Release and Pages: web export, post-export, notes site, changelogs, week start/pin, CI archive.

`python tools/release.py` lists the subcommands; `python tools/release.py SUB --help` prints that one's flags.
The work lives in tools/lib/release/ (one module per subcommand); this file only maps names to modules.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import boot  # noqa: E402

COMMANDS = [  # (subcommand, module under tools/lib/, what it does)
    ("export-web",       "release/export_web",             "Export the Pages build (Godot Web; --debug, --archives, --out)"),
    ("postexport",       "release/web_postexport",         "Stamp a Godot Web export (cache id, notes)"),
    ("mips",             "release/enable_texture_mips",    "Turn on mipmaps for 3D world PNGs"),
    ("archives",         "release/export_archives",        "Export pinned catalog archives into a Pages site"),
    ("pages-hash",       "release/pages_game_hash",        "Hash game-affecting paths so Pages can skip a Godot export"),
    ("notes-site",       "release/publish_notes_site",     "Copy version/changelog JSON onto the Pages site"),
    ("changelog",        "release/build_changelog",        "Rewrite scripts/data/changelog.json from design/changelog/*.md"),
    ("park-changelogs",  "release/archive_prior_changelogs", "Move non-current-series changelogs into archive/"),
    ("week-start",       "release/week_start",             "Week start from main: epoch, branches, locks, logs"),
    ("week-pin",         "release/week_pin",               "Catalog row, notes and local tag for a week (--web N, --build N)"),
    ("ci-archive",       "release/ci_archive",             "CI: pin web + build weeks when a release changelog merges"),
]

if __name__ == "__main__":
    raise SystemExit(boot.dispatch(__file__, __doc__, COMMANDS))
