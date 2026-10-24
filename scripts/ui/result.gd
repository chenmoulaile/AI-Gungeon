extends Control
## 结算（蔚蓝档案风格）：半身立绘 + 结果标题 + 本局藏品 + 四列数据卡片 + 按钮

signal restart
signal to_menu

const SLOT_W := 58.0

var _bust: Texture2D = null
var _bg: Texture2D = null
var _line: String = ""
var _is_record: bool = false
var _t: float = 0.0
var _pop: float = 0.0
var _enter: float = 20.0
var _focus: int = 0
var _restart_btn: BaButton = null
var _menu_btn: BaButton = null
var _win: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	var p := "res://assets/portraits/%s_bust.png" % GameState.char_id
	if ResourceLoader.exists(p):
		_bust = load(p)
	if ResourceLoader.exists("user://last_frame.png"):
		var img := Image.load_from_file(ProjectSettings.globalize_path("user://last_frame.png"))
		if img != null:
			_bg = ImageTexture.create_from_image(img)
	_is_record = GameState.floor_index >= MetaProgress.max_floor and GameState.floor_index > 0
	_win = GameState.run_cleared
	_line = DialogueManager.pick(GameState.char_id, "victory" if _win else "death")
	MusicManager.play("explore")
	Sfx.play("skill" if _win else "die", -4.0, 0.8)
	BaCursor.set_battle(false)

	_restart_btn = BaButton.new()
	add_child(_restart_btn)
	_restart_btn.setup("重新开始", Rect2(GameConfig.BASE_W * 0.5 - 108, 304, 100, 26),
		"primary", "", UiKit.F_BODY)
	_restart_btn.pressed.connect(func() -> void: restart.emit())
	_menu_btn = BaButton.new()
	add_child(_menu_btn)
	_menu_btn.setup("返回主菜单", Rect2(GameConfig.BASE_W * 0.5 + 8, 304, 100, 26),
		"ghost", "", UiKit.F_BODY)
	_menu_btn.pressed.connect(func() -> void: to_menu.emit())

	var tw := create_tween()
	tw.tween_property(self, "_enter", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	_pop = minf(1.0, _pop + delta * 2.2)
	if Input.is_action_just_pressed("ui_left"):
		_focus = 0
	if Input.is_action_just_pressed("ui_right"):
		_focus = 1
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ENTER, KEY_SPACE]:
			restart.emit()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	if _bg != null:
		draw_texture_rect(_bg, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), false)
		draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.90, 0.93, 0.99, 0.90))
	else:
		UiKit.gradient_backdrop(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H))

	draw_set_transform(Vector2(0, _enter), 0.0, Vector2.ONE)
	var panel := Rect2(24, 12, GameConfig.BASE_W - 48, GameConfig.BASE_H - 24)
	draw_style_box(UiKit.box(Color(1, 1, 1, 0.96), 12, Color(1, 1, 1, 0.8), 1, true), panel)

	# 顶部：半身立绘 + 标题
	var pr := Rect2(40, 28, 88, 88)
	draw_style_box(UiKit.box(Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.12), 10,
		Color(1, 1, 1, 0.7), 1, false), pr)
	if _bust != null:
		UiKit.draw_tex_cover(self, _bust, pr.grow(-2))

	var d = GameState.char_data
	var x := 142.0
	UiKit.text(self, Vector2(x, 50), "胜利" if _win else "阵亡", UiKit.F_H2,
		UiKit.ACCENT if _win else UiKit.DANGER)
	UiKit.text(self, Vector2(x, 64), "%s · %s" % [d.display_name if d != null else GameState.char_id,
		d.title if d != null else ""], UiKit.F_SMALL, GameConfig.char_color(GameState.char_id))
	UiKit.text(self, Vector2(x, 80), "到达 B%d · 第 %d 间" % [GameState.floor_index,
		GameState.room_index], UiKit.F_BODY, UiKit.TEXT)
	if _is_record:
		var badge := Rect2(x, 86, 54, 13)
		draw_style_box(UiKit.box(Color(1.0, 0.92, 0.70), 6, Color(1, 1, 1, 0.8), 1, false), badge)
		UiKit.text_center(self, badge.get_center().x, badge.get_center().y + 2.0, "新纪录",
			UiKit.F_TINY, Color(0.62, 0.45, 0.06))
	else:
		UiKit.text(self, Vector2(x, 96), "最高层数 B%d" % MetaProgress.max_floor, UiKit.F_TINY,
			UiKit.TEXT_DIM)
	if _line != "":
		UiKit.text_block(self, Vector2(x, 112), "「%s」" % _line, GameConfig.BASE_W - x - 50,
			UiKit.F_TINY, Color(0.72, 0.55, 0.18), 2)

	# 中部：本局藏品
	UiKit.text(self, Vector2(40, 138), "本局藏品", UiKit.F_TINY, UiKit.TEXT_DIM)
	_draw_relics(Vector2(40, 144))

	# 底部：四列数据卡片
	_draw_stats()

	UiKit.text_center(self, GameConfig.BASE_W * 0.5, 342,
		"非官方同人 · 完全免费 · 角色形象基于 B站 UP 主 ZipZipPipe 的二创（CC BY-NC-SA 4.0）",
		UiKit.F_TINY, Color(0.55, 0.60, 0.70))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_relics(origin: Vector2) -> void:
	var shown := 0
	var total := GameState.upgrades.size()
	for uid in GameState.upgrades:
		if shown >= 8:
			break
		var up: Upgrade = UpgradeDB.get_upgrade(uid)
		if up == null:
			continue
		var k: float = clampf(_pop * 3.0 - float(shown) * 0.3, 0.0, 1.0)
		var r := Rect2(origin + Vector2(shown * SLOT_W, 0), Vector2(44, 44))
		var c := r.get_center()
		draw_style_box(UiKit.box(Color(1, 1, 1, 0.9), 8, Color(1, 1, 1, 0.7), 1, false),
			Rect2(c - Vector2(20, 20) * (0.7 + 0.3 * k), Vector2(40, 40) * (0.7 + 0.3 * k)))
		var tex := UiKit.icon(up.icon_path)
		if tex != null:
			draw_texture_rect(tex, Rect2(c - Vector2(13, 13) * k, Vector2(26, 26) * k), false)
		UiKit.text_center(self, c.x, r.end.y + 7, UiKit.fit(up.title, SLOT_W - 4, UiKit.F_TINY),
			UiKit.F_TINY, UiKit.TEXT_DIM)
		shown += 1
	if total > shown:
		UiKit.text(self, origin + Vector2(shown * SLOT_W + 4, 28), "+%d" % (total - shown),
			UiKit.F_SMALL, UiKit.TEXT_DIM)
	if total == 0:
		UiKit.text(self, origin + Vector2(0, 22), "（本局没有购买藏品）", UiKit.F_TINY, UiKit.TEXT_DIM)


