extends Control
## 启动画面：logo + 标题淡入 0.8s，按任意键跳过，结束后发 finished

signal finished

var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	BaCursor.set_battle(false)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= 1.35 and not _done:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if (event is InputEventKey and event.pressed) or \
			(event is InputEventMouseButton and event.pressed) or \
			(event is InputEventJoypadButton and event.pressed):
		_finish()
		get_viewport().set_input_as_handled()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()


func _draw() -> void:
	UiKit.gradient_backdrop(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H))
	var cx := GameConfig.BASE_W * 0.5
	# logo：菱形 + 准星
	var c := Vector2(cx, 140)
	var k: float = clampf(_t / 0.8, 0.0, 1.0)
	draw_circle(c, 26.0 * k, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.14))
	var d := 16.0 * k
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]),
		UiKit.ACCENT)
	draw_arc(c, 24.0 * k, 0.0, TAU, 30, Color(1, 1, 1, 0.7), 1.5, true)
	UiKit.text_center(self, cx, 196, "AI GUNGEON", UiKit.F_H2, Color(UiKit.TEXT.r, UiKit.TEXT.g,
		UiKit.TEXT.b, k))
	UiKit.text_center(self, cx, 212, "v0.4.0", UiKit.F_TINY,
		Color(UiKit.TEXT_DIM.r, UiKit.TEXT_DIM.g, UiKit.TEXT_DIM.b, k))
	UiKit.text_center(self, cx, 300, "按任意键跳过", UiKit.F_TINY,
		Color(0.55, 0.60, 0.70, k * 0.8))
