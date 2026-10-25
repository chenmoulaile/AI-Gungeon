extends Control
## 启动画面（v0.7 P2）：像素菱形徽标 + 硬边标题，按任意键跳过，结束后发 finished

signal finished

var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_LINEAR)
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
	UiKit.gradient_backdrop(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), _t)
	UiKit.scanlines(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), 0.06)
	var cx := GameConfig.BASE_W * 0.5
	var k: float = clampf(_t / 0.5, 0.0, 1.0)
	var c := Vector2(cx, 132)
	# 像素菱形徽标（层层硬边）
	_pixel_diamond(c, int(round(8.0 + 24.0 * k)), UiKit.SHADOW)
	_pixel_diamond(c, int(round(6.0 + 22.0 * k)), Color("#1B2A46"))
	_pixel_diamond(c, int(round(2.0 + 13.0 * k)), UiKit.CYAN)
	_pixel_diamond(c, int(round(1.0 + 5.0 * k)), UiKit.VOID)
	# 准星
	var arm := int(round(26.0 + 12.0 * k))
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + d * 10.0, c + d * float(arm), UiKit.WHITE, 1.0)
	# 四角括号
	UiKit.corner_brackets(self, Rect2(c - Vector2(arm + 4, arm + 4), Vector2(arm + 4, arm + 4) * 2.0),
		Color(UiKit.CYAN.r, UiKit.CYAN.g, UiKit.CYAN.b, 0.6 * k), 6)

	var ta: float = clampf((_t - 0.35) / 0.35, 0.0, 1.0)
	UiKit.text_center(self, cx, 204, "AI GUNGEON", UiKit.F_H1,
		Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, ta))
	UiKit.text_center(self, cx, 222, "像素地牢 · 非官方同人", UiKit.F_SMALL,
		Color(UiKit.TEXT_DIM.r, UiKit.TEXT_DIM.g, UiKit.TEXT_DIM.b, ta))
	UiKit.text_center(self, cx, 240, "v0.7.0-pixel", UiKit.F_SMALL,
		Color(UiKit.TEXT_DIM.r, UiKit.TEXT_DIM.g, UiKit.TEXT_DIM.b, ta * 0.9))
	if fmod(_t, 0.9) < 0.6:
		UiKit.keycap(self, Vector2(cx - 9, 300), "A", 18)
		UiKit.text(self, Vector2(cx + 4, 314), "按任意键开始", UiKit.F_SMALL,
			Color(UiKit.TEXT_DIM.r, UiKit.TEXT_DIM.g, UiKit.TEXT_DIM.b, ta * 0.8))


func _pixel_diamond(c: Vector2, r: int, col: Color) -> void:
	if r <= 0:
		return
	for dy in range(-r, r + 1):
		var w := r - absi(dy)
		draw_line(Vector2(c.x - w, c.y + dy), Vector2(c.x + w + 1, c.y + dy), col, 1.0)
