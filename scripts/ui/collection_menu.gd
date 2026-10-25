extends Control
## 藏品图鉴（v0.7 P2 像素版）：6×4 网格 + 分类标签 + 黑色剪影 + 右侧详情

signal closed

const COLS := 6
const CELL_W := 56.0
const CELL_H := 50.0
const GAP := 6.0
const GRID_X := 24.0
const GRID_Y := 82.0
const TABS := ["全部", "通用", "专属", "质变"]
const TAB_W := 52.0
const TAB_H := 16.0
const TAB_GAP := 4.0

var _ids: Array = []
var _view: Array = []
var _rects: Array = []
var _tab_rects: Array = []
var _tab: int = 0
var _selected: String = ""
var _hover: int = -1
var _hover_k: Array = []
var _t: float = 0.0
var _enter: float = 12.0
var _back_btn: BaButton = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ids = UpgradeDB.all_ids()
	_ids.sort()
	_layout()
	for uid in _ids:
		if MetaProgress.seen_relics.has(uid):
			_selected = String(uid)
			break
	_back_btn = BaButton.new()
	add_child(_back_btn)
	_back_btn.setup("返回  [C]", Rect2(GameConfig.BASE_W - 116, 318, 92, 24),
		"secondary", "", UiKit.F_SMALL)
	_back_btn.pressed.connect(_close)
	BaCursor.set_battle(false)
	var tw := create_tween()
	tw.tween_property(self, "_enter", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("ui")


func _layout() -> void:
	_view.clear()
	for uid in _ids:
		if _matches(String(uid), _tab):
			_view.append(uid)
	_rects.clear()
	_hover_k.clear()
	for i in _view.size():
		var col := i % COLS
		var row := int(i / COLS)
		_rects.append(Rect2(GRID_X + col * (CELL_W + GAP), GRID_Y + row * (CELL_H + GAP),
			CELL_W, CELL_H))
		_hover_k.append(0.0)
	_tab_rects.clear()
	for i in TABS.size():
		_tab_rects.append(Rect2(GRID_X + i * (TAB_W + TAB_GAP), GRID_Y - 22, TAB_W, TAB_H))
	_hover = -1


func _matches(uid: String, tab: int) -> bool:
	if tab == 0:
		return true
	var up: Upgrade = UpgradeDB.get_upgrade(uid)
	if up == null:
		return false
	match tab:
		1:
			return up.char_tag == ""
		2:
			return up.char_tag != ""
		3:
			return up.mutation
	return true


func _process(delta: float) -> void:
	_t += delta
	var mouse := get_local_mouse_position()
	var prev := _hover
	_hover = -1
	for i in _rects.size():
		if (_rects[i] as Rect2).has_point(mouse) and MetaProgress.seen_relics.has(_view[i]):
			_hover = i
	if _hover != prev:
		for i in _rects.size():
			var on := i == _hover
			var tw := create_tween()
			tw.tween_method(func(v: float) -> void: _hover_k[i] = v, float(_hover_k[i]),
				1.0 if on else 0.0, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _hover >= 0:
		BaCursor.force_hot()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	for i in _tab_rects.size():
		if (_tab_rects[i] as Rect2).has_point(event.position):
			_switch_tab(i)
			accept_event()
			return
	if _hover >= 0:
		_selected = String(_view[_hover])
		Sfx.play("ui")
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ESCAPE, KEY_C, KEY_ENTER]:
			_close()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_4:
			_switch_tab(event.physical_keycode - KEY_1)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode in [KEY_LEFT, KEY_A]:
			_switch_tab((_tab + TABS.size() - 1) % TABS.size())
			get_viewport().set_input_as_handled()
		elif event.physical_keycode in [KEY_RIGHT, KEY_D]:
			_switch_tab((_tab + 1) % TABS.size())
			get_viewport().set_input_as_handled()


func _switch_tab(i: int) -> void:
	if i == _tab or i < 0 or i >= TABS.size():
		return
	_tab = i
	_layout()
	Sfx.play("ui")


func _close() -> void:
	Sfx.play("ui")
	closed.emit()
	queue_free()


# ---------------- 绘制 ----------------
func _draw() -> void:
	UiKit.gradient_backdrop(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), _t)
	draw_set_transform(Vector2(0, roundf(_enter)), 0.0, Vector2.ONE)

	UiKit.text(self, Vector2(24, 34), "藏品图鉴", UiKit.F_H2, UiKit.TEXT)
	UiKit.text(self, Vector2(24, 52), "最高层数 %d · 总击杀 %d · 通关 DS %d / GPT %d / CL %d"
		% [MetaProgress.max_floor, MetaProgress.total_kills,
		int(MetaProgress.clears["deepseek"]), int(MetaProgress.clears["gpt"]),
		int(MetaProgress.clears["claude"])], UiKit.F_SMALL, UiKit.TEXT_DIM)
	var seen_n := MetaProgress.seen_relics.size()
	UiKit.text_right(self, 616, 52, "已收集 %d / %d" % [seen_n, _ids.size()],
		UiKit.F_SMALL, UiKit.CYAN)

	for i in TABS.size():
		_draw_tab(i)

	for i in _view.size():
		_draw_cell(i, _rects[i])
	_draw_detail()
	UiKit.text(self, Vector2(24, 330), "点击查看 · 1-4 切换分类 · C 返回",
		UiKit.F_SMALL, UiKit.TEXT_DIM)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tab(i: int) -> void:
	var r: Rect2 = _tab_rects[i]
	var on := i == _tab
	draw_rect(r, UiKit.DEEP if on else UiKit.VOID)
	draw_rect(r, UiKit.BORDER, false, 1.0)
	if on:
		draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), UiKit.CYAN)
	UiKit.text_center(self, r.get_center().x, r.position.y + 12, TABS[i], UiKit.F_SMALL,
		UiKit.CYAN if on else UiKit.TEXT_DIM)


