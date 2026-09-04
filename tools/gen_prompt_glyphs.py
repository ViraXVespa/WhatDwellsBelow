#!/usr/bin/env python3
"""Chunky pixel prompt glyphs. Run from repo root:

    python tools/gen_prompt_glyphs.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "assets" / "ui" / "prompts"

INK = (16, 12, 8, 255)
FACE = (220, 204, 158, 255)
EDGE = (86, 64, 34, 255)
GLYPH = (22, 16, 10, 255)
PAD = (22, 22, 24, 255)
PAD_EDGE = (8, 8, 8, 255)
PAD_LIT = (236, 236, 230, 255)
PAD_DIM = (70, 70, 74, 255)
PAD_A = (42, 160, 78, 255)
PAD_B = (196, 48, 48, 255)
PAD_X = (48, 104, 196, 255)
PAD_Y = (214, 178, 42, 255)
DPAD_DISC = (168, 168, 172, 255)
DPAD_ARM = (28, 28, 30, 255)
DPAD_ARM_LIT = (78, 78, 82, 255)
CHEV_Y = (255, 214, 48, 255)
CHEV_O = (236, 118, 24, 255)
MOUSE_HOT = (42, 168, 72, 255)
MOUSE_GLOW = (110, 230, 130, 160)
CLEAR = (0, 0, 0, 0)

FONT = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01110"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "J": ["00111", "00001", "00001", "00001", "00001", "10001", "01110"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    "=": ["00000", "11111", "00000", "00000", "11111", "00000", "00000"],
    ",": ["00000", "00000", "00000", "00000", "00100", "00100", "01000"],
    ".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
    "[": ["01110", "01000", "01000", "01000", "01000", "01000", "01110"],
    "]": ["01110", "00010", "00010", "00010", "00010", "00010", "01110"],
}


def blank(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), CLEAR)


def px(img: Image.Image, x: int, y: int, c) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def fill_rect(img: Image.Image, x: int, y: int, w: int, h: int, c) -> None:
    ImageDraw.Draw(img).rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def outline_rect(img: Image.Image, x: int, y: int, w: int, h: int, c) -> None:
    ImageDraw.Draw(img).rectangle([x, y, x + w - 1, y + h - 1], outline=c)


def stamp(img: Image.Image, text: str, cx: int, cy: int, scale: int = 2, col=GLYPH) -> None:
    glyphs = []
    for ch in text.upper():
        if ch == " ":
            continue
        g = FONT.get(ch)
        if g:
            glyphs.append(g)
    if not glyphs:
        return
    total = len(glyphs) * 5 + max(0, len(glyphs) - 1)
    x = cx - (total * scale) // 2
    y0 = cy - (7 * scale) // 2
    for g in glyphs:
        for row, bits in enumerate(g):
            for col_i, bit in enumerate(bits):
                if bit != "1":
                    continue
                for oy in range(scale):
                    for ox in range(scale):
                        px(img, x + col_i * scale + ox, y0 + row * scale + oy, col)
        x += 6 * scale


def key_body(w: int, h: int) -> Image.Image:
    img = blank(w, h)
    fill_rect(img, 1, 1, w - 2, h - 2, FACE)
    outline_rect(img, 0, 0, w, h, EDGE)
    outline_rect(img, 1, 1, w - 2, h - 2, INK)
    fill_rect(img, 3, h - 4, w - 6, 2, EDGE)
    return img


def wide_key(label: str, w: int = 52, h: int = 28, scale: int = 2) -> Image.Image:
    img = key_body(w, h)
    stamp(img, label, w // 2, h // 2 - 1, scale)
    return img


def letter_key(label: str) -> Image.Image:
    return wide_key(label, 28, 28)


def space_key() -> Image.Image:
    img = wide_key("", 72, 24)
    fill_rect(img, 14, 11, 44, 3, INK)
    return img


def _mouse_hot(which: str, col, inflate: int = 0) -> Image.Image:
    w, h = 41, 60
    layer = blank(w, h)
    d = ImageDraw.Draw(layer)
    box = [6 - inflate, 2 - inflate, 34 + inflate, 57 + inflate]
    d.rounded_rectangle(box, radius=12 + inflate, fill=col)
    split = 20
    cut_y = 26 + inflate
    for y in range(max(0, cut_y + 1), h):
        for x in range(w):
            layer.putpixel((x, y), CLEAR)
    if which == "l":
        for y in range(h):
            for x in range(split, w):
                layer.putpixel((x, y), CLEAR)
    elif which == "r":
        for y in range(h):
            for x in range(0, split):
                layer.putpixel((x, y), CLEAR)
    else:
        layer = blank(w, h)
        d = ImageDraw.Draw(layer)
        d.ellipse([14 - inflate, 6 - inflate, 26 + inflate, 24 + inflate], fill=col)
    return layer


def mouse(which: str) -> Image.Image:
    w, h = 41, 60
    img = blank(w, h)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([6, 2, 34, 57], radius=12, fill=FACE, outline=EDGE, width=2)
    glow = _mouse_hot(which, MOUSE_GLOW, 2)
    hot = _mouse_hot(which, MOUSE_HOT, 0)
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, hot)
    d = ImageDraw.Draw(img)
    d.line([(20, 4), (20, 26)], fill=INK, width=2)
    d.line([(7, 26), (33, 26)], fill=INK, width=2)
    d.rounded_rectangle([16, 8, 24, 22], radius=3, fill=EDGE, outline=INK)
    if which == "m":
        d.rounded_rectangle([16, 8, 24, 22], radius=3, fill=MOUSE_HOT, outline=INK)
    return img


def pad_round(letter: str, col) -> Image.Image:
    w = h = 32
    img = blank(w, h)
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, w - 2, h - 2], fill=col, outline=PAD_EDGE)
    stamp(img, letter, w // 2, h // 2, 2, INK)
    return img


def pad_trigger(label: str, right: bool) -> Image.Image:
    w, h = 40, 32
    img = blank(w, h)
    d = ImageDraw.Draw(img)
    if right:
        pts = [(6, 12), (38, 2), (38, 30), (6, 26)]
    else:
        pts = [(2, 2), (34, 12), (34, 26), (2, 30)]
    d.polygon(pts, fill=PAD, outline=PAD_EDGE)
    stamp(img, label, w // 2 + (2 if right else -2), h // 2 + 2, 2, PAD_LIT)
    return img


def pad_bumper(label: str) -> Image.Image:
    w, h = 44, 20
    img = blank(w, h)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1, 1, w - 2, h - 2], radius=4, fill=PAD, outline=PAD_EDGE)
    stamp(img, label, w // 2, h // 2, 2, PAD_LIT)
    return img


def stick(label: str) -> Image.Image:
    w = h = 40
    img = blank(w, h)
    d = ImageDraw.Draw(img)
    d.ellipse([2, 2, 37, 37], fill=PAD, outline=PAD_EDGE)
    d.ellipse([10, 10, 29, 29], fill=PAD_DIM, outline=PAD_LIT)
    d.ellipse([16, 16, 23, 23], fill=PAD_LIT)
    stamp(img, label, w // 2, 34, 1, PAD_LIT)
    return img


def _chevron(img: Image.Image, lit: str) -> None:
    if lit == "up":
        pts_o = [(22, 6), (26, 12), (18, 12)]
        pts_y = [(22, 7), (25, 11), (19, 11)]
    elif lit == "down":
        pts_o = [(22, 38), (26, 32), (18, 32)]
        pts_y = [(22, 37), (25, 33), (19, 33)]
    elif lit == "left":
        pts_o = [(6, 22), (12, 18), (12, 26)]
        pts_y = [(7, 22), (11, 19), (11, 25)]
    else:
        pts_o = [(38, 22), (32, 18), (32, 26)]
        pts_y = [(37, 22), (33, 19), (33, 25)]
    d = ImageDraw.Draw(img)
    d.polygon(pts_o, fill=CHEV_O)
    d.polygon(pts_y, fill=CHEV_Y)


def dpad(lit: str) -> Image.Image:
    w = h = 45
    img = blank(w, h)
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, 43, 43], fill=DPAD_DISC, outline=PAD_EDGE)
    fill_rect(img, 16, 4, 13, 37, DPAD_ARM)
    fill_rect(img, 4, 16, 37, 13, DPAD_ARM)
    cx, cy = 22, 22
    if lit == "up":
        d.polygon([(cx, cy), (16, 16), (28, 16)], fill=DPAD_ARM_LIT)
        fill_rect(img, 16, 4, 13, 13, DPAD_ARM_LIT)
    elif lit == "down":
        d.polygon([(cx, cy), (16, 28), (28, 28)], fill=DPAD_ARM_LIT)
        fill_rect(img, 16, 28, 13, 13, DPAD_ARM_LIT)
    elif lit == "left":
        d.polygon([(cx, cy), (16, 16), (16, 28)], fill=DPAD_ARM_LIT)
        fill_rect(img, 4, 16, 13, 13, DPAD_ARM_LIT)
    else:
        d.polygon([(cx, cy), (28, 16), (28, 28)], fill=DPAD_ARM_LIT)
        fill_rect(img, 28, 16, 13, 13, DPAD_ARM_LIT)
    _chevron(img, lit)
    return img


def menu_btn() -> Image.Image:
    w, h = 40, 24
    img = blank(w, h)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1, 1, w - 2, h - 2], radius=6, fill=PAD, outline=PAD_EDGE)
    for y in (7, 11, 15):
        fill_rect(img, 12, y, 16, 2, PAD_LIT)
    return img


def view_btn() -> Image.Image:
    w, h = 40, 24
    img = blank(w, h)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1, 1, w - 2, h - 2], radius=6, fill=PAD, outline=PAD_EDGE)
    d.rectangle([10, 6, 22, 16], outline=PAD_LIT)
    d.rectangle([16, 9, 28, 19], outline=PAD_LIT)
    return img


def save(img: Image.Image, folder: str, name: str) -> None:
    dest = ROOT / folder
    dest.mkdir(parents=True, exist_ok=True)
    img.save(dest / f"{name}.png")


def save_aliases(img: Image.Image, folder: str, names: list[str]) -> None:
    for name in names:
        save(img, folder, name)


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    for ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
        save(letter_key(ch), "kb", ch.lower())
    save_aliases(wide_key("ESC", 44, 28), "kb", ["esc", "escape"])
    save(wide_key("TAB", 44, 28), "kb", "tab")
    save(wide_key("SHFT", 56, 28), "kb", "shift")
    save(wide_key("CTRL", 56, 28), "kb", "ctrl")
    save(wide_key("ALT", 44, 28), "kb", "alt")
    save(wide_key("BKSP", 56, 28), "kb", "backspace")
    save(wide_key("DEL", 40, 28), "kb", "del")
    save(wide_key("ENTER", 64, 28), "kb", "enter")
    save(space_key(), "kb", "space")
    save(wide_key("PGUP", 52, 28), "kb", "pageup")
    save(wide_key("PGDN", 52, 28), "kb", "pagedown")
    save(wide_key("-", 28, 28), "kb", "minus")
    save(wide_key("=", 28, 28), "kb", "equal")
    save(wide_key(",", 28, 28), "kb", "comma")
    save(wide_key(".", 28, 28), "kb", "period")
    save_aliases(wide_key("[", 28, 28), "kb", ["lbracket", "bracketleft"])
    save_aliases(wide_key("]", 28, 28), "kb", ["rbracket", "bracketright"])
    save(letter_key("<"), "kb", "left")
    save(letter_key(">"), "kb", "right")
    save(wide_key("UP", 28, 28), "kb", "up")
    save(wide_key("DN", 28, 28), "kb", "down")
    save(mouse("l"), "mouse", "lmb")
    save(mouse("r"), "mouse", "rmb")
    save(mouse("m"), "mouse", "mmb")
    save(pad_round("A", PAD_A), "pad", "a")
    save(pad_round("B", PAD_B), "pad", "b")
    save(pad_round("X", PAD_X), "pad", "x")
    save(pad_round("Y", PAD_Y), "pad", "y")
    save(pad_trigger("LT", False), "pad", "lt")
    save(pad_trigger("RT", True), "pad", "rt")
    save(pad_bumper("LB"), "pad", "lb")
    save(pad_bumper("RB"), "pad", "rb")
    save(stick("LS"), "pad", "ls")
    save(stick("RS"), "pad", "rs")
    save(menu_btn(), "pad", "menu")
    save(view_btn(), "pad", "view")
    save(dpad("up"), "pad", "dpad_up")
    save(dpad("down"), "pad", "dpad_down")
    save(dpad("left"), "pad", "dpad_left")
    save(dpad("right"), "pad", "dpad_right")
    for stale in ("start", "l3", "r3"):
        p = ROOT / "pad" / f"{stale}.png"
        if p.exists():
            p.unlink()
    print("wrote", ROOT)


if __name__ == "__main__":
    main()