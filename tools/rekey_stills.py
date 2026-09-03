"""Re-key live stills from Grok session sources with plate_remap + sprite_pipeline."""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import i2v_seeds  # noqa: E402
import plate_remap as pr  # noqa: E402
import sprite_pipeline as sp  # noqa: E402

SESS = Path(r"C:\Users\Vira\.grok\sessions")
P4 = SESS / r"C%3A%5CUsers%5CVira%5Csource%5Crepos%5CWhatDwellsBelow\01a03e55-f390-7750-ab00-b30f1e6ba566\images"
LIVE = SESS / r"C%3A%5CUsers%5CVira%5Csource%5Crepos%5CWhatDwellsBelow\01a01c9b-e657-73d2-9eee-65d986e4e859\images"
FRAMES = ROOT / "_src" / "anim_frames"
SPR = ROOT / "assets" / "sprites"
FX = ROOT / "assets" / "fx"

DIRS = (
    "right",
    "down_right",
    "down",
    "down_left",
    "left",
    "up_left",
    "up",
    "up_right",
)
LEFT = {"left", "up_left", "down_left"}
WORK_MAX = 512
SMALL = 256
WALK_PICKS = (8, 12, 16, 20)
ATK_PICKS = (8, 18, 28, 38)


def prep(im: Image.Image) -> Image.Image:
    """Bible-style 4x NN if the still is small; cap wand cost at 512."""
    im = im.convert("RGBA")
    w, h = im.size
    if min(w, h) < SMALL:
        im = i2v_seeds.scale_nn(im, i2v_seeds.SCALE)
        w, h = im.size
    mx = max(w, h)
    if mx > WORK_MAX:
        s = WORK_MAX / mx
        im = im.resize(
            (max(1, int(round(w * s))), max(1, int(round(h * s)))),
            Image.Resampling.NEAREST,
        )
    return im


def key_still(src: Path) -> Image.Image:
    raw = prep(Image.open(src))
    remapped, _vis, _info = pr.remap(raw)
    return sp.key_to_alpha(remapped, spill_flood=True)


def fit_square(keyed: Image.Image, canvas: int) -> Image.Image:
    return sp.fit_canvas(keyed, canvas, key=False)


def fit_width(keyed: Image.Image, width: int) -> Image.Image:
    bbox = keyed.getbbox()
    if bbox is None:
        return Image.new("RGBA", (width, width), (0, 0, 0, 0))
    cropped = keyed.crop(bbox)
    scale = width / max(1, cropped.size[0])
    nw = width
    nh = max(1, int(round(cropped.size[1] * scale)))
    return cropped.resize((nw, nh), Image.Resampling.NEAREST)


def write(im: Image.Image, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest)
    print(f"wrote {dest.relative_to(ROOT)} {im.size}", flush=True)


def rekey(src: Path, dest: Path, canvas: int, wide: bool = False) -> Image.Image | None:
    if not src.exists():
        print(f"missing {src}", flush=True)
        return None
    keyed = key_still(src)
    out = fit_width(keyed, canvas) if wide else fit_square(keyed, canvas)
    write(out, dest)
    return out


def fill_dirs(down: Image.Image, dest_dir: Path, prefix: str) -> None:
    flipped = down.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    for k in DIRS:
        write(flipped if k in LEFT else down, dest_dir / f"{prefix}_{k}.png")


def fill_diags(folder: Path, pose: str) -> None:
    mapping = {
        "down_right": "down",
        "down_left": "down",
        "up_right": "up",
        "up_left": "up",
    }
    for diag, src_f in mapping.items():
        src = folder / f"{pose}_{src_f}.png"
        dest = folder / f"{pose}_{diag}.png"
        if src.exists():
            Image.open(src).save(dest)


def pack_cycle(folder: str, dest_dir: Path, prefix: str, picks: tuple[int, ...], canvas: int = 128) -> None:
    for i, fi in enumerate(picks):
        src = FRAMES / folder / f"f{fi:03d}.png"
        rekey(src, dest_dir / f"{prefix}_{i}.png", canvas)


