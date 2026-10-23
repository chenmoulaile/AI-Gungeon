extends Control
## 藏品图鉴 + 局外统计（只读，不提供重置）

signal closed

const COLS := 6
const ICON := 34.0
const GAP := 10.0

var _ids: Array = []
var _rects: Array = []
var _selected: String = ""
var _hover: int = -1
var _icon_cache: Dictionary = {}
var _t: float = 0.0
var _focus: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	_ids = UpgradeDB.all_ids()
	_ids.sort()
	_layout()
	Sfx.play("ui")


func _layout() -> void:
	_rects.clear()
	var x0 := 34.0
	var y0 := 84.0
	for i in _ids.size():
		var col := i % COLS
		var row := int(i / COLS)
		_rects.append(Rect2(x0 + col * (ICON + GAP), y0 + row * (ICON + GAP), ICON, ICON))


func _process(delta: float) -> void:
	_t += delta
	var mouse := get_local_mouse_position()
	_hover = -1
	for i in _rects.size():
		if _rects[i].grow(2).has_point(mouse):
			_hover = i
	if Input.is_action_just_pressed("ui_left"):
		_focus = maxi(0, _focus - 1)
	if Input.is_action_just_pressed("ui_right"):
		_focus = mini(_ids.size() - 1, _focus + 1)
	if Input.is_action_just_pressed("ui_up"):
		_focus = maxi(0, _focus - COLS)
	if Input.is_action_just_pressed("ui_down"):
		_focus = mini(_ids.size() - 1, _focus + COLS)
	if Input.is_action_just_pressed("ui_accept") and _focus < _ids.size():
		var uid: String = _ids[_focus]
		if MetaProgress.seen_relics.has(uid):
			_selected = uid
			Sfx.play("ui")
	if Input.is_action_just_pressed("ui_cancel"):
		_close()
	if InputDevice.using_pad:
		_hover = _focus
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hover >= 0:
			var uid: String = _ids[_hover]
			if MetaProgress.seen_relics.has(uid):
				_selected = uid
				Sfx.play("ui")
		elif _back_rect().has_point(get_local_mouse_position()):
			_close()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ESCAPE, KEY_C, KEY_ENTER]:
			_close()
			get_viewport().set_input_as_handled()


func _back_rect() -> Rect2:
	return Rect2(GameConfig.BASE_W - 92, GameConfig.BASE_H - 40, 74, 24)


func _close() -> void:
	Sfx.play("ui")
	closed.emit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.04, 0.05, 0.08, 0.97))
	if GameConfig.ui_font == null:
		return
	_text(Vector2(34, 30), "藏品图鉴", 16, GameConfig.COL_TEXT)
	_text(Vector2(34, 48), "最高层数 %d    总击杀 %d    通关  DeepSeek %d / GPT %d / Claude %d"
		% [MetaProgress.max_floor, MetaProgress.total_kills,
		int(MetaProgress.clears["deepseek"]), int(MetaProgress.clears["gpt"]),
		int(MetaProgress.clears["claude"])], 9, GameConfig.COL_DIM)
	var hours := int(MetaProgress.total_time / 3600.0)
	var mins := int(fmod(MetaProgress.total_time, 3600.0) / 60.0)
	var top: Array = MetaProgress.top_relics(3)
	var top_txt := ""
	for i in top.size():
		var up: Upgrade = UpgradeDB.get_upgrade(String(top[i]["id"]))
		if up != null:
			top_txt += ("%s×%d  " % [up.title, int(top[i]["count"])])
	_text(Vector2(34, 62), "累计时长 %dh%02dm    最常见藏品：%s"
		% [hours, mins, top_txt if top_txt != "" else "—"], 9, GameConfig.COL_DIM)

	for i in _ids.size():
		var uid: String = _ids[i]
		var seen: bool = MetaProgress.seen_relics.has(uid)
		var r: Rect2 = _rects[i]
		var up: Upgrade = UpgradeDB.get_upgrade(uid)
		draw_rect(r, Color(0.08, 0.09, 0.13))
		if seen and up != null:
			var tex := _icon(up.icon_path)
			if tex != null:
				draw_texture_rect(tex, r, false)
		else:
			draw_rect(r, Color(0.05, 0.06, 0.09))
			_text(Vector2(r.position.x + 12, r.position.y + 22), "?", 12, Color(0.3, 0.33, 0.4))
		if _hover == i or (_focus == i and InputDevice.using_pad):
			draw_rect(r, Color(1.0, 0.85, 0.4), false, 1.0)
		if _selected == uid:
			draw_rect(r.grow(1), Color(0.55, 0.75, 1.0), false, 2.0)

	# 详情
	var box := Rect2(34, 232, GameConfig.BASE_W - 68, 74)
	draw_rect(box, Color(0.07, 0.08, 0.12, 0.96))
	draw_rect(box, Color(0.3, 0.36, 0.48), false, 1.0)
	if _selected == "":
		_text(Vector2(box.position.x + 12, box.position.y + 22), "点击已见过的藏品查看描述", 10,
			GameConfig.COL_DIM)
	else:
		var up2: Upgrade = UpgradeDB.get_upgrade(_selected)
		if up2 != null:
			_text(Vector2(box.position.x + 12, box.position.y + 22), up2.title, 12,
				Color(1.0, 0.88, 0.5))
			_text(Vector2(box.position.x + 12, box.position.y + 40), "价格 %d 金币" % up2.price,
				9, GameConfig.COL_DIM)
			draw_multiline_string(GameConfig.ui_font,
				Vector2(box.position.x + 12, box.position.y + 56), up2.desc,
				HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 24, 9, 2, GameConfig.COL_TEXT)

	var b := _back_rect()
	draw_rect(b, Color(0.16, 0.22, 0.32))
	draw_rect(b, Color(0.5, 0.65, 0.9), false, 1.0)
	_text(Vector2(b.position.x + 18, b.position.y + 16), "返回 [C]", 10, GameConfig.COL_TEXT)


func _icon(path: String) -> Texture2D:
	if _icon_cache.has(path):
		return _icon_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	_icon_cache[path] = tex
	return tex


func _text(pos: Vector2, s: String, size: int, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if GameConfig.ui_font == null:
		return
	var p := pos
	if align != HORIZONTAL_ALIGNMENT_LEFT:
		var w: float = GameConfig.ui_font.get_string_size(
			s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		p.x -= w
	draw_string(GameConfig.ui_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
