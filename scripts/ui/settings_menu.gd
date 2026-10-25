extends Control
## 设置（v0.7 P2）：像素标签页 + 硬边滑条（8 段感）+ 方块开关。
## 音频 / 显示 / 操作；Web 端隐藏不可用项。

signal closed

var _panel: Control = null
const MARGIN := 16

var _tabs: TabContainer = null
var _sliders: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modulate.a = 0.0
	await get_tree().process_frame
	if not is_inside_tree():
		return
	position = Vector2.ZERO
	size = Vector2(GameConfig.BASE_W, GameConfig.BASE_H)
	_build()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.12)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(holder)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(0.98))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	holder.add_child(panel)
	_panel = panel

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(520, 0)
	margin.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UiKit.CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var hint := Label.new()
	hint.text = "ESC 返回"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	head.add_child(hint)

	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(520, 196)
	_tabs.add_theme_font_size_override("font_size", 12)
	_tabs.add_theme_stylebox_override("panel", _tab_panel())
	_tabs.add_theme_stylebox_override("tab_selected", _tab_sb(UiKit.DEEP, true))
	_tabs.add_theme_stylebox_override("tab_unselected", _tab_sb(UiKit.VOID, false))
	_tabs.add_theme_stylebox_override("tab_hovered", _tab_sb(UiKit.PANEL, false))
	_tabs.add_theme_stylebox_override("tab_disabled", _tab_sb(UiKit.VOID, false))
	_tabs.add_theme_color_override("font_selected_color", UiKit.CYAN)
	_tabs.add_theme_color_override("font_unselected_color", UiKit.TEXT_DIM)
	_tabs.add_theme_color_override("font_hovered_color", UiKit.TEXT)
	col.add_child(_tabs)
	_tabs.add_child(_audio_tab())
	_tabs.add_child(_video_tab())
	_tabs.add_child(_input_tab())

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 8)
	col.add_child(footer)
	var back := BaButton.new()
	back.custom_minimum_size = Vector2(96, 22)
	back.setup("返回", Rect2(0, 0, 96, 22), "primary", "", UiKit.F_BODY)
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
	tip.text = "移动 WASD / 瞄准 鼠标 / 射击 左键 / 翻滚 空格\n技能 E / 副武器 Q / 暂停 ESC / 训练场 T"
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	box.add_child(tip)
	var diff_row := _row("难度")
	var diff_val := Label.new()
	diff_val.add_theme_font_size_override("font_size", 12)
	diff_val.add_theme_color_override("font_color", UiKit.GOLD)
	diff_val.custom_minimum_size = Vector2(64, 0)
	diff_val.text = ["简单", "普通", "困难"][clampi(Settings.difficulty, 0, 2)]
	box.add_child(diff_row)
	diff_row.add_child(_pixel_slider(float(Settings.difficulty) / 2.0, 0.5,
		func(v: float) -> void:
			Settings.difficulty = clampi(int(round(v * 2.0)), 0, 2)
			SeedManager.difficulty = Settings.difficulty
			diff_val.text = ["简单", "普通", "困难"][Settings.difficulty]))
	diff_row.add_child(diff_val)
	return box


func _tab_sb(col: Color, selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if selected:
		sb.border_width_bottom = 2
		sb.border_color = UiKit.CYAN
	else:
		sb.border_width_bottom = 1
		sb.border_color = UiKit.BORDER
	return sb


func _tab_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.15, 1.0)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.set_border_width_all(1)
	sb.border_color = UiKit.BORDER
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 8
	return sb


func _page(name_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = name_text
	box.add_theme_constant_override("separation", 8)
	return box


func _row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(104, 0)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", UiKit.TEXT)
	row.add_child(l)
	return row


func _slider_row(label_text: String, key: String, value: float, cb: Callable) -> Control:
	var row := _row(label_text)
	var val := Label.new()
	val.text = "%d%%" % int(round(value * 100.0))
	val.custom_minimum_size = Vector2(44, 0)
	val.add_theme_font_size_override("font_size", 12)
	val.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	row.add_child(_pixel_slider(value, 0.05, func(v: float) -> void:
		val.text = "%d%%" % int(round(v * 100.0))
		cb.call(v)))
	row.add_child(val)
	_sliders[key] = row
	return row


func _pixel_slider(value: float, step: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0, 20)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	var track := StyleBoxFlat.new()
	track.bg_color = UiKit.VOID
	track.set_corner_radius_all(0)
	track.set_border_width_all(1)
	track.border_color = UiKit.BORDER
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiKit.CYAN
	fill.set_corner_radius_all(0)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	# 8×12 金色方块滑块（程序生成，避免默认圆角贴图）
	var img := Image.create_empty(8, 12, false, Image.FORMAT_RGBA8)
	img.fill(UiKit.GOLD)
	for x in 8:
		img.set_pixel(x, 0, UiKit.BORDER_HI)
		img.set_pixel(x, 11, UiKit.SHADOW)
	s.add_theme_icon_override("grabber", ImageTexture.create_from_image(img))
	s.add_theme_icon_override("grabber_highlight", ImageTexture.create_from_image(img))
	s.value_changed.connect(cb)
	return s


func _toggle_row(label_text: String, value: bool, cb: Callable) -> Control:
	var row := _row(label_text)
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = value
	b.custom_minimum_size = Vector2(56, 20)
	b.focus_mode = Control.FOCUS_NONE
	b.text = "开" if value else "关"
	UiKit.style_button(b, "primary" if value else "ghost")
	b.toggled.connect(func(on: bool) -> void:
		b.text = "开" if on else "关"
		UiKit.style_button(b, "primary" if on else "ghost")
		Sfx.play("ui", -12.0)
		cb.call(on))
	row.add_child(b)
	return row


func _close() -> void:
	Settings.save_settings()
	closed.emit()
	if is_instance_valid(self):
		queue_free()


func _process(_delta: float) -> void:
	if _panel != null and is_instance_valid(_panel):
		var canvas := Vector2(GameConfig.BASE_W, GameConfig.BASE_H)
		_panel.position = ((canvas - _panel.size) * 0.5).round()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()


func _center_panel(panel: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	panel.position = ((size - panel.size) * 0.5).round()
