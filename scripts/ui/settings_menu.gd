extends Control
## 设置：TabContainer + 容器布局，任何分辨率下都不重叠
## 音频 / 显示 / 操作 三个页签，每次只显示一个面板

signal closed

const MARGIN := 32

var _tabs: TabContainer = null
var _sliders: Dictionary = {}
var _values: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	modulate.a = 0.0
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_build()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.16)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.07, 0.13, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(0.92))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(520, 0)
	margin.add_child(col)

	var title := Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", UiKit.TEXT)
	col.add_child(title)

	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(520, 230)
	_tabs.add_theme_font_size_override("font_size", 9)
	_tabs.add_theme_stylebox_override("panel", _tab_panel())
	_tabs.add_theme_stylebox_override("tab_selected", _tab_sb(UiKit.ACCENT, true))
	_tabs.add_theme_stylebox_override("tab_unselected", _tab_sb(Color(0.90, 0.94, 1.0), false))
	_tabs.add_theme_stylebox_override("tab_hovered", _tab_sb(Color(0.80, 0.90, 1.0), false))
	_tabs.add_theme_stylebox_override("tab_disabled", _tab_sb(Color(0.88, 0.89, 0.92), false))
	_tabs.add_theme_color_override("font_selected_color", Color(1, 1, 1))
	_tabs.add_theme_color_override("font_unselected_color", UiKit.TEXT)
	_tabs.add_theme_color_override("font_hovered_color", UiKit.TEXT)
	col.add_child(_tabs)
	_tabs.add_child(_audio_tab())
	_tabs.add_child(_video_tab())
	_tabs.add_child(_input_tab())

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 8)
	col.add_child(footer)
	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(96, 32)
	back.focus_mode = Control.FOCUS_NONE
	UiKit.style_button(back, "primary")
	back.pressed.connect(_close)
	footer.add_child(back)


# ---------------- 音频 ----------------
func _audio_tab() -> Control:
	var box := _page("音频")
	box.add_child(_slider_row("主音量", "master", Settings.master_volume, func(v: float) -> void:
		Settings.master_volume = v
		Sfx.apply_volumes()))
	box.add_child(_slider_row("音效", "sfx", Settings.sfx_volume, func(v: float) -> void:
		Settings.sfx_volume = v
		Sfx.apply_volumes()))
	box.add_child(_slider_row("音乐", "music", Settings.music_volume, func(v: float) -> void:
		Settings.music_volume = v
		Sfx.apply_volumes()))
	return box


# ---------------- 显示 ----------------
func _video_tab() -> Control:
	var box := _page("显示")
	box.add_child(_toggle_row("全屏", Settings.fullscreen, func(on: bool) -> void:
		Settings.fullscreen = on
		Settings.apply_all()))
	box.add_child(_slider_row("震屏强度", "shake", Settings.shake_scale, func(v: float) -> void:
		Settings.shake_scale = v))
	box.add_child(_toggle_row("画面震动", Settings.vibration, func(on: bool) -> void:
		Settings.vibration = on))
	box.add_child(_toggle_row("高对比弹幕", Settings.high_contrast, func(on: bool) -> void:
		Settings.high_contrast = on
		Settings.apply_all()))
	return box


# ---------------- 操作 ----------------
func _input_tab() -> Control:
	var box := _page("操作")
	var tip := Label.new()
	tip.text = "移动 WASD / 瞄准 鼠标 / 射击 左键 / 翻滚 空格\n技能 E / 副武器 Q / 暂停 ESC"
	tip.add_theme_font_size_override("font_size", 8)
	tip.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	box.add_child(tip)
	box.add_child(_slider_row("难度", "diff", float(Settings.difficulty) / 2.0,
		func(v: float) -> void:
			Settings.difficulty = clampi(int(round(v * 2.0)), 0, 2)
			SeedManager.difficulty = Settings.difficulty))
	return box


func _tab_sb(col: Color, selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	if not selected:
		sb.border_width_bottom = 1
		sb.border_color = Color(0.78, 0.86, 0.98)
	return sb


func _tab_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.55)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.80, 0.88, 1.0, 0.9)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 14
	sb.content_margin_bottom = 12
	return sb


func _page(name_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = name_text
	box.add_theme_constant_override("separation", 10)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 4)
	pad.add_theme_constant_override("margin_top", 8)
	return box


func _row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(110, 0)
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", UiKit.TEXT)
	row.add_child(l)
	return row


func _slider_row(label_text: String, key: String, value: float, cb: Callable) -> Control:
	var row := _row(label_text)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(240, 20)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.86, 0.90, 0.97)
	track.set_corner_radius_all(4)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiKit.ACCENT
	fill.set_corner_radius_all(4)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var val := Label.new()
	val.text = "%d%%" % int(round(value * 100.0))
	val.custom_minimum_size = Vector2(44, 0)
	val.add_theme_font_size_override("font_size", 8)
	val.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	s.value_changed.connect(func(v: float) -> void:
		val.text = "%d%%" % int(round(v * 100.0))
		cb.call(v))
	row.add_child(s)
	row.add_child(val)
	_sliders[key] = s
	return row


func _toggle_row(label_text: String, value: bool, cb: Callable) -> Control:
	var row := _row(label_text)
	var c := CheckButton.new()
	c.button_pressed = value
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 9)
	c.toggled.connect(func(on: bool) -> void: cb.call(on))
	row.add_child(c)
	return row


func _close() -> void:
	Settings.save_settings()
	closed.emit()
	if is_instance_valid(self):
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()
