extends Control
## 层间转场：显示层名 + 序号，背景为该层主题色渐变
## 时间轴：淡入 0.3s -> 停留 0.6s -> 淡出 0.3s，结束后发 finished

signal finished

var _floor: int = 1
var _theme: Dictionary = {}
var _alpha: float = 0.0
var _enter: float = 10.0
var _t: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tw := create_tween()
	tw.tween_property(self, "_alpha", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_enter", 0.0, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(self, "_alpha", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
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
	var floor_a: Color = _theme.get("floor_a", Color(0.6, 0.65, 0.75))
	var accent: Color = _theme.get("accent", Color(0.6, 0.8, 1.0))

	# 主题色竖向渐变
	var steps := 16
	for i in steps:
		var k := float(i) / float(steps)
		var c := wall.darkened(0.35).lerp(floor_a.darkened(0.15), k)
		c.a = a
		draw_rect(Rect2(0, h * k, w, h / float(steps) + 1.0), c)
	# 斜纹装饰
	var off := fmod(_t * 10.0, 28.0)
	var x := -h + off
	while x < w:
		draw_line(Vector2(x, h), Vector2(x + h, 0), Color(1, 1, 1, 0.035 * a), 8.0)
		x += 28.0

	var cx := w * 0.5
	var cy := h * 0.5 + _enter
	# 上下装饰线
	for dy in [-46.0, 30.0]:
		draw_line(Vector2(cx - 90, cy + dy), Vector2(cx + 90, cy + dy),
			Color(accent.r, accent.g, accent.b, 0.55 * a), 1.0)
		draw_circle(Vector2(cx - 94, cy + dy), 1.6, Color(accent.r, accent.g, accent.b, a))
		draw_circle(Vector2(cx + 94, cy + dy), 1.6, Color(accent.r, accent.g, accent.b, a))

	UiKit.text_center(self, cx, cy - 26, "第 %d 层" % _floor, UiKit.F_SMALL,
		Color(1, 1, 1, 0.72 * a))
	UiKit.text_center(self, cx, cy + 6, String(_theme.get("name", "未知区域")), UiKit.F_H1,
		Color(1, 1, 1, a))
	UiKit.text_center(self, cx, cy + 20, String(_theme.get("subtitle", "")), UiKit.F_TINY,
		Color(accent.r, accent.g, accent.b, 0.85 * a))
