extends Control
## 设置（蔚蓝档案风格）：左侧五个标签页，右侧「标签 + 控件」横排
## 自定义音量滑块（轨道 + 圆形滑块）、按键重映射（点击后进入"按下新键"状态）

signal closed

const TABS := [["audio", "音频"], ["video", "显示"], ["input", "操作"],
	["access", "可访问性"], ["about", "关于"]]
const TAB_X := 28.0
const TAB_Y := 64.0
const TAB_W := 74.0
const TAB_H := 22.0
const TAB_GAP := 6.0
const CONTENT := Rect2(112, 56, 500, 244)

var _rows: Array = []
var _tab: String = "audio"
var _hover: int = -1
var _focus: int = 0
var _dragging: String = ""
var _listening: String = ""
var _listen_pad: bool = false
var _enter: float = 20.0
var _close_btn: BaButton = null
var _pad_tab: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	_build_rows()
	_close_btn = BaButton.new()
	add_child(_close_btn)
	_close_btn.setup("返回", Rect2(GameConfig.BASE_W - 96, 308, 76, 24),
		"secondary", "", UiKit.F_SMALL)
	_close_btn.pressed.connect(_close)
	BaCursor.set_battle(false)
	var tw := create_tween()
	tw.tween_property(self, "_enter", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("ui")


func _build_rows() -> void:
	_rows.clear()
	var x := CONTENT.position.x + 12.0
	var y := CONTENT.position.y + 22.0
	var w := CONTENT.size.x - 24.0
	match _tab:
		"audio":
			for item in [["master", "主音量"], ["sfx", "音效"], ["music", "音乐"]]:
				_rows.append({"rect": Rect2(x, y, w, 26), "kind": "slider", "id": item[0],
					"label": item[1]})
				y += 34.0
		"video":
			_rows.append({"rect": Rect2(x, y, w, 26), "kind": "toggle", "id": "fullscreen",
				"label": "全屏显示"})
			y += 34.0
			_rows.append({"rect": Rect2(x, y, w, 26), "kind": "info", "id": "res",
				"label": "渲染分辨率"})
			y += 34.0
		"input":
			_rows.append({"rect": Rect2(x, y, w, 20), "kind": "subtabs", "id": "padsrc",
				"label": ""})
			y += 26.0
			var acts: Array = []
			if _pad_tab:
				for a in Settings.PAD_ACTIONS:
					acts.append([a, _pad_label_of(a)])
			else:
				acts = [["move_left", "左移"], ["move_right", "右移"], ["move_up", "上移"],
					["move_down", "下移"], ["shoot", "射击"], ["roll", "翻滚"],
					["skill", "技能"], ["sub_weapon", "副武器"], ["switch_mode", "切换模式"],
					["pause", "暂停"]]
			for a in acts:
				_rows.append({"rect": Rect2(x, y, w, 20), "kind": "key", "id": a[0],
					"label": a[1]})
				y += 21.0
		"access":
			for item in [["contrast", "高对比弹幕"], ["vibration", "手柄震动"]]:
				_rows.append({"rect": Rect2(x, y, w, 26), "kind": "toggle", "id": item[0],
					"label": item[1]})
				y += 34.0
			_rows.append({"rect": Rect2(x, y, w, 26), "kind": "slider", "id": "shake",
				"label": "屏幕震动强度"})
			y += 34.0
		_:
			_rows.append({"rect": Rect2(x, y, w, 26), "kind": "info", "id": "version",
				"label": "版本"})
			y += 30.0
			_rows.append({"rect": Rect2(x, y, w, 26), "kind": "info", "id": "seed",
				"label": "本局种子"})
			y += 30.0
			_rows.append({"rect": Rect2(x, y, w, 26), "kind": "info", "id": "credit",
				"label": "同人声明"})


func _pad_label_of(action: String) -> String:
	var names := {"move_left": "左移", "move_right": "右移", "move_up": "上移",
		"move_down": "下移", "aim_left": "瞄准左", "aim_right": "瞄准右",
		"aim_up": "瞄准上", "aim_down": "瞄准下", "shoot": "射击", "roll": "翻滚",
		"skill": "技能", "sub_weapon": "副武器", "switch_mode": "切换模式", "pause": "暂停"}
	return String(names.get(action, action))


func _process(_delta: float) -> void:
	var mouse := get_local_mouse_position()
	_hover = -1
	for i in _rows.size():
		if (_rows[i]["rect"] as Rect2).has_point(mouse):
			_hover = i
	if _hover >= 0:
		BaCursor.force_hot()
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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var m := get_local_mouse_position()
		if mb.pressed:
			for i in TABS.size():
				if _tab_rect(i).has_point(m):
					_tab = String(TABS[i][0])
					_focus = 0
					_build_rows()
					Sfx.play("ui")
					accept_event()
					return
			if _hover >= 0:
				var row: Dictionary = _rows[_hover]
				if String(row["kind"]) == "subtabs":
					_pad_tab = not _pad_tab
					_build_rows()
					Sfx.play("ui")
				else:
					_press_row(_hover)
					if String(row["kind"]) == "slider":
						_dragging = String(row["id"])
						_drag_to(m)
			elif _seed_rect().has_point(m) and _tab == "about":
				SeedManager.copy_seed()
				Sfx.play("ui")
		else:
			_dragging = ""
		accept_event()
	elif event is InputEventMouseMotion and _dragging != "":
		_drag_to(get_local_mouse_position())
		accept_event()


func _tab_rect(i: int) -> Rect2:
	return Rect2(TAB_X, TAB_Y + i * (TAB_H + TAB_GAP), TAB_W, TAB_H)


func _seed_rect() -> Rect2:
	return Rect2(CONTENT.position.x + 92, CONTENT.position.y + 56, 200, 20)


func _capture(event: InputEvent) -> void:
	if _listen_pad:
		if event is InputEventJoypadButton and event.pressed:
			Settings.rebind_pad(_listening, "joy_button", (event as InputEventJoypadButton).button_index)
			_listening = ""
		elif event is InputEventJoypadMotion:
			var m := event as InputEventJoypadMotion
			if absf(m.axis_value) > 0.5:
				Settings.rebind_pad(_listening, "joy_axis", m.axis, 1 if m.axis_value > 0 else -1)
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
	if index < 0 or index >= _rows.size():
		return
	var row: Dictionary = _rows[index]
	match String(row["kind"]):
		"slider":
			_drag_to(get_local_mouse_position())
		"toggle":
			_toggle(String(row["id"]))
		"key":
			_listening = String(row["id"])
			_listen_pad = _pad_tab
		"subtabs":
			_pad_tab = not _pad_tab
			_build_rows()
	Sfx.play("ui")


func _toggle(id: String) -> void:
	match id:
		"fullscreen":
			Settings.fullscreen = not Settings.fullscreen
			Settings.apply_video()
		"contrast":
			Settings.high_contrast = not Settings.high_contrast
		"vibration":
			Settings.vibration = not Settings.vibration
	Settings.save_settings()


func _adjust(dir: int) -> void:
	if _focus < 0 or _focus >= _rows.size():
		return
	var row: Dictionary = _rows[_focus]
	if String(row["kind"]) != "slider":
		return
	var v: float = clampf(_slider_value(String(row["id"])) + 0.05 * float(dir), 0.0, 1.0)
	_apply_slider(String(row["id"]), v)


func _drag_to(mouse: Vector2) -> void:
	for row in _rows:
		if String(row["id"]) != _dragging:
			continue
		var r: Rect2 = row["rect"]
		var bar := Rect2(r.position.x + 120.0, r.position.y + 9.0, r.size.x - 168.0, 8.0)
		var v: float = clampf((mouse.x - bar.position.x) / maxf(1.0, bar.size.x), 0.0, 1.0)
		_apply_slider(_dragging, v)


func _apply_slider(id: String, v: float) -> void:
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


func _close() -> void:
	Settings.save_settings()
	Sfx.play("ui")
	closed.emit()
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.07, 0.10, 0.17, 0.55))
	draw_set_transform(Vector2(0, _enter), 0.0, Vector2.ONE)
	var panel := Rect2(16, 12, GameConfig.BASE_W - 32, GameConfig.BASE_H - 24)
	draw_style_box(UiKit.box(Color(0.96, 0.97, 1.0, 0.98), 12, Color(1, 1, 1, 0.8), 1, true), panel)
	UiKit.text(self, Vector2(28, 44), "设置", UiKit.F_H2, UiKit.TEXT)
	UiKit.text_right(self, 612, 42, "改动即时保存", UiKit.F_TINY, UiKit.TEXT_DIM)

	# 左侧标签
	for i in TABS.size():
		var r := _tab_rect(i)
		var on := _tab == String(TABS[i][0])
		draw_style_box(UiKit.box(UiKit.ACCENT if on else Color(1, 1, 1, 0.55), 8,
			Color(1, 1, 1, 0.8), 1, false), r)
		UiKit.text_center(self, r.get_center().x, r.get_center().y + 3.0, String(TABS[i][1]),
			UiKit.F_SMALL, UiKit.TEXT_LIGHT if on else UiKit.TEXT_DIM)

	# 内容底板
	draw_style_box(UiKit.box(Color(1, 1, 1, 0.85), 10, Color(1, 1, 1, 0.9), 1, false), CONTENT)

	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var r: Rect2 = row["rect"]
		if _focus == i:
			draw_style_box(UiKit.box(Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.10), 7,
				Color(0, 0, 0, 0), 1, false), r.grow(2))
		match String(row["kind"]):
			"slider":
				_draw_slider(r, String(row["id"]), String(row["label"]))
			"toggle":
				_draw_toggle(r, String(row["id"]), String(row["label"]))
			"key":
				_draw_key(r, String(row["id"]), String(row["label"]))
			"subtabs":
				_draw_subtabs(r)
			"info":
				_draw_info(r, String(row["id"]), String(row["label"]))

	UiKit.text(self, Vector2(28, 342),
		"方向键选择 · 左右调节 · ESC 返回", UiKit.F_TINY, UiKit.TEXT_DIM)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_slider(r: Rect2, id: String, label: String) -> void:
	UiKit.text(self, r.position + Vector2(0, 17), label, UiKit.F_SMALL, UiKit.TEXT)
	var bar := Rect2(r.position.x + 120.0, r.position.y + 9.0, r.size.x - 168.0, 8.0)
	var v := _slider_value(id)
	draw_style_box(UiKit.box(Color(0.84, 0.88, 0.95), 4, Color(0, 0, 0, 0), 0, false), bar)
	draw_style_box(UiKit.box(UiKit.ACCENT, 4, Color(0, 0, 0, 0), 0, false),
		Rect2(bar.position, Vector2(bar.size.x * v, bar.size.y)))
	draw_circle(Vector2(bar.position.x + bar.size.x * v, bar.get_center().y), 6.0,
		Color(1, 1, 1, 1))
	draw_arc(Vector2(bar.position.x + bar.size.x * v, bar.get_center().y), 6.0, 0.0, TAU, 20,
		UiKit.ACCENT, 1.6, true)
	UiKit.text_right(self, r.end.x, r.position.y + 17, "%d%%" % int(round(v * 100.0)),
		UiKit.F_TINY, UiKit.TEXT_DIM)


