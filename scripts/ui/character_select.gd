extends Control
## 角色选择（蔚蓝档案风格）：三张正视图立绘卡片 + 难度/种子 + 开始按钮 + 次级入口
## 卡片悬停：立绘放大 1.04 + 卡片上浮 6px；选中：强调色描边 + 1.00→1.02 脉冲

signal character_chosen(id: String, seed_text: String, difficulty: int)
signal open_collection
signal open_training
signal resume_requested
signal abandon_requested

const IDS := ["deepseek", "gpt", "claude"]
const CARD_W := 140.0
const CARD_H := 216.0
const CARD_Y := 62.0
const CARD_GAP := 16.0

var _data: Array = []
var _tex: Array = []
var _intro: Array = []
var _rects: Array = []
var _hover: int = -1
var _hover_k: Array = [0.0, 0.0, 0.0]
var _sel: int = 0
var _pulse: float = 0.0
var _t: float = 0.0
var _enter: float = 20.0

var seed_text: String = ""
var _difficulty: int = 1
var _editing: bool = false
var _has_save: bool = false
var _confirm_abandon: float = 0.0
var _tip_visible: bool = true

var _start_btn: BaButton = null
var _btns: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	mouse_filter = Control.MOUSE_FILTER_STOP
	for id in IDS:
		_data.append(GameState.load_character(id))
		var p := "res://assets/portraits/%s_face.png" % id
		_tex.append(load(p) if ResourceLoader.exists(p) else null)
		_intro.append(DialogueManager.pick(id, "intro"))
	_has_save = RunSave.has_save()
	_difficulty = clampi(Settings.difficulty, 0, 2)
	SeedManager.difficulty = _difficulty
	_tip_visible = not MetaProgress.tutorial_flag("seen_select_tip")
	_layout()
	_build_buttons()
	BaCursor.set_battle(false)
	var tw := create_tween()
	tw.tween_property(self, "_enter", 0.0, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var pw := create_tween().set_loops()
	pw.tween_property(self, "_pulse", 1.0, 0.75)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pw.tween_property(self, "_pulse", 0.0, 0.75)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _layout() -> void:
	var total: float = IDS.size() * CARD_W + (IDS.size() - 1) * CARD_GAP
	var x0: float = (GameConfig.BASE_W - total) * 0.5
	for i in IDS.size():
		_rects.append(Rect2(x0 + i * (CARD_W + CARD_GAP), CARD_Y, CARD_W, CARD_H))


func _build_buttons() -> void:
	_start_btn = BaButton.new()
	add_child(_start_btn)
	_start_btn.setup("开始游戏", Rect2(GameConfig.BASE_W * 0.5 - 62, 292, 124, 26), "primary",
		"", UiKit.F_H3)
	_start_btn.pressed.connect(func() -> void: _choose(_sel))

	var labels := [["训练场", "T"], ["图鉴", "C"], ["继续", "V"], ["放弃", "X"]]
	var w := 92.0
	var gap := 8.0
	var total: float = labels.size() * w + (labels.size() - 1) * gap
	var x0: float = (GameConfig.BASE_W - total) * 0.5
	for i in labels.size():
		var b := BaButton.new()
		add_child(b)
		b.setup(String(labels[i][0]) + "  [" + String(labels[i][1]) + "]",
			Rect2(x0 + i * (w + gap), 326, w, 20), "ghost", "", UiKit.F_SMALL)
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
	var mouse := get_local_mouse_position()
	var prev := _hover
	_hover = -1
	for i in _rects.size():
		if (_rects[i] as Rect2).has_point(mouse):
			_hover = i
	if _hover != prev:
		for i in 3:
			_tween_hover(i, 1.0 if i == _hover else 0.0)
	if _hover >= 0:
		BaCursor.force_hot()
	for i in 3:
		if Input.is_action_just_pressed("select_%d" % (i + 1)):
			_sel = i
			Sfx.play("ui")
	if Input.is_action_just_pressed("ui_accept") and not _editing:
		_choose(_sel)
	if InputDevice.using_pad:
		pass
	queue_redraw()


func _tween_hover(i: int, target: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _hover_k[i] = v, float(_hover_k[i]), target, 0.12)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


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
		if _sel == _hover:
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
	return Rect2(28 + i * 40, 296, 36, 18)


func _seed_rect() -> Rect2:
	return Rect2(474, 296, 138, 18)


func _tip_rect() -> Rect2:
	return Rect2(GameConfig.BASE_W * 0.5 - 130, 34, 260, 18)


func _tip_close_rect() -> Rect2:
	var r := _tip_rect()
	return Rect2(r.end.x - 16, r.position.y + 2, 14, 14)


func _choose(index: int) -> void:
	if index < 0 or index >= IDS.size():
		return
	Sfx.play("ui_confirm", -4.0)
	set_process(false)
	character_chosen.emit(IDS[index], seed_text, _difficulty)


# ---------------- 绘制 ----------------
func _draw() -> void:
	UiKit.gradient_backdrop(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H))
	UiKit.stripes(self, Rect2(0, 0, GameConfig.BASE_W, 90), _t)
	draw_set_transform(Vector2(0, _enter), 0.0, Vector2.ONE)

	UiKit.text(self, Vector2(28, 32), "选择角色", UiKit.F_H2, UiKit.TEXT)
	UiKit.text(self, Vector2(28, 44), "挑一个搭档，闯进回响聚合体的核心", UiKit.F_TINY, UiKit.TEXT_DIM)
	UiKit.text_right(self, 612, 30, "种子 " + (seed_text if seed_text != "" else "随机"),
		UiKit.F_TINY, UiKit.TEXT_DIM)

	for i in IDS.size():
		_draw_card(i, _rects[i])

	# 难度
	UiKit.text(self, Vector2(28, 291), "难度", UiKit.F_TINY, UiKit.TEXT_DIM)
	for i in 3:
		var dr := _diff_rect(i)
		var on := i == _difficulty
		draw_style_box(UiKit.box(UiKit.ACCENT if on else Color(1, 1, 1, 0.72), 7,
			Color(1, 1, 1, 0.8), 1, false), dr)
		UiKit.text_center(self, dr.get_center().x, dr.position.y + 12,
			["简单", "普通", "困难"][i], UiKit.F_TINY, UiKit.TEXT_LIGHT if on else UiKit.TEXT_DIM)

	# 种子
	var sr := _seed_rect()
	draw_style_box(UiKit.box(Color(1, 1, 1, 0.9), 8, UiKit.ACCENT if _editing else Color(1, 1, 1, 0.8),
		1, false), sr)
	UiKit.text(self, sr.position + Vector2(8, 12),
		("种子 " + seed_text + ("_" if _editing else "")) if seed_text != "" else "种子 随机（点击输入）",
		UiKit.F_TINY, UiKit.TEXT if _editing else UiKit.TEXT_DIM)

	if _tip_visible:
		_draw_tip()
	if _confirm_abandon > 0.0:
		UiKit.text_center(self, GameConfig.BASE_W * 0.5, 288, "再点一次「放弃」确认删除本局存档",
			UiKit.F_TINY, UiKit.DANGER)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	UiKit.text_center(self, GameConfig.BASE_W * 0.5, GameConfig.BASE_H - 2,
		"非官方同人 · 完全免费 · 角色形象基于 B站 UP 主 ZipZipPipe 的二创（CC BY-NC-SA 4.0）",
		UiKit.F_TINY, Color(0.55, 0.60, 0.70))


