extends Control
## 角色选择（v0.7 P2）：4 张 104×176 像素卡（第 4 张大肥鱼锁定）、属性分段条、
## 难度药丸、种子输入、像素按钮。悬停只上移 1px，不做缩放/脉冲。

signal character_chosen(id: String, seed_text: String, difficulty: int)
signal open_collection
signal open_training
signal resume_requested
signal abandon_requested

const IDS := ["deepseek", "gpt", "claude"]
const CARD_W := 104.0
const CARD_H := 176.0
const CARD_Y := 60.0
const CARD_GAP := 12.0

var _data: Array = []
var _tex: Array = []
var _intro: Array = []
var _rects: Array = []
var _stats: Array = []
var _hover: int = -1
var _sel: int = 0
var _t: float = 0.0
var _enter: float = 8.0

var seed_text: String = ""
var _difficulty: int = 1
var _editing: bool = false
var _has_save: bool = false
var _confirm_abandon: float = 0.0
var _tip_visible: bool = true
var _toast: String = ""
var _toast_t: float = 0.0

var _start_btn: BaButton = null
var _btns: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	for id in IDS:
		_data.append(GameState.load_character(id))
		var p := "res://assets/portraits/%s_pixel.png" % id
		_tex.append(load(p) if ResourceLoader.exists(p) else null)
		_intro.append(DialogueManager.pick(id, "intro"))
		_stats.append(Stats.char(id))
	_has_save = RunSave.has_save()
	_difficulty = clampi(Settings.difficulty, 0, 2)
	SeedManager.difficulty = _difficulty
	_tip_visible = not MetaProgress.tutorial_flag("seen_select_tip")
	_layout()
	_build_buttons()
	BaCursor.set_battle(false)
	var tw := create_tween()
	tw.tween_property(self, "_enter", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _layout() -> void:
	_rects.clear()
	var count := IDS.size() + 1
	var total: float = count * CARD_W + (count - 1) * CARD_GAP
	var x0: float = (GameConfig.BASE_W - total) * 0.5
	for i in count:
		_rects.append(Rect2(x0 + i * (CARD_W + CARD_GAP), CARD_Y, CARD_W, CARD_H))


func _build_buttons() -> void:
	_start_btn = BaButton.new()
	add_child(_start_btn)
	_start_btn.setup("开始游戏", Rect2(500, 318, 116, 22), "primary", "", UiKit.F_BODY)
	_start_btn.pressed.connect(func() -> void: _choose(_sel))

	var labels := [["训练场", "T"], ["图鉴", "C"], ["继续", "V"], ["放弃", "X"]]
	var w := 92.0
	var gap := 8.0
	for i in labels.size():
		var b := BaButton.new()
		add_child(b)
		b.setup(String(labels[i][0]) + " [" + String(labels[i][1]) + "]",
			Rect2(24 + i * (w + gap), 319, w, 22), "ghost", "", UiKit.F_BODY)
		_btns.append(b)
	_btns[0].pressed.connect(func() -> void: open_training.emit())
	_btns[1].pressed.connect(func() -> void: open_collection.emit())
	_btns[2].pressed.connect(func() -> void:
		if _has_save:
			resume_requested.emit())
	_btns[3].pressed.connect(func() -> void: _abandon())
	_btns[2].disabled = not _has_save
	_btns[3].disabled = not _has_save


func _abandon() -> void:
	if not _has_save:
		return
	if _confirm_abandon > 0.0:
		abandon_requested.emit()
	else:
		_confirm_abandon = 2.0
		Sfx.play("hurt", -10.0, 1.4)


func _process(delta: float) -> void:
	_t += delta
	_confirm_abandon = maxf(0.0, _confirm_abandon - delta)
	_toast_t = maxf(0.0, _toast_t - delta)
	var mouse := get_local_mouse_position()
	var prev := _hover
	_hover = -1
	for i in _rects.size():
		if (_rects[i] as Rect2).has_point(mouse):
			_hover = i
	if _hover >= 0:
		BaCursor.force_hot()
	for i in 3:
		if Input.is_action_just_pressed("select_%d" % (i + 1)):
			_sel = i
			Sfx.play("ui")
	if Input.is_action_just_pressed("ui_accept") and not _editing:
		_choose(_sel)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	var m := get_local_mouse_position()
	if _seed_rect().has_point(m):
		_editing = true
		Sfx.play("ui")
		accept_event()
		return
	if _tip_close_rect().has_point(m) and _tip_visible:
		_tip_visible = false
		MetaProgress.set_tutorial_flag("seen_select_tip")
		Sfx.play("ui")
		accept_event()
		return
	for i in 3:
		if _diff_rect(i).has_point(m):
			_difficulty = i
			Settings.difficulty = i
			Settings.save_settings()
			SeedManager.difficulty = i
			Sfx.play("ui")
			accept_event()
			return
	if _hover >= 0:
		if _hover >= IDS.size():
			_toast = "大肥鱼尚未解锁 · 将在 P6 加入"
			_toast_t = 1.6
			Sfx.play("hurt", -16.0, 1.6)
		elif _sel == _hover:
			_choose(_hover)
		else:
			_sel = _hover
			Sfx.play("ui")
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _editing:
		if event is InputEventKey and event.pressed:
			var k := event as InputEventKey
			if k.physical_keycode in [KEY_ENTER, KEY_ESCAPE]:
				_editing = false
			elif k.physical_keycode == KEY_BACKSPACE:
				seed_text = seed_text.substr(0, maxi(0, seed_text.length() - 1))
			elif k.unicode >= 32 and seed_text.length() < 10:
				seed_text += char(k.unicode)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_C:
				Sfx.play("ui")
				open_collection.emit()
				get_viewport().set_input_as_handled()
			KEY_T:
				Sfx.play("ui")
				open_training.emit()
				get_viewport().set_input_as_handled()
			KEY_V:
				if _has_save:
					resume_requested.emit()
					get_viewport().set_input_as_handled()
			KEY_X:
				if _has_save:
					_abandon()
					get_viewport().set_input_as_handled()
			KEY_LEFT:
				_sel = maxi(0, _sel - 1)
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				_sel = mini(IDS.size() - 1, _sel + 1)
				get_viewport().set_input_as_handled()


func _diff_rect(i: int) -> Rect2:
	return Rect2(56 + i * 48, 294, 44, 18)


func _seed_rect() -> Rect2:
	return Rect2(452, 10, 164, 20)


func _tip_rect() -> Rect2:
	return Rect2(24, 36, 288, 18)


func _tip_close_rect() -> Rect2:
	var r := _tip_rect()
	return Rect2(r.end.x - 18, r.position.y + 1, 16, 16)


func _choose(index: int) -> void:
	if index < 0 or index >= IDS.size():
		return
	Sfx.play("ui_confirm", -4.0)
	set_process(false)
	character_chosen.emit(IDS[index], seed_text, _difficulty)


# ---------------- 绘制 ----------------
func _draw() -> void:
	UiKit.gradient_backdrop(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), _t)
	draw_set_transform(Vector2(0, _enter), 0.0, Vector2.ONE)

	UiKit.text(self, Vector2(24, 30), "选择角色", UiKit.F_H2, UiKit.TEXT)
	# 种子
	var sr := _seed_rect()
	UiKit.inset(self, sr, UiKit.VOID, UiKit.CYAN if _editing else UiKit.BORDER)
	var seed_show := seed_text if seed_text != "" else "随机"
	UiKit.text(self, sr.position + Vector2(8, 15), "种子 " + seed_show + ("_" if _editing else ""),
		12, UiKit.TEXT if _editing else UiKit.TEXT_DIM)
	if _editing:
		UiKit.corner_brackets(self, sr, UiKit.CYAN, 3)

	for i in _rects.size():
		_draw_card(i, _rects[i])
	_draw_detail()

	# 难度药丸
	UiKit.text(self, Vector2(24, 308), "难度", 12, UiKit.TEXT_DIM)
	for i in 3:
		var dr := _diff_rect(i)
		var on := i == _difficulty
		UiKit.frame(self, dr, UiKit.RAISED if on else UiKit.PANEL,
			UiKit.GOLD if on else UiKit.BORDER, Color(0, 0, 0, 0), false)
		UiKit.text_center(self, dr.get_center().x, dr.position.y + 13,
			["简单", "普通", "困难"][i], 12, UiKit.GOLD if on else UiKit.TEXT_DIM)

	if _tip_visible:
		_draw_tip()
	if _confirm_abandon > 0.0:
		UiKit.text_center(self, GameConfig.BASE_W * 0.5, 300,
			"再点一次「放弃」确认删除本局存档", 12, UiKit.DANGER)
	if _toast_t > 0.0:
		var tw := UiKit.measure(_toast, 12) + 20
		UiKit.frame(self, Rect2((640 - tw) * 0.5, 340, tw, 18), UiKit.DEEP, UiKit.DANGER, Color(0, 0, 0, 0))
		UiKit.text_center(self, 320, 352, _toast, 12, UiKit.DANGER)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	UiKit.text_center(self, GameConfig.BASE_W * 0.5, 354,
		"非官方同人 · 完全免费 · 角色形象基于 B站 UP 主 ZipZipPipe 二创（CC BY-NC-SA 4.0）",
		12, Color(0.42, 0.47, 0.57))


