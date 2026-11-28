"""Studio registry: the one source for what every subject type's steps hold and do.

For each type: the steps (one per store section), the fields the game needs on each, the actions
a step offers, and what a step needs before it can be approved. For each action: the command the
studio expects, its inputs and outputs, the model setup it needs, and whether it is wired.
The server reads this module; `media.py studio --gaps` writes the Build gap list from it.
Grounding: scripts/data (content_pack, balance/enemies, catalog, affixes, gear_roll, talk_lines),
scripts/combat/roster.gd, assets/, and the design docs named in each type's `source`.
"""
from __future__ import annotations

from media.pipeline import store

# ---- model setups ------------------------------------------------------------------------------
# status: ready (works in the pipeline today), partial (works for one case only), missing.
SETUPS: dict[str, dict] = {
    "qwen-still": {"label": "Picture from a description", "models": "Qwen Image 2.1 int8, text encoder staged on CPU", "status": "partial",
                   "note": "Works for the character T-pose. Needs a default recipe (workflow + prompt layer) per type and step; see recipes."},
    "qwen-edit": {"label": "Change an existing picture", "models": "Qwen Image 2.1 int8 edit graph", "status": "partial",
                  "note": "Used inside pipeline edit for a whole-body still. Needs a general still-to-still graph for variants and colour swaps."},
    "qwen3-vl": {"label": "Check a picture", "models": "Ollama qwen3-vl:8b (not Comfy)", "status": "ready", "note": "pipeline review / tune."},
    "hunyuan-3d": {"label": "3D model from a front picture", "models": "Hunyuan3D 2.1", "status": "ready", "note": "pipeline body / smooth."},
    "hi3d-refine": {"label": "Refine a 3D model from a picture", "models": "Hi3D v1.0 int8, DINOv2 Large, CLIP ViT-L/14", "status": "ready", "note": "pipeline edit."},
    "motion-8dir": {"label": "Animate a 3D model in 8 directions", "models": "MotionBricks SOMA FP16 (on disk, not wired) + a render pass per facing", "status": "missing",
                    "note": "Clip by name and direction count, rendered at a larger size, then pixel finish to 128."},
    "frames-2d": {"label": "Frames for a flat effect or object", "models": "To pick (Wan 2.2 14B stays out)", "status": "missing",
                  "note": "Short frame strips for effects, projectiles and prop states from one key picture."},
    "overlay-fit": {"label": "Worn and held pictures per facing", "models": "Qwen Image edit on the character's facings, or a 3D fit and render", "status": "missing",
                    "note": "One overlay per body type and facing, matched to the paper-doll offsets."},
    "tile-seamless": {"label": "Seamless ground and wall tiles", "models": "Qwen Image 2.1 int8 with a tiling pass", "status": "missing", "note": "Floor, wall and path tiles that repeat cleanly."},
    "wang-tiles": {"label": "Wang tilesets from two materials", "models": "Qwen Image 2.1 int8 edit with a corner or edge mask per tile, seeded from two approved seamless tiles; a Python packer for the sheet and a Godot TileSet",
                   "status": "missing", "note": "Every tile of the variant matches its neighbours on shared corners or edges. Packs a sheet and, when asked, a Godot TileSet .tres with one terrain set."},
    "stable-audio": {"label": "Placeholder sound effect", "models": "Stable Audio 3 Small-SFX", "status": "missing", "note": "Marked placeholder until a recorded sound replaces it."},
}

