extends CanvasLayer
## 像素准星（Autoload: BaCursor）：1px 十字 + 四角括号，不旋转、不画圆弧。
## 悬停可交互元素时变金色并加粗 1px；射击时十字外扩 2px。

const COLD := Color("#8A9BB8")
const HOT := Color("#FFD166")
const CORE := Color("#DCE7FF")

var _drawer: Node2D = null
var _hot: bool = false
var _forced: float = 0.0
var _battle: bool = false
var _click: float = 0.0
var _visible: bool = true


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_drawer = Node2D.new()
	_drawer.name = "CursorDraw"
	add_child(_drawer)
	_drawer.draw.connect(_on_draw)
	_hide_system_cursor()
	visible = true


func _hide_system_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_IBEAM,
			Input.CURSOR_CROSS, Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP]:
		Input.set_custom_mouse_cursor(img, shape, Vector2.ZERO)


## 战斗 / 菜单两种尺寸
func set_battle(on: bool) -> void:
	_battle = on


## 卡片等自绘区域用：每帧调用即可保持高亮
func force_hot(on: bool = true) -> void:
	if on:
		_forced = 0.06


func set_shown(on: bool) -> void:
	_visible = on
	if _drawer != null:
		_drawer.visible = on


func _process(delta: float) -> void:
	_forced = maxf(0.0, _forced - delta)
	_click = maxf(0.0, _click - delta * 6.0)
	var hc := get_viewport().gui_get_hovered_control()
	var over_ui := hc != null and is_instance_valid(hc) and hc.is_visible_in_tree() \
		and (hc.is_in_group("ui_hotspot") or hc.has_meta("hot"))
	_hot = over_ui or _forced > 0.0
	_drawer.position = get_viewport().get_mouse_position().round()
	_drawer.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_click = 1.0
			if _hot:
				Sfx.play("ui_confirm", -10.0)


func _on_draw() -> void:
	if not _visible:
		return
	var ci: CanvasItem = _drawer
	var col := HOT if _hot else COLD
	var gap: int = 3 + int(round(_click * 2.0))
	var arm: int = 2 if _battle else 3
	# 十字：中心留 1px 空隙
	ci.draw_rect(Rect2(-arm, 0, arm, 1), col)
	ci.draw_rect(Rect2(gap, 0, arm, 1), col)
	ci.draw_rect(Rect2(0, -arm, 1, arm), col)
	ci.draw_rect(Rect2(0, gap, 1, arm), col)
	# 中心点
	ci.draw_rect(Rect2(0, 0, 1, 1), CORE)
	# 四角括号（L 形，向中心折）
	var br := gap + 5
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			var cx: int = sx * br
			var cy: int = sy * br
			var hx: int = cx - 3 if sx > 0 else cx
			var vy: int = cy - 3 if sy > 0 else cy
			ci.draw_rect(Rect2(hx, cy, 3, 1), col)
			ci.draw_rect(Rect2(cx, vy, 1, 3), col)