func _draw_cell(i: int, r: Rect2) -> void:
	var uid: String = _view[i]
	var seen: bool = MetaProgress.seen_relics.has(uid)
	var hk: float = float(_hover_k[i])
	UiKit.inset(self, r, UiKit.VOID, UiKit.BORDER)
	if seen:
		var up: Upgrade = UpgradeDB.get_upgrade(uid)
		var tex: Texture2D = null
		if up != null:
			tex = UiKit.icon(up.icon_path)
		if tex != null:
			self.draw_texture_rect(tex, Rect2(r.position + Vector2(12, 3), Vector2(32, 32)), false)
		else:
			draw_rect(Rect2(r.position + Vector2(18, 10), Vector2(20, 18)), UiKit.RAISED)
		if up != null:
			UiKit.text_center(self, r.get_center().x, r.position.y + 46,
				UiKit.fit(up.title, CELL_W - 4, UiKit.F_SMALL), UiKit.F_SMALL,
				UiKit.TEXT if hk < 0.5 else UiKit.WHITE)
	else:
		# 黑色剪影：用原图标压暗，保留轮廓
		var up2: Upgrade = UpgradeDB.get_upgrade(uid)
		var tex2: Texture2D = UiKit.icon(up2.icon_path) if up2 != null else null
		if tex2 != null:
			self.draw_texture_rect(tex2, Rect2(r.position + Vector2(12, 3), Vector2(32, 32)),
				false, Color(0.03, 0.04, 0.08, 1.0))
		else:
			draw_rect(Rect2(r.position + Vector2(18, 10), Vector2(20, 18)), UiKit.SHADOW)
		UiKit.text_center(self, r.get_center().x, r.position.y + 46, "???", UiKit.F_SMALL,
			Color(0.35, 0.40, 0.52))
	if hk > 0.5:
		UiKit.corner_brackets(self, r, UiKit.GOLD, 4)
	if _selected == uid:
		draw_rect(r, UiKit.GOLD, false, 1.0)
		UiKit.corner_brackets(self, r, UiKit.GOLD, 5)


func _draw_detail() -> void:
	var box := Rect2(402, 82, 214, 218)
	UiKit.frame(self, box, UiKit.DEEP, UiKit.BORDER, UiKit.BORDER_HI, true)
	draw_rect(Rect2(box.position.x + 1, box.position.y + 1, box.size.x - 2, 2), UiKit.PANEL)
	if _selected == "":
		UiKit.text_center(self, box.get_center().x, box.position.y + 96, "点击已见过的藏品",
			UiKit.F_SMALL, UiKit.TEXT_DIM)
		UiKit.text_center(self, box.get_center().x, box.position.y + 114, "查看效果与价格",
			UiKit.F_SMALL, UiKit.TEXT_DIM)
		return
	var up: Upgrade = UpgradeDB.get_upgrade(_selected)
	if up == null:
		return
	var tex := UiKit.icon(up.icon_path)
	if tex != null:
		self.draw_texture_rect(tex, Rect2(box.position + Vector2(12, 12), Vector2(32, 32)), false)
	UiKit.text(self, box.position + Vector2(52, 28), UiKit.fit(up.title, 150, UiKit.F_BODY),
		UiKit.F_BODY, UiKit.TEXT)
	var tag := ""
	if up.mutation:
		tag = "质变 · "
	elif up.char_tag != "":
		tag = "专属 · "
	UiKit.text(self, box.position + Vector2(52, 44), "%s%d 金币" % [tag, up.price],
		UiKit.F_SMALL, UiKit.GOLD)
	draw_line(box.position + Vector2(12, 54), box.position + Vector2(box.size.x - 12, 54),
		UiKit.BORDER, 1.0)
	UiKit.text_block(self, box.position + Vector2(12, 70), up.desc, box.size.x - 24,
		UiKit.F_SMALL, UiKit.TEXT, 8)
	var owned := int(MetaProgress.relic_counts.get(_selected, 0))
	UiKit.text(self, box.position + Vector2(12, box.size.y - 10), "已获得 %d 次" % owned,
		UiKit.F_SMALL, UiKit.TEXT_DIM)