# ---- actions -----------------------------------------------------------------------------------
# makes: still | mesh | clip | sound | check | data. recipe: needs a default recipe for the type and step.
ACTIONS: dict[str, dict] = {
    "reference": {"label": "Read the reference picture", "command": "pipeline reference ID --path P|--url U|--post U --json",
                  "inputs": "stored reference on the subject", "outputs": "{image, description, mannequin:[], traits:[], source}", "setup": "qwen3-vl", "wired": False, "makes": "still"},
    "generate": {"label": "Make pictures", "command": "pipeline still ID --step STEP --count N --json",
                 "inputs": "subject prompt layers, the step's adjusted settings, count", "outputs": "{stills:[path], prompt, seed}", "setup": "qwen-still", "wired": False, "makes": "still", "recipe": True},
    "tune": {"label": "Auto-tune a picture", "command": "pipeline tune --image P --role R --workflow W --turns N",
             "inputs": "start picture, checklist role, the step's recipe", "outputs": "{verdict, turns, review, stills:[path]}", "setup": "qwen3-vl", "wired": True, "makes": "still", "recipe": True},
    "review": {"label": "Check a picture", "command": "pipeline review --image P --role R",
               "inputs": "picture, checklist role", "outputs": "{verdict, failed:[], review}", "setup": "qwen3-vl", "wired": True, "makes": "check"},
    "frame": {"label": "Center and trim a picture", "command": "pipeline frame --image P --out P",
              "inputs": "picture", "outputs": "{out, height, canvas}", "setup": None, "wired": True, "makes": "still"},
    "proportion": {"label": "Measure proportions", "command": "pipeline proportion ID --image P|--glb G",
                   "inputs": "picture or 3D model, the subject's measures", "outputs": "{verdict, measures:{}}", "setup": None, "wired": True, "makes": "check"},
    "smooth": {"label": "Make the four body pictures", "command": "pipeline smooth ID",
               "inputs": "the subject's body measures", "outputs": "{stills:[front, left, back, right], glb}", "setup": "qwen-still", "wired": True, "makes": "still"},
    "body": {"label": "Build the 3D body", "command": "pipeline body ID",
             "inputs": "approved front and side pictures", "outputs": "{glb, verts}", "setup": "hunyuan-3d", "wired": True, "makes": "mesh"},
    "mesh": {"label": "Check the 3D model", "command": "pipeline mesh --glb G",
             "inputs": "3D model", "outputs": "{verdict, pieces, bands}", "setup": None, "wired": True, "makes": "check"},
    "edit": {"label": "Change something", "command": "pipeline edit ID --text TEXT",
             "inputs": "what should change, the kept 3D model", "outputs": "{still, glb}", "setup": "hi3d-refine", "wired": True, "makes": "mesh"},
    "variant": {"label": "Make a variant", "command": "pipeline variant ID --from P --text TEXT --json",
                "inputs": "approved picture, what should differ", "outputs": "{stills:[path]}", "setup": "qwen-edit", "wired": False, "makes": "still", "recipe": True},
    "icon": {"label": "Make the inventory icon", "command": "pipeline icon ID --json",
             "inputs": "approved picture or description", "outputs": "{stills:[icon 128 png]}", "setup": "qwen-still", "wired": False, "makes": "still", "recipe": True},
    "overlay": {"label": "Make the worn pictures", "command": "pipeline overlay ID --body female|male --json",
                "inputs": "approved item picture, character facings, offsets", "outputs": "{stills:[one per facing]}", "setup": "overlay-fit", "wired": False, "makes": "still"},
    "tile": {"label": "Make a seamless tile", "command": "pipeline tile ID --kind floor|wall|path --json",
             "inputs": "description, tile kind", "outputs": "{stills:[tile png]}", "setup": "tile-seamless", "wired": False, "makes": "still", "recipe": True},
    "wang": {"label": "Make Wang tileset", "command": "pipeline wang ID --kind seamless|wang-corner-16|wang-edge-16|blob-47 --from A --to B --size 64|128|256 --layout sheet|terrain|both --json",
             "inputs": "two approved seamless tiles (or descriptions) for the two materials, the variant, tile size, layout",
             "outputs": "{stills:[sheet png, preview png], tileset: .tres with a terrain set when the layout asks, tiles:[{index, mask}]}",
             "setup": "wang-tiles", "wired": False, "makes": "still", "recipe": True},
    "keyframes": {"label": "Make reference frames", "command": "pipeline keyframes ID --clip CLIP --json",
                  "inputs": "clip name, the step prompt", "outputs": "{clip, frames:[png], picked:[]}", "setup": "qwen-still", "wired": False, "makes": "still", "recipe": True},
    "animate": {"label": "Make the animation", "command": "pipeline animate ID --clip CLIP --dirs N --json",
                "inputs": "approved 3D model (or key picture for flat things), clip name, directions, frames", "outputs": "{clip, dirs, frames:{dir:[png]}, strip}", "setup": "motion-8dir", "wired": False, "makes": "clip"},
    "flatanim": {"label": "Make flat frames", "command": "pipeline frames ID --clip CLIP --frames N --json",
                 "inputs": "approved key picture, clip name, frame count", "outputs": "{clip, frames:[png], strip}", "setup": "frames-2d", "wired": False, "makes": "clip"},
    "pixel": {"label": "Turn into pixel art", "command": "pipeline pixel ID --image P --size 128 --json",
              "inputs": "picture or frames", "outputs": "{out, palette}", "setup": None, "wired": False, "makes": "still"},
    "sheet": {"label": "Pack the frames for the game", "command": "pipeline sheet ID --json",
              "inputs": "approved clips", "outputs": "{sheets:[png], frames:{clip:{count, columns, w, h, origin}}}", "setup": None, "wired": False, "makes": "data"},
    "sound": {"label": "Make a placeholder sound", "command": "pipeline sound ID --cue CUE --text TEXT --json",
              "inputs": "cue name, description", "outputs": "{sound, cue, placeholder:true}", "setup": "stable-audio", "wired": False, "makes": "sound"},
    "preview": {"label": "Preview in the game", "command": "shots.py / release.py capture of a temp worktree",
                "inputs": "exported subject", "outputs": "{shots:[png]}", "setup": None, "wired": False, "makes": "still"},
    "export": {"label": "Send to the game", "command": "pipeline export ID", "inputs": "every approved step", "outputs": "data/pipeline/export/TYPE/ID.json",
               "setup": None, "wired": True, "makes": "data"},
}

# Default recipes (workflow + step prompt) Build has written, keyed "type/step". None yet.
RECIPES_READY: set[str] = set()

# Seams that are not one action.
SEAMS: list[dict] = [
    {"id": "dirty-clear", "want": "Clear one hard or soft flag: `store.clear_flag(repo, id, kind, reason)` or `pipeline clear ID --hard|--soft REASON --json` returning `{subject}`.", "seam": "Backend.clear_flag"},
    {"id": "soft-dirty-clear", "want": "Clear the soft flags a regenerate acknowledged: the same call with `--soft --all`.", "seam": "Backend.clear_soft"},
    {"id": "export-bypass", "want": "Export with hard flags held: `pipeline export ID --bypass-hard` returning `{path, sections, bypassed:[reasons]}`.", "seam": "Backend.export_check"},
    {"id": "safe-cancel", "want": "Stop a model job at a safe point without killing a pid: a cancel file or `pipeline cancel JOB` that calls `stop_comfyui`.", "seam": "Backend._cli cancel"},
    {"id": "model-lock", "want": "`pipeline lock --json` returning `{family, holder, since}` so a CLI run and the studio share one model slot, and a `stop_comfyui` hook.", "seam": "Api.start_job busy check"},
    {"id": "step-locks", "want": "Adopt the studio's step rules in the CLI: `pipeline step ID STEP --finish|--reopen`; actions and section saves need every earlier step Done (a group opens together) and their own step open; a step is Done only when its needs below are met; export needs every step Done and the bypass skips neither gate. Record keys: `studio.steps`, `studio.approvals {path: {state, view, step}}` (state also `hidden`).", "seam": "Backend.require_open, Backend.set_step, Backend.export_check"},
    {"id": "step-overrides", "want": "`generate`, `tune`, `smooth`, `body`, `edit` read `studio.overrides[step]` (prompt, negative, seed, strength, steps, width, height) or take the same flags, and echo what they used.", "seam": "Backend.check_overrides"},
    {"id": "artifacts", "want": "Every command lists what it wrote in `RESULT`/`--json` with the step: `{stills:[], glbs:[], clips:[], sounds:[], review, step}`.", "seam": "Backend._cli"},
    {"id": "review-latest", "want": "`pipeline review-latest ID --json` returning `[{path, image, role, verdict, checks}]`.", "seam": "Backend.reviews"},
    {"id": "json-lists", "want": "`--json` on `pipeline list`, `show`, `status`, and `coverage`.", "seam": "Backend.list_subjects"},
    {"id": "export-sections", "want": "Export maps section fields into the contract: `stats`, `dialog`, `audio`, `rules`, `paperdoll`, and `frames`/`sheets` from packed clips; today they are written empty and the fields ride under `sections`.", "seam": "store.export_subject"},
    {"id": "wang-game", "want": "The game draws a Wang tileset where two materials meet. Today floors and walls are one seamless texture each, sampled by world position (ground_shader.gd, wall_shader.gd), and two grounds meet with a shader fade (`GroundShader.feathered`); there is no TileSet or TileMap. How it is drawn is for Build to decide: either the packed sheet is read in the ground shader by a per-cell mask, or a TileMap/terrain path is added for the flat areas.", "seam": "scripts/graphics/ground_shader.gd, scripts/world/dungeon_geo.gd, scripts/world/camp/layout_spec.gd"},
    {"id": "vfx-attach", "want": "The game places an effect at the chosen attach point (feet, aimed point, projectile tip, target, and planned hand and weapon tip). Today effects spawn at a world position with no attach-point table, and hand and weapon tip have no code path yet.", "seam": "scripts/combat/player_hit/hit_atk.gd _spawn_fx"},
]

