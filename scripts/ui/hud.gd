extends Control
## HUD：生命 / 金币 / 技能冷却 / GPT 模式 / 藏品侧栏 / Boss 血条 / 提示

var toast_text: String = ""
var toast_time: float = 0.0
var combo_text: String = ""
var combo_time: float = 0.0
var _icon_cache: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.combo_activated.connect(_on_combo_activated)


func _process(delta: float) -> void:
	toast_time = maxf(0.0, toast_time - delta)
	combo_time = maxf(0.0, combo_time - delta)
	queue_redraw()


func show_toast(text: String, dur: float = 2.4) -> void:
	toast_text = text
	toast_time = dur


func _on_combo_activated(combo_name: String) -> void:
	combo_text = "组合效果激活：%s" % combo_name
	combo_time = 3.0
	Sfx.play("skill", -4.0, 1.3)


func _draw() -> void:
	var p = GameState.player
	_draw_hearts()
	_draw_coins()
	_draw_room_info()
	if p != null and is_instance_valid(p):
		_draw_skill(p)
		_draw_mode(p)
	_draw_upgrades()
	_draw_boss()
	_draw_toasts()


# ---------------- 各区块 ----------------
func _draw_hearts() -> void:
	for i in GameState.max_hp:
		var pos := Vector2(12 + i * 13, 12)
		var filled := i < GameState.hp
		_heart(pos, 5.0, GameConfig.COL_HP if filled else Color(0.25, 0.27, 0.33))


func _heart(center: Vector2, r: float, color: Color) -> void:
	draw_circle(center + Vector2(-r * 0.5, -r * 0.3), r * 0.62, color)
	draw_circle(center + Vector2(r * 0.5, -r * 0.3), r * 0.62, color)
	var pts := PackedVector2Array([
		center + Vector2(-r * 1.05, -r * 0.05),
		center + Vector2(r * 1.05, -r * 0.05),
		center + Vector2(0, r * 1.15),
	])
	draw_colored_polygon(pts, color)


func _draw_coins() -> void:
	var pos := Vector2(12, 36)
	draw_circle(pos + Vector2(4, -3), 4.0, GameConfig.COL_GOLD)
	draw_circle(pos + Vector2(3, -4), 1.4, Color(1, 1, 1, 0.9))
	_text(pos + Vector2(12, 1), str(GameState.coins), 11, GameConfig.COL_GOLD)


func _draw_room_info() -> void:
	var txt := "B%d  ·  房间 %d/5" % [GameState.floor_index, GameState.room_index]
	_text(Vector2(GameConfig.BASE_W - 12, 18), txt, 10, GameConfig.COL_DIM,
		HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_skill(p) -> void:
	var w = p.weapon
	if w == null:
		return
	var name: String = "技能"
	if p.data != null:
		name = p.data.skill_name
	var cd: float = float(w.skill_cd_left)
	var total: float = 8.0
	if p.data != null:
		total = maxf(0.5, p.data.skill_cd)
	var ratio: float = clampf(1.0 - cd / total, 0.0, 1.0)
	var base := Vector2(12, GameConfig.BASE_H - 26)
	draw_rect(Rect2(base, Vector2(92, 7)), Color(0.1, 0.11, 0.16, 0.9))
	var col := GameConfig.char_color(GameState.char_id)
	draw_rect(Rect2(base, Vector2(92 * ratio, 7)), col if cd <= 0.0 else col.darkened(0.45))
	draw_rect(Rect2(base, Vector2(92, 7)), Color(0, 0, 0, 0.5), false, 1.0)
	var label := "%s [E]" % name
	if cd > 0.0:
		label += "  %.1fs" % cd
	else:
		label += "  就绪"
	_text(Vector2(12, GameConfig.BASE_H - 30), label, 9,
		GameConfig.COL_TEXT if cd <= 0.0 else GameConfig.COL_DIM)


func _draw_mode(p) -> void:
	if p.char_id != "gpt" or p.weapon == null:
		return
	var w = p.weapon
	var txt := "模式：%s  [R]" % w.mode_text()
	_text(Vector2(GameConfig.BASE_W * 0.5, GameConfig.BASE_H - 10), txt, 10,
		Color("#c9b6ff"), HORIZONTAL_ALIGNMENT_CENTER)
	if w.has_method("buff_text"):
		var b: String = w.buff_text()
		if b != "":
			_text(Vector2(GameConfig.BASE_W * 0.5, GameConfig.BASE_H - 24), b, 9,
				Color("#ffd166"), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_upgrades() -> void:
	var x := GameConfig.BASE_W - 30.0
	var y := 34.0
	for uid in GameState.upgrades:
		var up: Upgrade = UpgradeDB.get_upgrade(uid)
		if up == null:
			continue
		var tex := _icon(up.icon_path)
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(x, y), Vector2(22, 22)), false)
		y += 24.0
		if y > GameConfig.BASE_H - 60.0:
			break


func _icon(path: String) -> Texture2D:
	if _icon_cache.has(path):
		return _icon_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	_icon_cache[path] = tex
	return tex


func _draw_boss() -> void:
	var boss = get_tree().get_first_node_in_group("boss")
	if boss == null or not is_instance_valid(boss) or boss.dead:
		return
	var w := 240.0
	var x := (GameConfig.BASE_W - w) * 0.5
	var y := 28.0
	draw_rect(Rect2(Vector2(x, y), Vector2(w, 8)), Color(0.08, 0.06, 0.1, 0.9))
	var col := Color("#ff5b8b") if boss.phase < 3 else Color("#ff5b5b")
	draw_rect(Rect2(Vector2(x, y), Vector2(w * boss.hp_ratio(), 8)), col)
	draw_rect(Rect2(Vector2(x, y), Vector2(w, 8)), Color(0, 0, 0, 0.6), false, 1.0)
	_text(Vector2(GameConfig.BASE_W * 0.5, y - 3), "回响聚合体 · 第 %d 阶段" % boss.phase,
		9, GameConfig.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_toasts() -> void:
	if toast_time > 0.0:
		var a: float = clampf(toast_time, 0.0, 1.0)
		_text(Vector2(GameConfig.BASE_W * 0.5, GameConfig.BASE_H * 0.36), toast_text, 12,
			Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER)
	if combo_time > 0.0:
		var a2: float = clampf(combo_time, 0.0, 1.0)
		_text(Vector2(GameConfig.BASE_W * 0.5, GameConfig.BASE_H * 0.44), combo_text, 10,
			Color(1.0, 0.85, 0.4, a2), HORIZONTAL_ALIGNMENT_CENTER)


func _text(pos: Vector2, s: String, size: int, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if GameConfig.ui_font == null:
		return
	var p := pos
	if align != HORIZONTAL_ALIGNMENT_LEFT:
		# draw_string 的 width=-1 时对齐无效，这里手动按文字宽度偏移
		var w: float = GameConfig.ui_font.get_string_size(
			s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		p.x -= w * 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else w
	draw_string(GameConfig.ui_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
