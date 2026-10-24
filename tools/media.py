#!/usr/bin/env python3
"""Art and audio pipelines: isolated Grok media jobs, rekeying, sprite packing, icons, Bible, SFX.

`python tools/media.py` lists the subcommands; `python tools/media.py SUB --help` prints that one's flags.
The work lives in tools/lib/media/ (one module per subcommand); this file only maps names to modules.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import boot  # noqa: E402

COMMANDS = [  # (subcommand, module under tools/lib/, what it does)
    ("grok",             "media/run_isolated_grok",      "Isolated Grok Build media job in a scratch dir (--kind ui|i2v|...)"),
    ("i2v-seeds",        "media/i2v_seeds",              "I2V seed plate and prompt (gender, facing, action)"),
    ("rekey",            "media/rekey_all_stills",       "Rekey every manifest still from _src (--check, --out DIR)"),
    ("rekey-preview",    "media/rekey_preview",          "Open-set rekey preview on blue (no live writes)"),
    ("rekey-check",      "media/rekey_check",            "Full-set rekey check of --new DIR against live"),
    ("sprites",          "media/sprite_pipeline",        "Section 19 sprite cleanup: wand, Color-to-Alpha lip, 128 fit"),
    ("world",            "media/process_world_pass",     "Key and install the world art pass stills"),
    ("gear-icons",       "media/process_gear_icons",     "Key gear plates into assets/ui/gear (--check)"),
    ("shop-icons",       "media/slice_shop_icons",       "Slice the ghost-shop sheet into gear plates and icons"),
    ("plate-remap",      "media/plate_remap",            "Remap a generated chroma plate to exact #FF00FF"),
    ("keyed-region",     "media/match_keyed_region",     "Match a keyed source region against a live sprite"),
    ("pack-loco",        "media/pack_locomotion",        "Pack idle and walk frames from I2V clips"),
    ("pack-oneshot",     "media/pack_oneshot",           "Pack one-shot I2V clips into engine frames"),
    ("pack-turntable",   "media/pack_turntable",         "Pack 8-dir player sheets from turntable clips"),
    ("bible-prompt",     "media/bible_prompt",           "Bible Imagine text (--gender, --enemy ID)"),
    ("bible-normalize",  "media/bible_normalize",        "Squared 3x3 Bible to the live lock sheet"),
    ("attack-keys",      "media/attack_keyframes",       "Beat-by-beat attack stills from a Bible cell"),
    ("keytest",          "media/keytest",                "Golden-set keying regression"),
    ("sfx",              "media/make_sfx",               "Placeholder SFX wavs from tools/data/sfx-cues.json"),
    ("glyphs",           "media/gen_prompt_glyphs",      "Chunky pixel prompt glyphs"),
    ("anim-review",      "media/anim_review",            "Animation Browser review briefs: pack, regen, tree"),
]

if __name__ == "__main__":
    raise SystemExit(boot.dispatch(__file__, __doc__, COMMANDS))
