extends Control
## 角色选择：三张立绘卡片，点击或按 1/2/3 选择

signal character_chosen(id: String)
signal open_collection
signal open_training
signal resume_requested
signal abandon_requested

const IDS := ["deepseek", "gpt", "claude"]
const CARD_W := 186.0
const CARD_H := 244.0
const CARD_Y := 62.0

var _data: Array = []
var _tex: Array = []
var _rects: Array = []
var _hover: int = -1
var _t: float = 0.0
var _intro: Array = []
var _focus: int = 0
var seed_text: String = ""
var _difficulty: int = 1
var _editing: bool = false
var _has_save: bool = false
var _confirm_abandon: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	mouse_filter = Control.MOUSE_FILTER_STOP
	for id in IDS:
		_data.append(GameState.load_character(id))
		var p := "res://assets/portraits/%s_full.png" % id
		_tex.append(load(p) if ResourceLoader.exists(p) else null)
		_intro.append(DialogueManager.pick(id, "intro"))
	_has_save = RunSave.has_save()
	_difficulty = clampi(Settings.difficulty, 0, 2)
	SeedManager.difficulty = _difficulty
	_layout()


func _layout() -> void:
	var total: float = IDS.size() * CARD_W + (IDS.size() - 1) * 14.0
	var x0: float = (GameConfig.BASE_W - total) * 0.5
	for i in IDS.size():
		_rects.append(Rect2(x0 + i * (CARD_W + 14.0), CARD_Y, CARD_W, CARD_H))


func _process(delta: float) -> void:
	_t += delta
	_confirm_abandon = maxf(0.0, _confirm_abandon - delta)
	var mouse := get_local_mouse_position()
	_hover = -1
	for i in _rects.size():
		if _rects[i].has_point(mouse):
			_hover = i
	for i in 3:
		if Input.is_action_just_pressed("select_%d" % (i + 1)):
			_choose(i)
	# 手柄 / 方向键导航
	if Input.is_action_just_pressed("ui_left"):
		_focus = maxi(0, _focus - 1)
	if Input.is_action_just_pressed("ui_right"):
		_focus = mini(IDS.size() - 1, _focus + 1)
	if Input.is_action_just_pressed("ui_accept"):
		_choose(_focus)
	if InputDevice.using_pad:
		_hover = _focus
	else:
		_focus = _hover if _hover >= 0 else _focus
	if Input.is_key_pressed(KEY_C):
		pass
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_local_mouse_position()
		if _seed_rect().has_point(m):
			_editing = true
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
			_choose(_hover)
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
		if event.physical_keycode == KEY_C:
			Sfx.play("ui")
			open_collection.emit()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_T:
			Sfx.play("ui")
			open_training.emit()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_V and _has_save:
			Sfx.play("ui")
			resume_requested.emit()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_X and _has_save:
			if _confirm_abandon > 0.0:
				Sfx.play("ui")
				abandon_requested.emit()
			else:
				_confirm_abandon = 2.0
				Sfx.play("hurt", -8.0, 1.4)
			get_viewport().set_input_as_handled()


func _diff_rect(i: int) -> Rect2:
	return Rect2(40 + i * 34, 312, 32, 14)


func _seed_rect() -> Rect2:
	return Rect2(150, 312, 96, 14)


func _choose(index: int) -> void:
	if index < 0 or index >= IDS.size():
		return
	Sfx.play("ui")
	set_process(false)
	character_chosen.emit(IDS[index], seed_text, _difficulty)


