extends Control
## 主菜单：容器布局（MarginContainer 32 + VBox），任何分辨率不重叠

signal start_game
signal continue_run
signal open_settings
signal open_collection
signal open_training
signal open_about

var _t: float = 0.0
var _enter: float = 20.0
var _has_save: bool = false
var _btn_continue: Button = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_has_save = RunSave.has_save()
	_build()
	BaCursor.set_battle(false)
	var tw := create_tween()
	tw.tween_property(self, "_enter", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	MusicManager.play("explore")


func _build() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 32)
	add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	root.add_child(col)

	var top := Control.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(top)

	var title := Label.new()
	title.text = "AI GUNGEON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UiKit.ACCENT)
	col.add_child(title)

	var sub := Label.new()
	sub.text = "非官方同人 · 像素俯视角 Roguelike · v%s" % str(
		ProjectSettings.get_setting("application/config/version", "0.5.2"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 7)
	sub.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	col.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	col.add_child(gap)

	var center := CenterContainer.new()
	col.add_child(center)
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	btns.custom_minimum_size = Vector2(220, 0)
	center.add_child(btns)

	var b_start := _button("开始游戏", "primary")
	b_start.pressed.connect(func() -> void: start_game.emit())
	btns.add_child(b_start)

	_btn_continue = _button("继续游戏", "ghost")
	_btn_continue.disabled = not _has_save
	_btn_continue.pressed.connect(func() -> void:
		if _has_save:
			continue_run.emit())
	btns.add_child(_btn_continue)

	var b_set := _button("设置", "ghost")
	b_set.pressed.connect(func() -> void: open_settings.emit())
	btns.add_child(b_set)

	var bottom := Control.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(bottom)

	var extra := HBoxContainer.new()
	extra.alignment = BoxContainer.ALIGNMENT_CENTER
	extra.add_theme_constant_override("separation", 8)
	col.add_child(extra)
	var pairs := [["图鉴", open_collection], ["训练场", open_training], ["关于", open_about]]
	for p in pairs:
		var b := _button(String(p[0]), "ghost")
		b.custom_minimum_size = Vector2(84, 26)
		var sig: Signal = p[1]
		b.pressed.connect(func() -> void: sig.emit())
		extra.add_child(b)

	var hint := Label.new()
	hint.text = "WASD 移动 · 左键射击 · 空格翻滚 · E 技能 · Q 副武器 · ESC 暂停"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 7)
	hint.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	col.add_child(hint)

	var credit := Label.new()
	credit.text = "角色形象基于 B站 UP 主 ZipZipPipe 的二创（CC BY-NC-SA 4.0）"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.add_theme_font_size_override("font_size", 6)
	credit.add_theme_color_override("font_color", Color(0.58, 0.62, 0.70))
	col.add_child(credit)


func _button(text: String, kind: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 34)
	b.focus_mode = Control.FOCUS_NONE
	UiKit.style_button(b, kind)
	b.mouse_entered.connect(func() -> void: Sfx.play("ui_hover", -14.0))
	b.pressed.connect(func() -> void: Sfx.play("ui_confirm", -10.0))
	return b


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ENTER, KEY_SPACE]:
			start_game.emit()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	UiKit.gradient_backdrop(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H))
	for i in 5:
		var a := 0.05 + 0.01 * i
		draw_rect(Rect2(0, 40 + i * 56, GameConfig.BASE_W, 28),
			Color(0.42, 0.58, 0.95, a * 0.5))
	UiKit.stripes(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), _t)
