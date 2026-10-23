extends Control
## 藏品图鉴（蔚蓝档案风格）：5 列网格，未见过显示剪影，已见过悬停放大 1.05 + 右侧详情

signal closed

const COLS := 5
const CELL_W := 76.0
const CELL_H := 58.0
const GAP := 8.0
const GRID_X := 28.0
const GRID_Y := 62.0

var _ids: Array = []
var _rects: Array = []
var _selected: String = ""
var _hover: int = -1
var _hover_k: Array = []
var _t: float = 0.0
var _enter: float = 20.0
var _back_btn: BaButton = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	_ids = UpgradeDB.all_ids()
	_ids.sort()
	_layout()
	_back_btn = BaButton.new()
	add_child(_back_btn)
	_back_btn.setup("返回  [C]", Rect2(GameConfig.BASE_W - 108, GameConfig.BASE_H - 34, 88, 24),
		"secondary", "", UiKit.F_SMALL)
	_back_btn.pressed.connect(_close)
	BaCursor.set_battle(false)
	var tw := create_tween()
	tw.tween_property(self, "_enter", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("ui")


func _layout() -> void:
	_rects.clear()
	_hover_k.clear()
	for i in _ids.size():
		var col := i % COLS
		var row := int(i / COLS)
		_rects.append(Rect2(GRID_X + col * (CELL_W + GAP), GRID_Y + row * (CELL_H + GAP),
			CELL_W, CELL_H))
		_hover_k.append(0.0)


func _process(delta: float) -> void:
	_t += delta
	var mouse := get_local_mouse_position()
	var prev := _hover
	_hover = -1
	for i in _rects.size():
		if (_rects[i] as Rect2).has_point(mouse) and MetaProgress.seen_relics.has(_ids[i]):
			_hover = i
	if _hover != prev:
		for i in _rects.size():
			var on := i == _hover
			var tw := create_tween()
			tw.tween_method(func(v: float) -> void: _hover_k[i] = v, float(_hover_k[i]),
				1.0 if on else 0.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _hover >= 0:
		BaCursor.force_hot()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hover >= 0:
			_selected = String(_ids[_hover])
			Sfx.play("ui")
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ESCAPE, KEY_C, KEY_ENTER]:
			_close()
			get_viewport().set_input_as_handled()


func _close() -> void:
	Sfx.play("ui")
	closed.emit()
	queue_free()


func _draw() -> void:
	UiKit.gradient_backdrop(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H))
	UiKit.stripes(self, Rect2(0, 0, GameConfig.BASE_W, 60), _t)
	draw_set_transform(Vector2(0, _enter), 0.0, Vector2.ONE)

	UiKit.text(self, Vector2(28, 32), "藏品图鉴", UiKit.F_H2, UiKit.TEXT)
	UiKit.text(self, Vector2(28, 46), "最高层数 %d · 总击杀 %d · 通关 DS %d / GPT %d / CL %d"
		% [MetaProgress.max_floor, MetaProgress.total_kills,
		int(MetaProgress.clears["deepseek"]), int(MetaProgress.clears["gpt"]),
		int(MetaProgress.clears["claude"])], UiKit.F_TINY, UiKit.TEXT_DIM)
	var seen_n := MetaProgress.seen_relics.size()
	UiKit.text_right(self, 612, 46, "已收集 %d / %d" % [seen_n, _ids.size()], UiKit.F_SMALL,
		UiKit.ACCENT)

	for i in _ids.size():
		_draw_cell(i, _rects[i])
	_draw_detail()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cell(i: int, r: Rect2) -> void:
	var uid: String = _ids[i]
	var seen: bool = MetaProgress.seen_relics.has(uid)
	var hk: float = float(_hover_k[i])
	var rr := r
	if hk > 0.01:
		var k := 1.0 + 0.05 * hk
		rr = Rect2(r.get_center() - r.size * k * 0.5, r.size * k)
	var bg := Color(1, 1, 1, 0.96) if seen else Color(0.90, 0.92, 0.96, 0.9)
	draw_style_box(UiKit.box(bg, 9, Color(1, 1, 1, 0.8), 1, true), rr)
	var up: Upgrade = UpgradeDB.get_upgrade(uid)
	if seen and up != null:
		var tex := UiKit.icon(up.icon_path)
		if tex != null:
			var sz := 30.0 * (1.0 + 0.06 * hk)
			draw_texture_rect(tex, Rect2(rr.get_center() - Vector2(sz, sz) * 0.5, Vector2(sz, sz)),
				false)
		UiKit.text_center(self, rr.get_center().x, rr.end.y - 5, UiKit.fit(up.title, rr.size.x - 6,
			UiKit.F_TINY), UiKit.F_TINY, UiKit.TEXT_DIM)
	else:
		# 剪影：一个深色问号
		draw_circle(rr.get_center() - Vector2(0, 4), 11.0, Color(0.72, 0.75, 0.82, 0.55))
		UiKit.text_center(self, rr.get_center().x, rr.get_center().y + 2, "?", UiKit.F_H3,
			Color(1, 1, 1, 0.9))
	if _selected == uid:
		draw_style_box(UiKit.box(Color(0, 0, 0, 0), 9, UiKit.ACCENT, 2, false), rr)


func _draw_detail() -> void:
	var box := Rect2(452, GRID_Y, 160, 4 * CELL_H + 3 * GAP)
	draw_style_box(UiKit.box(Color(1, 1, 1, 0.94), 10, Color(1, 1, 1, 0.8), 1, true), box)
	if _selected == "":
		UiKit.text(self, box.position + Vector2(12, 24), "点击已见过的藏品", UiKit.F_SMALL, UiKit.TEXT_DIM)
		UiKit.text(self, box.position + Vector2(12, 38), "查看效果与价格", UiKit.F_TINY, UiKit.TEXT_DIM)
		return
	var up: Upgrade = UpgradeDB.get_upgrade(_selected)
	if up == null:
		return
	var tex := UiKit.icon(up.icon_path)
	if tex != null:
		draw_texture_rect(tex, Rect2(box.position + Vector2(12, 12), Vector2(36, 36)), false)
	UiKit.text(self, box.position + Vector2(56, 30), up.title, UiKit.F_H3, UiKit.TEXT)
	UiKit.text(self, box.position + Vector2(56, 44), "%d 金币" % up.price, UiKit.F_TINY,
		Color(0.80, 0.58, 0.10))
	draw_line(box.position + Vector2(12, 58), box.position + Vector2(box.size.x - 12, 58),
		UiKit.LINE, 1.0)
	UiKit.text_block(self, box.position + Vector2(12, 74), up.desc, box.size.x - 24,
		UiKit.F_TINY, UiKit.TEXT, 6)
	var owned := int(MetaProgress.relic_counts.get(_selected, 0))
	UiKit.text(self, box.position + Vector2(12, box.size.y - 10), "已获得 %d 次" % owned,
		UiKit.F_TINY, UiKit.TEXT_DIM)
