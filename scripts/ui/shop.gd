extends Control
## 商店（蔚蓝档案风格）：三张商品卡片，悬停上浮 6px + 描边高亮 + 图标微旋转
## 买不起：整体降饱和 + 价格变红 + 不响应上浮

signal closed

const CARD_W := 150.0
const CARD_H := 170.0
const CARD_Y := 76.0
const CARD_GAP := 14.0

var offers: Array = []
var _rects: Array = []
var _hover: int = -1
var _hover_k: Array = []
var _icon_rot: Array = []
var _msg: String = ""
var _msg_t: float = 0.0
var _enter: float = 20.0
var _t: float = 0.0
var _coins_shown: float = 0.0
var _show_tip: bool = false
var _skip_btn: BaButton = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	mouse_filter = Control.MOUSE_FILTER_STOP
	offers = UpgradeDB.roll_offers(3, GameState.upgrades)
	_show_tip = not MetaProgress.tutorial_flag("seen_shop_tip")
	_coins_shown = float(GameState.coins)
	_relayout()
	_skip_btn = BaButton.new()
	add_child(_skip_btn)
	_skip_btn.setup("跳过", Rect2(GameConfig.BASE_W * 0.5 - 44, 286, 88, 24),
		"ghost", "", UiKit.F_BODY)
	_skip_btn.pressed.connect(_close)
	BaCursor.set_battle(false)
	var tw := create_tween()
	tw.tween_property(self, "_enter", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("ui")


func _relayout() -> void:
	_rects.clear()
	_hover_k.clear()
	_icon_rot.clear()
	var total: float = offers.size() * CARD_W + maxf(0.0, offers.size() - 1) * CARD_GAP
	var x0: float = (GameConfig.BASE_W - total) * 0.5
	for i in offers.size():
		_rects.append(Rect2(x0 + i * (CARD_W + CARD_GAP), CARD_Y, CARD_W, CARD_H))
		_hover_k.append(0.0)
		_icon_rot.append(0.0)


func _process(delta: float) -> void:
	_t += delta
	_msg_t = maxf(0.0, _msg_t - delta)
	if absf(_coins_shown - float(GameState.coins)) > 0.01:
		_coins_shown = move_toward(_coins_shown, float(GameState.coins),
			maxf(1.0, absf(float(GameState.coins) - _coins_shown) * 8.0) * delta)
	var mouse := get_local_mouse_position()
	var prev := _hover
	_hover = -1
	for i in _rects.size():
		if (_rects[i] as Rect2).has_point(mouse):
			_hover = i
	if _hover != prev:
		for i in _rects.size():
			var can := _affordable(i)
			_tween_hover(i, 1.0 if (i == _hover and can) else 0.0)
			_tween_icon(i, 3.0 if (i == _hover and can) else 0.0)
	if _hover >= 0 and _affordable(_hover):
		BaCursor.force_hot()
	queue_redraw()


func _tween_hover(i: int, target: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _hover_k[i] = v, float(_hover_k[i]), target, 0.12)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _tween_icon(i: int, deg: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _icon_rot[i] = v, float(_icon_rot[i]), deg, 0.12)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _affordable(i: int) -> bool:
	if i < 0 or i >= offers.size():
		return false
	return GameState.coins >= (offers[i] as Upgrade).price


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	if _hover >= 0:
		_buy(_hover)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE]:
			_close()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode in [KEY_1, KEY_2, KEY_3]:
			_buy(event.physical_keycode - KEY_1)
			get_viewport().set_input_as_handled()


func _buy(index: int) -> void:
	if index < 0 or index >= offers.size():
		return
	var up: Upgrade = offers[index]
	if GameState.coins < up.price:
		_msg = "金币不足（需要 %d）" % up.price
		_msg_t = 1.6
		Sfx.play("hurt", -12.0, 1.5)
		return
	if GameState.try_buy(up):
		_msg = "已获得 · %s" % up.title
		_msg_t = 1.8
		Sfx.play("coin")
		MetaProgress.set_tutorial_flag("seen_shop_tip")
		_show_tip = false
		offers.remove_at(index)
		_relayout()
		_hover = -1


func _close() -> void:
	MetaProgress.set_tutorial_flag("seen_shop_tip")
	Sfx.play("ui")
	closed.emit()
	queue_free()


