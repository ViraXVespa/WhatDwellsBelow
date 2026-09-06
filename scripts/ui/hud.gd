extends CanvasLayer

## Dungeon gauntlet cluster (top-left) + minimap (top-right).
## Custom ColorRects, no default ProgressBar.

const View := preload("res://scripts/ui/hud_view.gd")
const Act := preload("res://scripts/ui/hud_act.gd")

const STRIP_W := 540.0
const STRIP_H := 196.0
const MINI_W := 350.0
const MINI_H := 250.0
const MARGIN := 24.0

var strip: Control
var portrait: TextureRect
var hp_fill: ColorRect
var hp_lab: Label
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
var mini: TextureRect
var fps_lab: Label
var look_lab: Label
var portrait_path := ""
var _prompt_shown := ""
var _prompt_scheme := ""


func _ready() -> void:
	layer = 20
	View.build(self)


func bind_map(tex: Texture2D) -> void:
	mini.texture = tex


func refresh(player: Node, dungeon: Node) -> void:
	Act.refresh(self, player, dungeon)
