extends Control
## 事件房（v0.10）：无敌人，进门弹出三选一；1/2/3 或点击，ESC 跳过
## 三个选项：回复生命 / 随机白档藏品 / 金币。结果直接结算后关闭。

signal closed

const HEAL_AMOUNT := 25
const COIN_AMOUNT := 35

var _cards: Array = []
var _rects: Array = []
var _relic: Upgrade = null
var _hover: int = -1
var _pick_index: int = -1
var _done: bool = false
var _t: float = 0.0
var _enter: float = 12.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "EventRoom"
	_relic = UpgradeDB.pick_by_rarity(GameState.upgrades, 0)
	_build_cards()
	_layout()
	BaCursor.set_battle(false)
	Sfx.play("ui")
	var tw := create_tween()
	tw.tween_property(self, "_enter", 0.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_cards() -> void:
	var heal_desc := "回复 %d 点生命" % HEAL_AMOUNT
	if GameState.hp >= GameState.max_hp:
		heal_desc = "生命已满 · 仍可留作纪念"
	var relic_title := "空书架"
	var relic_desc := "白档藏品已集齐"
	var relic_ok := false
	var relic_rarity := 0
	if _relic != null:
		relic_title = _relic.title
		relic_rarity = UpgradeDB.rarity_of(_relic)
		relic_desc = "随机%s档藏品 1 件" % String(UpgradeDB.RARITY_NAMES[relic_rarity])
		relic_ok = true
	else:
		relic_rarity = 0
	_cards = [
		{"kind": "heal", "title": "热汤", "desc": heal_desc, "enabled": true,
			"color": "#6EE7A8"},
		{"kind": "relic", "title": relic_title,
			"desc": relic_desc, "enabled": relic_ok,
			"color": UpgradeDB.RARITY_COLORS[relic_rarity],
			"icon": _relic.icon_path if _relic != null else ""},
		{"kind": "coin", "title": "零钱罐", "desc": "获得 %d 金币" % COIN_AMOUNT,
			"enabled": true, "color": "#FFD166"},
	]


func _layout() -> void:
	_rects.clear()
	var n := _cards.size()
	var w := 152.0
	var h := 160.0
	var gap := 20.0
	var total := n * w + (n - 1) * gap
	var x0 := (GameConfig.BASE_W - total) * 0.5
	for i in n:
		_rects.append(Rect2(x0 + i * (w + gap), 130, w, h))


func _process(delta: float) -> void:
	_t += delta
	var mouse := get_local_mouse_position()
	_hover = -1
	for i in _rects.size():
		if (_rects[i] as Rect2).has_point(mouse):
			_hover = i
	if _hover >= 0 and bool((_cards[_hover] as Dictionary)["enabled"]):
		BaCursor.force_hot()
	queue_redraw()


## 暂停状态下的全局鼠标兜底：直接按坐标命中，不依赖 GUI 命中测试
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	var m: Vector2 = event.position
	for i in _rects.size():
		if (_rects[i] as Rect2).has_point(m):
			_pick(i)
			get_viewport().set_input_as_handled()
			return


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_1, KEY_2, KEY_3:
			_pick(event.physical_keycode - KEY_1)
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_skip()
			get_viewport().set_input_as_handled()


func _pick(i: int) -> void:
	if _done or i < 0 or i >= _cards.size():
		return
	var c: Dictionary = _cards[i]
	if not bool(c["enabled"]):
		Sfx.play("hurt", -14.0, 1.5)
		return
	_done = true
	_pick_index = i
	match String(c["kind"]):
		"heal":
			GameState.heal(HEAL_AMOUNT)
			Sfx.play("relic", -6.0, 1.1)
		"relic":
			GameState.add_upgrade(_relic.id)
			Sfx.play("relic", -2.0, 1.1)
		"coin":
			GameState.add_coins(COIN_AMOUNT)
			Sfx.play("coin")
	_finish()


func _skip() -> void:
	if _done:
		return
	_done = true
	Sfx.play("ui")
	_finish()


func _finish() -> void:
	set_process(false)
	await get_tree().create_timer(0.22).timeout
	closed.emit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.02, 0.03, 0.06, 0.78))
	draw_set_transform(Vector2(0, roundf(_enter)), 0.0, Vector2.ONE)
	var panel := Rect2(48, 52, GameConfig.BASE_W - 96, GameConfig.BASE_H - 104)
	UiKit.frame(self, panel, UiKit.DEEP, UiKit.BORDER, UiKit.BORDER_HI, true)
	UiKit.scanlines(self, panel.grow(-2), 0.05)

	# 事件房牌匾
	var board := Rect2(64, 60, 120, 18)
	UiKit.frame(self, board, Color("#2A2418"), UiKit.GOLD, Color(0, 0, 0, 0), false)
	UiKit.text_center(self, board.get_center().x, board.get_center().y + 4, "事件房", 12, UiKit.GOLD)
	UiKit.text(self, Vector2(64, 104), "三选一 · 只能带走一样", UiKit.F_H2, UiKit.TEXT)
	UiKit.text(self, Vector2(64, 122), "没有敌人，也没有第二次机会", UiKit.F_SMALL, UiKit.TEXT_DIM)

	for i in _cards.size():
		_draw_card(i, _rects[i], _cards[i])

	UiKit.text_center(self, GameConfig.BASE_W * 0.5, 324,
		"1 / 2 / 3 或点击选择 · ESC 跳过", UiKit.F_SMALL, UiKit.TEXT_DIM)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_card(i: int, r: Rect2, c: Dictionary) -> void:
	var col := Color(String(c["color"]))
	var enabled := bool(c["enabled"])
	var on := enabled and (i == _hover or i == _pick_index)
	var rr := Rect2((r.position + Vector2(0, -1 if on else 0)).round(), r.size.round())
	UiKit.frame(self, rr, UiKit.RAISED if on else UiKit.PANEL,
		col if on else UiKit.BORDER, UiKit.BORDER_HI, true)
	draw_rect(Rect2(rr.position + Vector2(1, 1), Vector2(rr.size.x - 2, 3)),
		col if enabled else UiKit.BORDER)

	# 图标槽 36×36
	var slot := Rect2(rr.get_center().x - 18, rr.position.y + 14, 36, 36)
	UiKit.inset(self, slot, UiKit.VOID, UiKit.BORDER)
	if bool(c.has("icon")) and String(c["icon"]) != "" and UiKit.draw_icon(self, String(c["icon"]),
			Rect2(slot.position + Vector2(2, 2), Vector2(32, 32))):
		pass
	elif String(c["kind"]) == "heal":
		_draw_heart(slot.position + Vector2(12, 11), Color("#FF7A8A") if enabled else UiKit.BORDER)
	elif String(c["kind"]) == "coin":
		_draw_coin(slot.position + Vector2(12, 12))
	else:
		draw_rect(Rect2(slot.position + Vector2(10, 12), Vector2(16, 12)), UiKit.RAISED)
		draw_rect(Rect2(slot.position + Vector2(10, 12), Vector2(16, 1)), UiKit.BORDER_HI)

	UiKit.text_center(self, rr.get_center().x, rr.position.y + 66, UiKit.fit(String(c["title"]),
		rr.size.x - 16, UiKit.F_BODY), UiKit.F_BODY, col if enabled else UiKit.TEXT_DIM)
	UiKit.text_block(self, rr.position + Vector2(12, 80), String(c["desc"]), rr.size.x - 24,
		UiKit.F_SMALL, UiKit.TEXT_DIM if enabled else Color(0.42, 0.46, 0.55), 3)

	var tag := Rect2(rr.position.x + 12, rr.end.y - 28, rr.size.x - 24, 18)
	UiKit.inset(self, tag, UiKit.VOID, UiKit.BORDER)
	UiKit.text_center(self, tag.get_center().x, tag.get_center().y + 4,
		("按 %d" % (i + 1)) if enabled else "不可用", 12,
		UiKit.GOLD if on else UiKit.TEXT_DIM)

	if on:
		UiKit.corner_brackets(self, rr.grow(1), UiKit.GOLD, 5)