func _draw_toggle(r: Rect2, id: String, label: String) -> void:
	UiKit.text(self, r.position + Vector2(0, 17), label, UiKit.F_SMALL, UiKit.TEXT)
	var on := _toggle_value(id)
	var box := Rect2(r.end.x - 42.0, r.position.y + 6.0, 38.0, 15.0)
	draw_style_box(UiKit.box(UiKit.ACCENT if on else Color(0.84, 0.86, 0.90), 8,
		Color(1, 1, 1, 0.7), 1, false), box)
	var kx: float = box.end.x - 8.0 if on else box.position.x + 8.0
	draw_circle(Vector2(kx, box.get_center().y), 5.0, Color(1, 1, 1, 1))
	UiKit.text_right(self, box.position.x - 8.0, r.position.y + 17, "开" if on else "关",
		UiKit.F_TINY, UiKit.TEXT_DIM)


func _draw_key(r: Rect2, id: String, label: String) -> void:
	UiKit.text(self, r.position + Vector2(0, 14), label, UiKit.F_SMALL, UiKit.TEXT)
	var listening := (_listening == id)
	var txt := "按下新键…" if listening else (
		Settings.pad_label(id) if _pad_tab else Settings.key_label(id))
	var w := UiKit.measure(txt, UiKit.F_TINY) + 16.0
	var box := Rect2(r.end.x - w, r.position.y + 2.0, w, 16.0)
	draw_style_box(UiKit.box(Color(1.0, 0.93, 0.72) if listening else Color(0.93, 0.95, 0.99), 6,
		Color(1, 1, 1, 0.8), 1, false), box)
	UiKit.text_center(self, box.get_center().x, box.get_center().y + 2.0, txt, UiKit.F_TINY,
		Color(0.62, 0.45, 0.08) if listening else UiKit.TEXT)


