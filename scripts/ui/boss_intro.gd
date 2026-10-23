extends Control
## Boss 登场：程序化绘制的高分辨率 Boss 剪影 + 打字机台词
## 说明：Boss 没有参考立绘，这里用与战斗内一致的几何风格放大渲染，不引入外部素材

signal finished

const LINES := [
	"三个助手的推理回响，在这个房间里聚成了一个实体。",
	"它没有名字，只有你刚才打出的每一发子弹的记忆。",
	"清空它，才能进入下一层。",
]

var line_index: int = 0
var typed: float = 0.0
var speed: float = 30.0
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	mouse_filter = Control.MOUSE_FILTER_STOP
	Sfx.play("boss")


func _process(delta: float) -> void:
	_t += delta
	if not _done and line_index < LINES.size():
		var full: String = LINES[line_index]
		if typed < float(full.length()):
			typed = minf(float(full.length()), typed + speed * delta)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
			_advance()
			get_viewport().set_input_as_handled()


func _advance() -> void:
	if _done:
		return
	var full: String = LINES[line_index] if line_index < LINES.size() else ""
	if typed < float(full.length()):
		typed = float(full.length())
		return
	line_index += 1
	typed = 0.0
	if line_index >= LINES.size():
		_done = true
		finished.emit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.02, 0.01, 0.04, 0.92))

	# 背景光晕
	var center := Vector2(GameConfig.BASE_W * 0.5, GameConfig.BASE_H * 0.4)
	for i in 6:
		var r := 40.0 + i * 18.0
		draw_circle(center, r, Color(0.55, 0.2, 0.9, 0.05 - i * 0.007))

	# 旋转外环
	for k in 4:
		var rr := 52.0 + k * 13.0
		var a0 := _t * (0.9 + k * 0.4)
		draw_arc(center, rr, a0, a0 + PI * 1.4, 28,
			Color(0.72, 0.36, 1.0, 0.5 - k * 0.09), 2.0, true)

	# 核心多边形
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0 + _t * 0.5
		var rr := 44.0 * (1.0 if i % 2 == 0 else 0.58)
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, Color(0.7, 0.36, 1.0))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0, 0, 0, 0.9), 2.0)
	draw_circle(center, 18.0, Color(1, 1, 1, 0.95))
	draw_circle(center, 10.0, Color(0.08, 0.02, 0.12))

	if GameConfig.ui_font == null:
		return
	draw_string(GameConfig.ui_font, Vector2(0, 40), "回响聚合体", HORIZONTAL_ALIGNMENT_CENTER,
		GameConfig.BASE_W, 22, Color(1, 0.85, 0.45))
	draw_string(GameConfig.ui_font, Vector2(0, 58), "ECHO AGGREGATE", HORIZONTAL_ALIGNMENT_CENTER,
		GameConfig.BASE_W, 9, Color(0.7, 0.6, 0.9))

	var box := Rect2(80, GameConfig.BASE_H - 96, GameConfig.BASE_W - 160, 76)
	draw_rect(box, Color(0.06, 0.05, 0.09, 0.95))
	draw_rect(box, Color(0.5, 0.35, 0.8, 0.8), false, 1.0)
	var full: String = LINES[line_index] if line_index < LINES.size() else ""
	var shown: String = full.substr(0, int(typed))
	draw_multiline_string(GameConfig.ui_font, box.position + Vector2(14, 26), shown,
		HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 28, 11, -1, GameConfig.COL_TEXT)
	if fmod(_t, 0.9) < 0.55:
		draw_string(GameConfig.ui_font, Vector2(box.end.x - 96, box.end.y - 8),
			"空格 / 点击 继续", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GameConfig.COL_DIM)
