extends Control
## 暂停菜单（v0.7 P2 像素面板）：继续 / 退出训练场 / 返回主菜单 / 退出游戏
## 容器布局，process_mode = WHEN_PAUSED；ESC 关闭由 main 统一接管。

signal resume_pressed
signal menu_pressed
signal quit_pressed
signal training_exit_pressed

var in_training: bool = false

var _panel: Control = null
const MARGIN := 20


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
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
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(root)

	var col := VBoxContainer.new()
	root.add_child(col)
	var top_sp := Control.new()
	top_sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(top_sp)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(panel)
	_panel = panel

	var bottom_sp := Control.new()
	bottom_sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(bottom_sp)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(220, 0)
	margin.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var title := Label.new()
	title.text = "暂停"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UiKit.CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var esc := Label.new()
	esc.text = "ESC 继续"
	esc.add_theme_font_size_override("font_size", 12)
	esc.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	head.add_child(esc)

	var sep := ColorRect.new()
	sep.color = UiKit.BORDER
	sep.custom_minimum_size = Vector2(0, 1)
	box.add_child(sep)
	box.add_child(_spacer(4))
	box.add_child(_btn("继续游戏", "primary", func() -> void: resume_pressed.emit()))
	if in_training:
		box.add_child(_btn("退出训练场", "ghost", func() -> void: training_exit_pressed.emit()))
	box.add_child(_btn("返回主菜单", "ghost", func() -> void: menu_pressed.emit()))
	if not OS.has_feature("web"):
		box.add_child(_btn("退出游戏", "ghost", func() -> void: quit_pressed.emit()))

	var tip := Label.new()
	tip.text = "进度已自动保存"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", Color(0.42, 0.48, 0.58))
	box.add_child(tip)


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _btn(text: String, kind: String, cb: Callable) -> Control:
	var b := BaButton.new()
	b.custom_minimum_size = Vector2(0, 24)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.setup(text, Rect2(0, 0, 220, 24), kind, "", UiKit.F_BODY)
	b.pressed.connect(cb)
	return b


func _center_panel(panel: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	panel.position = ((size - panel.size) * 0.5).round()
