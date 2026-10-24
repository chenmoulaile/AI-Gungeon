extends Control
## 暂停菜单：全容器布局，process_mode = WHEN_PAUSED
## 继续 / 返回主菜单 / 退出（Web 端隐藏退出）

signal resume_pressed
signal menu_pressed
signal quit_pressed

const MARGIN := 32


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	modulate.a = 0.0
	# 等一帧拿到真实尺寸，容器才能正确居中
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_build()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.16)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.07, 0.13, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", MARGIN)
	margin.add_theme_constant_override("margin_right", MARGIN)
	margin.add_theme_constant_override("margin_top", MARGIN - 8)
	margin.add_theme_constant_override("margin_bottom", MARGIN - 8)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(300, 0)
	margin.add_child(box)

	var title := Label.new()
	title.text = "暂 停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", UiKit.TEXT)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "ESC 继续游戏"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 7)
	sub.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	box.add_child(sub)

	box.add_child(_spacer(8))
	box.add_child(_button("继续游戏", "primary", func() -> void: resume_pressed.emit()))
	box.add_child(_button("返回主菜单", "ghost", func() -> void: menu_pressed.emit()))
	if not OS.has_feature("web"):
		box.add_child(_button("退出游戏", "ghost", func() -> void: quit_pressed.emit()))


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _button(text: String, kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.focus_mode = Control.FOCUS_NONE
	UiKit.style_button(b, kind)
	b.pressed.connect(cb)
	b.mouse_entered.connect(func() -> void: Sfx.play("ui_hover", -12.0))
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		resume_pressed.emit()
		get_viewport().set_input_as_handled()
