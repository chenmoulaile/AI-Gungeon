extends Control
## 算力商店（v0.7 P2 像素版）：三座石台货架 + 32×32 像素图标 + 像素价签
## 悬停只上浮 1px + 金色角括号；买不起灰化 + 红价；保留原购买/跳过逻辑。

signal closed

const CARD_W := 150.0
const CARD_H := 170.0
const CARD_Y := 80.0
const CARD_GAP := 14.0
const PANEL_PAD := 12.0

var offers: Array = []
var _rects: Array = []
var _hover: int = -1
var _hover_k: Array = []
var _msg: String = ""
var _msg_t: float = 0.0
var _enter: float = 16.0
var _t: float = 0.0
var _coins_shown: float = 0.0
var _show_tip: bool = false
var _skip_btn: BaButton = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	offers = UpgradeDB.roll_offers(3, GameState.upgrades)
	_maybe_add_exclusive()
	_show_tip = not MetaProgress.tutorial_flag("seen_shop_tip")
	_coins_shown = float(GameState.coins)
	_relayout()
	_skip_btn = BaButton.new()
	add_child(_skip_btn)
	_skip_btn.setup("跳过  [ESC]", Rect2(276, 284, 88, 24), "ghost", "", UiKit.F_BODY)
	_skip_btn.pressed.connect(_close)
	BaCursor.set_battle(false)
	var tw := create_tween()
	tw.tween_property(self, "_enter", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("ui")


## 达成局内任务后，商店出现专属武器
func _maybe_add_exclusive() -> void:
	var d = GameState.char_data
	if d == null or d.exclusive_path == "":
		return
	if not GameState.exclusive_ready() or GameState.exclusive_equipped:
		return
	var up := Upgrade.new()
	up.id = "excl_weapon"
	up.title = d.exclusive_name
	up.desc = d.exclusive_desc
	up.price = 30
	match GameState.char_id:
		"deepseek":
			up.icon_path = "res://assets/icons/weapons/excl_harness.png"
		"gpt":
			up.icon_path = "res://assets/icons/weapons/excl_codex.png"
		_:
			up.icon_path = "res://assets/icons/weapons/excl_hammer.png"
	offers.insert(0, up)


func _relayout() -> void:
	_rects.clear()
	_hover_k.clear()
	var n := offers.size()
	if n <= 0:
		return
	var gap_total: float = maxf(0.0, float(n - 1)) * CARD_GAP
	var avail := GameConfig.BASE_W - 32.0 - PANEL_PAD * 2.0
	var cw := minf(CARD_W, floorf((avail - gap_total) / float(n)))
	var total: float = n * cw + gap_total
	var x0: float = roundf((GameConfig.BASE_W - total) * 0.5)
	for i in n:
		_rects.append(Rect2(x0 + i * (cw + CARD_GAP), CARD_Y, cw, CARD_H))
		_hover_k.append(0.0)


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
			_tween_hover(i, 1.0 if i == _hover else 0.0)
	if _hover >= 0 and _affordable(_hover):
		BaCursor.force_hot()
	queue_redraw()


func _tween_hover(i: int, target: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _hover_k[i] = v, float(_hover_k[i]), target, 0.1)\
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
		elif event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
			_buy(event.physical_keycode - KEY_1)
			get_viewport().set_input_as_handled()


func _buy(index: int) -> void:
	if index < 0 or index >= offers.size():
		return
	if _msg_t > 0.0:
		return
	var up: Upgrade = offers[index]
	if GameState.coins < up.price:
		_msg = "金币不足 · 需要 %d" % up.price
		_msg_t = 1.6
		Sfx.play("hurt", -12.0, 1.5)
		return
	if up.id == "excl_weapon":
		_buy_exclusive(index)
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


func _buy_exclusive(index: int) -> void:
	var up: Upgrade = offers[index]
	var d = GameState.char_data
	GameState.coins -= up.price
	GameState.coins_changed.emit(GameState.coins)
	GameState.exclusive_equipped = true
	if GameState.player != null and is_instance_valid(GameState.player):
		GameState.player.equip_weapon(d.exclusive_path)
	_msg = "已装备专武 · %s" % d.exclusive_name
	_msg_t = 2.2
	Sfx.play("relic", -2.0, 1.1)
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
	draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.02, 0.03, 0.06, 0.78))
	draw_set_transform(Vector2(0, roundf(_enter)), 0.0, Vector2.ONE)
	var panel := Rect2(16, 8, GameConfig.BASE_W - 32, GameConfig.BASE_H - 16)
	UiKit.frame(self, panel, UiKit.DEEP, UiKit.BORDER, UiKit.BORDER_HI, true)
	UiKit.scanlines(self, panel.grow(-2), 0.05)
	UiKit.dither_rect(self, Rect2(16, 8, GameConfig.BASE_W - 32, 2), UiKit.PANEL, 2)

	UiKit.text(self, Vector2(32, 36), "算力商店", UiKit.F_H2, UiKit.TEXT)
	UiKit.text(self, Vector2(32, 52), "每层限时一次 · 藏品可叠加", UiKit.F_SMALL, UiKit.TEXT_DIM)
	_draw_coin(Vector2(548, 22), 12)
	UiKit.text_right(self, 612, 36, str(int(round(_coins_shown))), UiKit.F_H2, UiKit.GOLD)

	if _show_tip:
		var tip := Rect2(32, 58, GameConfig.BASE_W - 64, 16)
		UiKit.frame(self, tip, UiKit.PANEL, UiKit.BORDER, Color(0, 0, 0, 0), false)
		UiKit.text_center(self, tip.get_center().x, 70,
			"用金币购买藏品，增强本局能力", UiKit.F_SMALL, UiKit.GOLD)

	for i in offers.size():
		_draw_card(i, _rects[i], offers[i])

	if offers.is_empty():
		UiKit.text_center(self, GameConfig.BASE_W * 0.5, 156, "货架已空", UiKit.F_H2, UiKit.TEXT_DIM)
		UiKit.text_center(self, GameConfig.BASE_W * 0.5, 180, "下次刷新会补货", UiKit.F_SMALL, UiKit.TEXT_DIM)

	_draw_merchant(Vector2(26, 300))

	if _msg_t > 0.0:
		var w := UiKit.measure(_msg, 12) + 28.0
		var m := Rect2(roundf((GameConfig.BASE_W - w) * 0.5), 256, w, 18)
		UiKit.frame(self, m, UiKit.PANEL, UiKit.BORDER, UiKit.BORDER_HI, true)
		UiKit.text_center(self, m.get_center().x, 269, _msg, UiKit.F_BODY,
			Color(UiKit.DANGER.r, UiKit.DANGER.g, UiKit.DANGER.b, clampf(_msg_t, 0.0, 1.0)))

	UiKit.text_center(self, GameConfig.BASE_W * 0.5, 332,
		"点击石台购买 · 数字键 1-4 快捷购买 · ESC 跳过", UiKit.F_SMALL, UiKit.TEXT_DIM)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_card(i: int, r: Rect2, up: Upgrade) -> void:
	var hk: float = float(_hover_k[i])
	var can := GameState.coins >= up.price
	var lift := -1.0 if hk > 0.5 else 0.0
	var rr := Rect2(Vector2(r.position.x, r.position.y + lift).round(), r.size)
	var bg := UiKit.PANEL if can else Color("#161C2C")
	UiKit.frame(self, rr, bg, UiKit.BORDER, UiKit.BORDER_HI, true)
	if can:
		draw_line(rr.position + Vector2(1, 1),
			Vector2(rr.end.x - 2, rr.position.y + 1), UiKit.BORDER_HI)
	# 顶部铭牌色条：角色专属=角色色，普通=青
	var strip := UiKit.CYAN
	if up.char_tag == "gpt":
		strip = UiKit.PURPLE
	elif up.char_tag == "claude":
		strip = UiKit.ORANGE
	elif up.char_tag == "deepseek":
		strip = Color("#4453C4")
	draw_rect(Rect2(rr.position.x + 1, rr.position.y + 1, rr.size.x - 2, 3), strip)

	# 图标凹槽 36×36 + 32×32 图标
	var slot := Rect2(rr.position.x + (rr.size.x - 36) * 0.5, rr.position.y + 12, 36, 36)
	UiKit.inset(self, slot, UiKit.VOID, UiKit.BORDER)
	var tex := UiKit.icon(up.icon_path)
	if tex != null:
		var tint := Color(1, 1, 1, 1) if can else Color(0.42, 0.45, 0.54, 1)
		self.draw_texture_rect(tex, Rect2(slot.position + Vector2(2, 2), Vector2(32, 32)), false, tint)
	else:
		draw_rect(Rect2(slot.position + Vector2(10, 12), Vector2(16, 12)), UiKit.RAISED)
		draw_rect(Rect2(slot.position + Vector2(10, 12), Vector2(16, 1)), UiKit.BORDER_HI)

	UiKit.text_center(self, rr.get_center().x, rr.position.y + 64, UiKit.fit(up.title,
		rr.size.x - 12, UiKit.F_BODY), UiKit.F_BODY, UiKit.TEXT if can else UiKit.TEXT_DIM)
	UiKit.text_block(self, rr.position + Vector2(10, 78), up.desc, rr.size.x - 20,
		UiKit.F_SMALL, UiKit.TEXT_DIM if can else Color(0.42, 0.46, 0.55), 3)

	# 价签
	var tag := Rect2(roundf(rr.get_center().x - 28.0), rr.position.y + 132, 56, 16)
	UiKit.frame(self, tag, UiKit.VOID, UiKit.DANGER if not can else UiKit.GOLD,
		Color(0, 0, 0, 0), false)
	_draw_coin(Vector2(tag.position.x + 4, tag.position.y + 2), 12)
	UiKit.text(self, Vector2(tag.position.x + 20, tag.position.y + 12),
		str(up.price), UiKit.F_BODY, UiKit.GOLD if can else UiKit.DANGER, false)

	# 石台（硬边三层）
	var ped := Rect2(rr.position.x, rr.position.y + rr.size.y - 16, rr.size.x, 16)
	draw_rect(Rect2(ped.position + Vector2(0, 4), Vector2(ped.size.x, 12)), Color("#151A29"))
	draw_rect(Rect2(ped.position + Vector2(0, 2), Vector2(ped.size.x, 4)), Color("#2B3350"))
	draw_rect(Rect2(ped.position + Vector2(0, 2), Vector2(ped.size.x, 1)), UiKit.BORDER_HI)
	for k in 4:
		var bx := ped.position.x + 6 + k * 18
		draw_rect(Rect2(bx, ped.position.y + 8, 1, 6), Color("#10141F"))

	if hk > 0.5:
		UiKit.corner_brackets(self, rr.grow(1), UiKit.GOLD, 5)

	if _forms_combo(up.id):
		var star := rr.position + Vector2(rr.size.x - 10, 9)
		draw_rect(Rect2(star + Vector2(0, 2), Vector2(2, 2)), UiKit.GOLD)
		draw_rect(Rect2(star + Vector2(-2, 0), Vector2(6, 2)), UiKit.GOLD)
		draw_rect(Rect2(star + Vector2(0, -2), Vector2(2, 6)), UiKit.GOLD)


