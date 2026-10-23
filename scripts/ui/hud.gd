extends Control
## HUD：生命 / 金币 / 技能环形冷却 / GPT 模式 / 藏品侧栏 / Boss 血条 / 暗角
## 全部贴边绘制，中间 70% 区域留给弹幕

var toast_text: String = ""
var toast_time: float = 0.0
var combo_text: String = ""
var combo_time: float = 0.0

var _icon_cache: Dictionary = {}
var _pop: Dictionary = {}          # uid -> 剩余弹跳时间
var _desc_uid: String = ""
var _desc_t: float = 0.0
var _low_flash: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.combo_activated.connect(_on_combo_activated)
	GameState.upgrades_changed.connect(_on_upgrades_changed)
	GameState.synergy_activated.connect(_on_synergy)
	GameState.low_health_triggered.connect(_on_low_health)


func _process(delta: float) -> void:
	toast_time = maxf(0.0, toast_time - delta)
	combo_time = maxf(0.0, combo_time - delta)
	for k in _pop.keys():
		_pop[k] = maxf(0.0, float(_pop[k]) - delta)
	_desc_t = maxf(0.0, _desc_t - delta)
	_low_flash = maxf(0.0, _low_flash - delta)
	queue_redraw()


func show_toast(text: String, dur: float = 2.4) -> void:
	toast_text = text
	toast_time = dur


func _on_combo_activated(combo_name: String) -> void:
	combo_text = "组合效果激活：%s" % combo_name
	combo_time = 3.0
	Sfx.play("skill", -4.0, 1.3)


func _on_low_health() -> void:
	_low_flash = 0.7


func _on_synergy(synergy_name: String) -> void:
	combo_text = "协同激活：%s" % synergy_name
	combo_time = 3.2
	Sfx.play("skill", -2.0, 1.5)


func _on_upgrades_changed() -> void:
	if GameState.upgrades.is_empty():
		return
	var uid: String = GameState.upgrades[GameState.upgrades.size() - 1]
	_pop[uid] = 0.45
	_desc_uid = uid
	_desc_t = 3.0


func _draw() -> void:
	var p = GameState.player
	_draw_vignette()
	if _low_flash > 0.0:
		_draw_low_health_flash()
	_draw_hearts()
	_draw_coins()
	_draw_room_info()
	if p != null and is_instance_valid(p):
		_draw_skill(p)
		_draw_mode(p)
	_draw_upgrades()
	_draw_specialty()
	_draw_relic_desc()
	_draw_boss()
	_draw_toasts()


# ---------------- 前景暗角：让视线收束到房间中央 ----------------
func _draw_vignette() -> void:
	var w := GameConfig.BASE_W
	var h := GameConfig.BASE_H
	var steps := 7
	for i in steps:
		var t: float = float(i) / float(steps)
		var a: float = 0.085 * (1.0 - t * 0.55)
		var d: float = 10.0 + i * 5.0
		draw_rect(Rect2(0, 0, w, d), Color(0, 0, 0, a))
		draw_rect(Rect2(0, h - d, w, d), Color(0, 0, 0, a))
		draw_rect(Rect2(0, 0, d, h), Color(0, 0, 0, a))
		draw_rect(Rect2(w - d, 0, d, h), Color(0, 0, 0, a))


## 低血量：屏幕边缘闪一次红（不遮挡中间战场）
func _draw_low_health_flash() -> void:
	var a: float = clampf(_low_flash / 0.7, 0.0, 1.0) * 0.5
	for i in 5:
		var d: float = 8.0 + i * 6.0
		var aa: float = a * (1.0 - float(i) / 5.0)
		draw_rect(Rect2(0, 0, GameConfig.BASE_W, d), Color(0.9, 0.1, 0.15, aa))
		draw_rect(Rect2(0, GameConfig.BASE_H - d, GameConfig.BASE_W, d),
			Color(0.9, 0.1, 0.15, aa))
		draw_rect(Rect2(0, 0, d, GameConfig.BASE_H), Color(0.9, 0.1, 0.15, aa))
		draw_rect(Rect2(GameConfig.BASE_W - d, 0, d, GameConfig.BASE_H),
			Color(0.9, 0.1, 0.15, aa))


# ---------------- 各区块 ----------------
func _draw_hearts() -> void:
	for i in GameState.max_hp:
		var pos := Vector2(12 + i * 13, 12)
		var filled := i < GameState.hp
		_heart(pos, 5.0, GameConfig.COL_HP if filled else Color(0.24, 0.26, 0.32))


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


## 技能：环形冷却 + 名称，比纯数字更好读
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
	var ready: bool = cd <= 0.0
	var ratio: float = clampf(1.0 - cd / total, 0.0, 1.0)

	var c := Vector2(28, GameConfig.BASE_H - 30)
	var col: Color = GameConfig.char_color(GameState.char_id)
	draw_circle(c, 16.0, Color(0.06, 0.07, 0.11, 0.85))
	draw_arc(c, 15.0, 0.0, TAU, 32, Color(0.22, 0.25, 0.34, 0.9), 2.0, true)
	if ratio > 0.0:
		draw_arc(c, 15.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 32,
			col if ready else col.darkened(0.35), 3.0, true)
	if ready:
		var pulse: float = 0.55 + 0.25 * sin(Time.get_ticks_msec() / 260.0)
		draw_arc(c, 18.5, 0.0, TAU, 32, Color(col.r, col.g, col.b, pulse * 0.5), 1.0, true)
	draw_circle(c, 2.6, Color(1, 1, 1, 0.85) if ready else Color(0.4, 0.43, 0.5))
	_text(Vector2(50, GameConfig.BASE_H - 34), "%s [E]" % name, 9,
		GameConfig.COL_TEXT if ready else GameConfig.COL_DIM)
	_text(Vector2(50, GameConfig.BASE_H - 24),
		"就绪" if ready else "%.1fs" % cd, 8,
		col if ready else GameConfig.COL_DIM)


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


