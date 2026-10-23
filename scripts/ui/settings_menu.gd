extends Control
## 设置菜单：音量 / 震动 / 全屏 / 高对比 / 手柄震动 / 静音开关 / 按键重映射（键盘·手柄两页）
## 全部即时生效并写入 user://settings.cfg；手柄可完整导航

signal closed

const PANEL := Rect2(40, 14, 560, 332)
const TAB_KEY := Rect2(300, 22, 62, 18)
const TAB_PAD := Rect2(368, 22, 62, 18)

var _rows: Array = []          # {rect, kind, id, label}
var _dragging: String = ""
var _listening: String = ""
var _listen_pad: bool = false
var _hover: int = -1
var _focus: int = 0
var _tab: String = "key"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	_build_rows()
	Sfx.play("ui")


func _build_rows() -> void:
	_rows.clear()
	var x := PANEL.position.x + 16.0
	var y := PANEL.position.y + 40.0
	var w := 236.0
	_rows.append({"rect": Rect2(x, y, w, 16), "kind": "slider", "id": "master", "label": "主音量"})
	y += 24.0
	_rows.append({"rect": Rect2(x, y, w, 16), "kind": "slider", "id": "sfx", "label": "音效"})
	y += 24.0
	_rows.append({"rect": Rect2(x, y, w, 16), "kind": "slider", "id": "music", "label": "音乐"})
	y += 24.0
	_rows.append({"rect": Rect2(x, y, w, 16), "kind": "slider", "id": "shake", "label": "屏幕震动"})
	y += 26.0
	for t in [["fullscreen", "全屏"], ["contrast", "高对比弹幕"], ["vibration", "手柄震动"],
			["mute_sfx", "静音音效"], ["mute_music", "静音音乐"]]:
		_rows.append({"rect": Rect2(x, y, w, 16), "kind": "toggle", "id": t[0], "label": t[1]})
		y += 21.0

	var rx := PANEL.position.x + 268.0
	var ry := PANEL.position.y + 52.0
	var actions: Array = []
	if _tab == "key":
		actions = [["move_left", "左移"], ["move_right", "右移"], ["move_up", "上移"],
			["move_down", "下移"], ["shoot", "射击"], ["roll", "翻滚"],
			["skill", "技能"], ["switch_mode", "切换模式"]]
	else:
		for a in Settings.PAD_ACTIONS:
			actions.append([a, _pad_label_of(a)])
	for a in actions:
		_rows.append({"rect": Rect2(rx, ry, 276, 17), "kind": "key", "id": a[0], "label": a[1]})
		ry += 19.0


func _pad_label_of(action: String) -> String:
	var names := {"move_left": "左移", "move_right": "右移", "move_up": "上移",
		"move_down": "下移", "aim_left": "瞄准左", "aim_right": "瞄准右",
		"aim_up": "瞄准上", "aim_down": "瞄准下", "shoot": "射击", "roll": "翻滚",
		"skill": "技能", "switch_mode": "切换模式", "pause": "暂停"}
	return String(names.get(action, action))