func _draw_heart(p: Vector2, col: Color) -> void:
	var o := p.round()
	draw_rect(Rect2(o + Vector2(1, 2), Vector2(2, 2)), col)
	draw_rect(Rect2(o + Vector2(5, 2), Vector2(2, 2)), col)
	draw_rect(Rect2(o + Vector2(0, 4), Vector2(8, 2)), col)
	draw_rect(Rect2(o + Vector2(1, 6), Vector2(6, 2)), col)
	draw_rect(Rect2(o + Vector2(2, 8), Vector2(4, 1)), col)
	draw_rect(Rect2(o + Vector2(3, 9), Vector2(2, 1)), col)
	draw_rect(Rect2(o + Vector2(2, 3), Vector2(1, 1)), Color(1, 1, 1, 0.7))


func _draw_coin(p: Vector2) -> void:
	var o := p.round()
	draw_rect(Rect2(o + Vector2(2, 0), Vector2(4, 1)), Color("#E8B24A"))
	draw_rect(Rect2(o + Vector2(0, 2), Vector2(8, 5)), UiKit.GOLD)
	draw_rect(Rect2(o + Vector2(2, 7), Vector2(4, 1)), Color("#B8862A"))
	draw_rect(Rect2(o + Vector2(3, 2), Vector2(1, 3)), Color("#FFF3C4"))
	draw_rect(Rect2(o + Vector2(4, 4), Vector2(1, 1)), Color("#C79434"))
