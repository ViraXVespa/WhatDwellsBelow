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

## The same colour with another alpha (HUD draws, washes).
static func fade(col: Color, alpha: float) -> Color:
	return Color(col.r, col.g, col.b, alpha)