func _draw_tip() -> void:
	var r := _tip_rect()
	UiKit.frame(self, r, Color("#2A2418"), UiKit.GOLD, Color(0, 0, 0, 0), false)
	UiKit.text(self, r.position + Vector2(8, 13), "第一次玩？先试试训练场（T）", 12, UiKit.GOLD)
	var c := _tip_close_rect()
	UiKit.text_center(self, c.get_center().x, c.get_center().y + 4, "×", 12, UiKit.TEXT_DIM)


func _draw_card(i: int, r: Rect2) -> void:
	if i >= IDS.size():
		_draw_locked_card(r)
		return
	var d: CharacterData = _data[i]
	var accent: Color = d.accent
	var hk := 1.0 if _hover == i else 0.0
	var selected := (_sel == i)
	var rr := Rect2(r.position + Vector2(0, -1 if (hk > 0.0 or selected) else 0), r.size)
	var bg := UiKit.RAISED if (hk > 0.0 or selected) else UiKit.PANEL
	UiKit.frame(self, rr, bg, UiKit.BORDER, UiKit.BORDER_HI, true)
	# 顶部角色色条
	draw_rect(Rect2(rr.position + Vector2(1, 1), Vector2(rr.size.x - 2, 2)), accent)

	# 立绘 96×128（1x 精确放入 96×132 区域）
	var pr := Rect2(rr.position + Vector2(4, 4), Vector2(96, 132))
	UiKit.inset(self, pr, Color(accent.r, accent.g, accent.b, 0.10), UiKit.BORDER)
	if _tex[i] != null:
		UiKit.draw_tex_contain(self, _tex[i], Rect2(pr.position + Vector2(0, 2), Vector2(96, 128)))

	# 名字
	UiKit.text_center(self, rr.get_center().x, rr.position.y + 148, d.display_name, 12,
		accent if (selected or hk > 0.0) else UiKit.TEXT)
	# 武器图标 24×24 + 名称
	var icon_path := "res://assets/icons/weapons/%s.png" % d.id
	var icon_rect := Rect2(rr.position + Vector2(8, 151), Vector2(20, 20))
	if not UiKit.draw_icon(self, icon_path, icon_rect):
		_draw_weapon_placeholder(icon_rect, accent)
	UiKit.text(self, rr.position + Vector2(32, 166),
		UiKit.fit(d.weapon_name, rr.size.x - 38, 12), 12, UiKit.TEXT_DIM)

	if selected:
		UiKit.corner_brackets(self, rr.grow(1), UiKit.GOLD, 6)
		if fmod(_t, 1.0) < 0.6:
			var tag := Rect2(rr.position + Vector2(62, 6), Vector2(38, 16))
			draw_rect(tag, UiKit.GOLD)
			UiKit.text_center(self, tag.get_center().x, tag.get_center().y + 4, "READY", 12,
				UiKit.VOID)