## 藏品侧栏：拾取时 1.15 倍弹跳
func _draw_upgrades() -> void:
	var x := GameConfig.BASE_W - 30.0
	var y := 34.0
	for uid in GameState.upgrades:
		var up: Upgrade = UpgradeDB.get_upgrade(uid)
		if up == null:
			continue
		var tex := _icon(up.icon_path)
		var pop: float = float(_pop.get(uid, 0.0))
		var sc: float = 1.0
		if pop > 0.0:
			sc = 1.0 + 0.15 * sin(clampf(pop / 0.45, 0.0, 1.0) * PI)
		var size := 22.0 * sc
		var rect := Rect2(Vector2(x + (22.0 - size) * 0.5, y + (22.0 - size) * 0.5),
			Vector2(size, size))
		if tex != null:
			draw_texture_rect(tex, rect, false)
		if pop > 0.0:
			draw_rect(rect.grow(1), Color(1.0, 0.85, 0.4, pop * 0.8), false, 1.0)
		y += 24.0
		if y > GameConfig.BASE_H - 60.0:
			break


## 首次/新获得藏品：右侧显示 3s 描述
func _draw_relic_desc() -> void:
	if _desc_t <= 0.0 or _desc_uid == "":
		return
	var up: Upgrade = UpgradeDB.get_upgrade(_desc_uid)
	if up == null:
		return
	var a: float = clampf(_desc_t / 0.6, 0.0, 1.0)
	var w := 150.0
	var r := Rect2(Vector2(GameConfig.BASE_W - w - 10.0, 34.0 + minf(GameState.upgrades.size(), 8) * 24.0 + 6.0),
		Vector2(w, 44))
	draw_rect(r, Color(0.05, 0.07, 0.11, 0.86 * a))
	draw_rect(r, Color(1.0, 0.82, 0.35, 0.7 * a), false, 1.0)
	if GameConfig.ui_font != null:
		draw_string(GameConfig.ui_font, r.position + Vector2(6, 13), up.title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.88, 0.5, a))
		draw_multiline_string(GameConfig.ui_font, r.position + Vector2(6, 27), up.desc,
			HORIZONTAL_ALIGNMENT_LEFT, w - 12, 8, 2, Color(0.88, 0.92, 1.0, a))


## 专精：同一角色两件专属藏品时，右上角亮一个小徽章（不写效果）
func _draw_specialty() -> void:
	if String(GameState.mods.get("specialty", "")) == "":
		return
	var c := Vector2(GameConfig.BASE_W - 44, GameConfig.BASE_H - 34)
	var col := GameConfig.char_color(GameState.char_id)
	var pulse: float = 0.55 + 0.25 * sin(Time.get_ticks_msec() / 300.0)
	draw_circle(c, 9.0, Color(0.06, 0.07, 0.11, 0.9))
	draw_arc(c, 9.0, 0.0, TAU, 20, Color(col.r, col.g, col.b, pulse), 1.5, true)
	for i in 5:
		var ang := -PI / 2.0 + TAU * i / 5.0
		var p1 := c + Vector2(cos(ang), sin(ang)) * 6.0
		var ang2 := ang + TAU / 5.0 * 0.5
		var p2 := c + Vector2(cos(ang2), sin(ang2)) * 2.6
		var ang3 := ang + TAU / 5.0
		var p3 := c + Vector2(cos(ang3), sin(ang3)) * 6.0
		draw_colored_polygon(PackedVector2Array([p1, p2, p3]), col)


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
	# 阶段分界刻度（60% / 25%）
	for mark in [0.6, 0.25]:
		var mx: float = x + w * float(mark)
		draw_line(Vector2(mx, y - 2), Vector2(mx, y + 10), Color(1, 1, 1, 0.45), 1.0)
	_text(Vector2(GameConfig.BASE_W * 0.5, y - 3), "回响聚合体 · 第 %d 阶段" % boss.phase,
		9, GameConfig.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	# 本阶段抽到的两个招式
	var mv: Array = boss.current_moves() if boss.has_method("current_moves") else []
	var labels := {"ring": "环", "fan": "扇", "charge": "冲", "homing": "追",
		"summon": "召", "laser": "激", "spiral": "旋", "mine": "雷"}
	for i in mv.size():
		var bx := x + i * 18.0
		var box := Rect2(Vector2(bx, y + 12), Vector2(15, 13))
		draw_rect(box, Color(0.12, 0.1, 0.18, 0.9))
		draw_rect(box, Color(0.6, 0.5, 0.85, 0.8), false, 1.0)
		_text(Vector2(box.position.x, box.position.y + 10), String(labels.get(String(mv[i]), "?")),
			8, Color(0.9, 0.85, 1.0))

	# 阶段转换预警横幅
	if float(boss.telegraph) > 0.0:
		var a: float = clampf(float(boss.telegraph) / 0.75, 0.0, 1.0)
		var bw := 150.0
		draw_rect(Rect2(Vector2((GameConfig.BASE_W - bw) * 0.5, y + 14), Vector2(bw, 14)),
			Color(0.45, 0.06, 0.10, 0.75 * a))
		_text(Vector2(GameConfig.BASE_W * 0.5, y + 24), "阶段转换！", 10,
			Color(1.0, 0.55, 0.55, a), HORIZONTAL_ALIGNMENT_CENTER)


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
		var w: float = GameConfig.ui_font.get_string_size(
			s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		p.x -= w * 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else w
	draw_string(GameConfig.ui_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