func _draw_tip() -> void:
	var r := _tip_rect()
	draw_style_box(UiKit.box(Color(1.0, 0.97, 0.88, 0.95), 8, Color(1, 1, 1, 0.9), 1, true), r)
	UiKit.text(self, r.position + Vector2(10, 12), "第一次玩？先试试训练场（T）",
		UiKit.F_TINY, Color(0.55, 0.42, 0.12))
	var c := _tip_close_rect()
	UiKit.text_center(self, c.get_center().x, c.get_center().y + 4, "×", UiKit.F_SMALL, UiKit.TEXT_DIM)


func _draw_card(i: int, r: Rect2) -> void:
	var d: CharacterData = _data[i]
	var accent: Color = d.accent
	var hk: float = float(_hover_k[i])
	var selected := (_sel == i)
	var lift: float = -6.0 * hk
	var rr := Rect2(r.position + Vector2(0, lift), r.size)
	if selected:
		var k: float = 1.0 + 0.02 * _pulse
		var c2 := rr.get_center()
		rr = Rect2(c2 - rr.size * k * 0.5, rr.size * k)
	var bg := Color(1, 1, 1, 0.95) if not selected else Color(1, 1, 1, 0.99)
	draw_style_box(UiKit.box(bg, 10, Color(1, 1, 1, 0.9), 1, true), rr)
	if selected:
		draw_style_box(UiKit.box(Color(0, 0, 0, 0), 10, accent, 2, false), rr)
	elif hk > 0.01:
		draw_style_box(UiKit.box(Color(0, 0, 0, 0), 10,
			Color(accent.r, accent.g, accent.b, 0.35 * hk), 1, false), rr)

	# 立绘：正视图裁切，底部渐隐（图本身已带 alpha 渐隐）
	var pr := Rect2(rr.position + Vector2(5, 5), Vector2(rr.size.x - 10, rr.size.y - 70))
	draw_style_box(UiKit.box(Color(accent.r, accent.g, accent.b, 0.10), 8,
		Color(1, 1, 1, 0.6), 1, false), pr)
	if _tex[i] != null:
		var sc: float = 1.0 + 0.04 * hk
		var size := pr.size * sc
		var dst := Rect2(pr.get_center() - size * 0.5, size)
		UiKit.draw_tex_cover(self, _tex[i], dst)

	var tx := rr.position.x + 8.0
	var base := rr.end.y - 54.0
	UiKit.text(self, Vector2(tx, base), d.display_name, UiKit.F_H3, accent)
	UiKit.text(self, Vector2(tx, base + 10), UiKit.fit(d.title, rr.size.x - 16, UiKit.F_TINY),
		UiKit.F_TINY, UiKit.TEXT_DIM)
	UiKit.text(self, Vector2(tx, base + 22), "武器 · " + d.weapon_name, UiKit.F_TINY, UiKit.TEXT)
	UiKit.text(self, Vector2(tx, base + 32), "副武器 · " + _sub_name(d.id), UiKit.F_TINY,
		Color(accent.r * 0.8, accent.g * 0.8, accent.b * 0.9))
	UiKit.text(self, Vector2(tx, base + 44), "技能 · " + d.skill_name, UiKit.F_TINY, UiKit.TEXT)

	if selected:
		var cc := Vector2(rr.end.x - 12, rr.position.y + 12)
		draw_circle(cc, 5.0, accent)
		draw_polyline(PackedVector2Array([
			cc + Vector2(-2.4, 0.2), cc + Vector2(-0.6, 2.0), cc + Vector2(2.6, -2.0)]),
			Color(1, 1, 1, 0.96), 1.6, true)


func _sub_name(id: String) -> String:
	match id:
		"deepseek":
			return "深度检索"
		"gpt":
			return "思维链"
		_:
			return "对齐协议"