func _draw_stats() -> void:
	var mins := int(GameState.run_time / 60.0)
	var secs := int(fmod(GameState.run_time, 60.0))
	var diff: String = ["简单", "普通", "困难"][clampi(SeedManager.difficulty, 0, 2)]
	var items := [
		["击杀", str(GameState.kills)],
		["金币", str(GameState.coins_earned)],
		["用时", "%d:%02d" % [mins, secs]],
		["难度", diff],
	]
	var w := 128.0
	var gap := 10.0
	var total: float = items.size() * w + (items.size() - 1) * gap
	var x0: float = (GameConfig.BASE_W - total) * 0.5
	for i in items.size():
		var r := Rect2(x0 + i * (w + gap), 214, w, 40)
		draw_style_box(UiKit.box(Color(0.96, 0.97, 1.0, 0.95), 9, Color(1, 1, 1, 0.8), 1, true), r)
		UiKit.text_center(self, r.get_center().x, r.position.y + 13, String(items[i][0]),
			UiKit.F_TINY, UiKit.TEXT_DIM)
		UiKit.text_center(self, r.get_center().x, r.position.y + 30, String(items[i][1]),
			UiKit.F_H3, UiKit.TEXT)
	UiKit.text_center(self, GameConfig.BASE_W * 0.5, 268,
		"组合 %d 组 · 协同 %d 组" % [GameState.combos.size(), GameState.synergies.size()],
		UiKit.F_TINY, UiKit.TEXT_DIM)
