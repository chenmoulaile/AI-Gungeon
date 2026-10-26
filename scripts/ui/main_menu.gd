extends Control
## 主菜单（v0.7 P2）：左对齐终端菜单 + 右侧像素小剧场；无圆角/渐变/线性过滤。

signal start_game
signal continue_run
signal open_settings
signal open_collection
signal open_training
signal open_about
signal quit_game

const IDS := ["deepseek", "gpt", "claude"]
const MENU_X := 32.0
const MENU_Y := 104.0
const BTN_W := 176.0
const BTN_H := 22.0
const BTN_GAP := 4.0

var _t: float = 0.0
var _enter: float = 8.0
var _has_save: bool = false
var _btns: Array = []
var _focus: int = 0
var _sprites: Array = []
var _accents: Array = [Color("#5F86F0"), Color("#B06BFF"), Color("#FF8A4D")]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = null
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_has_save = RunSave.has_save()
	for id in IDS:
		var p := "res://assets/sprites/%s/idle.png" % id
		_sprites.append(load(p) if ResourceLoader.exists(p) else null)
	_build()
	BaCursor.set_battle(false)
	var tw := create_tween()
	tw.tween_property(self, "_enter", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	MusicManager.play("explore")


func _build() -> void:
	var rows := [
		["开始游戏", "primary", "start"],
		["继续游戏", "ghost", "continue"],
		["训练场", "ghost", "training"],
		["图鉴", "ghost", "collection"],
		["设置", "ghost", "settings"],
		["关于", "ghost", "about"],
		["退出游戏", "ghost", "quit"],
	]
	for i in rows.size():
		var row: Array = rows[i]
		var b := BaButton.new()
		add_child(b)
		b.setup(String(row[0]), Rect2(MENU_X, MENU_Y + i * (BTN_H + BTN_GAP), BTN_W, BTN_H),
			String(row[1]), "", UiKit.F_BODY)
		b.pressed.connect(_on_action.bind(String(row[2])))
		if i == 1:
			b.disabled = not _has_save
		_btns.append(b)


func _on_action(action: String) -> void:
	match action:
		"start":
			start_game.emit()
		"continue":
			if _has_save:
				continue_run.emit()
		"training":
			open_training.emit()
		"collection":
			open_collection.emit()
		"settings":
			open_settings.emit()
		"about":
			open_about.emit()
		"quit":
			quit_game.emit()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.physical_keycode:
			KEY_ENTER, KEY_SPACE:
				# Enter 只做“确认 / 下一步”，不是某个菜单项的独立快捷键
				_activate(_focus)
				get_viewport().set_input_as_handled()
			KEY_F:
				start_game.emit()
				get_viewport().set_input_as_handled()
			KEY_DOWN, KEY_S:
				_move_focus(1)
				get_viewport().set_input_as_handled()
			KEY_UP, KEY_W:
				_move_focus(-1)
				get_viewport().set_input_as_handled()
			KEY_V:
				if _has_save:
					continue_run.emit()
					get_viewport().set_input_as_handled()
			KEY_T:
				open_training.emit()
				get_viewport().set_input_as_handled()
			KEY_C:
				open_collection.emit()
				get_viewport().set_input_as_handled()
			KEY_O:
				open_settings.emit()
				get_viewport().set_input_as_handled()
			KEY_F1:
				open_about.emit()
				get_viewport().set_input_as_handled()
			KEY_Q:
				quit_game.emit()
				get_viewport().set_input_as_handled()


func _move_focus(dir: int) -> void:
	var n := _btns.size()
	for _i in n:
		_focus = (_focus + dir + n) % n
		if not (_btns[_focus] as BaButton).disabled:
			break
	Sfx.play("ui", -14.0)


func _activate(i: int) -> void:
	if i < 0 or i >= _btns.size():
		return
	var b: BaButton = _btns[i]
	if b.disabled:
		return
	b.pressed.emit()


func _draw() -> void:
	UiKit.gradient_backdrop(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), _t)
	draw_set_transform(Vector2(0, _enter), 0.0, Vector2.ONE)

	# 标题：36px + 1px 深描边 + 2px 硬阴影
	var tp := Vector2(MENU_X, 52)
	UiKit.text(self, tp + Vector2(2, 2), "AI GUNGEON", 36, Color(0, 0, 0, 0.45))
	UiKit.text(self, tp, "AI GUNGEON", 36, UiKit.CYAN, false)
	UiKit.text(self, Vector2(MENU_X + 1, 68), "像素地牢", 12, UiKit.TEXT_DIM)
	draw_rect(Rect2(MENU_X, 78, BTN_W, 1), UiKit.BORDER)
	draw_rect(Rect2(MENU_X, 78, 40, 1), UiKit.CYAN)

	var ver := "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.7.0-pixel"))
	UiKit.text_right(self, GameConfig.BASE_W - 16, 22, ver, 12, UiKit.TEXT_DIM)
	UiKit.text_right(self, GameConfig.BASE_W - 16, 38, "640×360 · PIXEL", 12, Color(0.45, 0.5, 0.6))

	# 菜单键位提示 + 焦点角标
	for i in _btns.size():
		var b: BaButton = _btns[i]
		var rr := Rect2(b.position, b.size)
		if i == _focus and not b.disabled:
			UiKit.corner_brackets(self, rr.grow(1), UiKit.GOLD, 5)
		var key: String = ["F", "V", "T", "C", "O", "F1", "Q"][i]
		var kw := UiKit.measure(key, 12) + 8
		var kr := Rect2(rr.end.x + 10, rr.position.y + 4, maxf(18.0, kw), 16)
		draw_rect(Rect2(kr.position + Vector2(0, 1), kr.size), UiKit.SHADOW)
		draw_rect(kr, Color(0.09, 0.11, 0.17, 0.8))
		draw_rect(kr, UiKit.BORDER, false, 1.0)
		UiKit.text_center(self, kr.get_center().x, kr.get_center().y + 4, key, 12,
			UiKit.GOLD if i == _focus else UiKit.TEXT_DIM)

	UiKit.text(self, Vector2(MENU_X, 293), "W/S 选择 · Enter 下一步 · F 开始", 12,
		Color(0.55, 0.62, 0.75))

	_draw_diorama(Rect2(376, 92, 240, 184))

	# 底部操作提示
	var hint_y := 318.0
	var keys := [["WASD", "移动"], ["左键", "射击"], ["空格", "翻滚"], ["E", "技能"], ["滚轮", "切武器"], ["ESC", "暂停"]]
	var x := 32.0
	for pair in keys:
		UiKit.keycap(self, Vector2(x, hint_y), String(pair[0]), 16)
		x += UiKit.measure(String(pair[0]), 12) + 12
		UiKit.text(self, Vector2(x, hint_y + 12), String(pair[1]), 12, UiKit.TEXT_DIM)
		x += UiKit.measure(String(pair[1]), 12) + 14

	# 同人声明只放在「关于」页，主菜单不再重复
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_diorama(r: Rect2) -> void:
	UiKit.frame(self, r, UiKit.DEEP, UiKit.BORDER, UiKit.BORDER_HI, true)
	# 电梯井：两侧导轨 + 顶部灯 + 地板格
	var inner := r.grow(-6)
	draw_rect(inner, Color("#0C1120"))
	var grid_y := inner.position.y + 8
	while grid_y < inner.end.y - 20:
		draw_line(Vector2(inner.position.x, grid_y), Vector2(inner.end.x, grid_y),
			Color("#141B2E"), 1.0)
		grid_y += 16.0
	var gx := inner.position.x
	while gx < inner.end.x:
		draw_line(Vector2(gx, inner.position.y), Vector2(gx, inner.end.y - 18),
			Color("#141B2E"), 1.0)
		gx += 16.0
	# 导轨
	draw_rect(Rect2(inner.position.x + 14, inner.position.y, 2, inner.size.y - 18), UiKit.BORDER)
	draw_rect(Rect2(inner.end.x - 16, inner.position.y, 2, inner.size.y - 18), UiKit.BORDER)
	# 顶灯 2 帧
	var flick := int(fmod(_t * 6.0, 2.0))
	draw_rect(Rect2(r.get_center().x - 22, inner.position.y, 44, 4),
		Color("#7FE3FF") if flick == 0 else Color("#4C8FA8"))
	# 地板
	var floor_y := inner.end.y - 18
	draw_rect(Rect2(inner.position.x, floor_y, inner.size.x, 18), Color("#1A2238"))
	draw_rect(Rect2(inner.position.x, floor_y, inner.size.x, 1), UiKit.BORDER_HI)

	# 三位角色 idle 2 帧（1x，不缩放）
	for i in IDS.size():
		var tex: Texture2D = _sprites[i]
		var px := inner.position.x + 18 + i * 68
		var py := floor_y - 58
		# 脚底硬阴影
		draw_rect(Rect2(px + 18, floor_y - 3, 28, 3), Color(0, 0, 0, 0.35))
		if tex == null:
			continue
		var fw := 64
		var frames: int = maxi(1, int(tex.get_width() / fw))
		var frame: int = int(_t * 4.0) % mini(frames, 2)
		draw_texture_rect_region(tex, Rect2(px, py, 64, 64), Rect2(frame * fw, 0, fw, 64))
		# 角色色小灯
		draw_rect(Rect2(px + 30, floor_y + 3, 4, 2), _accents[i])

	UiKit.text(self, Vector2(r.position.x + 8, r.end.y - 6), "ELEVATOR // READY", 12,
		Color(0.5, 0.56, 0.68))