func _forms_combo(uid: String) -> bool:
	for c in UpgradeDB.COMBOS:
		if (c["a"] == uid and GameState.upgrades.has(c["b"])) or \
				(c["b"] == uid and GameState.upgrades.has(c["a"])):
			return true
	return false


func _draw_merchant(p: Vector2) -> void:
	var bob := int(_t * 2.5) % 2
	var o := Vector2(p.x, p.y + bob)
	draw_rect(Rect2(o.x + 3, o.y + 32, 20, 2), Color(0, 0, 0, 0.35))
	# 斗篷
	draw_rect(Rect2(o.x + 3, o.y + 8, 18, 24), Color("#241F38"))
	draw_rect(Rect2(o.x + 3, o.y + 8, 18, 1), UiKit.PURPLE)
	draw_rect(Rect2(o.x + 3, o.y + 30, 18, 2), UiKit.SHADOW)
	# 兜帽与脸
	draw_rect(Rect2(o.x + 6, o.y, 12, 10), Color("#3B3260"))
	draw_rect(Rect2(o.x + 8, o.y + 3, 8, 5), Color("#16121F"))
	draw_rect(Rect2(o.x + 7, o.y + 9, 10, 1), UiKit.PURPLE)
	if int(_t * 2.0) % 2 == 0:
		draw_rect(Rect2(o.x + 9, o.y + 5, 1, 1), UiKit.GOLD)
		draw_rect(Rect2(o.x + 13, o.y + 5, 1, 1), UiKit.GOLD)
	# 柜台与铜钱
	draw_rect(Rect2(o.x + 2, o.y + 20, 20, 10), Color("#2E2A44"))
	draw_rect(Rect2(o.x + 2, o.y + 20, 20, 1), UiKit.BORDER_HI)
	_draw_coin(Vector2(o.x + 15, o.y + 22), 6)


