extends CanvasLayer

## Dungeon gauntlet cluster (top-left) + minimap (top-right).
## Custom ColorRects, no default ProgressBar.

const View := preload("res://scripts/ui/hud/hud_view.gd")
const Act := preload("res://scripts/ui/hud/hud_act.gd")

const STRIP_W := 640.0
const STRIP_H := 210.0
const HP_W := 280.0
const MANA_W := 280.0
const POT_W := 120.0
const DASH_W := 112.0
const SPEC_W := 112.0
const MINI_W := 350.0
const MINI_H := 250.0
const MARGIN := 24.0

var strip: Control
var portrait: TextureRect
var hp_fill: ColorRect
var hp_lab: Label
var mana_fill: ColorRect
var mana_lab: Label
var gem: TextureRect
var pot_icon: TextureRect
var pot_fill: ColorRect
var pot_lab: Label
var dash_fill: ColorRect
var spec_fill: ColorRect
var lvl: Label
var res: Label
var floor_lab: Label
var shrine_icon: TextureRect
var shrine_lab: Label
var food_icon: TextureRect
var food_lab: Label
var boss_wrap: Control
var boss_fill: ColorRect
var boss_lab: Label
var prompt_row: HBoxContainer
var toast: Label
var mini_wrap: Control
var mini_map: TextureRect
var fps_lab: Label
var look_lab: Label
var portrait_path := ""

var _prompt_shown := ""
var _prompt_scheme := ""
var _lay_key := Vector3(-1.0, -1.0, -1.0)
var _txt_key: Array = []
var _boss: Node = null
var _boss_n := -1

func _ready() -> void:
	layer = 20
	View.build(self)

func bind_map(tex: Texture2D) -> void:
	if mini_map:
		mini_map.texture = tex

func refresh(player: Node, dungeon: Node) -> void:
	Act.refresh(self, player, dungeon)