# ---- fields ------------------------------------------------------------------------------------
def f(key: str, label: str, kind: str = "text", help: str = "", **kw) -> dict:
    return {"key": key, "label": label, "kind": kind, "help": help, **kw}


DIRS = f("directions", "Directions", "choice", "How many facings the game needs.", options=["8", "4", "1"], default="8")
RULES = f("rules", "When to use a different version", "table", "Plain rules the game checks, first match wins.",
          columns=[f("when", "When", "choice", options=["always", "equipped", "health_below", "has_item", "quest_complete"]),
                   f("value", "Which (slot:tag, 0.3, item or quest id)"), f("use", "Use this version")])
SOUNDS = f("sounds", "Sounds", "table", "Each cue the game plays. Placeholder until a recorded sound replaces it.",
           columns=[f("cue", "Cue"), f("describe", "What it sounds like"), f("recorded", "Recorded", "bool")])
NOTES = f("notes", "Notes", "long")
SUMMARY = f("summary", "What it is", "long", "One or two sentences.", required=True)
WEAPONS = ["great_axe", "staff", "longbow"]
SKILL_IDS = ["axe", "staff", "bow", "str", "mag", "rng", "def", "hp", "mine", "wood", "smith"]
# Display names exactly as the game shows them (scripts/data/locale/en.po, skill.*).
SKILL_NAMES = {"axe": "Great Axe", "staff": "Staff", "bow": "Longbow", "str": "Strength", "mag": "Magic", "rng": "Ranged", "def": "Defense",
               "hp": "Hitpoints", "mine": "Mining", "wood": "Woodcutting", "smith": "Smithing"}
# Plain step names where the store section id is not the plain word. Ids stay: they are the store and export contract.
STEP_LABELS = {"recipes": "Gather node", "interior": "Interior", "attach": "Attach points", "rooms": "Dungeon rooms"}
AFFIXES = ["dmg", "def", "hp", "crit_chance", "crit_dmg", "move_spd", "atk_spd", "atk_range", "hp_on_hit", "hp_on_kill", "gather_spd", "gather_pow", "yield_chance"]
ROSTER = ["slime", "goblin", "orc", "skeleton", "bat", "spider", "archer", "shaman", "imp", "wolf", "beetle", "wisp"]
PROPS = ["anvil", "banner", "barrel", "boss_door", "campfire", "chest", "coins", "crack_wall", "crystal", "dumpster", "extract_gate", "fence", "gate",
         "lever", "notice_board", "ore", "plate", "pot", "shrine", "sign", "stairs", "torch", "tree"]
PLAYER_CLIPS = ["idle", "idle_to_walk", "walk", "walk_to_idle", "atk_great_axe", "atk_staff", "atk_longbow", "spc_great_axe", "spc_staff", "spc_longbow",
                "gather_mine", "gather_wood", "hurt", "death", "dispel"]
ENEMY_CLIPS = ["idle", "idle_combat", "walk", "flee", "attack", "death"]
MEASURES = f("measures", "What to measure", "multi", "Checked on every body picture and 3D model.", options=["head", "thigh", "calf", "ears", "aspect"], required=True)
BANDS = f("bands", "Allowed ranges", "group", "Width ratios the proportion check allows.", fields=[
    f("front_head_min", "Front head, min", "number", step=0.01), f("front_head_max", "Front head, max", "number", step=0.01),
    f("front_thigh_max", "Front thigh, max", "number", step=0.01), f("front_calf_max", "Front calf, max", "number", step=0.01),
    f("side_head_min", "Side head, min", "number", step=0.01), f("side_head_max", "Side head, max", "number", step=0.01),
    f("side_thigh_max", "Side thigh, max", "number", step=0.01), f("side_calf_max", "Side calf, max", "number", step=0.01)])
SHAPE = f("shape", "Body shape", "long", "Plain description the pictures follow.", required=True)

BODY_ACTIONS = ["generate", "tune", "review", "frame", "proportion", "smooth", "body", "mesh", "edit"]
ART_ACTIONS = ["generate", "tune", "review", "frame", "variant", "pixel"]


# Tile set + decor used by a building interior and by a biome's dungeon rooms. Same shape; help differs.
ROOM_ACTIONS = ["generate", "tune", "review", "frame", "tile", "wang", "variant", "pixel", "sound"]
TILE_HELP = "Each is seamless. The ground draws 128 pixels per metre by default, so a 128 pixel tile repeats every metre."
WANG_KINDS = ["seamless", "wang-corner-16", "wang-edge-16", "blob-47"]

def TILES(help: str = TILE_HELP) -> dict:
    return f("tiles", "Tile set pieces", "table", help, required=True, columns=[
        f("piece", "Piece", "choice", options=["floor", "wall", "path", "roof", "other"]), f("name", "Name"),
        f("seamless", "Seamless", "bool"), f("tint", "Tint", "color")])

