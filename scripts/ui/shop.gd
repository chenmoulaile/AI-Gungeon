extends Control
## 商店：每层第 4 间房清空后出现，金币购买藏品

signal closed

const CARD_W := 168.0
const CARD_H := 186.0

var offers: Array = []
var _rects: Array = []
var _hover: int = -1
var _msg: String = ""
var _msg_t: float = 0.0
var _cont_rect := Rect2(GameConfig.BASE_W * 0.5 - 70, GameConfig.BASE_H - 44, 140, 26)
var _icon_cache: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	mouse_filter = Control.MOUSE_FILTER_STOP
	offers = UpgradeDB.roll_offers(3, GameState.upgrades)
	var total: float = offers.size() * CARD_W + maxf(0.0, offers.size() - 1) * 16.0
	var x0: float = (GameConfig.BASE_W - total) * 0.5
	for i in offers.size():
		_rects.append(Rect2(x0 + i * (CARD_W + 16.0), 78, CARD_W, CARD_H))
	Sfx.play("ui")


func _process(delta: float) -> void:
	_msg_t = maxf(0.0, _msg_t - delta)
	var mouse := get_local_mouse_position()
	_hover = -1
	for i in _rects.size():
		if _rects[i].has_point(mouse):
			_hover = i
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _cont_rect.has_point(get_local_mouse_position()):
		Sfx.play("ui")
		closed.emit()
		queue_free()
		accept_event()
		return
	if _hover >= 0 and _hover < offers.size():
		_buy(_hover)
		accept_event()


func _buy(index: int) -> void:
	var up: Upgrade = offers[index]
	if GameState.coins < up.price:
		_msg = "金币不足（需要 %d）" % up.price
		_msg_t = 1.6
		Sfx.play("hurt", -12.0, 1.5)
		return
	if GameState.try_buy(up):
		_msg = "已获得：%s" % up.title
		_msg_t = 1.8
		Sfx.play("coin")
		offers.remove_at(index)
		_rects.clear()
		var total: float = offers.size() * CARD_W + maxf(0.0, offers.size() - 1) * 16.0
		var x0: float = (GameConfig.BASE_W - total) * 0.5
		for i in offers.size():
			_rects.append(Rect2(x0 + i * (CARD_W + 16.0), 78, CARD_W, CARD_H))
		_hover = -1


func _draw() -> void:
	draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.02, 0.03, 0.05, 0.86))
	if GameConfig.ui_font == null:
		return
	draw_string(GameConfig.ui_font, Vector2(0, 40), "算力商店",
		HORIZONTAL_ALIGNMENT_CENTER, GameConfig.BASE_W, 18, Color(1.0, 0.86, 0.45))
	draw_string(GameConfig.ui_font, Vector2(0, 58), "金币 %d" % GameState.coins,
		HORIZONTAL_ALIGNMENT_CENTER, GameConfig.BASE_W, 11, GameConfig.COL_GOLD)
	draw_string(GameConfig.ui_font, Vector2(0, GameConfig.BASE_H - 54),
		"藏品可叠加，两件特定藏品同时持有会激活组合效果", HORIZONTAL_ALIGNMENT_CENTER,
		GameConfig.BASE_W, 9, GameConfig.COL_DIM)

	for i in offers.size():
		_draw_card(i, _rects[i], offers[i])

	# 继续按钮
	var hovered := _cont_rect.has_point(get_local_mouse_position())
	draw_rect(_cont_rect, Color(0.14, 0.18, 0.26) if not hovered else Color(0.2, 0.28, 0.4))
	draw_rect(_cont_rect, Color(0.5, 0.6, 0.8), false, 1.0)
	draw_string(GameConfig.ui_font, Vector2(_cont_rect.position.x, _cont_rect.position.y + 18),
		"继续前进", HORIZONTAL_ALIGNMENT_CENTER, _cont_rect.size.x, 11, GameConfig.COL_TEXT)

	if _msg_t > 0.0:
		draw_string(GameConfig.ui_font, Vector2(0, GameConfig.BASE_H - 70), _msg,
			HORIZONTAL_ALIGNMENT_CENTER, GameConfig.BASE_W, 10,
			Color(1, 1, 1, clampf(_msg_t, 0.0, 1.0)))


func _draw_card(i: int, r: Rect2, up: Upgrade) -> void:
	var hovered := (_hover == i)
	var affordable := GameState.coins >= up.price
	var border := Color(0.95, 0.78, 0.35) if hovered else Color(0.3, 0.34, 0.44)
	draw_rect(r, Color(0.09, 0.1, 0.14, 0.98))
	if hovered:
		draw_rect(r.grow(3), Color(1.0, 0.85, 0.4, 0.14))
	draw_rect(r, border, false, 2.0 if hovered else 1.0)

	var icon_rect := Rect2(r.position + Vector2(r.size.x * 0.5 - 24, 12), Vector2(48, 48))
	var tex := _icon(up.icon_path)
	if tex != null:
		draw_texture_rect(tex, icon_rect, false)

	draw_string(GameConfig.ui_font, Vector2(r.position.x, r.position.y + 82), up.title,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, GameConfig.COL_TEXT)
	draw_multiline_string(GameConfig.ui_font, Vector2(r.position.x + 10, r.position.y + 100),
		up.desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 9, -1, GameConfig.COL_DIM)
	draw_string(GameConfig.ui_font, Vector2(r.position.x, r.end.y - 12),
		"%d 金币" % up.price, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10,
		GameConfig.COL_GOLD if affordable else Color(0.6, 0.35, 0.35))
	draw_string(GameConfig.ui_font, Vector2(r.position.x, r.position.y - 4),
		"[%d]" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, GameConfig.COL_DIM)
	# 与已持有藏品能凑组合时给出暗示
	if _forms_combo(up.id):
		draw_string(GameConfig.ui_font, Vector2(r.position.x, r.end.y + 11),
			"★ 与已有藏品共鸣", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8,
			Color(1.0, 0.82, 0.35))


func _forms_combo(uid: String) -> bool:
	for c in UpgradeDB.COMBOS:
		if (c["a"] == uid and GameState.upgrades.has(c["b"])) or \
				(c["b"] == uid and GameState.upgrades.has(c["a"])):
			return true
	return false


func _icon(path: String) -> Texture2D:
	if _icon_cache.has(path):
		return _icon_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	_icon_cache[path] = tex
	return tex