func _draw_locked_card(r: Rect2) -> void:
	UiKit.frame(self, r, Color("#0C1120"), UiKit.BORDER, Color(0, 0, 0, 0), true)
	var pr := Rect2(r.position + Vector2(4, 4), Vector2(96, 132))
	UiKit.inset(self, pr, UiKit.VOID, Color("#222B40"))
	# 大肥鱼剪影：圆头 + 身体 + 鲸尾（纯色块，不用平滑多边形）
	var cx := pr.get_center().x
	var base := pr.end.y - 8
	draw_rect(Rect2(cx - 22, base - 50, 44, 42), Color("#121926"))
	draw_rect(Rect2(cx - 26, base - 38, 4, 26), Color("#121926"))
	draw_rect(Rect2(cx + 22, base - 38, 4, 26), Color("#121926"))
	draw_rect(Rect2(cx - 18, base - 70, 36, 22), Color("#121926"))
	draw_rect(Rect2(cx - 14, base - 76, 28, 6), Color("#121926"))
	# 鲸尾
	draw_rect(Rect2(cx - 34, base - 34, 12, 8), Color("#121926"))
	draw_rect(Rect2(cx + 22, base - 34, 12, 8), Color("#121926"))
	# 锁
	UiKit.text_center(self, r.get_center().x, r.position.y + 152, "大肥鱼", 12, Color("#4A5468"))
	UiKit.text_center(self, r.get_center().x, r.position.y + 172, "未解锁 · P6", 12, Color("#3A4A70"))