def WANG() -> dict:
    return f("wang", "Wang tilesets", "table",
             "Tiles that change where two materials meet, like floor to wall or grass to path. Kind is chosen per tileset: a corner or edge set is 16 tiles; blob-47 also matches inside corners.", columns=[
        f("name", "Name"), f("kind", "Kind", "choice", options=WANG_KINDS, default="wang-corner-16",
                             labels={"seamless": "Single seamless tile", "wang-corner-16": "Wang 2-corner (16)", "wang-edge-16": "Wang 2-edge (16)", "blob-47": "Blob (47)"}),
        f("from", "From material"), f("to", "To material"),
        f("size", "Tile size (pixels)", "choice", options=["64", "128", "256"], default="128"),
        f("layout", "Output", "choice", options=["sheet", "terrain", "both"], default="sheet",
          labels={"sheet": "Sheet picture", "terrain": "Godot terrain set", "both": "Sheet and Godot terrain set"})])

def DECOR(help: str, hits_help: str, *, loot: bool = False) -> dict:
    cols = [f("name", "Name"), f("decoration", "Decoration", "subject", of=["decoration"]), f("count", "How many", "number", step=1),
            f("destructible", "Breaks when hit", "bool"),
            f("hits", "Hits to break", "number", hits_help, min=1, max=20, step=1)]
    if loot:
        cols += [f("gold_chance", "Chance of gold", "number", min=0, max=1, step=0.05),
                 f("orb_chance", "Chance of a health orb", "number", min=0, max=1, step=0.05),
                 f("opens_chest", "Opens a hidden chest", "bool")]
    return f("decor", "Decor objects", "table", help, columns=cols)

def S(fields: list[dict], actions: list[str] | None = None, needs: list[str] | None = None, group: str | None = None, open_question: str | None = None) -> dict:
    return {"fields": fields, "actions": actions or [], "needs": needs or [], "group": group, "open": open_question}


def _foe(kind: str) -> dict:
    big = kind != "enemy"
    scale = {"enemy": 1, "sub-boss": 2, "boss": 4}[kind]
    steps = {
        "details": S([SUMMARY, f("family", "Family", "choice", "How it fights.", options=["melee", "ranged", "mage"], required=True),
                      f("floors", "Floors", "multi", "Floors it can appear on.", options=["1", "2", "3", "4", "5"], required=True),
                      f("draw_scale", "Drawn size", "choice", "Base size the art is made at; ship frames stay 128.", options=["1", "2", "4"], default=str(scale))]
                     + ([f("guards", "Guards", "choice", "Floor Guardian (1-4) or Gate Master (5).", options=["floor guardian", "gate master", "none"])] if big else [])),
        "description": S([f("look", "Look", "long", "The fully equipped design; this is the identity. Front and side first, then back.", required=True),
                          f("weapon", "Weapon", "text", "Weapons stay on this design."), f("palette", "Colours", "text")], ART_ACTIONS, ["pictures"]),
        "model": S([MEASURES, SHAPE, BANDS], BODY_ACTIONS, ["mesh"]),
        "portrait": S([f("crop", "Crop", "choice", options=["head", "bust", "full"], default="bust"), f("expression", "Expression", "text")], ART_ACTIONS, ["pictures"]),
        "behavior": S([f("role", "Role", "choice", options=["melee", "ranged", "mage"], required=True),
                       f("move", "Moves by", "choice", options=["walk", "hop", "fly", "float"], required=True),
                       f("temperament", "Temperament", "choice", options=["aggressive", "passive", "fearful"], default="aggressive"),
                       f("telegraph", "Wind-up", "choice", "What the player sees before an attack.", options=["wind-up then lunge", "draw then release", "charge then cast"], required=True),
                       f("arc", "Attack arc (degrees)", "number", min=0, max=360, step=1), f("size", "Body size", "number", min=0.5, max=8, step=0.05),
                       f("attack", "Attack pattern", "long", "What it does, in plain words.")]
                      + ([f("phases", "Phases", "table", "States or transformations.", columns=[f("when", "When (e.g. health below 0.5)"), f("change", "What changes")])] if big else [])
                      + [SOUNDS], ["sound"]),
        "stats": S([f("hp", "Health", "number", min=5, max=200 * scale, step=1, required=True), f("dmg", "Damage", "number", min=1, max=80, step=1, required=True),
                    f("spd", "Speed", "number", min=0.4, max=8, step=0.05, required=True), f("range", "Reach", "number", min=0.4, max=12, step=0.05, required=True),
                    f("def", "Defence", "number", min=0, max=40, step=1, required=True)]),
        "animation": S([f("clips", "Clips", "multi", "Every clip here needs an approved animation. An 8-direction walk is the minimum.", options=ENEMY_CLIPS + (["phase_change"] if big else []),
                          default=list(ENEMY_CLIPS), required=True, must=["walk"]),
                        DIRS, f("attacks", "Attacks", "table", "Different attacks can use different clips.", columns=[f("attack", "Attack"), f("clip", "Clip")]), RULES, f("direction", "Prompt for every clip", "long")],
                       ["keyframes", "animate", "pixel", "sheet", "review"], ["clips"]),
        "items": S([f("drops", "Can drop", "multi", "Each rolls its own chance per kill.", options=["gold", "hp orb", "mana orb", "gear"], required=True)]
                   + ([f("special_chest", "Special chest", "bool", "Guaranteed gear and one Artifact.", default=True)] if big else [])),
    }
    if not big:
        steps["alternates"] = S([f("swaps", "Versions by place", "table", "Colour-swapped versions that appear elsewhere, with their own attacks and behaviour.",
                                  columns=[f("where", "Where (biome or floors)"), f("colours", "Colours"), f("changes", "Attack or behaviour changes"), f("stat_scale", "Stat scale", "number", step=0.05)], required=True)],
                                ["variant", "review"], ["pictures"], group="variants")
        steps["diversity"] = S([f("hue", "Colour shift (degrees)", "number", "Subtle per-spawn colour change.", min=0, max=60, step=1, required=True),
                                f("size_min", "Smallest size", "number", min=0.5, max=1.5, step=0.05, default=0.9, required=True),
                                f("size_max", "Largest size", "number", min=0.5, max=2, step=0.05, default=1.1, required=True),
                                f("applies_to", "Also for", "multi", options=["alternates", "named"])], ["variant", "review"], [], group="variants")
        steps["named"] = S([f("scale", "Size", "number", "Named monsters are slightly larger.", min=1, max=2, step=0.05, default=1.15, required=True),
                            f("stronger", "Stronger attacks", "long", "e.g. three arrows at the normal rate.", required=True),
                            f("custom_art", "Own art", "bool", "Quest named monsters may have custom art.")],
                           ["variant", "review"], ["pictures"], group="variants")
    return steps


