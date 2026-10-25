extends Control
## 结算（v0.7 P2 像素版）：RUN OVER / CLEAR 印章 + 像素统计表 + 本局藏品

signal restart
signal to_menu

const SLOT_W := 56.0

var _bust: Texture2D = null
var _bg: Texture2D = null
var _line: String = ""
var _is_record: bool = false
var _t: float = 0.0
var _pop: float = 0.0
var _enter: float = 16.0
var _focus: int = 0
var _restart_btn: BaButton = null
var _menu_btn: BaButton = null
var _win: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	var p := "res://assets/portraits/%s_pixel.png" % GameState.char_id
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
	_restart_btn.setup("重新开始", Rect2(212, 306, 100, 24), "primary", "", UiKit.F_BODY)
	_restart_btn.pressed.connect(func() -> void: restart.emit())
	_menu_btn = BaButton.new()
	add_child(_menu_btn)
	_menu_btn.setup("返回主菜单", Rect2(328, 306, 100, 24), "ghost", "", UiKit.F_BODY)
	_menu_btn.pressed.connect(func() -> void: to_menu.emit())

	var tw := create_tween()
	tw.tween_property(self, "_enter", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	_pop = minf(1.0, _pop + delta * 3.2)
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
		draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H),
			Color(UiKit.VOID.r, UiKit.VOID.g, UiKit.VOID.b, 0.86))
	else:
		UiKit.gradient_backdrop(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), _t)
	UiKit.dither_rect(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H),
		Color(0.03, 0.04, 0.07, 0.5), 4)

	draw_set_transform(Vector2(0, roundf(_enter)), 0.0, Vector2.ONE)
	var panel := Rect2(24, 12, GameConfig.BASE_W - 48, GameConfig.BASE_H - 24)
	UiKit.frame(self, panel, UiKit.DEEP, UiKit.BORDER, UiKit.BORDER_HI, true)
	UiKit.scanlines(self, panel.grow(-2), 0.05)
	for k in 4:
		draw_rect(Rect2(panel.position.x + 4 + k * 6, panel.position.y + 1, 4, 1), UiKit.PANEL)

	# 头图立绘
	var pr := Rect2(40, 34, 96, 128)
	UiKit.inset(self, pr, UiKit.VOID, UiKit.BORDER)
	if _bust != null:
		UiKit.draw_tex_contain(self, _bust, pr.grow(-1))

	var d = GameState.char_data
	var x := 152.0
	UiKit.text(self, Vector2(x, 62), "通关" if _win else "阵亡", UiKit.F_H1,
		UiKit.SUCCESS if _win else UiKit.DANGER)
	UiKit.text(self, Vector2(x, 78), "CLEAR" if _win else "RUN OVER", UiKit.F_SMALL,
		UiKit.TEXT_DIM)
	UiKit.text(self, Vector2(x, 100), "%s · %s" % [
		d.display_name if d != null else GameState.char_id,
		d.title if d != null else ""], UiKit.F_SMALL, GameConfig.char_color(GameState.char_id))
	UiKit.text(self, Vector2(x, 116), "到达 B%d · 第 %d 间" % [GameState.floor_index,
		GameState.room_index], UiKit.F_BODY, UiKit.TEXT)
	if _is_record:
		var badge := Rect2(x, 124, 54, 14)
		UiKit.frame(self, badge, UiKit.PANEL, UiKit.GOLD, Color(0, 0, 0, 0), false)
		UiKit.text_center(self, badge.get_center().x, badge.get_center().y + 4.0, "新纪录",
			UiKit.F_SMALL, UiKit.GOLD)
	else:
		UiKit.text(self, Vector2(x + 60, 136), "最高 B%d" % MetaProgress.max_floor,
			UiKit.F_SMALL, UiKit.TEXT_DIM)
	if _line != "":
		UiKit.text_block(self, Vector2(x, 150), "「%s」" % _line,
			GameConfig.BASE_W - x - 40, UiKit.F_SMALL, Color(0.85, 0.70, 0.35), 2)

	# 印章
	var stamp := Rect2(452, 32, 128, 46)
	draw_rect(stamp, Color(UiKit.VOID.r, UiKit.VOID.g, UiKit.VOID.b, 0.7))
	draw_rect(stamp, UiKit.SUCCESS if _win else UiKit.DANGER, false, 2.0)
	draw_rect(stamp.grow(-3), UiKit.SUCCESS if _win else UiKit.DANGER, false, 1.0)
	UiKit.text_center(self, stamp.get_center().x, 58, "CLEAR" if _win else "RUN OVER",
		UiKit.F_H2, UiKit.SUCCESS if _win else UiKit.DANGER)
	UiKit.text_center(self, stamp.get_center().x, 74, "B%d" % GameState.floor_index,
		UiKit.F_SMALL, UiKit.TEXT_DIM)

	# 本局藏品
	UiKit.text(self, Vector2(40, 184), "本局藏品", UiKit.F_SMALL, UiKit.TEXT_DIM)
	_draw_relics(Vector2(40, 190))

	_draw_stats()

	UiKit.text_center(self, GameConfig.BASE_W * 0.5, 298,
		"组合 %d 组 · 协同 %d 组" % [GameState.combos.size(), GameState.synergies.size()],
		UiKit.F_SMALL, UiKit.TEXT_DIM)
	UiKit.text_center(self, GameConfig.BASE_W * 0.5, 342,
		"非官方同人 · 完全免费 · 角色形象基于 B站 UP 主 ZipZipPipe 的二创（CC BY-NC-SA 4.0）",
		UiKit.F_SMALL, Color(0.45, 0.50, 0.62))
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
		if _pop <= float(shown) * 0.08:
			break
		var r := Rect2(origin + Vector2(shown * SLOT_W, 0), Vector2(52, 44))
		UiKit.inset(self, r, UiKit.VOID, UiKit.BORDER)
		var tex := UiKit.icon(up.icon_path)
		if tex != null:
			draw_texture_rect(tex, Rect2(r.position + Vector2(10, 6), Vector2(32, 32)), false)
		UiKit.text_center(self, r.get_center().x, r.end.y + 11,
			UiKit.fit(up.title, SLOT_W - 8, UiKit.F_SMALL), UiKit.F_SMALL, UiKit.TEXT_DIM)
		shown += 1
	if total > shown:
		UiKit.text(self, origin + Vector2(shown * SLOT_W + 4, 28), "+%d" % (total - shown),
			UiKit.F_SMALL, UiKit.TEXT_DIM)
	if total == 0:
		UiKit.text(self, origin + Vector2(0, 22), "（本局没有购买藏品）", UiKit.F_SMALL,
			UiKit.TEXT_DIM)


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
	var x0: float = roundf((GameConfig.BASE_W - total) * 0.5)
	for i in items.size():
		var r := Rect2(x0 + i * (w + gap), 254, w, 36)
		UiKit.frame(self, r, UiKit.PANEL, UiKit.BORDER, UiKit.BORDER_HI, true)
		UiKit.text_center(self, r.get_center().x, r.position.y + 11, String(items[i][0]),
			UiKit.F_SMALL, UiKit.TEXT_DIM)
		UiKit.text_center(self, r.get_center().x, r.position.y + 32, String(items[i][1]),
			UiKit.F_H2, UiKit.TEXT)