func _draw_coin(pos: Vector2, s: int) -> void:
	var p := pos.round()
	if s < 12:
		draw_rect(Rect2(p + Vector2(1, 0), Vector2(s - 2, 1)), Color("#E8B24A"))
		draw_rect(Rect2(p + Vector2(0, 1), Vector2(s, s - 2)), UiKit.GOLD)
		draw_rect(Rect2(p + Vector2(1, s - 1), Vector2(s - 2, 1)), Color("#B8862A"))
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(1, 1)), Color("#FFF3C4"))
		return
	draw_rect(Rect2(p + Vector2(3, 0), Vector2(6, 1)), Color("#E8B24A"))
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(10, 1)), Color("#E8B24A"))
	draw_rect(Rect2(p + Vector2(0, 2), Vector2(12, 8)), UiKit.GOLD)
	draw_rect(Rect2(p + Vector2(1, 10), Vector2(10, 1)), Color("#E8B24A"))
	draw_rect(Rect2(p + Vector2(3, 11), Vector2(6, 1)), Color("#B8862A"))
	# 内圈凹槽
	draw_rect(Rect2(p + Vector2(4, 4), Vector2(4, 1)), Color("#C79434"))
	draw_rect(Rect2(p + Vector2(4, 7), Vector2(4, 1)), Color("#C79434"))
	draw_rect(Rect2(p + Vector2(3, 5), Vector2(1, 3)), Color("#C79434"))
	draw_rect(Rect2(p + Vector2(8, 5), Vector2(1, 3)), Color("#C79434"))
	draw_rect(Rect2(p + Vector2(2, 2), Vector2(2, 1)), Color("#FFF3C4"))