TYPES: dict[str, dict] = {
    "character": {"source": "design/player.md, design/content-pipeline.md, assets/sprites/player", "steps": {
        "details": S([SUMMARY, f("body_type", "Body type", "choice", "A new type needs its own locked front and side.", options=["female", "male", "new"], required=True),
                      f("voice", "Voice set", "text", "Each body type needs a full voice set.")]),
        "body": S([MEASURES, SHAPE, BANDS, f("digits", "Hands and feet", "group", fields=[f("fingers", "Fingers", "number", min=0, max=5, step=1),
                  f("thumb", "Thumb", "bool"), f("toes", "Toes", "number", min=0, max=5, step=1)]),
                   f("checks", "Optional checks", "multi", options=["breasts", "hourglass"])], BODY_ACTIONS, ["mesh"]),
        "model": S([f("pieces", "Pieces added on the model", "multi", "Later pieces go on the 3D source.", options=["eyes", "brows", "nose", "mouth", "ears", "fingers", "toes"]), NOTES],
                   BODY_ACTIONS, ["mesh"]),
        "portrait": S([f("crop", "Crop", "choice", "HUD portrait.", options=["head", "bust"], default="bust", required=True), f("expression", "Expression", "text")], ART_ACTIONS, ["pictures"]),
        "traits": S([f("categories", "What the player can change", "table", "Shared categories can be turned on per character type. Anchor is where the piece sits on this body.",
                        columns=[f("category", "Category", "choice", options=["hair", "eyes", "mouth", "nose", "brows", "ears", "head adornment", "skin tone", "bulk", "body slider"]),
                                 f("control", "Control", "choice", options=["picker", "colour", "slider"]), f("options", "Options (comma separated)"),
                                 f("on", "On for this type", "bool"), f("x", "Anchor X", "number"), f("y", "Anchor Y", "number")], required=True),
                     f("palette", "Palette", "list", "Colours the pixel finish keeps.")], ["generate", "variant", "review"], ["pictures"]),
        "defaults": S([f("presets", "Starting looks", "table", "What the player first sees. The first row is the default.",
                         columns=[f("name", "Name"), f("choices", "Choices (category: option, ...)")], required=True),
                       f("start_weapon", "Starting weapon", "choice", options=WEAPONS, required=True), f("outfit", "Default outfit", "long", "From the locked bibles: hair, neckband, coat, pants, boots.")],
                      ["generate", "review"], ["pictures"]),
        "equipment": S([f("paperdoll", "Where worn things sit", "table", "Per slot: offset, layer, scale, rotation.",
                          columns=[f("slot", "Slot", "choice", options=["weapon", "tool", "head", "body", "legs"]), f("x", "X", "number"), f("y", "Y", "number"),
                                   f("layer", "Layer", "number", step=1), f("scale", "Scale", "number", step=0.05), f("rotation", "Rotation", "number")], required=True)],
                       ["overlay", "review"], []),
        "animation": S([f("clips", "Clips", "multi", "Every clip here needs an approved animation. An 8-direction walk is the minimum.", options=PLAYER_CLIPS,
                          default=["idle", "idle_to_walk", "walk", "walk_to_idle"], required=True, must=["walk"]),
                        DIRS, RULES, f("direction", "Prompt for every clip", "long", "Character-wide details sent with every animation."),
                        f("avoid", "What to avoid in every clip", "long"), SOUNDS], ["keyframes", "animate", "pixel", "sheet", "review", "sound"], ["clips"]),
    }},
    "npc": {"source": "scripts/data/talk_lines.gd, design/hub-guild.md, design/interactables.md", "steps": {
        "details": S([SUMMARY, f("role", "Role", "choice", options=["vendor", "receptionist", "shopkeep", "ghost shop", "quest giver", "townsperson"], required=True),
                      f("where", "Where", "choice", options=["hub", "dungeon safe room", "city"], required=True), f("stationary", "Stays in place", "bool", default=True)]),
        "body": S([MEASURES, SHAPE], BODY_ACTIONS, ["mesh"]),
        "portrait": S([f("expressions", "Expressions", "multi", options=["neutral", "happy", "sad", "angry", "surprised"], default=["neutral"], required=True),
                       f("bust_cut", "Bust cut-off (0-1)", "number", "Where a window bust is clipped, e.g. 0.5.", min=0, max=1, step=0.05)], ART_ACTIONS, ["pictures"]),
        "dialog": S([f("lines", "Lines", "table", "Shown one per hub visit, never repeating until all are seen.",
                       columns=[f("key", "Text key (talk.ID.NN)"), f("text", "English text"), f("once", "First talk only", "bool"), f("when", "Only when (optional)")], required=True),
                     f("voice", "Voice", "choice", options=["text only", "text + sound"], default="text only"), SOUNDS], ["sound"]),
        "animation": S([f("clips", "Clips", "multi", "Every clip here needs an approved animation.", options=["idle", "idle_variant", "talk", "walk"], default=["idle", "talk"], required=True),
                        f("directions", "Directions", "choice", options=["1", "4", "8"], default="1")], ["animate", "pixel", "sheet", "review"], ["clips"]),
    }},
    "enemy": {"source": "scripts/combat/roster.gd, scripts/data/balance/enemies.gd, design/enemies.md", "steps": _foe("enemy")},
    "sub-boss": {"source": "design/enemies.md (Floor Guardians), design/content-pipeline.md (draw scale 2)", "steps": _foe("sub-boss")},
    "boss": {"source": "design/enemies.md (Gate Master), design/content-pipeline.md (draw scale 4)", "steps": _foe("boss")},
    "equipment": {"source": "scripts/data/gear_roll.gd, affixes.gd, item_names.gd, catalog.gd, design/skills.md, assets/ui/gear", "steps": {
        "details": S([SUMMARY, f("slot", "Slot", "choice", options=["weapon", "tool", "head", "body", "legs", "potion", "food", "artifact"], required=True),
                      f("kind", "Kind", "choice", "Weapon or tool type.", options=WEAPONS + ["pickaxe", "hatchet", "none"]),
                      f("set", "Artifact set", "choice", options=["cinder", "tide", "root", "ash", "spark", "bone", "veil", "iron", "none"]),
                      f("rarities", "Rarities", "multi", options=["white", "green", "blue"], default=["white", "green", "blue"])]),
        "skin": S([f("look", "Look", "long", required=True), f("carry", "Shown on the character", "bool", "Carry art over the body clips.", default=True)],
                  ["generate", "tune", "review", "frame", "icon", "overlay", "pixel"], ["pictures"]),
        "skills": S([f("xp", "Skills it trains", "multi", options=SKILL_IDS, labels=SKILL_NAMES, required=True), f("basic", "Basic attack", "long"), f("special", "Special", "long"),
                     f("clips", "Character clips it uses", "multi", options=[c for c in PLAYER_CLIPS if c.startswith(("atk_", "spc_", "gather_"))])], [], [], group="setup"),
        "offsets": S([f("offsets", "Placement per body and facing", "table", "Paper-doll numbers the game reads.",
                        columns=[f("body", "Body", "choice", options=["female", "male"]), f("facing", "Facing", "choice", options=["down", "down_left", "left", "up_left", "up", "up_right", "right", "down_right"]),
                                 f("x", "X", "number"), f("y", "Y", "number"), f("layer", "Layer", "number", step=1), f("scale", "Scale", "number", step=0.05), f("rotation", "Rotation", "number")], required=True)],
                     ["overlay", "review"], [], group="setup"),
        "stats": S([f("primary", "Main stat", "choice", options=["dmg", "def", "hp"], required=True), f("bonus_pool", "Bonus stats it can roll", "multi", options=AFFIXES),
                    f("charges", "Charges (potion)", "number", min=1, max=4, step=1), f("heal", "Heal", "number", min=0, max=160, step=1),
                    f("seconds", "Effect seconds", "number", min=0, max=30, step=0.5), f("cooldown", "Cooldown seconds", "number", min=0, max=12, step=0.5)], [], [], group="setup"),
        "hooks": S([f("when_used", "Shows during", "multi", options=PLAYER_CLIPS), RULES, f("vfx", "Effect it triggers", "text", "Name of a VFX subject."), SOUNDS], ["sound"]),
    }},
    "item": {"source": "design/tunables-combat.md (consumables), design/inventory-bag.md, assets/ui/gear", "steps": {
        "details": S([SUMMARY, f("kind", "Kind", "choice", options=["food", "potion", "snack", "pickup", "artifact", "material"], required=True),
                      f("stack", "Stack size", "number", min=1, max=99, step=1), f("price", "Price (gold)", "number", min=0, step=1)]),
        "art": S([f("look", "Look", "long", required=True), f("pickup", "Lies on the ground", "bool", "Needs a world picture as well as the icon.")],
                 ["generate", "tune", "review", "frame", "icon", "pixel", "sound"], ["pictures"]),
        "stats": S([f("heal", "Heal", "number", min=0, max=160, step=1), f("mana", "Mana", "number", min=0, max=100, step=1), f("seconds", "Over seconds", "number", min=0, max=30, step=0.5),
                    f("bonus", "Bonus", "choice", options=["none", "defense", "move speed", "max health"]), f("bonus_amount", "Bonus amount", "number", step=0.01), SOUNDS], ["sound"]),
    }},
    "projectile": {"source": "design/combat.md (Longbow, Lightning Staff), assets/fx/arrow.png", "steps": {
        "details": S([SUMMARY, f("source", "Fired by", "choice", options=["player weapon", "enemy"], required=True), f("by", "Which weapon or enemy", "text", required=True)]),
        "art": S([f("look", "Look", "long", required=True), f("frames", "Frames", "number", min=1, max=16, step=1, default=1), f("faces_travel", "Points where it flies", "bool", default=True)],
                 ["generate", "tune", "review", "frame", "flatanim", "pixel"], ["pictures"]),
        "motion": S([f("speed", "Speed", "number", min=0, step=0.1, required=True), f("range", "Range", "number", min=0, step=0.1, required=True),
                     f("count", "Shots per use", "number", min=1, max=12, step=1, default=1), f("spread", "Spread (degrees)", "number", min=0, max=180, step=1),
                     f("pierce", "Can glance into one more", "bool"), f("trail", "Trail effect", "text", "Name of a VFX subject."), f("hit", "Hit effect", "text", "Name of a VFX subject."), SOUNDS], ["sound"]),
    }},
    "decoration": {"source": "design/interactables.md, scripts/world/dungeon_props.gd, assets/sprites/props", "steps": {
        "details": S([SUMMARY, f("where", "Where", "multi", options=["hub", "dungeon", "safe room", "city"], required=True),
                      f("use", "What it does", "choice", options=["nothing", "breakable", "chest", "lever", "shrine", "sign", "notice board", "extract gate", "boss door", "light"], required=True),
                      f("size", "Size (metres)", "group", fields=[f("w", "Width", "number", step=0.1), f("d", "Depth", "number", step=0.1), f("h", "Height", "number", step=0.1)]),
                      f("states", "States", "list", "e.g. on, off, broken.")]),
        "art": S([f("look", "Look", "long", required=True), SOUNDS], ["generate", "tune", "review", "frame", "variant", "flatanim", "pixel", "sound"], ["pictures"]),
    }},
    "resource": {"source": "design/interactables.md, design/tunables-combat.md (Gathering), scripts/world/gather/gather_node.gd, gather/rules.gd, dungeon_props.gd, props_place.gd", "steps": {
        "details": S([SUMMARY, f("kind", "Kind", "choice", "Ore is mined with a pickaxe, wood is chopped with a hatchet.", options=["mine", "wood"], required=True)]),
        "art": S([f("look", "Look", "long", "The whole node standing in the world, before anyone has hit it.", required=True),
                  f("height", "Height (metres)", "number", "Ore is about 1.05, a tree about 1.55.", min=0.3, max=4, step=0.05)],
                 ["generate", "tune", "review", "frame", "variant", "pixel"], ["pictures"]),
        "recipes": S([
            f("tool", "Tool it needs", "choice", "The wrong tool is refused for the whole run.", options=["pickaxe", "hatchet"], required=True),
            f("skill", "Skill that helps", "choice", "Its level raises the reward chance.", options=["mine", "wood"], labels=SKILL_NAMES, required=True),
            f("hits", "Hits before it breaks", "number", "Ore takes 3 to 5, wood 6 to 10.", min=3, max=10, step=1, default=4, required=True),
            f("interval", "Seconds between hits", "number", "A faster tool shortens it. Ore 2.4, wood 1.2.", min=0.3, max=6, step=0.1, required=True),
            f("chance", "Chance each hit pays out", "number", "Ore 0.65, wood 0.32. Skill, tool and gear add to it; it never goes below 0.05 or above 0.95.", min=0.05, max=1, step=0.01, required=True),
            f("rewards", "What a hit can give", "table", "Each row rolls on a successful hit.", required=True, columns=[
                f("item", "Item", "choice", options=["ore", "wood", "gold", "root", "other"]), f("min", "Least", "number", step=1), f("max", "Most", "number", step=1),
                f("chance", "Chance", "number", min=0, max=1, step=0.01)]),
            f("xp", "Skill XP per payout", "number", min=0, max=40, step=0.5, default=6, required=True),
            f("states", "Pictures it needs", "multi", "Made from the node's art. The game flashes a hit and fades a broken node today.", options=["full", "hit", "broken", "rubble"], default=["full", "broken"], required=True),
            f("after_break", "After it breaks", "choice", "Today a broken node is gone for the rest of the floor.", options=["gone for the floor", "leaves rubble", "grows back"], default="gone for the floor", required=True),
            f("regrow", "Seconds until it grows back", "number", "Only used when it grows back. The game does not do this yet.", min=0, max=600, step=5),
            f("per_floor", "Nodes per floor", "number", "Ore 18, wood 14 in the live game.", min=1, max=40, step=1, required=True),
            f("vein", "Nodes in a vein room", "number", "A vein room is filled with one kind.", min=1, max=12, step=1),
            f("rooms", "Rooms it can stand in", "multi", "Never near the spawn, and never in safe, boss, gate or puzzle rooms.", options=["normal", "base"], default=["normal", "base"], required=True),
            f("biomes", "Biomes", "list", "One per line. Empty means the dungeon."),
            f("hit_vfx", "Effect on each hit", "subject", "A VFX subject.", of=["vfx"]),
            f("break_vfx", "Effect when it breaks", "subject", "A VFX subject.", of=["vfx"]),
            f("sounds", "Sounds", "table", "Today one cue per swing: mine or wood.", columns=[f("cue", "Cue"), f("describe", "What it sounds like"), f("recorded", "Recorded", "bool")]),
        ], ["variant", "flatanim", "pixel", "sound", "review"], ["pictures"]),
    }},
    "ui": {"source": "design/ui-style.md, design/ui-theme.md, assets/ui", "steps": {
        "details": S([SUMMARY, f("kind", "Kind", "choice", options=["panel (stretches)", "button", "icon", "HUD piece", "frame", "background"], required=True),
                      f("skin", "Skin", "choice", options=["neutral", "title", "journal", "dungeon"]),
                      f("size", "Size (px)", "group", fields=[f("w", "Width", "number", step=1), f("h", "Height", "number", step=1)])]),
        "art": S([f("look", "Look", "long", required=True), f("stretch", "Stretch edges (px)", "group", "9-slice margins for a panel or button.",
                  fields=[f("left", "Left", "number", step=1), f("top", "Top", "number", step=1), f("right", "Right", "number", step=1), f("bottom", "Bottom", "number", step=1)]), SOUNDS],
                 ["generate", "tune", "review", "frame", "pixel", "sound"], ["pictures"]),
    }},
    "biome": {"source": "design/dungeon.md, design/dungeon-gen.md, design/interactables.md, assets/tiles, scripts/world/dungeon_geo.gd, breakable.gd", "steps": {
        "details": S([SUMMARY, f("where", "Used for", "multi", options=["dungeon floors", "hub", "city", "open area"], required=True), f("floors", "Floors", "multi", options=["1", "2", "3", "4", "5"])]),
        "overview": S([f("mood", "Mood", "long", required=True), f("light", "Light", "multi", options=["torches", "crystals", "campfires", "sun"]), f("music", "Music", "text")], ["generate", "review"], ["pictures"]),
        "features": S([f("enemies", "Enemies", "multi", options=ROSTER, required=True), f("props", "Flavour props", "multi", options=PROPS), f("resources", "Resources", "multi", options=["ore", "tree"]),
                       f("traps", "Traps and puzzles", "list"), f("ghost_shop", "Ghost shop chance", "number", min=0, max=1, step=0.01, default=0.33)]),
        "art": S([f("tiles", "Tiles", "multi", options=["floor", "wall", "path", "roof"], required=True), f("palette", "Palette", "list"), WANG()], ["tile", "wang", "generate", "review", "pixel"], ["pictures"]),
        "layout": S([f("grid", "Floor size (cells)", "number", min=24, max=432, step=8, default=432), f("rooms", "Rooms", "number", min=6, max=200, step=1, default=128),
                     f("room_min", "Smallest room", "number", min=3, max=20, step=1, default=5), f("room_max", "Largest room", "number", min=3, max=30, step=1, default=9),
                     f("loops", "Extra loops", "number", min=0, max=40, step=1, default=8), f("hall_min", "Narrowest hall", "number", min=1, max=6, step=1, default=2),
                     f("hall_max", "Widest hall", "number", min=1, max=8, step=1, default=4), f("open_edges", "Open edges instead of walls", "bool"),
                     f("backdrop", "Backdrop in the empty space", "text", "e.g. a city parallax for a Sky City.")], ["generate", "review"], []),
        "rooms": S([TILES("Floor, wall and other tiles for dungeon rooms. " + TILE_HELP.split(". ", 1)[1]), WANG(),
                    DECOR("Things that stand in a dungeon room, like pots, barrels and a cracked wall. Link one to a decoration you already made.",
                          "Pots and barrels break in one. A cracked wall takes 8.", loot=True),
                    SOUNDS], ROOM_ACTIONS, ["pictures"]),
    }},
    "building": {"source": "design/hub.md, design/hub-guild.md, scripts/world/camp/layout_spec.gd", "steps": {
        "details": S([SUMMARY, f("where", "Where", "choice", options=["hub", "city"], required=True), f("use", "What happens there", "text")]),
        "art": S([f("look", "Look", "long", required=True), f("faces", "Faces drawn", "multi", options=["front", "side", "roof", "awning"], default=["front"]), WANG()],
                 ["generate", "tune", "review", "frame", "tile", "wang", "pixel"], ["pictures"]),
        "dimensions": S([f("size", "Size (metres)", "group", "Buildings are real 3D boxes.", required=True,
                           fields=[f("w", "Width", "number", step=0.1), f("d", "Depth", "number", step=0.1), f("h", "Height", "number", step=0.1)]),
                         f("roof", "Roof", "bool", default=True), f("door", "Door side", "choice", options=["south", "east", "west", "north", "none"]),
                         f("window_bust", "NPC shown in a window", "text", "Name of the NPC subject, if any.")]),
        "interior": S([TILES(), WANG(),
                       DECOR("Things that stand inside a hub or city building: a notice board, anvil, stall goods, a dumpster or a banner. Link one to a decoration you already made.",
                             "Most of these do not break. Set this only if they do."),
                       SOUNDS], ROOM_ACTIONS, ["pictures"]),
    }},
    "vfx": {"source": "design/combat.md (telegraphs, trails, crack), assets/fx", "steps": {
        "details": S([SUMMARY, f("trigger", "Plays on", "choice", options=["hit", "slam crack", "lightning strike", "arrow trail", "smash", "pickup", "level up", "telegraph", "other"], required=True)]),
        "art": S([f("look", "Look", "long", required=True), f("frames", "Frames", "number", min=1, max=24, step=1, default=6), f("fps", "Frames per second", "number", min=1, max=30, step=1, default=12),
                  f("loop", "Loops", "bool"), f("blend", "Blend", "choice", options=["normal", "add"], default="normal"), SOUNDS],
                 ["generate", "tune", "review", "flatanim", "pixel", "sheet", "sound"], ["pictures"]),
        "attach": S([
            f("points", "Attach points", "table", "Where the effect is placed when it plays.", required=True, columns=[
                f("point", "Where", "choice", "Feet: under the player. Aimed point: where the staff is aimed. Projectile tip: travels with an arrow. Target: on the enemy or breakable it hits. Hand and weapon tip are planned; the game does not support them yet.",
                  options=["feet", "aimed point", "projectile tip", "target", "hand", "weapon tip"]),
                f("flat", "Lies flat on the ground", "bool"), f("size", "Size (metres)", "number", min=0.2, max=8, step=0.1), f("lift", "Height above the ground", "number", step=0.05),
                f("fade", "Fade out (seconds)", "number", min=0, max=5, step=0.05), f("follows", "Moves with its parent", "bool")]),
        ]),
    }},
}

