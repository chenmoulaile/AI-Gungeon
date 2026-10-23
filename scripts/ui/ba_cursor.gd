extends CanvasLayer
## 蔚蓝档案风格自定义光标（Autoload: BaCursor）
## 默认菱形准星 + 呼吸外圈；悬停可交互元素时变亮蓝并旋转虚线环；点击收缩回弹
## hotspot 精确对齐视觉中心：所有图形都以原点为中心绘制，节点位置即鼠标位置

const COLD := Color(0.78, 0.82, 0.90)
const HOT := Color(0.45, 0.72, 1.0)
const CORE := Color(1, 1, 1, 0.98)

var _drawer: Node2D = null
var _hot: bool = false
var _forced: float = 0.0
var _battle: bool = false
var _spin: float = 0.0
var _breath: float = 0.0
var _click: float = 0.0
var _base: float = 1.0
var _visible: bool = true


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_drawer = Node2D.new()
	_drawer.name = "CursorDraw"
	add_child(_drawer)
	_drawer.draw.connect(_on_draw)
	_hide_system_cursor()
	_loop_breath()
	_loop_spin()
	visible = true


func _hide_system_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var img := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_IBEAM,
			Input.CURSOR_CROSS, Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP]:
		Input.set_custom_mouse_cursor(img, shape, Vector2.ZERO)


func _loop_breath() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(self, "_breath", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_breath", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _loop_spin() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(self, "_spin", TAU, 4.0).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)


## 战斗 / 菜单两种尺寸
func set_battle(on: bool) -> void:
	if _battle == on:
		return
	_battle = on
	var tw := create_tween()
	tw.tween_property(self, "_base", 0.7 if on else 1.0, 0.15)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


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
	var hc := get_viewport().gui_get_hovered_control()
	var over_ui := hc != null and is_instance_valid(hc) and hc.is_visible_in_tree() \
		and (hc.is_in_group("ui_hotspot") or hc.has_meta("hot"))
	_hot = over_ui or _forced > 0.0
	_drawer.position = get_viewport().get_mouse_position()
	_drawer.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_click_fx()
			if _hot:
				Sfx.play("ui_confirm", -10.0)


func _click_fx() -> void:
	_click = 1.0
	var tw := create_tween()
	tw.tween_property(self, "_click", 0.0, 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_draw() -> void:
	if not _visible:
		return
	var ci: CanvasItem = _drawer
	var col := HOT if _hot else COLD
	var s: float = _base * (1.0 - 0.12 * _click)
	var ring_r: float = (9.0 + 0.45 * _breath) * s * (1.0 - 0.55 * _click)
	# 外圈：默认细实线，悬停时变成旋转虚线环
	if _hot:
		var seg := 12
		for i in seg:
			var a0 := _spin + TAU * float(i) / float(seg)
			ci.draw_arc(Vector2.ZERO, ring_r, a0, a0 + 0.30, 6, col, 1.4, true)
		ci.draw_arc(Vector2.ZERO, ring_r + 2.5, 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.22), 1.0, true)
	else:
		ci.draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.55), 1.0, true)
	# 中心：菱形准星（悬停时收成更小的三角标）
	if _hot:
		var tri := PackedVector2Array([
			Vector2(0, -5.4) * s, Vector2(4.6, 3.6) * s, Vector2(-4.6, 3.6) * s])
		ci.draw_colored_polygon(tri, col)
		ci.draw_circle(Vector2(0, 1.0) * s, 1.5 * s, CORE)
	else:
		var d := PackedVector2Array([
			Vector2(0, -4.6) * s, Vector2(4.6, 0) * s, Vector2(0, 4.6) * s, Vector2(-4.6, 0) * s])
		ci.draw_colored_polygon(d, Color(1, 1, 1, 0.92))
		ci.draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]),
			Color(0.25, 0.32, 0.45, 0.55), 1.0)
		ci.draw_circle(Vector2.ZERO, 1.2 * s, col)
