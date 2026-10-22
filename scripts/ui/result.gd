extends Control
## 结算界面：击杀数 / 到达层数 / 藏品列表 / 立绘

signal restart

var _tex: Texture2D = null
var _btn := Rect2(GameConfig.BASE_W * 0.5 - 76, GameConfig.BASE_H - 52, 152, 28)
var _t: float = 0.0
var _icon_cache: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	mouse_filter = Control.MOUSE_FILTER_STOP
	var p := "res://assets/portraits/%s_full.png" % GameState.char_id
	if ResourceLoader.exists(p):
		_tex = load(p)
	Sfx.play("die", -4.0, 0.8)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _btn.has_point(get_local_mouse_position()):
			Sfx.play("ui")
			restart.emit()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ENTER, KEY_SPACE]:
			restart.emit()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.03, 0.04, 0.06, 0.94))

	# 立绘
	var pr := Rect2(30, 46, 210, 210)
	draw_rect(pr.grow(3), Color(0.1, 0.11, 0.16))
	if _tex != null:
		var side: float = minf(_tex.get_width(), _tex.get_height())
		var src := Rect2((_tex.get_width() - side) * 0.5, 0, side, side)
		draw_texture_rect_region(_tex, pr, src)
	else:
		draw_rect(pr, Color(0.12, 0.13, 0.18))

	if GameConfig.ui_font == null:
		return

	var x := 262.0
	draw_string(GameConfig.ui_font, Vector2(x, 56), "本局结束",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.55, 0.55))
	draw_string(GameConfig.ui_font, Vector2(x, 78),
		"%s · %s" % [GameState.char_data.display_name if GameState.char_data else GameState.char_id,
			GameState.char_data.title if GameState.char_data else ""],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GameConfig.char_color(GameState.char_id))

	var rows := [
		["击杀数", str(GameState.kills)],
		["到达层数", "B%d" % GameState.floor_index],
		["最远房间", "第 %d 间" % GameState.room_index],
		["持有藏品", "%d 件" % GameState.upgrades.size()],
		["激活组合", "%d 组" % GameState.combos.size()],
	]
	var y := 104.0
	for row in rows:
		draw_string(GameConfig.ui_font, Vector2(x, y), row[0], HORIZONTAL_ALIGNMENT_LEFT,
			-1, 10, GameConfig.COL_DIM)
		draw_string(GameConfig.ui_font, Vector2(x + 76, y), row[1], HORIZONTAL_ALIGNMENT_LEFT,
			-1, 11, GameConfig.COL_TEXT)
		y += 18.0

	# 藏品图标
	var ix := x
	var iy := 208.0
	for uid in GameState.upgrades:
		var up: Upgrade = UpgradeDB.get_upgrade(uid)
		if up == null:
			continue
		var tex := _icon(up.icon_path)
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(ix, iy), Vector2(20, 20)), false)
		ix += 24.0
		if ix > GameConfig.BASE_W - 40:
			ix = x
			iy += 26.0
	if GameState.upgrades.is_empty():
		draw_string(GameConfig.ui_font, Vector2(x, iy + 12), "（本局没有购买藏品）",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GameConfig.COL_DIM)

	# 组合效果 + 协同列表
	var cy := iy + 34.0
	for cname in GameState.combos:
		draw_string(GameConfig.ui_font, Vector2(x, cy), "· 组合 " + str(cname),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.85, 0.4))
		cy += 13.0
	for sname in GameState.synergies:
		draw_string(GameConfig.ui_font, Vector2(x, cy), "· 协同 " + str(sname),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.7, 0.85, 1.0))
		cy += 13.0

	# 按钮
	var hovered := _btn.has_point(get_local_mouse_position())
	draw_rect(_btn, Color(0.16, 0.2, 0.28) if not hovered else Color(0.24, 0.32, 0.44))
	draw_rect(_btn, Color(0.55, 0.65, 0.85), false, 1.0)
	draw_string(GameConfig.ui_font, Vector2(_btn.position.x, _btn.position.y + 19),
		"重新开始", HORIZONTAL_ALIGNMENT_CENTER, _btn.size.x, 11, GameConfig.COL_TEXT)
	draw_string(GameConfig.ui_font, Vector2(0, GameConfig.BASE_H - 12),
		"非官方同人作品 · 完全免费 · 不含任何付费或捐赠解锁内容",
		HORIZONTAL_ALIGNMENT_CENTER, GameConfig.BASE_W, 8, Color(0.5, 0.53, 0.6))


func _icon(path: String) -> Texture2D:
	if _icon_cache.has(path):
		return _icon_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	_icon_cache[path] = tex
	return tex
