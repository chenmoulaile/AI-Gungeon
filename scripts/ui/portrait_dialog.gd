extends Control
## 通用立绘对话框（打字机效果）
## blocking 模式：暂停由调用方负责，播完发 finished
## non_blocking 模式：不暂停、不吃输入、每句自动停留 auto_delay 秒后淡出

signal finished

var portrait_path: String = ""
var speaker: String = ""
var lines: Array = []
var line_index: int = 0
var typed: float = 0.0
var speed: float = 34.0
var finished_flag: bool = false

var non_blocking: bool = false
var auto_delay: float = 2.2

var _tex: Texture2D = null
var _t: float = 0.0
var _blink: float = 0.0
var _slide: float = -1.0
var _auto_t: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE if non_blocking else Control.MOUSE_FILTER_STOP
	if non_blocking:
		process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(portrait_path):
		_tex = load(portrait_path)
	var tw := create_tween()
	tw.tween_property(self, "_slide", 0.0, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func setup(p_path: String, p_speaker: String, p_lines: Array) -> void:
	portrait_path = p_path
	speaker = p_speaker
	lines = p_lines
	if is_inside_tree() and ResourceLoader.exists(portrait_path):
		_tex = load(portrait_path)


func _process(delta: float) -> void:
	_t += delta
	_blink += delta
	if finished_flag or line_index >= lines.size():
		return
	var full: String = str(lines[line_index])
	if typed < float(full.length()):
		typed = minf(float(full.length()), typed + speed * delta)
	elif non_blocking:
		_auto_t += delta
		if _auto_t >= auto_delay:
			_auto_t = 0.0
			_advance()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if non_blocking:
		return
	if event is InputEventMouseButton and event.pressed:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if non_blocking:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_E, KEY_ESCAPE]:
			_advance()
			get_viewport().set_input_as_handled()


func _advance() -> void:
	if finished_flag:
		return
	var full: String = str(lines[line_index]) if line_index < lines.size() else ""
	if typed < float(full.length()):
		typed = float(full.length())
		return
	line_index += 1
	typed = 0.0
	if line_index >= lines.size():
		finished_flag = true
		if non_blocking:
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.25)
			tw.tween_callback(queue_free)
		else:
			finished.emit()


func _draw() -> void:
	var pr := Rect2(28 + _slide * 240.0, 34, 208, 208)
	if not non_blocking:
		draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.01, 0.02, 0.04, 0.74))
		draw_rect(pr.grow(3), Color(0, 0, 0, 0.5))
		if _tex != null:
			draw_texture_rect(_tex, pr, false)
		var box := Rect2(250, 44, GameConfig.BASE_W - 280, 196)
		draw_rect(box, Color(0.07, 0.08, 0.11, 0.94))
		draw_rect(box, Color(0.45, 0.5, 0.65, 0.8), false, 1.0)
		draw_line(Vector2(box.position.x, box.position.y + 26),
			Vector2(box.end.x, box.position.y + 26), Color(0.3, 0.35, 0.45), 1.0)
		if GameConfig.ui_font != null:
			draw_string(GameConfig.ui_font, box.position + Vector2(12, 18), speaker,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.86, 0.45))
			var full: String = str(lines[line_index]) if line_index < lines.size() else ""
			draw_multiline_string(GameConfig.ui_font, box.position + Vector2(14, 52),
				full.substr(0, int(typed)), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 28,
				11, -1, GameConfig.COL_TEXT)
			if fmod(_blink, 0.9) < 0.55:
				draw_string(GameConfig.ui_font, Vector2(box.end.x - 92, box.end.y - 10),
					"空格 / 点击 继续", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GameConfig.COL_DIM)
		return

	# 非阻塞模式：贴底小条，位置上移避开右下角技能环
	var bar_y := GameConfig.BASE_H - 86.0
	var bar := Rect2(20, bar_y, GameConfig.BASE_W - 40, 30)
	draw_style_box(UiKit.box(Color(1, 1, 1, 0.88), 9, Color(1, 1, 1, 0.9), 1, true), bar)
	if _tex != null:
		draw_texture_rect_region(_tex, Rect2(26, bar_y + 4, 22, 22),
			Rect2(120, 40, 800, 800))
	if GameConfig.ui_font == null:
		return
	draw_string(GameConfig.ui_font, Vector2(56, bar_y + 12), speaker,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.78, 0.55, 0.12))
	var full2: String = str(lines[line_index]) if line_index < lines.size() else ""
	draw_multiline_string(GameConfig.ui_font, Vector2(56, bar_y + 24),
		full2.substr(0, int(typed)), HORIZONTAL_ALIGNMENT_LEFT, GameConfig.BASE_W - 90,
		8, 1, UiKit.TEXT)
