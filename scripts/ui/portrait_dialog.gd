extends Control
## 通用立绘对话框（打字机效果）
## 用法：instantiate -> setup(立绘路径, 说话人, 台词数组) -> add_child -> 监听 finished

signal finished

var portrait_path: String = ""
var speaker: String = ""
var lines: Array = []
var line_index: int = 0
var typed: float = 0.0
var speed: float = 34.0     # 每秒字数
var finished_flag: bool = false

var _tex: Texture2D = null
var _t: float = 0.0
var _blink: float = 0.0
var _slide: float = -1.0   # -1 完全在画面外，0 到位


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists(portrait_path):
		_tex = load(portrait_path)
	# 立绘从左侧滑入
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
	if not finished_flag and line_index < lines.size():
		var full: String = str(lines[line_index])
		if typed < float(full.length()):
			typed = minf(float(full.length()), typed + speed * delta)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_E, KEY_ESCAPE]:
			_advance()
			get_viewport().set_input_as_handled()


func _advance() -> void:
	if finished_flag:
		return
	var full: String = str(lines[line_index]) if line_index < lines.size() else ""
	if typed < float(full.length()):
		typed = float(full.length())   # 先补全当前句
		return
	line_index += 1
	typed = 0.0
	if line_index >= lines.size():
		finished_flag = true
		finished.emit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.01, 0.02, 0.04, 0.74))

	# 立绘（只用于界面层，不进入战斗场景）：从左侧滑入
	var pr := Rect2(28 + _slide * 240.0, 34, 208, 208)
	draw_rect(pr.grow(3), Color(0, 0, 0, 0.5))
	if _tex != null:
		draw_texture_rect(_tex, pr, false)

	# 对话框
	var box := Rect2(250, 44, GameConfig.BASE_W - 280, 196)
	draw_rect(box, Color(0.07, 0.08, 0.11, 0.94))
	draw_rect(box, Color(0.45, 0.5, 0.65, 0.8), false, 1.0)
	draw_line(Vector2(box.position.x, box.position.y + 26),
		Vector2(box.end.x, box.position.y + 26), Color(0.3, 0.35, 0.45), 1.0)

	if GameConfig.ui_font != null:
		draw_string(GameConfig.ui_font, box.position + Vector2(12, 18), speaker,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.86, 0.45))
		var full: String = str(lines[line_index]) if line_index < lines.size() else ""
		var shown: String = full.substr(0, int(typed))
		draw_multiline_string(GameConfig.ui_font, box.position + Vector2(14, 52), shown,
			HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 28, 11, -1, GameConfig.COL_TEXT)
		# 提示
		if fmod(_blink, 0.9) < 0.55:
			draw_string(GameConfig.ui_font, Vector2(box.end.x - 92, box.end.y - 10),
				"空格 / 点击 继续", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GameConfig.COL_DIM)
		pass
