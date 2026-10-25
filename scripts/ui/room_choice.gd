extends Control
## 门后二选一（v0.10）：清场后站在门口，弹出两条路线；1/2 或点击选择
## 只负责选择，进入房间由 game.gd 处理。

signal chosen(node_id: int)

var _ids: Array = []
var _nodes: Array = []
var _rects: Array = []
var _sel: int = 0
var _hover: int = -1
var _done: bool = false
var _t: float = 0.0
var _enter: float = 12.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_mode = Node.PROCESS_MODE_ALWAYS
	BaCursor.set_battle(false)
	Sfx.play("ui")
	var tw := create_tween()
	tw.tween_property(self, "_enter", 0.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func setup(ids: Array, floor_index: int = 1) -> void:
	_ids = ids.duplicate()
	var map := GameState.ensure_map()
	for id in _ids:
		_nodes.append(map.node_at(int(id)))
	_layout(floor_index)


func _layout(floor_index: int) -> void:
	_rects.clear()
	var n := _nodes.size()
	if n == 0:
		return
	var w := 240.0
	var h := 168.0
	var gap := 24.0
	var total := n * w + (n - 1) * gap
	var x0 := (GameConfig.BASE_W - total) * 0.5
	for i in n:
		_rects.append(Rect2(x0 + i * (w + gap), 112, w, h))
	name = "RoomChoice"
	set_meta("floor", floor_index)


func _process(delta: float) -> void:
	_t += delta
	var mouse := get_local_mouse_position()
	var prev := _hover
	_hover = -1
	for i in _rects.size():
		if (_rects[i] as Rect2).has_point(mouse):
			_hover = i
	if _hover != prev and _hover >= 0:
		_sel = _hover
	if _hover >= 0:
		BaCursor.force_hot()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	if _hover >= 0:
		_pick(_hover)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_1, KEY_2:
			_pick(event.physical_keycode - KEY_1)
			get_viewport().set_input_as_handled()
		KEY_LEFT:
			_sel = maxi(0, _sel - 1)
			Sfx.play("ui", -14.0)
			get_viewport().set_input_as_handled()
		KEY_RIGHT:
			_sel = mini(_nodes.size() - 1, _sel + 1)
			Sfx.play("ui", -14.0)
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_SPACE:
			_pick(_sel)
			get_viewport().set_input_as_handled()


func _pick(i: int) -> void:
	if _done or i < 0 or i >= _nodes.size():
		return
	_done = true
	_sel = i
	Sfx.play("ui_confirm", -4.0)
	chosen.emit(int(_nodes[i]["id"]))


func _draw() -> void:
	draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.02, 0.03, 0.06, 0.78))
	draw_set_transform(Vector2(0, roundf(_enter)), 0.0, Vector2.ONE)
	var panel := Rect2(48, 52, GameConfig.BASE_W - 96, GameConfig.BASE_H - 104)
	UiKit.frame(self, panel, UiKit.DEEP, UiKit.BORDER, UiKit.BORDER_HI, true)
	UiKit.scanlines(self, panel.grow(-2), 0.05)
	UiKit.text(self, Vector2(64, 80), "选择下一间", UiKit.F_H2, UiKit.TEXT)
	UiKit.text(self, Vector2(64, 98), "两条路线只能选一条 · 清场奖励已结算", UiKit.F_SMALL, UiKit.TEXT_DIM)

	for i in _nodes.size():
		_draw_card(i, _rects[i])

	var t := "1 / 2 或点击选择 · 方向键 + 回车"
	UiKit.text_center(self, GameConfig.BASE_W * 0.5, 324, t, UiKit.F_SMALL, UiKit.TEXT_DIM)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_card(i: int, r: Rect2) -> void:
	if i >= _nodes.size():
		return
	var n: Dictionary = _nodes[i]
	var kind := String(n["kind"])
	var col := Color(FloorMap.kind_color(kind))
	var on := (i == _sel or i == _hover)
	var lift := -1.0 if on else 0.0
	var rr := Rect2(Vector2(r.position.x, r.position.y + lift).round(), r.size)
	UiKit.frame(self, rr, UiKit.RAISED if on else UiKit.PANEL,
		col if on else UiKit.BORDER, UiKit.BORDER_HI, true)
	draw_rect(Rect2(rr.position + Vector2(1, 1), Vector2(rr.size.x - 2, 3)), col)

	# 类型大字
	var badge := Rect2(rr.get_center().x - 22, rr.position.y + 16, 44, 44)
	UiKit.inset(self, badge, UiKit.VOID, col)
	UiKit.text_center(self, badge.get_center().x, badge.get_center().y + 9,
		FloorMap.kind_short(kind), UiKit.F_H2, col)

	UiKit.text_center(self, rr.get_center().x, rr.position.y + 92, String(n["name"]),
		UiKit.F_H2, col)
	UiKit.text_block(self, rr.position + Vector2(16, 110), String(n["desc"]),
		rr.size.x - 32, UiKit.F_SMALL, UiKit.TEXT_DIM, 2)

	# 提示条
	var tag := Rect2(rr.position.x + 16, rr.end.y - 30, rr.size.x - 32, 18)
	UiKit.inset(self, tag, UiKit.VOID, UiKit.BORDER)
	UiKit.text_center(self, tag.get_center().x, tag.get_center().y + 4,
		"按 %d 选它" % (i + 1), UiKit.F_SMALL, UiKit.GOLD if on else UiKit.TEXT_DIM)

	# 风险/收益小标签
	if kind == FloorMap.KIND_ELITE:
		UiKit.chip(self, Vector2(rr.end.x - 34, rr.position.y + 18), "风险 +", 12,
			UiKit.PURPLE, UiKit.VOID)
	elif kind == FloorMap.KIND_SHOP:
		UiKit.chip(self, Vector2(rr.end.x - 34, rr.position.y + 18), "消费", 12,
			UiKit.GOLD, UiKit.VOID)
	elif kind == FloorMap.KIND_EVENT:
		UiKit.chip(self, Vector2(rr.end.x - 34, rr.position.y + 18), "随机", 12,
			UiKit.GOLD, UiKit.VOID)

	if on:
		UiKit.corner_brackets(self, rr.grow(1), UiKit.GOLD, 6)
