extends Control
## 角色选择：三张立绘卡片，点击或按 1/2/3 选择

signal character_chosen(id: String)
signal open_collection

const IDS := ["deepseek", "gpt", "claude"]
const CARD_W := 186.0
const CARD_H := 262.0
const CARD_Y := 62.0

var _data: Array = []
var _tex: Array = []
var _rects: Array = []
var _hover: int = -1
var _t: float = 0.0
var _intro: Array = []
var _focus: int = 0


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
	_layout()


func _layout() -> void:
	var total: float = IDS.size() * CARD_W + (IDS.size() - 1) * 14.0
	var x0: float = (GameConfig.BASE_W - total) * 0.5
	for i in IDS.size():
		_rects.append(Rect2(x0 + i * (CARD_W + 14.0), CARD_Y, CARD_W, CARD_H))


func _process(delta: float) -> void:
	_t += delta
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
		if _hover >= 0:
			_choose(_hover)
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_C:
			Sfx.play("ui")
			open_collection.emit()
			get_viewport().set_input_as_handled()


func _choose(index: int) -> void:
	if index < 0 or index >= IDS.size():
		return
	Sfx.play("ui")
	set_process(false)
	character_chosen.emit(IDS[index])


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
		draw_string(GameConfig.ui_font, Vector2(0, GameConfig.BASE_H - 12),
			"WASD 移动 · 鼠标瞄准 · 左键射击 · 空格翻滚 · E 技能 · R 切换模式 · C 图鉴",
			HORIZONTAL_ALIGNMENT_CENTER, GameConfig.BASE_W, 9, GameConfig.COL_DIM)
		draw_string(GameConfig.ui_font, Vector2(0, GameConfig.BASE_H - 26),
			"非官方同人 · 角色形象基于 B站 UP 主 ZipZipPipe 的二创设计（CC BY-NC-SA 4.0）",
			HORIZONTAL_ALIGNMENT_CENTER, GameConfig.BASE_W, 8, Color(0.5, 0.55, 0.65))


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
		# 等比裁切：取中间 1:1 区域铺满
		var side: float = minf(tex.get_width(), tex.get_height())
		var src := Rect2((tex.get_width() - side) * 0.5, 0, side, side)
		draw_texture_rect_region(tex, pr, src)

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
	draw_string(GameConfig.ui_font, Vector2(tx, ty + 60), "「%s」" % str(_intro[i]),
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 9, Color(1.0, 0.86, 0.55))
	draw_string(GameConfig.ui_font, Vector2(r.position.x, r.end.y - 8),
		"[%d]" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 9,
		accent if hovered else GameConfig.COL_DIM)
