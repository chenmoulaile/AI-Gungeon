extends Control
## 层间转场（v0.7 P2）：像素砖墙 + 硬边装饰线 + 层名；0.18s 抖动进出

signal finished

var _floor: int = 1
var _theme: Dictionary = {}
var _alpha: float = 0.0
var _enter: float = 12.0
var _t: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tw := create_tween()
	tw.tween_property(self, "_alpha", 1.0, 0.18).set_trans(Tween.TRANS_LINEAR)
	tw.parallel().tween_property(self, "_enter", 0.0, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(self, "_alpha", 0.0, 0.18).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func() -> void: finished.emit())


func setup(floor_index: int) -> void:
	_floor = floor_index
	_theme = FloorTheme.get_theme(floor_index)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.001:
		return
	var a: float = clampf(_alpha, 0.0, 1.0)
	var w := GameConfig.BASE_W
	var h := GameConfig.BASE_H
	var wall: Color = _theme.get("wall", Color(0.2, 0.25, 0.35))
	var accent: Color = _theme.get("accent", UiKit.CYAN)

	draw_rect(Rect2(0, 0, w, h), Color(UiKit.VOID.r, UiKit.VOID.g, UiKit.VOID.b, a))
	# 16px 砖墙
	var row := 0
	var y := 0.0
	while y < h:
		var off := 0.0 if row % 2 == 0 else 16.0
		var x := -off
		while x < w:
			draw_rect(Rect2(x, y, 32, 16), Color(wall.r, wall.g, wall.b, 0.30 * a))
			draw_line(Vector2(x, y), Vector2(x, y + 16),
				Color(0, 0, 0, 0.25 * a), 1.0)
			x += 32.0
		draw_line(Vector2(0, y), Vector2(w, y), Color(0, 0, 0, 0.25 * a), 1.0)
		y += 16.0
		row += 1
	# 上下抖动暗带
	UiKit.dither_rect(self, Rect2(0, 0, w, 26), Color(0, 0, 0, 0.45 * a), 2)
	UiKit.dither_rect(self, Rect2(0, h - 26, w, 26), Color(0, 0, 0, 0.45 * a), 2)

	var cx := w * 0.5
	var cy := h * 0.5 + roundf(_enter)
	UiKit.text_center(self, cx, cy - 42, "FLOOR %d" % _floor, UiKit.F_SMALL,
		Color(accent.r, accent.g, accent.b, 0.85 * a))
	UiKit.text_center(self, cx, cy + 4, String(_theme.get("name", "未知区域")), UiKit.F_H1,
		Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, a))
	UiKit.text_center(self, cx, cy + 22, String(_theme.get("subtitle", "")), UiKit.F_SMALL,
		Color(accent.r, accent.g, accent.b, 0.85 * a))

	# 硬边装饰线 + 像素菱形
	draw_line(Vector2(cx - 96, cy - 30), Vector2(cx + 96, cy - 30),
		Color(accent.r, accent.g, accent.b, 0.45 * a), 1.0)
	draw_line(Vector2(cx - 96, cy + 14), Vector2(cx + 96, cy + 14),
		Color(accent.r, accent.g, accent.b, 0.45 * a), 1.0)
	for s in [-1.0, 1.0]:
		var c := Vector2(cx + 100 * s, cy - 30)
		for i in 4:
			draw_rect(Rect2(c.x - 3 + i, c.y + 3 - i * 2, 2, 2),
				Color(accent.r, accent.g, accent.b, a))
