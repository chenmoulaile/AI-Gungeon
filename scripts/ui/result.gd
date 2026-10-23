extends Control
## 结算：上（立绘上半身 + 层数 + 新纪录）/ 中（本局藏品）/ 下（数据 + 按钮）
## 背景用战场最后一帧 + 暗色遮罩，不切纯黑

signal restart
signal to_menu

var _tex: Texture2D = null
var _bg: Texture2D = null
var _line: String = ""
var _is_record: bool = false
var _btn_restart := Rect2(GameConfig.BASE_W * 0.5 - 150, GameConfig.BASE_H - 44, 138, 26)
var _btn_menu := Rect2(GameConfig.BASE_W * 0.5 + 12, GameConfig.BASE_H - 44, 138, 26)
var _t: float = 0.0
var _icon_cache: Dictionary = {}
var _pop: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	var p := "res://assets/portraits/%s_full.png" % GameState.char_id
	if ResourceLoader.exists(p):
		_tex = load(p)
	if ResourceLoader.exists("user://last_frame.png"):
		var img := Image.load_from_file(ProjectSettings.globalize_path("user://last_frame.png"))
		if img != null:
			_bg = ImageTexture.create_from_image(img)
	_is_record = GameState.floor_index >= MetaProgress.max_floor and GameState.floor_index > 0
	_line = DialogueManager.pick(GameState.char_id,
		"victory" if GameState.run_cleared else "death")
	Sfx.play("die" if not GameState.run_cleared else "skill", -4.0, 0.8)


func _process(delta: float) -> void:
	_t += delta
	_pop = minf(1.0, _pop + delta * 2.2)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_local_mouse_position()
		if _btn_restart.has_point(m):
			Sfx.play("ui")
			restart.emit()
		elif _btn_menu.has_point(m):
			Sfx.play("ui")
			to_menu.emit()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ENTER, KEY_SPACE]:
			restart.emit()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	# 背景：战场最后一帧
	if _bg != null:
		draw_texture_rect(_bg, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), false)
	draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.02, 0.03, 0.05, 0.86))

	# 顶部：立绘上半身
	var pr := Rect2(30, 26, 108, 108)
	draw_rect(pr.grow(2), Color(0.1, 0.12, 0.18))
	if _tex != null:
		draw_texture_rect_region(_tex, pr, Rect2(0, 0, 1024, 640))
	if GameConfig.ui_font == null:
		return

	var x := 152.0
	var d = GameState.char_data
	draw_string(GameConfig.ui_font, Vector2(x, 44), "本局结束",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
		Color(1.0, 0.62, 0.62) if not GameState.run_cleared else Color(1.0, 0.86, 0.45))
	draw_string(GameConfig.ui_font, Vector2(x, 62),
		"%s · %s" % [d.display_name if d != null else GameState.char_id,
			d.title if d != null else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		GameConfig.char_color(GameState.char_id))
	draw_string(GameConfig.ui_font, Vector2(x, 84), "到达 B%d · 第 %d 间" % [GameState.floor_index,
		GameState.room_index], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GameConfig.COL_TEXT)
	if _is_record:
		draw_string(GameConfig.ui_font, Vector2(x, 104), "新纪录！",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.35))
	else:
		draw_string(GameConfig.ui_font, Vector2(x, 104), "最高层数：B%d" % MetaProgress.max_floor,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GameConfig.COL_DIM)

	# 台词
	if _line != "":
		draw_multiline_string(GameConfig.ui_font, Vector2(x, 124), "「%s」" % _line,
			HORIZONTAL_ALIGNMENT_LEFT, GameConfig.BASE_W - x - 24, 9, 2,
			Color(1.0, 0.86, 0.55, 0.9))

	# 中部：本局藏品（依次弹出）
	var iy := 168.0
	var ix := 30.0
	var shown := 0
	for uid in GameState.upgrades:
		if shown >= 8:
			break
		var up: Upgrade = UpgradeDB.get_upgrade(uid)
		if up == null:
			continue
		var tex := _icon(up.icon_path)
		var k: float = clampf(_pop * 3.0 - float(shown) * 0.35, 0.0, 1.0)
		var size := 26.0 * (0.6 + 0.4 * k)
		var rect := Rect2(Vector2(ix + (26.0 - size) * 0.5, iy + (26.0 - size) * 0.5),
			Vector2(size, size))
		if tex != null:
			draw_texture_rect(tex, rect, false)
		ix += 32.0
		shown += 1
	var extra: int = GameState.upgrades.size() - shown
	if extra > 0:
		draw_string(GameConfig.ui_font, Vector2(ix + 4, iy + 18), "+%d" % extra,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GameConfig.COL_DIM)
	if GameState.upgrades.is_empty():
		draw_string(GameConfig.ui_font, Vector2(30, iy + 18), "（本局没有购买藏品）",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GameConfig.COL_DIM)

	# 底部：数据
	var mins := int(GameState.run_time / 60.0)
	var secs := int(fmod(GameState.run_time, 60.0))
	draw_string(GameConfig.ui_font, Vector2(30, GameConfig.BASE_H - 62),
		"击杀 %d    金币 %d    用时 %d:%02d" % [GameState.kills, GameState.coins_earned,
		mins, secs], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GameConfig.COL_TEXT)
	draw_string(GameConfig.ui_font, Vector2(30, GameConfig.BASE_H - 46),
		"组合 %d 组 · 协同 %d 组" % [GameState.combos.size(), GameState.synergies.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GameConfig.COL_DIM)

	_button(_btn_restart, "重新开始")
	_button(_btn_menu, "返回主菜单")
	draw_string(GameConfig.ui_font, Vector2(0, GameConfig.BASE_H - 8),
		"非官方同人 · 完全免费 · 角色形象基于 B站 UP 主 ZipZipPipe 的二创（CC BY-NC-SA 4.0）",
		HORIZONTAL_ALIGNMENT_CENTER, GameConfig.BASE_W, 7, Color(0.45, 0.5, 0.6))


func _button(r: Rect2, label: String) -> void:
	var hovered := r.has_point(get_local_mouse_position())
	draw_rect(r, Color(0.16, 0.2, 0.28) if not hovered else Color(0.24, 0.32, 0.44))
	draw_rect(r, Color(0.55, 0.65, 0.85), false, 1.0)
	draw_string(GameConfig.ui_font, Vector2(r.position.x, r.position.y + 18), label,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, GameConfig.COL_TEXT)


func _icon(path: String) -> Texture2D:
	if _icon_cache.has(path):
		return _icon_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	_icon_cache[path] = tex
	return tex