START = {"fields": [], "actions": ["reference"], "needs": [], "group": None, "open": None}
EXPORT = {"fields": [], "actions": ["export", "preview"], "needs": [], "group": None, "open": None}


def step_spec(subject_type: str, step: str) -> dict:
    if step == "start":
        return START
    if step == "export":
        return EXPORT
    return TYPES[subject_type]["steps"][step]


def recipe_key(subject_type: str, step: str) -> str:
    return f"{subject_type}/{step}"


def available(action: str, subject_type: str, step: str, simulated: bool) -> tuple[bool, str | None]:
    """(ok, seam). Simulate runs everything; real mode needs the action wired and, if it reads one, the step's recipe."""
    spec = ACTIONS[action]
    if simulated:
        return True, None
    if not spec["wired"]:
        return False, f"action:{action}"
    if spec.get("recipe") and recipe_key(subject_type, step) not in RECIPES_READY:
        return False, f"recipe:{recipe_key(subject_type, step)}"
    return True, None


def check() -> list[str]:
    """Problems: registry steps must match the store sections, actions and setups must exist."""
    out = []
    for t, (rows) in store.SECTIONS.items():
        want = [s for s, _ in rows]
        have = list(TYPES.get(t, {}).get("steps", {}))
        if want != have:
            out.append(f"{t}: steps {have} != store sections {want}")
    for t, spec in TYPES.items():
        for sid, st in spec["steps"].items():
            for a in st["actions"]:
                if a not in ACTIONS:
                    out.append(f"{t}/{sid}: unknown action {a}")
            if not st["fields"]:
                out.append(f"{t}/{sid}: no fields")
    for a, spec in ACTIONS.items():
        if spec["setup"] and spec["setup"] not in SETUPS:
            out.append(f"action {a}: unknown setup {spec['setup']}")
    return out


def public(simulated: bool) -> dict:
    """The registry as the page and the gap list read it."""
    types = {}
    for t in store.TYPES:
        rows = []
        for sid in ["start", *TYPES[t]["steps"], "export"]:
            st = step_spec(t, sid)
            acts = []
            for a in st["actions"]:
                ok, seam = available(a, t, sid, simulated)
                acts.append({"id": a, "ok": ok, "seam": seam, "wired": ACTIONS[a]["wired"],
                             "recipe": recipe_key(t, sid) if ACTIONS[a].get("recipe") else None})
            rows.append({"id": sid, "label": STEP_LABELS.get(sid) or sid.replace("-", " ").replace("_", " ").capitalize(), "fields": st["fields"], "actions": acts, "needs": st["needs"], "group": st["group"], "open": st["open"]})
        types[t] = {"source": TYPES[t]["source"], "steps": rows}
    return {"setups": SETUPS, "actions": ACTIONS, "types": types, "seams": SEAMS, "recipes_ready": sorted(RECIPES_READY)}