def main() -> None:
    p4_enemies = {
        "21.jpg": "orc",
        "22.jpg": "spider",
        "23.jpg": "goblin",
        "24.jpg": "slime",
        "25.jpg": "archer",
        "26.jpg": "skeleton",
        "27.jpg": "shaman",
        "28.jpg": "bat",
        "29.jpg": "gate_master",
        "30.jpg": "imp",
        "31.jpg": "wolf",
        "32.jpg": "wisp",
        "33.jpg": "beetle",
        "34.jpg": "guardian",
    }
    for name, typ in p4_enemies.items():
        dest_dir = SPR / "enemies" / typ
        im = rekey(P4 / name, dest_dir / "idle_down.png", 128)
        if im is not None:
            fill_dirs(im, dest_dir, "idle")

    squares: list[tuple[Path, Path, int]] = [
        (P4 / "15.jpg", SPR / "player" / "male" / "equip_great_axe_down.png", 128),
        (P4 / "9.jpg", SPR / "player" / "male" / "equip_staff_down.png", 128),
        (P4 / "16.jpg", SPR / "player" / "male" / "equip_longbow_down.png", 128),
        (P4 / "17.jpg", SPR / "player" / "male" / "equip_great_axe_right.png", 128),
        (P4 / "20.jpg", SPR / "player" / "male" / "equip_great_axe_up.png", 128),
        (P4 / "14.jpg", SPR / "player" / "female" / "equip_great_axe_down.png", 128),
        (P4 / "18.jpg", SPR / "player" / "female" / "equip_staff_down.png", 128),
        (P4 / "19.jpg", SPR / "player" / "female" / "equip_longbow_down.png", 128),
        (P4 / "12.jpg", FX / "dummy.png", 128),
        (P4 / "11.jpg", FX / "arrow.png", 128),
        (P4 / "10.jpg", FX / "lightning.png", 128),
        (P4 / "13.jpg", FX / "crack.png", 128),
        (LIVE / "105.jpg", SPR / "npcs" / "vendor.png", 128),
        (LIVE / "113.jpg", SPR / "npcs" / "receptionist.png", 128),
        (LIVE / "124.jpg", SPR / "npcs" / "miner.png", 128),
        (LIVE / "130.jpg", SPR / "npcs" / "shopkeep.png", 128),
        (LIVE / "132.jpg", SPR / "npcs" / "runner.png", 128),
        (LIVE / "133.jpg", SPR / "npcs" / "gopher.png", 128),
        (LIVE / "134.jpg", SPR / "npcs" / "stonemason.png", 128),
        (LIVE / "135.jpg", SPR / "npcs" / "lumberjack.png", 128),
        (LIVE / "136.jpg", SPR / "npcs" / "alchemist.png", 128),
        (LIVE / "137.jpg", SPR / "npcs" / "fishmonger.png", 128),
        (LIVE / "138.jpg", SPR / "npcs" / "patty.png", 128),
        (LIVE / "117.jpg", SPR / "props" / "crystal.png", 128),
        (LIVE / "121.jpg", SPR / "props" / "anvil.png", 128),
        (LIVE / "120.jpg", SPR / "props" / "tree.png", 128),
        (LIVE / "125.jpg", SPR / "props" / "fence.png", 128),
        (LIVE / "149.jpg", SPR / "props" / "gate.png", 128),
        (LIVE / "150.jpg", SPR / "props" / "dumpster.png", 128),
        (LIVE / "151.jpg", SPR / "props" / "ore.png", 128),
        (LIVE / "152.jpg", SPR / "props" / "campfire.png", 128),
        (LIVE / "157.jpg", SPR / "props" / "sign.png", 128),
        (LIVE / "160.jpg", SPR / "props" / "notice_board.png", 128),
        (LIVE / "156.jpg", SPR / "props" / "pot.png", 96),
        (LIVE / "162.jpg", SPR / "props" / "barrel.png", 96),
        (LIVE / "164.jpg", SPR / "props" / "bush.png", 128),
        (LIVE / "167.jpg", SPR / "props" / "banner.png", 128),
        (LIVE / "166.jpg", SPR / "props" / "bolt.png", 48),
        (LIVE / "163.jpg", SPR / "props" / "hp_orb.png", 48),
        (LIVE / "1.jpg", SPR / "props" / "mana_orb.png", 48),
        (LIVE / "139.jpg", SPR / "props" / "chest.png", 128),
        (LIVE / "140.jpg", SPR / "props" / "stairs.png", 128),
        (LIVE / "107.jpg", SPR / "player" / "down.png", 128),
        (LIVE / "118.jpg", SPR / "player" / "right.png", 128),
        (LIVE / "116.jpg", SPR / "player" / "up.png", 128),
        (LIVE / "190.jpg", SPR / "player" / "left.png", 128),
        (LIVE / "189.jpg", SPR / "player" / "down_left.png", 128),
        (LIVE / "129.jpg", SPR / "player" / "down_right.png", 128),
        (LIVE / "188.jpg", SPR / "player" / "up_left.png", 128),
        (LIVE / "127.jpg", SPR / "player" / "up_right.png", 128),
    ]
    for src, dest, canvas in squares:
        rekey(src, dest, canvas)

    banner = SPR / "props" / "banner.png"
    if banner.exists():
        Image.open(banner).save(SPR / "props" / "welcome_banner.png")
        print("copied welcome_banner", flush=True)

    for name, dest, width in (
        ("111.jpg", SPR / "buildings" / "guild.png", 320),
        ("119.jpg", SPR / "buildings" / "stall.png", 320),
        ("112.jpg", SPR / "buildings" / "guild_reception.png", 360),
    ):
        rekey(LIVE / name, dest, width, wide=True)

    axe_right = SPR / "player" / "male" / "equip_great_axe_right.png"
    if axe_right.exists():
        Image.open(axe_right).transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(
            SPR / "player" / "male" / "equip_great_axe_left.png"
        )
    for gender in ("male", "female"):
        for wpn in ("great_axe", "staff", "longbow"):
            down = SPR / "player" / gender / f"equip_{wpn}_down.png"
            if not down.exists():
                continue
            src_im = Image.open(down)
            for k in DIRS:
                p = SPR / "player" / gender / f"equip_{wpn}_{k}.png"
                if not p.exists():
                    src_im.save(p)

    combat = {
        "bruiser": {
            "idle": {"down": "115.jpg", "left": "153.jpg", "right": "155.jpg", "up": "154.jpg"},
            "windup": {"down": "141.jpg", "left": "174.jpg", "right": "170.jpg", "up": "175.jpg"},
            "strike": {"down": "142.jpg", "left": "173.jpg", "right": "172.jpg", "up": "171.jpg"},
        },
        "ranged": {
            "idle": {"down": "122.jpg", "left": "161.jpg", "right": "159.jpg", "up": "158.jpg"},
            "windup": {"down": "147.jpg", "left": "177.jpg", "right": "176.jpg", "up": "180.jpg"},
            "strike": {"down": "146.jpg", "left": "181.jpg", "right": "178.jpg", "up": "179.jpg"},
        },
        "tank": {
            "idle": {"down": "123.jpg", "left": "165.jpg", "right": "168.jpg", "up": "169.jpg"},
            "windup": {"down": "144.jpg", "left": "187.jpg", "right": "184.jpg", "up": "185.jpg"},
            "strike": {"down": "148.jpg", "left": "183.jpg", "right": "182.jpg", "up": "186.jpg"},
        },
    }
    for role, poses in combat.items():
        folder = SPR / "enemies" / role
        for pose, facings in poses.items():
            for facing, jpg in facings.items():
                rekey(LIVE / jpg, folder / f"{pose}_{facing}.png", 128)
            fill_diags(folder, pose)
        for facing in ("down", "left", "right", "up"):
            pack_cycle(f"{role}_walk_{facing}", folder, f"walk_{facing}", WALK_PICKS, 128)

    player = SPR / "player"
    for facing in DIRS:
        pack_cycle(f"player_walk_{facing}", player, f"walk_{facing}", WALK_PICKS, 128)
        pack_cycle(f"player_attack_{facing}", player, f"attack_{facing}", ATK_PICKS, 128)

    print("rekey stills done", flush=True)


if __name__ == "__main__":
    main()
