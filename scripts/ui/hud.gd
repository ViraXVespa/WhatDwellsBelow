extends CanvasLayer

## Dungeon gauntlet cluster (top-left) + minimap (top-right).
## Custom ColorRects, no default ProgressBar.

const View := preload("res://scripts/ui/hud/hud_view.gd")
const Act := preload("res://scripts/ui/hud/hud_act.gd")

const STRIP_W := 452.0
const STRIP_H := 168.0
const HP_W := 270.0
const MANA_W := 270.0
const DASH_W := 110.0
const SPEC_W := 128.0
const MARGIN := 24.0
const PORTRAIT_PX := 64.0

var strip: Control
var portrait: TextureRect
var hp_fill: ColorRect
var hp_lab: Label
var mana_fill: ColorRect
var mana_lab: Label
var gem: TextureRect
var pot_icon: TextureRect
var pot_timer: TextureProgressBar
var pot_lab: Label
var dash_fill: ColorRect
var spec_fill: ColorRect
var lvl: Label
var res: Label
var floor_lab: Label
var shrine_icon: TextureRect
var shrine_lab: Label
var food_icon: TextureRect
var food_timer: TextureProgressBar
var food_lab: Label
var wound: TextureRect
var border: Control
var border_top: TextureRect
var border_bottom: TextureRect
var border_left: TextureRect
var border_right: TextureRect
var boss_wrap: Control
var boss_fill: ColorRect
var boss_lab: Label
var prompt_back: ColorRect
var prompt_row: HBoxContainer
var toast: Label
var mini_wrap: Control
var mini_frame: ColorRect
var mini_map: TextureRect
var fps_lab: Label
var look_lab: Label
var portrait_path := ""
var _wound_key := -1

var _state: Dictionary = {}
var _player: Node
var _dungeon: Node
var _lay_key := Vector3(-1.0, -1.0, -1.0)
var _chrome_key: Vector2 = Vector2(-1.0, -1.0)
var _boss: Node = null
var _boss_n := -1

func _ready() -> void:
	layer = 20
	View.build(self)

func bind_map(tex: Texture2D) -> void:
	if mini_map == null:
		return
	mini_map.texture = tex
	if is_instance_valid(_dungeon) and _dungeon.has_method("sync_map_view"):
		_dungeon.sync_map_view()

# Continuous fractions require sampling; cached static components do not repaint.
func _process(_delta: float) -> void:
	if is_instance_valid(_player) and is_instance_valid(_dungeon):
		Act.refresh(self, _player, _dungeon)

func refresh(player: Node, dungeon: Node) -> void:
	_player = player
	_dungeon = dungeon
	Act.refresh(self, player, dungeon)