func _process(_delta: float) -> void:
	var mouse := get_local_mouse_position()
	_hover = -1
	for i in _rows.size():
		if (_rows[i]["rect"] as Rect2).grow(2).has_point(mouse):
			_hover = i
	if _hover >= 0:
		_focus = _hover
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _listening != "":
		_capture(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				_close()
			KEY_UP, KEY_W:
				_focus = maxi(0, _focus - 1)
			KEY_DOWN, KEY_S:
				_focus = mini(_rows.size() - 1, _focus + 1)
			KEY_LEFT, KEY_A:
				_adjust(-1)
			KEY_RIGHT, KEY_D:
				_adjust(1)
			KEY_ENTER, KEY_SPACE:
				if _focus >= 0 and _focus < _rows.size():
					_press_row(_focus)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		var b := (event as InputEventJoypadButton).button_index
		if b == 0:
			if _focus >= 0 and _focus < _rows.size():
				_press_row(_focus)
		elif b == 1:
			_close()
		elif b == 11:
			_focus = maxi(0, _focus - 1)
		elif b == 12:
			_focus = mini(_rows.size() - 1, _focus + 1)
		elif b == 13:
			_adjust(-1)
		elif b == 14:
			_adjust(1)
	elif event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		if absf(m.axis_value) > 0.5:
			if m.axis == 1:
				_focus = maxi(0, _focus - 1) if m.axis_value < 0 else mini(_rows.size() - 1, _focus + 1)
			elif m.axis == 0:
				_adjust(-1 if m.axis_value < 0 else 1)


func _adjust(dir: int) -> void:
	if _focus < 0 or _focus >= _rows.size():
		return
	var row: Dictionary = _rows[_focus]
	if String(row["kind"]) != "slider":
		return
	var id := String(row["id"])
	var v := _slider_value(id) + 0.05 * float(dir)
	v = clampf(v, 0.0, 1.0)
	match id:
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
			Settings.set_shake(v)
	Settings.save_settings()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if TAB_KEY.has_point(get_local_mouse_position()):
				_tab = "key"
				_build_rows()
			elif TAB_PAD.has_point(get_local_mouse_position()):
				_tab = "pad"
				_build_rows()
			elif _hover >= 0:
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


func _capture(event: InputEvent) -> void:
	if _listen_pad:
		if event is InputEventJoypadButton and event.pressed:
			Settings.rebind_pad(_listening, "joy_button", (event as InputEventJoypadButton).button_index)
			_listening = ""
		elif event is InputEventJoypadMotion:
			var m := event as InputEventJoypadMotion
			if absf(m.axis_value) > 0.5:
				Settings.rebind_pad(_listening, "joy_axis", m.axis,
					1 if m.axis_value > 0 else -1)
				_listening = ""
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_listening = ""
		else:
			Settings.rebind(_listening, "key", event.physical_keycode)
			_listening = ""
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
			_toggle(String(row["id"]))
		"key":
			_listening = String(row["id"])
			_listen_pad = _tab == "pad"


func _toggle(id: String) -> void:
	match id:
		"fullscreen":
			Settings.fullscreen = not Settings.fullscreen
			Settings.apply_video()
		"contrast":
			Settings.high_contrast = not Settings.high_contrast
		"vibration":
			Settings.vibration = not Settings.vibration
		"mute_sfx":
			Settings.sfx_volume = 0.0 if Settings.sfx_volume > 0.0 else 0.8
			Settings.apply_audio()
		"mute_music":
			Settings.music_volume = 0.0 if Settings.music_volume > 0.0 else 0.6
			Settings.apply_audio()
	Settings.save_settings()
	Sfx.play("ui")


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
				Settings.set_shake(v)
		Settings.save_settings()


func _close_rect() -> Rect2:
	return Rect2(PANEL.end.x - 92.0, PANEL.end.y - 32.0, 74.0, 22.0)


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
	_text(Vector2(PANEL.position.x + 16, PANEL.position.y + 24), "设置", 16, GameConfig.COL_TEXT)
	# 分页
	for t in [["key", "键盘", TAB_KEY], ["pad", "手柄", TAB_PAD]]:
		var r: Rect2 = t[2]
		var on := _tab == String(t[0])
		draw_rect(r, Color(0.2, 0.32, 0.5) if on else Color(0.12, 0.14, 0.2))
		draw_rect(r, Color(0.55, 0.7, 1.0) if on else Color(0.3, 0.34, 0.42), false, 1.0)
		_text(Vector2(r.position.x + 14, r.position.y + 13), String(t[1]), 10,
			GameConfig.COL_TEXT if on else GameConfig.COL_DIM)

	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var r: Rect2 = row["rect"]
		var focused := (_focus == i)
		if focused:
			draw_rect(r.grow(2), Color(0.45, 0.65, 1.0, 0.16))
			draw_rect(r.grow(2), Color(0.55, 0.75, 1.0, 0.7), false, 1.0)
		match String(row["kind"]):
			"slider":
				_text(r.position + Vector2(0, 9), String(row["label"]), 10, GameConfig.COL_TEXT)
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
				_text(r.position + Vector2(0, 11), String(row["label"]), 10, GameConfig.COL_TEXT)
				var on := _toggle_value(String(row["id"]))
				var box := Rect2(r.end.x - 34.0, r.position.y + 1.0, 34.0, 13.0)
				draw_rect(box, Color(0.2, 0.45, 0.75) if on else Color(0.16, 0.18, 0.24))
				_text(Vector2(box.position.x + 6.0, box.position.y + 10.0), "开" if on else "关",
					9, Color(1, 1, 1))
			"key":
				_text(r.position + Vector2(0, 12), String(row["label"]), 9, GameConfig.COL_TEXT)
				var listening := (_listening == String(row["id"]))
				var label := "按新键…" if listening else (
					Settings.pad_label(String(row["id"])) if _tab == "pad"
					else Settings.key_label(String(row["id"])))
				_text(Vector2(r.end.x, r.position.y + 12), label, 9,
					Color(1, 0.85, 0.4) if listening else GameConfig.COL_DIM,
					HORIZONTAL_ALIGNMENT_RIGHT)

	var btn := _close_rect()
	draw_rect(btn, Color(0.16, 0.22, 0.32))
	draw_rect(btn, Color(0.5, 0.65, 0.9), false, 1.0)
	_text(Vector2(btn.position.x, btn.position.y + 15), "返回", 10, GameConfig.COL_TEXT)
	_text(Vector2(PANEL.position.x + 16, PANEL.end.y - 10),
		"方向键选择 · 左右调滑块 · ESC 关闭 · 设置自动保存", 8, GameConfig.COL_DIM)
	_text(Vector2(0, GameConfig.BASE_H - 10),
		"非官方同人 · 完全免费 · 角色形象基于 B站 UP 主 ZipZipPipe 的二创（CC BY-NC-SA 4.0）",
		7, Color(0.45, 0.5, 0.6), HORIZONTAL_ALIGNMENT_CENTER)


func _toggle_value(id: String) -> bool:
	match id:
		"fullscreen":
			return Settings.fullscreen
		"contrast":
			return Settings.high_contrast
		"vibration":
			return Settings.vibration
		"mute_sfx":
			return Settings.sfx_volume <= 0.001
		_:
			return Settings.music_volume <= 0.001


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
