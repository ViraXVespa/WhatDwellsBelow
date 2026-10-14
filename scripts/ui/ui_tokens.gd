extends Object

## Shared tokens of the ink-and-paper UI: colours and outline weights, named once.
## Edit a value here, rebuild the screen, and every builder that names it follows.
## ThemeS (theme.gd) forwards these names; object frames keep their own material palette in their own script.

const INK: Color = Color(0.24, 0.15, 0.09)
const INK_SOFT: Color = Color(0.40, 0.28, 0.18)
const INK_FAINT: Color = Color(0.52, 0.40, 0.30)
const PAPER: Color = Color(0.95, 0.90, 0.80, 0.98)
const PAPER_DEEP: Color = Color(0.84, 0.76, 0.62, 1.0)
const PAPER_HOVER: Color = Color(0.90, 0.83, 0.70, 1.0)
const PAPER_LIFT: Color = Color(0.98, 0.95, 0.88, 1.0)
const RULE: Color = Color(0.45, 0.32, 0.20, 1.0)
const RULE_QUIET: Color = Color(0.45, 0.32, 0.20, 0.40)
const DANGER: Color = Color(0.55, 0.16, 0.11)
const DANGER_RULE: Color = Color(0.58, 0.24, 0.16)
const BTN_PAPER: Color = Color(0.93, 0.86, 0.72, 0.96)
const BTN_HOVER: Color = Color(0.98, 0.94, 0.86, 1.0)
const OUTLINE: Color = Color(0.05, 0.03, 0.02)
const OUTLINE_SIZE: int = 6
const PROMPT_OUTLINE_SIZE: int = 5
const CLEAR: Color = Color(0, 0, 0, 0)
## Tappable hint chips (prompt_chip.gd): a modulate over the chip's own glyph and word, so it suits any frame.
const CHIP_REST: Color = Color(1, 1, 1, 1)
const CHIP_HOVER: Color = Color(1.18, 1.12, 1.02, 1)
const CHIP_PRESS: Color = Color(0.72, 0.66, 0.58, 1)

## The same colour with another alpha (HUD draws, washes).
static func fade(col: Color, alpha: float) -> Color:
	return Color(col.r, col.g, col.b, alpha)

## Control skins outside the pause journal (btn_skin.gd paints them; the journal keeps the paper look above).
## Keys: fill/hover/press/off (button faces), edge/edge_hi/edge_off, glow (focus ring), word/word_hi/word_off,
## words (ink, soft, faint on panels) / panel / panel_edge: tooltips, pickers, confirms (BtnSkin "panel").
## primary_fill/primary_edge, danger_edge/danger_word, slot/slot_edge (gear slot face: light, so item art reads), ring (focus edge width, default 2). "words"/"panel"/"panel_edge" make a
## skin recolour ink labels and plates too (title screens).
const SKIN_NEUTRAL: Dictionary = {
	"fill": Color(0.19, 0.14, 0.105, 0.97), "hover": Color(0.27, 0.20, 0.14, 1.0), "press": Color(0.12, 0.09, 0.07, 1.0),
	"off": Color(0.15, 0.13, 0.11, 0.75), "edge": Color(0.50, 0.38, 0.21), "edge_hi": Color(0.80, 0.62, 0.32),
	"edge_off": Color(0.32, 0.27, 0.22, 0.8), "glow": Color(1.0, 0.84, 0.42), "word": Color(0.93, 0.86, 0.69),
	"word_hi": Color(1.0, 0.96, 0.82), "word_off": Color(0.55, 0.50, 0.44), "primary_fill": Color(0.30, 0.19, 0.10, 0.98),
	"primary_edge": Color(0.86, 0.66, 0.30), "danger_edge": Color(0.72, 0.30, 0.20), "danger_word": Color(1.0, 0.74, 0.64),
	"slot": Color(0.84, 0.76, 0.62, 0.92), "slot_edge": Color(0.45, 0.32, 0.20), "radius": 4,
	"words": [Color(0.96, 0.90, 0.74), Color(0.86, 0.78, 0.62), Color(0.66, 0.58, 0.46)],
	"panel": Color(0.10, 0.075, 0.055, 1.0), "panel_edge": Color(0.70, 0.54, 0.27),
}
const SKIN_TITLE: Dictionary = {
	"fill": Color(0.13, 0.095, 0.075, 0.94), "hover": Color(0.22, 0.15, 0.10, 0.97), "press": Color(0.08, 0.06, 0.05, 0.97),
	"off": Color(0.12, 0.10, 0.09, 0.7), "edge": Color(0.62, 0.47, 0.24), "edge_hi": Color(0.90, 0.72, 0.38),
	"edge_off": Color(0.32, 0.27, 0.22, 0.8), "glow": Color(1.0, 0.86, 0.48), "word": Color(0.96, 0.90, 0.74),
	"word_hi": Color(1.0, 0.97, 0.86), "word_off": Color(0.55, 0.50, 0.44), "primary_fill": Color(0.34, 0.13, 0.09, 0.96),
	"primary_edge": Color(0.92, 0.72, 0.36), "danger_edge": Color(0.72, 0.30, 0.20), "danger_word": Color(1.0, 0.74, 0.64),
	"slot": Color(0.84, 0.76, 0.62, 0.92), "slot_edge": Color(0.62, 0.47, 0.24), "radius": 3,
	"words": [Color(0.96, 0.90, 0.74), Color(0.84, 0.76, 0.60), Color(0.66, 0.58, 0.46)],
	"panel": Color(0.085, 0.065, 0.05, 0.94), "panel_edge": Color(0.62, 0.47, 0.24),
}
const SKIN_CRYSTAL: Dictionary = {
	"fill": Color(0.05, 0.24, 0.30, 0.90), "hover": Color(0.09, 0.36, 0.44, 0.95), "press": Color(0.03, 0.15, 0.19, 0.95),
	"off": Color(0.12, 0.30, 0.35, 0.55), "edge": Color(0.36, 0.80, 0.90), "edge_hi": Color(0.70, 0.98, 1.0),
	"edge_off": Color(0.30, 0.58, 0.66, 0.8), "glow": Color(1.0, 0.45, 0.75), "ring": 3, "word": Color(0.88, 1.0, 1.0),
	"word_hi": Color(1.0, 1.0, 1.0), "word_off": Color(0.80, 0.92, 0.94), "primary_fill": Color(0.05, 0.24, 0.30, 0.90),
	"primary_edge": Color(0.36, 0.80, 0.90), "danger_edge": Color(0.93, 0.30, 0.30), "danger_word": Color(1.0, 0.78, 0.78),
	"slot": Color(0.86, 0.98, 1.0, 0.85), "slot_edge": Color(0.20, 0.62, 0.74), "radius": 3,
	"words": [Color(0.92, 1.0, 1.0), Color(0.76, 0.92, 0.95), Color(0.56, 0.74, 0.78)],
	"panel": Color(0.03, 0.15, 0.19, 1.0), "panel_edge": Color(0.36, 0.80, 0.90),
}
const SKINS: Dictionary = {"neutral": SKIN_NEUTRAL, "title": SKIN_TITLE, "crystal": SKIN_CRYSTAL}
