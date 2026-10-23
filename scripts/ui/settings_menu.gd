extends Control
## 设置菜单：音量 / 震动强度 / 全屏 / 高对比弹幕 / 按键重映射
## 全部即时生效并写入 user://settings.cfg

signal closed

const PANEL := Rect2(56, 24, 528, 312)

var _rows: Array = []          # {rect, kind, id, label}
var _dragging: String = ""
var _listening: String = ""
var _hover: int = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	_build_rows()
	Sfx.play("ui")


func _build_rows() -> void:
	var x := PANEL.position.x + 18.0
	var y := PANEL.position.y + 48.0
	var w := 232.0
	# 左列：音频与画面
	_rows.append({"rect": Rect2(x, y, w, 16), "kind": "slider", "id": "master", "label": "主音量"})
	y += 26.0
	_rows.append({"rect": Rect2(x, y, w, 16), "kind": "slider", "id": "sfx", "label": "音效"})
	y += 26.0
	_rows.append({"rect": Rect2(x, y, w, 16), "kind": "slider", "id": "music", "label": "音乐"})
	y += 26.0
	_rows.append({"rect": Rect2(x, y, w, 16), "kind": "slider", "id": "shake", "label": "屏幕震动"})
	y += 30.0
	_rows.append({"rect": Rect2(x, y, w, 18), "kind": "toggle", "id": "fullscreen", "label": "全屏"})
	y += 26.0
	_rows.append({"rect": Rect2(x, y, w, 18), "kind": "toggle", "id": "contrast", "label": "高对比弹幕"})

	# 右列：按键
	var rx := PANEL.position.x + 274.0
	var ry := PANEL.position.y + 48.0
	var actions := [
		["move_left", "左移"], ["move_right", "右移"], ["move_up", "上移"],
		["move_down", "下移"], ["shoot", "射击"], ["roll", "翻滚"], ["skill", "技能"],
	]
	for a in actions:
		_rows.append({"rect": Rect2(rx, ry, 236, 18), "kind": "key", "id": a[0], "label": a[1]})
		ry += 26.0


func _process(_delta: float) -> void:
	var mouse := get_local_mouse_position()
	_hover = -1
	for i in _rows.size():
		if (_rows[i]["rect"] as Rect2).has_point(mouse):
			_hover = i
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if _hover >= 0:
				_press_row(_hover)
				_dragging = String(_rows[_hover]["id"]) if _rows[_hover]["kind"] == "slider" else ""
			elif _close_rect().has_point(get_local_mouse_position()):
				_close()
		else:
			_dragging = ""
		accept_event()
	elif event is InputEventMouseMotion and _dragging != "":
		_drag_to(get_local_mouse_position())
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _listening == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_ESCAPE:
			_listening = ""
		else:
			Settings.rebind(_listening, "key", k.physical_keycode)
			_listening = ""
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		Settings.rebind(_listening, "mouse", (event as InputEventMouseButton).button_index)
		_listening = ""
		get_viewport().set_input_as_handled()


func _press_row(index: int) -> void:
	var row: Dictionary = _rows[index]
	match String(row["kind"]):
		"slider":
			_drag_to(get_local_mouse_position())
		"toggle":
			if String(row["id"]) == "fullscreen":
				Settings.fullscreen = not Settings.fullscreen
				Settings.apply_video()
			else:
				Settings.high_contrast = not Settings.high_contrast
			Settings.save_settings()
			Sfx.play("ui")
		"key":
			_listening = String(row["id"])


func _drag_to(mouse: Vector2) -> void:
	for row in _rows:
		if String(row["id"]) != _dragging:
			continue
		var r: Rect2 = row["rect"]
		var bar := Rect2(r.position.x + 74.0, r.position.y + 5.0, r.size.x - 84.0, 7.0)
		var v: float = clampf((mouse.x - bar.position.x) / bar.size.x, 0.0, 1.0)
		match _dragging:
			"master":
				Settings.master_volume = v
				Settings.apply_audio()
			"sfx":
				Settings.sfx_volume = v
				Settings.apply_audio()
			"music":
				Settings.music_volume = v
				Settings.apply_audio()
			"shake":
				Settings.shake_scale = v
		Settings.save_settings()