func _draw_detail() -> void:
	var r := Rect2(24, 240, 592, 48)
	UiKit.frame(self, r, UiKit.DEEP, UiKit.BORDER, UiKit.BORDER_HI, true)
	var d: CharacterData = _data[_sel]
	var st: CharacterStats = _stats[_sel]
	UiKit.text(self, Vector2(36, 258), d.display_name, 24, d.accent, false)
	UiKit.text(self, Vector2(36, 278),
		UiKit.fit(d.title + " · 武器 " + d.weapon_name + " · 技能 " + d.skill_name, 320, 12),
		12, UiKit.TEXT_DIM)

	# 属性：HP / SPD / CD 三列，数值与条留 6px 间隙
	var bx := 388.0
	UiKit.text(self, Vector2(bx, 254), "HP", 12, UiKit.TEXT_DIM)
	UiKit.bar(self, Rect2(bx + 30, 246, 58, 8), clampf(float(st.max_hp) / 120.0, 0.0, 1.0), UiKit.SUCCESS)
	UiKit.text(self, Vector2(bx + 94, 254), str(st.max_hp), 12, UiKit.TEXT)

	UiKit.text(self, Vector2(bx, 274), "SPD", 12, UiKit.TEXT_DIM)
	UiKit.bar(self, Rect2(bx + 30, 266, 58, 8), clampf(st.move_speed / 160.0, 0.0, 1.0), UiKit.CYAN)
	UiKit.text(self, Vector2(bx + 94, 274), str(int(st.move_speed)), 12, UiKit.TEXT)

	UiKit.text(self, Vector2(524, 254), "CD", 12, UiKit.TEXT_DIM)
	UiKit.bar(self, Rect2(550, 246, 58, 8), clampf(1.0 - st.skill_cd / 12.0, 0.0, 1.0), UiKit.GOLD)
	UiKit.text(self, Vector2(524, 274), "技能 %.0fs" % st.skill_cd, 12, UiKit.TEXT_DIM)


func _draw_weapon_placeholder(r: Rect2, accent: Color) -> void:
	UiKit.inset(self, r, UiKit.VOID, UiKit.BORDER)
	# 简易手枪剪影：1px 像素块
	var c := r.position
	draw_rect(Rect2(c + Vector2(4, 7), Vector2(13, 4)), accent)
	draw_rect(Rect2(c + Vector2(14, 10), Vector2(4, 7)), accent)
	draw_rect(Rect2(c + Vector2(7, 11), Vector2(5, 3)), accent.darkened(0.25))