func _draw() -> void:
	# 背景
	draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color("#0a0c12"))
	for i in 12:
		var a := 0.05 - i * 0.004
		draw_rect(Rect2(0, i * 30, GameConfig.BASE_W, 30), Color(0.2, 0.3, 0.6, a))
	# 标题
	if GameConfig.ui_font != null:
		draw_string(GameConfig.ui_font, Vector2(0, 34), "AI GUNGEON · 选择角色",
			HORIZONTAL_ALIGNMENT_CENTER, GameConfig.BASE_W, 16, GameConfig.COL_TEXT)
		draw_string(GameConfig.ui_font, Vector2(0, 50),
			"非官方同人作品 · 完全免费 · 无任何付费内容", HORIZONTAL_ALIGNMENT_CENTER,
			GameConfig.BASE_W, 9, GameConfig.COL_DIM)

	for i in IDS.size():
		_draw_card(i, _rects[i])

	if GameConfig.ui_font != null:
		draw_string(GameConfig.ui_font, Vector2(0, GameConfig.BASE_H - 24),
			"WASD 移动 · 左键射击 · 空格翻滚 · E 技能 · R 切换模式 · C 图鉴 · T 训练场",
			HORIZONTAL_ALIGNMENT_CENTER, GameConfig.BASE_W, 8, GameConfig.COL_DIM)
		draw_string(GameConfig.ui_font, Vector2(0, GameConfig.BASE_H - 11),
			"非官方同人 · 角色形象基于 B站 UP 主 ZipZipPipe 的二创（CC BY-NC-SA 4.0）",
			HORIZONTAL_ALIGNMENT_CENTER, GameConfig.BASE_W, 7, Color(0.5, 0.55, 0.65))

	# 难度 + 种子
	draw_string(GameConfig.ui_font, Vector2(14, 323), "难度", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		GameConfig.COL_DIM)
	for i in 3:
		var dr := _diff_rect(i)
		var on := i == _difficulty
		draw_rect(dr, Color(0.18, 0.3, 0.46) if on else Color(0.1, 0.12, 0.17))
		draw_rect(dr, Color(0.55, 0.72, 1.0) if on else Color(0.3, 0.34, 0.42), false, 1.0)
		draw_string(GameConfig.ui_font, Vector2(dr.position.x, dr.position.y + 11),
			["简单", "普通", "困难"][i], HORIZONTAL_ALIGNMENT_CENTER, dr.size.x, 8,
			GameConfig.COL_TEXT if on else GameConfig.COL_DIM)
	var sr := _seed_rect()
	draw_rect(sr, Color(0.06, 0.08, 0.12, 0.95))
	draw_rect(sr, Color(1.0, 0.85, 0.4) if _editing else Color(0.3, 0.34, 0.42), false, 1.0)
	draw_string(GameConfig.ui_font, Vector2(sr.position.x + 5, sr.position.y + 11),
		("种子：" + seed_text + ("_" if _editing else "")) if seed_text != "" else "种子：随机",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		Color(1.0, 0.88, 0.5) if _editing else GameConfig.COL_DIM)
	_right_text(GameConfig.BASE_W - 10, 323, "训练场 [T]", 9, Color(0.6, 0.8, 1.0))
	if _has_save:
		_right_text(GameConfig.BASE_W - 10, 14, "继续上一局 [V]", 9, Color(0.7, 1.0, 0.75))
		_right_text(GameConfig.BASE_W - 10, 26,
			"再按一次 X 确认放弃" if _confirm_abandon > 0.0 else "放弃当前局 [X]", 8,
			Color(1.0, 0.45, 0.45) if _confirm_abandon > 0.0 else Color(0.6, 0.5, 0.5))


func _draw_card(i: int, r: Rect2) -> void:
	var d: CharacterData = _data[i]
	var accent: Color = d.accent
	var hovered := (_hover == i)
	var focused := (_focus == i and InputDevice.using_pad)
	var border := accent if hovered else Color(0.28, 0.32, 0.42)
	draw_rect(r, Color(0.08, 0.09, 0.13, 0.96))
	if hovered:
		draw_rect(r.grow(3), Color(accent.r, accent.g, accent.b, 0.16))
	draw_rect(r, border, false, 2.0 if hovered else 1.0)
	if focused:
		draw_rect(r.grow(4), Color(1.0, 0.85, 0.4, 0.9), false, 2.0)

	# 立绘区域
	var bob := sin(_t * 1.6 + float(i) * 1.1) * 2.0
	var pr := Rect2(r.position + Vector2(6, 6 + bob), Vector2(r.size.x - 12, 150))
	draw_rect(pr, Color(0.05, 0.06, 0.09))
	if _tex[i] != null:
		var tex: Texture2D = _tex[i]
		# 透明底全身立绘：按高度等比缩放，水平居中，不再裁切
		var side: float = pr.size.y
		var dst := Rect2(pr.get_center().x - side * 0.5, pr.position.y, side, side)
		draw_texture_rect(tex, dst, false)

	if GameConfig.ui_font == null:
		return
	var tx := r.position.x + 8
	var ty := pr.end.y + 16
	draw_string(GameConfig.ui_font, Vector2(tx, ty), d.display_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, accent)
	draw_string(GameConfig.ui_font, Vector2(tx, ty + 14), d.title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GameConfig.COL_DIM)
	draw_string(GameConfig.ui_font, Vector2(tx, ty + 32), "武器 · " + d.weapon_name,
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 9, GameConfig.COL_TEXT)
	draw_string(GameConfig.ui_font, Vector2(tx, ty + 46), "技能 · " + d.skill_name,
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 9, GameConfig.COL_TEXT)
	draw_string(GameConfig.ui_font, Vector2(tx, ty + 60),
		_fit("「%s」" % str(_intro[i]), r.size.x - 16, 9),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.86, 0.55))
	# 序号放左上角，避免和底部台词叠在一起
	draw_string(GameConfig.ui_font, Vector2(r.position.x + 8, r.position.y + 14),
		"%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		accent if hovered else Color(0.55, 0.6, 0.72))


## 右对齐文本（draw_string 的 width=-1 会忽略对齐参数，这里手算宽度）
func _right_text(x_right: float, y: float, text: String, size: int, color: Color) -> void:
	if GameConfig.ui_font == null:
		return
	var w: float = GameConfig.ui_font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(GameConfig.ui_font, Vector2(x_right - w, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## 超宽时截断并补省略号
func _fit(text: String, max_w: float, size: int) -> String:
	if GameConfig.ui_font == null:
		return text
	if GameConfig.ui_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_w:
		return text
	var out := text
	while out.length() > 1:
		out = out.substr(0, out.length() - 1)
		var probe := out + "…"
		if GameConfig.ui_font.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_w:
			return probe
	return out