func _draw_subtabs(r: Rect2) -> void:
	for i in 2:
		var rr := Rect2(r.position.x, r.position.y, 60, 18)
		rr.position.x += i * 64.0
		var on := (_pad_tab and i == 1) or (not _pad_tab and i == 0)
		draw_style_box(UiKit.box(UiKit.ACCENT if on else Color(1, 1, 1, 0.6), 7,
			Color(1, 1, 1, 0.8), 1, false), rr)
		UiKit.text_center(self, rr.get_center().x, rr.get_center().y + 2.0,
			"键盘" if i == 0 else "手柄", UiKit.F_TINY,
			UiKit.TEXT_LIGHT if on else UiKit.TEXT_DIM)


func _draw_info(r: Rect2, id: String, label: String) -> void:
	UiKit.text(self, r.position + Vector2(0, 16), label, UiKit.F_SMALL, UiKit.TEXT)
	match id:
		"version":
			UiKit.text_right(self, r.end.x, r.position.y + 16, "v0.4.0", UiKit.F_SMALL, UiKit.ACCENT)
		"seed":
			var sr := _seed_rect()
			sr.position.y = r.position.y + 2
			draw_style_box(UiKit.box(Color(0.93, 0.95, 0.99), 6, Color(1, 1, 1, 0.8), 1, false), sr)
			UiKit.text(self, sr.position + Vector2(8, 14), SeedManager.seed_string + "（点击复制）",
				UiKit.F_TINY, UiKit.TEXT_DIM)
		"credit":
			UiKit.text_right(self, r.end.x, r.position.y + 16, "非官方同人 · 完全免费",
				UiKit.F_TINY, UiKit.TEXT_DIM)
		"res":
			UiKit.text_right(self, r.end.x, r.position.y + 16,
				"%d×%d（整数倍缩放）" % [GameConfig.BASE_W, GameConfig.BASE_H],
				UiKit.F_TINY, UiKit.TEXT_DIM)


func _toggle_value(id: String) -> bool:
	match id:
		"fullscreen":
			return Settings.fullscreen
		"contrast":
			return Settings.high_contrast
		"vibration":
			return Settings.vibration
		_:
			return false


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