func _close_rect() -> Rect2:
	return Rect2(PANEL.position.x + PANEL.size.x - 92.0, PANEL.end.y - 34.0, 74.0, 22.0)


func _close() -> void:
	Settings.save_settings()
	Sfx.play("ui")
	closed.emit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.01, 0.02, 0.04, 0.78))
	draw_rect(PANEL, Color(0.07, 0.09, 0.14, 0.97))
	draw_rect(PANEL, Color(0.42, 0.56, 0.82, 0.9), false, 1.0)
	if GameConfig.ui_font == null:
		return
	_text(Vector2(PANEL.position.x + 18, PANEL.position.y + 26), "设置", 16, GameConfig.COL_TEXT)
	_text(Vector2(PANEL.position.x + 274, PANEL.position.y + 26), "按键（点击后按新键）", 10,
		GameConfig.COL_DIM)

	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var r: Rect2 = row["rect"]
		var hovered := (_hover == i)
		match String(row["kind"]):
			"slider":
				_text(r.position + Vector2(0, 9), String(row["label"]), 10,
					GameConfig.COL_TEXT if not hovered else Color(1, 0.9, 0.6))
				var bar := Rect2(r.position.x + 74.0, r.position.y + 5.0, r.size.x - 84.0, 7.0)
				draw_rect(bar, Color(0.16, 0.2, 0.28))
				var v := _slider_value(String(row["id"]))
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * v, bar.size.y)),
					Color(0.45, 0.68, 1.0))
				draw_circle(Vector2(bar.position.x + bar.size.x * v, bar.get_center().y), 4.0,
					Color(0.9, 0.95, 1.0))
				_text(Vector2(r.end.x, r.position.y + 9), "%d%%" % int(round(v * 100.0)), 9,
					GameConfig.COL_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
			"toggle":
				_text(r.position + Vector2(0, 12), String(row["label"]), 10, GameConfig.COL_TEXT)
				var on := Settings.fullscreen if String(row["id"]) == "fullscreen" else Settings.high_contrast
				var box := Rect2(r.end.x - 34.0, r.position.y + 2.0, 34.0, 14.0)
				draw_rect(box, Color(0.2, 0.45, 0.75) if on else Color(0.16, 0.18, 0.24))
				_text(Vector2(box.position.x + 6.0, box.position.y + 11.0), "开" if on else "关",
					9, Color(1, 1, 1))
			"key":
				_text(r.position + Vector2(0, 12), String(row["label"]), 10, GameConfig.COL_TEXT)
				var listening := (_listening == String(row["id"]))
				var label: String = "按新键…" if listening else Settings.key_label(String(row["id"]))
				_text(Vector2(r.end.x, r.position.y + 12), label, 9,
					Color(1, 0.85, 0.4) if listening else GameConfig.COL_DIM,
					HORIZONTAL_ALIGNMENT_RIGHT)

	var btn := _close_rect()
	draw_rect(btn, Color(0.16, 0.22, 0.32))
	draw_rect(btn, Color(0.5, 0.65, 0.9), false, 1.0)
	_text(Vector2(btn.position.x, btn.position.y + 15), "返回", 10, GameConfig.COL_TEXT)
	_text(Vector2(PANEL.position.x + 18, PANEL.end.y - 12), "ESC 打开/关闭 · 设置自动保存", 8,
		GameConfig.COL_DIM)
	_text(Vector2(0, GameConfig.BASE_H - 12),
		"非官方同人 · 完全免费 · 角色形象基于 B站 UP 主 ZipZipPipe 的二创（CC BY-NC-SA 4.0）",
		8, Color(0.45, 0.5, 0.6), HORIZONTAL_ALIGNMENT_CENTER)


func _slider_value(id: String) -> float:
	match id:
		"master":
			return Settings.master_volume
		"sfx":
			return Settings.sfx_volume
		"music":
			return Settings.music_volume
		_:
			return Settings.shake_scale


func _text(pos: Vector2, s: String, size: int, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if GameConfig.ui_font == null:
		return
	var p := pos
	if align != HORIZONTAL_ALIGNMENT_LEFT:
		var w: float = GameConfig.ui_font.get_string_size(
			s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		p.x -= w
	draw_string(GameConfig.ui_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
