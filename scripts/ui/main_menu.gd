extends Control
## 主菜单（蔚蓝档案风格）：中央大标题 + 三个主按钮 + 右下角次级入口

signal start_game
signal continue_run
signal open_settings
signal open_collection
signal open_training
signal open_about

var _t: float = 0.0
var _enter: float = 20.0
var _has_save: bool = false
var _btn_start: BaButton = null
var _btn_continue: BaButton = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_has_save = RunSave.has_save()
	_build()
	BaCursor.set_battle(false)
	var tw := create_tween()
	tw.tween_property(self, "_enter", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	MusicManager.play("explore")


func _build() -> void:
	var cx := GameConfig.BASE_W * 0.5
	_btn_start = BaButton.new()
	add_child(_btn_start)
	_btn_start.setup("开始游戏", Rect2(cx - 84, 196, 168, 30), "primary", "", UiKit.F_H3)
	_btn_start.pressed.connect(func() -> void: start_game.emit())

	_btn_continue = BaButton.new()
	add_child(_btn_continue)
	_btn_continue.setup("继续游戏", Rect2(cx - 84, 232, 168, 26), "secondary", "", UiKit.F_BODY)
	_btn_continue.disabled = not _has_save
	_btn_continue.pressed.connect(func() -> void:
		if _has_save:
			continue_run.emit())

	var b3 := BaButton.new()
	add_child(b3)
	b3.setup("设置", Rect2(cx - 84, 264, 168, 26), "secondary", "", UiKit.F_BODY)
	b3.pressed.connect(func() -> void: open_settings.emit())

	var labels := [["图鉴", 0], ["训练场", 1], ["关于", 2]]
	for i in labels.size():
		var b := BaButton.new()
		add_child(b)
		b.setup(String(labels[i][0]), Rect2(GameConfig.BASE_W - 60, 250 + i * 30, 46, 24),
			"ghost", "", UiKit.F_TINY)
		match i:
			0:
				b.pressed.connect(func() -> void: open_collection.emit())
			1:
				b.pressed.connect(func() -> void: open_training.emit())
			_:
				b.pressed.connect(func() -> void: open_about.emit())


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
	# 背景：淡淡的像素场景虚化（几个大色块 + 斜纹）
	for i in 5:
		var a := 0.05 + 0.01 * i
		draw_rect(Rect2(0, 40 + i * 56, GameConfig.BASE_W, 28),
			Color(0.42, 0.58, 0.95, a * 0.5))
	UiKit.stripes(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), _t)
	draw_set_transform(Vector2(0, _enter), 0.0, Vector2.ONE)

	# 标题
	var cx := GameConfig.BASE_W * 0.5
	draw_style_box(UiKit.box(Color(1, 1, 1, 0.72), 14, Color(1, 1, 1, 0.8), 1, true),
		Rect2(cx - 150, 62, 300, 78))
	UiKit.text_center(self, cx, 106, "AI GUNGEON", UiKit.F_H1, UiKit.ACCENT)
	UiKit.text_center(self, cx, 126, "非官方同人 · 像素俯视角 Roguelike", UiKit.F_TINY, UiKit.TEXT_DIM)
	UiKit.chip(self, Vector2(cx, 152), "v0.4.0", UiKit.F_TINY,
		Color(1, 1, 1, 0.8), UiKit.TEXT_DIM)

	# 底部信息
	UiKit.text_center(self, cx, 318, "WASD 移动 · 左键射击 · 空格翻滚 · E 技能 · Q 副武器 · R 切换",
		UiKit.F_TINY, UiKit.TEXT_DIM)
	UiKit.text_center(self, cx, 334,
		"角色形象基于 B站 UP 主 ZipZipPipe 的二创（CC BY-NC-SA 4.0）",
		UiKit.F_TINY, Color(0.58, 0.62, 0.70))
	if not _has_save:
		UiKit.text_right(self, cx - 96, 248, "", UiKit.F_TINY, UiKit.TEXT_DIM)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
