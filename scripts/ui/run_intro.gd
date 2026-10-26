extends Control
## 开局全屏登场（Boss 登场同款）：暂停游戏并拦截所有点击/空格，关闭后才开始刷怪。
## 这样选完角色进游戏的第一下点击不会变成攻击，空格也不会触发翻滚。

signal finished

var _data = null
var _floor: int = 1
var _t: float = 0.0
var _armed: bool = false
var _done: bool = false


func setup(data, floor_index: int) -> void:
	_data = data
	_floor = floor_index


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "RunIntro"
	_build_portrait()
	Sfx.play("ui_confirm", -6.0)


func _build_portrait() -> void:
	if _data == null:
		return
	var path := ""
	for suffix in ["full", "bust", "face"]:
		var cand := "res://assets/portraits/%s_%s.png" % [_data.id, suffix]
		if ResourceLoader.exists(cand):
			path = cand
			break
	if path == "":
		return
	var tr := TextureRect.new()
	tr.texture = load(path)
	# 忽略原图 1024×1024 尺寸，严格按 196×306 显示
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.position = Vector2(404, 26)
	tr.size = Vector2(196, 306)
	add_child(tr)


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.35:
		_armed = true
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _armed or _done:
		return
	var ok := false
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		ok = true
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
		ok = true
	if ok:
		_advance()
		get_viewport().set_input_as_handled()


## 供测试/截图脚本关闭
func _advance() -> void:
	if _done:
		return
	_done = true
	finished.emit()


func _draw() -> void:
	var accent: Color = _data.accent if _data != null else UiKit.CYAN
	var name_txt := String(_data.display_name) if _data != null else "AI"
	var title_txt := String(_data.title) if _data != null else ""

	draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.015, 0.022, 0.04, 0.94))
	var panel := Rect2(20, 18, 600, 324)
	UiKit.frame(self, panel, Color(0.04, 0.06, 0.11, 0.96), UiKit.BORDER, UiKit.BORDER_HI, true)
	UiKit.scanlines(self, panel.grow(-2), 0.045)
	# 左侧角色色竖条
	draw_rect(Rect2(panel.position + Vector2(0, 1), Vector2(4, panel.size.y - 2)), accent)

	UiKit.text(self, Vector2(44, 52), "RUN START", 12, accent)
	UiKit.text(self, Vector2(44, 92), name_txt, UiKit.F_H1, UiKit.TEXT, false)
	UiKit.text(self, Vector2(44, 118), title_txt, UiKit.F_BODY, accent)
	draw_line(Vector2(44, 132), Vector2(336, 132), UiKit.BORDER, 1.0)

	var floor_txt := "第 %d 层" % _floor
	if _floor == 1:
		floor_txt += " · 清空 5 间房，第 5 间是 Boss"
	UiKit.text(self, Vector2(44, 158), floor_txt, UiKit.F_BODY, UiKit.TEXT_DIM)

	var lines: Array = []
	if _data != null:
		lines = [
			String(_data.blurb),
			"武器「%s」：%s" % [_data.weapon_name, _data.weapon_desc],
			"技能「%s」：%s" % [_data.skill_name, _data.skill_desc],
			"天赋「%s」：%s" % [_data.passive_name, _data.passive_desc],
		]
	for i in lines.size():
		# 限宽到立绘左缘之前，避免文字被右侧立绘盖住
		UiKit.text(self, Vector2(44, 186 + i * 19),
			UiKit.fit(String(lines[i]), 348, 12), 12,
			Color(0.68, 0.74, 0.86) if i > 0 else UiKit.TEXT)

	var hint_col := UiKit.GOLD if _armed else UiKit.TEXT_DIM
	UiKit.text_center(self, GameConfig.BASE_W * 0.5, 330,
		"点击或空格开始 · 本次输入不会触发攻击/翻滚", 12, hint_col)

	if _t < 0.2:
		draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H),
			Color(0, 0, 0, 1.0 - _t / 0.2))
