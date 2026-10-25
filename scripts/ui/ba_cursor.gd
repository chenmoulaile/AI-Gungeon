extends Node
## 像素光标（Autoload: BaCursor）
## 用真实 16x16 贴图作为系统光标：菜单=箭头，战斗=十字准星；悬停可交互元素时变金色。
## 不再自绘准星——旧做法把系统光标涂成 1x1 透明，一旦自绘层失败就“完全没有鼠标”。

const TEX_ARROW := "res://assets/ui/cursor_arrow.png"
const TEX_ARROW_HOT := "res://assets/ui/cursor_arrow_hot.png"
const TEX_CROSS := "res://assets/ui/cursor_cross.png"
const TEX_CROSS_HOT := "res://assets/ui/cursor_cross_hot.png"

const SHAPES := [
	Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_IBEAM,
	Input.CURSOR_CROSS, Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP,
	Input.CURSOR_MOVE, Input.CURSOR_WAIT,
]

var _tex: Dictionary = {}
var _battle: bool = false
var _hot: bool = false
var _forced: float = 0.0
var _shown: bool = true
var _applied_key: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_tex()
	_apply()


func _ensure_tex() -> void:
	for path in [TEX_ARROW, TEX_ARROW_HOT, TEX_CROSS, TEX_CROSS_HOT]:
		var n: String = path.get_file().get_basename()
		if _tex.has(n):
			continue
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path) as Texture2D
			if tex != null:
				_tex[n] = tex


## 战斗 / 菜单两种光标
func set_battle(on: bool) -> void:
	_battle = on
	_apply()


## 卡片等自绘区域用：每帧调用即可保持高亮
func force_hot(on: bool = true) -> void:
	if on:
		_forced = 0.06


func set_shown(on: bool) -> void:
	_shown = on
	_apply()


func _process(delta: float) -> void:
	_forced = maxf(0.0, _forced - delta)
	var hc := get_viewport().gui_get_hovered_control()
	var over_ui := hc != null and is_instance_valid(hc) and hc.is_visible_in_tree() \
		and (hc.is_in_group("ui_hotspot") or hc.has_meta("hot"))
	_hot = over_ui or _forced > 0.0
	_apply()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed and _hot:
			Sfx.play("ui_confirm", -10.0)


func _apply() -> void:
	var key := "%s|%s|%s" % [_battle, _hot, _shown]
	if key == _applied_key:
		return
	if DisplayServer.get_name() == "headless":
		return
	if not _shown:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		_applied_key = key
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _tex.is_empty():
		_ensure_tex()
	var tex_name := ("cross" if _battle else "arrow") + ("_hot" if _hot else "")
	var tex: Texture2D = _tex.get(tex_name)
	if tex == null:
		tex = _tex.get("arrow")
	if tex == null:
		# 贴图未就绪时保持系统默认光标，且不记录 key，下一帧继续重试
		return
	_applied_key = key
	var hotspot := Vector2(8, 8) if _battle else Vector2(1, 1)
	for shape in SHAPES:
		Input.set_custom_mouse_cursor(tex, shape, hotspot)