# ---------------- 绘制 ----------------
func _draw() -> void:
	# 半透明浅色底板（横向滑动转场配合）
	draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.06, 0.09, 0.16, 0.55))
	draw_set_transform(Vector2(0, _enter), 0.0, Vector2.ONE)
	var panel := Rect2(16, 8, GameConfig.BASE_W - 32, GameConfig.BASE_H - 16)
	draw_style_box(UiKit.box(Color(0.96, 0.97, 1.0, 0.97), 12, Color(1, 1, 1, 0.7), 1, true), panel)
	UiKit.text(self, Vector2(30, 34), "算力商店", UiKit.F_H2, UiKit.TEXT)
	UiKit.text(self, Vector2(30, 46), "每层限时一次 · 藏品可叠加", UiKit.F_TINY, UiKit.TEXT_DIM)
	# 金币
	draw_circle(Vector2(548, 30), 7.0, UiKit.GOLD)
	draw_circle(Vector2(546, 28), 2.4, Color(1, 1, 1, 0.9))
	UiKit.text(self, Vector2(560, 34), str(int(round(_coins_shown))), UiKit.F_H2,
		Color(0.24, 0.26, 0.32))

	if _show_tip:
		var tip := Rect2(30, 54, GameConfig.BASE_W - 60, 16)
		draw_style_box(UiKit.box(Color(1.0, 0.97, 0.86, 0.95), 7, Color(1, 1, 1, 0.8), 1, false), tip)
		UiKit.text_center(self, tip.get_center().x, tip.get_center().y + 2.0,
			"用金币购买藏品，增强本局能力", UiKit.F_TINY, Color(0.58, 0.44, 0.12))

	for i in offers.size():
		_draw_card(i, _rects[i], offers[i])

	if _msg_t > 0.0:
		UiKit.text_center(self, GameConfig.BASE_W * 0.5, 272, _msg,
			UiKit.F_SMALL, Color(UiKit.DANGER.r, UiKit.DANGER.g, UiKit.DANGER.b,
			clampf(_msg_t, 0.0, 1.0)))
	UiKit.text_center(self, GameConfig.BASE_W * 0.5, 324,
		"点击卡片购买 · ESC 跳过", UiKit.F_TINY, UiKit.TEXT_DIM)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_card(i: int, r: Rect2, up: Upgrade) -> void:
	var hk: float = float(_hover_k[i])
	var can := GameState.coins >= up.price
	var lift: float = -6.0 * hk
	var rr := Rect2(r.position + Vector2(0, lift), r.size)
	var bg := Color(1, 1, 1, 0.98) if can else Color(0.93, 0.94, 0.96, 0.96)
	draw_style_box(UiKit.box(bg, 10, Color(1, 1, 1, 0.9), 1, true), rr)
	if hk > 0.01:
		draw_style_box(UiKit.box(Color(0, 0, 0, 0), 10,
			Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.85 * hk), 2, false), rr)

	# 图标（悬停轻微旋转 ±3°）
	var ic := rr.position + Vector2(rr.size.x * 0.5, 44) + Vector2(0, _enter)
	draw_circle(ic, 24.0, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.10))
	draw_set_transform(ic, deg_to_rad(float(_icon_rot[i])), Vector2.ONE)
	var tex := UiKit.icon(up.icon_path)
	if tex != null:
		var tint := Color(1, 1, 1, 1) if can else Color(0.62, 0.64, 0.70, 1)
		draw_texture_rect(tex, Rect2(-18, -18, 36, 36), false, tint)
	draw_set_transform(Vector2(0, _enter), 0.0, Vector2.ONE)

	UiKit.text_center(self, rr.get_center().x, rr.position.y + 86, up.title, UiKit.F_H3,
		UiKit.TEXT if can else UiKit.TEXT_DIM)
	UiKit.text_block(self, rr.position + Vector2(10, 98), up.desc, rr.size.x - 20,
		UiKit.F_TINY, UiKit.TEXT_DIM if can else Color(0.62, 0.64, 0.70), 3)
	UiKit.text_center(self, rr.get_center().x, rr.end.y - 12, "%d 金币" % up.price, UiKit.F_SMALL,
		UiKit.ACCENT if can else UiKit.DANGER)
	if _forms_combo(up.id):
		UiKit.text_center(self, rr.get_center().x, rr.end.y - 2, "★ 与已有藏品共鸣",
			UiKit.F_TINY, Color(0.85, 0.62, 0.12))


func _forms_combo(uid: String) -> bool:
	for c in UpgradeDB.COMBOS:
		if (c["a"] == uid and GameState.upgrades.has(c["b"])) or \
				(c["b"] == uid and GameState.upgrades.has(c["a"])):
			return true
	return false
