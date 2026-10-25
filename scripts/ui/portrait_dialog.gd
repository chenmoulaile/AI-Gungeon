extends Control
## 通用立绘对话框（v0.7 P2 像素版）：96×96 像素头像 + 1px 框名牌 + 打字机
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
var _icon: Texture2D = null
var _t: float = 0.0
var _blink: float = 0.0
var _slide: float = -1.0
var _auto_t: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE if non_blocking else Control.MOUSE_FILTER_STOP
	if non_blocking:
		process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(portrait_path):
		_tex = load(portrait_path)
	var tw := create_tween()
	tw.tween_property(self, "_slide", 0.0, 0.18)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func setup(p_path: String, p_speaker: String, p_lines: Array, p_icon_path: String = "") -> void:
	portrait_path = p_path
	speaker = p_speaker
	lines = p_lines
	_icon = null
	if is_inside_tree():
		if ResourceLoader.exists(portrait_path):
			_tex = load(portrait_path)
		if p_icon_path != "" and ResourceLoader.exists(p_icon_path):
			_icon = load(p_icon_path)


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
			tw.tween_property(self, "modulate:a", 0.0, 0.18)
			tw.tween_callback(queue_free)
		else:
			finished.emit()


func _draw() -> void:
	if not non_blocking:
		_draw_blocking()
		return
	_draw_toast_bar()


func _draw_blocking() -> void:
	draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.02, 0.03, 0.06, 0.72))
	UiKit.dither_rect(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H),
		Color(0.0, 0.0, 0.0, 0.25), 4)
	var off := roundf(_slide * 120.0)
	var pr := Rect2(24 + off, 40, 96, 96)
	UiKit.frame(self, pr, UiKit.VOID, UiKit.BORDER, UiKit.BORDER_HI, true)
	if _tex != null:
		var ts := _tex.get_size()
		if ts.x >= 94.0 and ts.y >= 94.0:
			draw_texture_rect_region(_tex, Rect2(pr.position + Vector2(1, 1), Vector2(94, 94)),
				Rect2(0, 0, 94, 94))
		else:
			UiKit.draw_tex_contain(self, _tex, pr.grow(-1))
	else:
		UiKit.text_center(self, pr.get_center().x, pr.get_center().y + 6, "?", UiKit.F_H1,
			UiKit.TEXT_DIM)

	var name_w: float = UiKit.measure(speaker, 12) + 18.0
	var tag := Rect2(132 + off, 30, name_w, 18)
	UiKit.frame(self, tag, UiKit.PANEL, UiKit.CYAN, Color(0, 0, 0, 0), true)
	UiKit.text(self, tag.position + Vector2(8, 13), speaker, UiKit.F_SMALL, UiKit.CYAN)

	var box := Rect2(132 + off, 44, GameConfig.BASE_W - 156 - off, 140)
	UiKit.frame(self, box, UiKit.DEEP, UiKit.BORDER, UiKit.BORDER_HI, true)
	UiKit.scanlines(self, box.grow(-2), 0.05)
	draw_line(box.position + Vector2(12, 24), Vector2(box.end.x - 12, box.position.y + 24),
		UiKit.BORDER, 1.0)
	UiKit.text(self, box.position + Vector2(12, 18), "PAUSED // DIALOGUE", UiKit.F_SMALL,
		UiKit.GOLD)
	var full: String = str(lines[line_index]) if line_index < lines.size() else ""
	UiKit.text_block(self, box.position + Vector2(14, 46),
		full.substr(0, int(typed)), box.size.x - 28, UiKit.F_BODY, UiKit.TEXT, 6)
	if fmod(_blink, 0.9) < 0.55:
		UiKit.text_right(self, box.end.x - 14, box.end.y - 10, "空格 / 点击 继续",
			UiKit.F_SMALL, UiKit.TEXT_DIM)


func _draw_toast_bar() -> void:
	var bar_y := GameConfig.BASE_H - 84.0
	var bar := Rect2(20, bar_y, GameConfig.BASE_W - 40, 36)
	UiKit.frame(self, bar, UiKit.DEEP, UiKit.BORDER, UiKit.BORDER_HI, true)
	var icon_tex: Texture2D = _icon if _icon != null else _tex
	if icon_tex != null:
		draw_texture_rect(icon_tex, Rect2(24, bar_y + 2, 32, 32), false)
	else:
		draw_rect(Rect2(24, bar_y + 2, 32, 32), UiKit.PANEL)
	draw_rect(Rect2(20, bar_y, 3, 36), UiKit.CYAN)
	UiKit.text(self, Vector2(64, bar_y + 15), speaker, UiKit.F_SMALL, UiKit.GOLD)
	var full2: String = str(lines[line_index]) if line_index < lines.size() else ""
	UiKit.text_block(self, Vector2(64, bar_y + 30),
		full2.substr(0, int(typed)), GameConfig.BASE_W - 100, UiKit.F_BODY, UiKit.TEXT, 1)
