extends Control
## HUD（蔚蓝档案风格）：生命图标 / 金币 / 技能与副武器环形冷却 / 藏品侧栏 / Boss 血条 / 挑战
## 全部贴边、半透明白底，中间 70% 区域完全留给弹幕

var toast_text: String = ""
var toast_time: float = 0.0
var combo_text: String = ""
var combo_time: float = 0.0

var _pop: Dictionary = {}
var _desc_uid: String = ""
var _desc_t: float = 0.0
var _low_flash: float = 0.0
var _challenge_title: String = ""
var _challenge_desc: String = ""
var _challenge_done: bool = false
var _challenge_pop: float = 0.0
var _coins_shown: float = 0.0
var _coins_from: float = 0.0
var _skill_pulse: float = 0.0
var _sub_pulse: float = 0.0
var _sub_was_ready: bool = true
var _skill_was_ready: bool = true
var _t: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://resources/ui/theme.tres"):
		theme = load("res://resources/ui/theme.tres")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.combo_activated.connect(_on_combo_activated)
	GameState.upgrades_changed.connect(_on_upgrades_changed)
	GameState.synergy_activated.connect(_on_synergy)
	GameState.low_health_triggered.connect(_on_low_health)
	ChallengeManager.challenge_changed.connect(_on_challenge)
	ChallengeManager.completed.connect(_on_challenge_done)
	_coins_shown = float(GameState.coins)


func _process(delta: float) -> void:
	_t += delta
	toast_time = maxf(0.0, toast_time - delta)
	combo_time = maxf(0.0, combo_time - delta)
	for k in _pop.keys():
		_pop[k] = maxf(0.0, float(_pop[k]) - delta)
	_desc_t = maxf(0.0, _desc_t - delta)
	_low_flash = maxf(0.0, _low_flash - delta)
	_challenge_pop = maxf(0.0, _challenge_pop - delta)
	_skill_pulse = maxf(0.0, _skill_pulse - delta)
	_sub_pulse = maxf(0.0, _sub_pulse - delta)
	# 金币数字滚动
	if absf(_coins_shown - float(GameState.coins)) > 0.01:
		_coins_shown = move_toward(_coins_shown, float(GameState.coins),
			maxf(1.0, absf(float(GameState.coins) - _coins_shown) * 8.0) * delta)
	# 冷却完成时脉冲一次
	var p = GameState.player
	if p != null and is_instance_valid(p) and p.weapon != null:
		var rdy: bool = float(p.weapon.skill_cd_left) <= 0.0
		if rdy and not _skill_was_ready:
			_skill_pulse = 0.45
		_skill_was_ready = rdy
	queue_redraw()


func show_toast(text: String, dur: float = 2.4) -> void:
	toast_text = text
	toast_time = dur


func _on_combo_activated(combo_name: String) -> void:
	combo_text = "组合效果激活 · %s" % combo_name
	combo_time = 3.0
	Sfx.play("skill", -4.0, 1.3)


func _on_challenge(title: String, desc: String) -> void:
	_challenge_title = title
	_challenge_desc = desc
	_challenge_done = false


func _on_challenge_done(title: String) -> void:
	_challenge_done = true
	_challenge_pop = 1.0
	_challenge_title = title
	Sfx.play("relic", -2.0, 1.2)


func _on_low_health() -> void:
	_low_flash = 0.7


func _on_synergy(synergy_name: String) -> void:
	combo_text = "协同激活 · %s" % synergy_name
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
	if _low_flash > 0.0:
		_draw_low_flash()
	_draw_hearts()
	_draw_coins()
	_draw_room_info()
	_draw_exclusive()
	var p = GameState.player
	if p != null and is_instance_valid(p):
		_draw_rings(p)
		_draw_mode(p)
	_draw_upgrades()
	_draw_relic_desc()
	_draw_boss()
	_draw_challenge()
	_draw_toasts()


# ---------------- 生命 ----------------
func _draw_hearts() -> void:
	var ratio: float = clampf(float(GameState.hp) / maxf(1.0, float(GameState.max_hp)), 0.0, 1.0)
	var w := 88.0
	var panel := Rect2(8, 6, w + 62, 22)
	draw_style_box(UiKit.box(Color(1, 1, 1, 0.30), 8, Color(1, 1, 1, 0.35), 1, false), panel)
	UiKit.text(self, Vector2(panel.position.x + 6, panel.position.y + 15), "HP", UiKit.F_TINY,
		Color(0.92, 0.94, 1.0, 0.85))
	var bar := Rect2(panel.position.x + 24, panel.position.y + 6, w, 10)
	draw_style_box(UiKit.box(Color(0.30, 0.16, 0.20, 0.55), 5, Color(0, 0, 0, 0), 0, false), bar)
	var col := Color(0.35, 0.82, 0.45)
	if ratio <= 0.3:
		col = Color(0.95, 0.32, 0.34)
	elif ratio <= 0.6:
		col = Color(0.95, 0.72, 0.28)
	var fill := Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y))
	if fill.size.x > 1.0:
		draw_style_box(UiKit.box(col, 5, Color(0, 0, 0, 0), 0, false), fill)
		draw_rect(Rect2(fill.position + Vector2(1, 1), Vector2(fill.size.x - 2, 2)),
			Color(1, 1, 1, 0.28))
	# 低血量闪烁描边
	if ratio <= 0.3 and fmod(_t, 0.6) < 0.3:
		draw_style_box(UiKit.box(Color(0, 0, 0, 0), 5, Color(1.0, 0.35, 0.35, 0.9), 1, false),
			bar.grow(1.0))
	UiKit.text(self, Vector2(bar.end.x + 6, panel.position.y + 14),
		"%d/%d" % [GameState.hp, GameState.max_hp], UiKit.F_TINY, Color(0.95, 0.96, 1.0, 0.92))



# ---------------- 金币 ----------------
func _draw_coins() -> void:
	var y := GameConfig.BASE_H - 16.0
	var r := Rect2(8, y - 10, 74, 18)
	draw_style_box(UiKit.box(Color(1, 1, 1, 0.34), 9, Color(1, 1, 1, 0.35), 1, false), r)
	draw_circle(Vector2(18, y - 1), 5.0, UiKit.GOLD)
	draw_circle(Vector2(17, y - 2), 1.8, Color(1, 1, 1, 0.9))
	UiKit.text(self, Vector2(27, y + 3.5), str(int(round(_coins_shown))), UiKit.F_H3,
		Color(0.22, 0.24, 0.30))


func _draw_room_info() -> void:
	var s := "B%d  ·  %d/5" % [GameState.floor_index, GameState.room_index]
	var w := UiKit.measure(s, UiKit.F_TINY) + 12.0
	var r := Rect2(GameConfig.BASE_W - w - 8, 8, w, 14)
	draw_style_box(UiKit.box(Color(1, 1, 1, 0.28), 7, Color(1, 1, 1, 0.3), 1, false), r)
	UiKit.text_center(self, r.get_center().x, r.get_center().y + 2.2, s, UiKit.F_TINY,
		Color(0.96, 0.97, 1.0, 0.9))


# ---------------- 专武解锁进度 ----------------
func _draw_exclusive() -> void:
	var d = GameState.char_data
	if d == null:
		return
	var ready: bool = GameState.exclusive_ready()
	var w := 126.0
	var r := Rect2(GameConfig.BASE_W - w - 8, 26, w, 28)
	draw_style_box(UiKit.box(Color(1, 1, 1, 0.26 if not ready else 0.42), 7,
		Color(1, 1, 1, 0.32), 1, false), r)
	var title := "专武 · %s" % d.exclusive_name
	UiKit.text(self, r.position + Vector2(6, 10), title, UiKit.F_TINY,
		Color(0.55, 0.36, 0.06) if ready else Color(0.22, 0.28, 0.40, 0.9))
	var bar := Rect2(r.position.x + 6, r.position.y + 13, w - 12, 5)
	draw_style_box(UiKit.box(Color(0.25, 0.28, 0.38, 0.5), 2, Color(0, 0, 0, 0), 0, false), bar)
	var ratio: float = GameState.exclusive_ratio()
	if ratio > 0.01:
		draw_style_box(UiKit.box(Color(0.98, 0.78, 0.35) if ready else Color(0.55, 0.72, 0.95), 2,
			Color(0, 0, 0, 0), 0, false), Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)))
	UiKit.text(self, r.position + Vector2(6, 26),
		"已解锁 · 商店购买" if ready else GameState.exclusive_progress(),
		UiKit.F_TINY, Color(0.62, 0.40, 0.05) if ready else Color(0.30, 0.36, 0.48, 0.9))


# ---------------- 技能环（主技能 + 副武器） ----------------
func _draw_rings(p) -> void:
	var w = p.weapon
	var base := Vector2(GameConfig.BASE_W - 30.0, GameConfig.BASE_H - 32.0)
	var col: Color = GameConfig.char_color(GameState.char_id)
	if w != null:
		var cd: float = float(w.skill_cd_left)
		var total: float = 8.0
		if p.data != null:
			total = maxf(0.5, p.data.skill_cd)
		var ready: bool = cd <= 0.0
		var ratio: float = clampf(1.0 - cd / total, 0.0, 1.0)
		_ring(base, 15.0, ratio, col, "E", ready, cd, _skill_pulse, _skill_name(p))
	# 副武器
	var sub = p.sub
	if sub != null and is_instance_valid(sub):
		var sready: bool = sub.ready()
		if sready and not _sub_was_ready:
			_sub_pulse = 0.45
		_sub_was_ready = sready
		_ring(base + Vector2(-40, 2), 11.5, sub.ratio(), sub.color, "Q", sready,
			float(sub.cd_left), _sub_pulse, String(sub.display_name))


func _skill_name(p) -> String:
	if p.data != null:
		return p.data.skill_name
	return "技能"


func _ring(c: Vector2, radius: float, ratio: float, col: Color, key: String,
		ready: bool, cd: float, pulse: float, label: String) -> void:
	var glow: float = 0.0
	if ready:
		glow = 0.5 + 0.5 * sin(_t * 3.0)
	draw_circle(c, radius + 2.0, Color(1, 1, 1, 0.20))
	UiKit.ring(self, c, radius, ratio, col if ready else col.darkened(0.15), 3.0,
		Color(0.55, 0.62, 0.75, 0.55))
	if ready:
		draw_arc(c, radius + 2.0 + glow * 1.2, 0.0, TAU, 26,
			Color(col.r, col.g, col.b, 0.35 * glow), 1.2, true)
	if pulse > 0.0:
		draw_arc(c, radius + 3.0 + (0.45 - pulse) * 10.0, 0.0, TAU, 26,
			Color(1, 1, 1, pulse * 1.4), 1.4, true)
	UiKit.text_center(self, c.x, c.y + 2.0, key, UiKit.F_SMALL,
		UiKit.TEXT if ready else Color(0.30, 0.35, 0.45))
	if radius >= 14.0:
		UiKit.text_center(self, c.x, c.y + 10.0, label, UiKit.F_TINY, UiKit.TEXT_DIM)
		if not ready:
			UiKit.text_center(self, c.x, c.y - 6.0, "%.1f" % cd, UiKit.F_TINY, UiKit.TEXT_DIM)


func _draw_mode(p) -> void:
	if p.char_id != "gpt" or p.weapon == null:
		return
	var w = p.weapon
	var txt := String(w.mode_text())
	var b: String = w.buff_text() if w.has_method("buff_text") else ""
	if b != "":
		txt += "  ·  " + b
	var wd := UiKit.measure(txt, UiKit.F_TINY) + 16.0
	var r := Rect2(GameConfig.BASE_W * 0.5 - wd * 0.5, GameConfig.BASE_H - 20, wd, 14)
	draw_style_box(UiKit.box(Color(0.72, 0.62, 1.0, 0.30), 7, Color(1, 1, 1, 0.35), 1, false), r)
	UiKit.text_center(self, r.get_center().x, r.get_center().y + 2.2, txt, UiKit.F_TINY,
		Color(0.98, 0.97, 1.0, 0.95))


# ---------------- 藏品侧栏 ----------------
func _draw_upgrades() -> void:
	var x := GameConfig.BASE_W - 26.0
	var y := 60.0
	for uid in GameState.upgrades:
		var up: Upgrade = UpgradeDB.get_upgrade(uid)
		if up == null:
			continue
		var pop: float = float(_pop.get(uid, 0.0))
		var sc: float = 1.0
		if pop > 0.0:
			sc = 1.0 + 0.15 * sin(clampf(pop / 0.45, 0.0, 1.0) * PI)
		var size := 18.0 * sc
		var r := Rect2(Vector2(x + (18.0 - size) * 0.5, y + (18.0 - size) * 0.5),
			Vector2(size, size))
		draw_style_box(UiKit.box(Color(1, 1, 1, 0.55), 5, Color(1, 1, 1, 0.6), 1, false),
			r.grow(1.0))
		UiKit.draw_icon(self, up.icon_path, r)
		if pop > 0.0:
			draw_style_box(UiKit.box(Color(0, 0, 0, 0), 5, Color(1.0, 0.85, 0.4, pop * 0.9), 1, false),
				r.grow(1.0))
		y += 21.0
		if y > GameConfig.BASE_H - 54.0:
			break


func _draw_relic_desc() -> void:
	if _desc_t <= 0.0 or _desc_uid == "":
		return
	var up: Upgrade = UpgradeDB.get_upgrade(_desc_uid)
	if up == null:
		return
	var a: float = clampf(_desc_t / 0.6, 0.0, 1.0)
	var w := 148.0
	var r := Rect2(Vector2(GameConfig.BASE_W - w - 8.0,
		64.0 + minf(GameState.upgrades.size(), 8) * 21.0 + 4.0), Vector2(w, 40))
	draw_style_box(UiKit.box(Color(1, 1, 1, 0.92 * a), 8, Color(1, 1, 1, 0.8), 1, true), r)
	UiKit.text(self, r.position + Vector2(7, 13), up.title, UiKit.F_SMALL,
		Color(0.80, 0.55, 0.10, a))
	UiKit.text_block(self, r.position + Vector2(7, 26), up.desc, w - 14, UiKit.F_TINY,
		Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, a), 2)


# ---------------- Boss ----------------
func _draw_boss() -> void:
	var boss = get_tree().get_first_node_in_group("boss")
	if boss == null or not is_instance_valid(boss) or boss.dead:
		return
	var w := 220.0
	var x := (GameConfig.BASE_W - w) * 0.5
	var y := 24.0
	var r := Rect2(x - 5, y - 4, w + 10, 20)
	draw_style_box(UiKit.box(Color(1, 1, 1, 0.26), 8, Color(1, 1, 1, 0.3), 1, false), r)
	UiKit.bar(self, Rect2(x, y + 2, w, 6), boss.hp_ratio(),
		Color(0.95, 0.36, 0.52) if boss.phase < 3 else Color(0.95, 0.28, 0.28),
		Color(0.35, 0.30, 0.45, 0.5))
	for mark in [0.6, 0.25]:
		var mx: float = x + w * float(mark)
		draw_line(Vector2(mx, y + 1), Vector2(mx, y + 9), Color(1, 1, 1, 0.55), 1.0)
	UiKit.text(self, Vector2(x, y - 1), "回响聚合体 · 第 %d 阶段" % boss.phase, UiKit.F_TINY,
		Color(1, 1, 1, 0.9))
	var mv: Array = boss.current_moves() if boss.has_method("current_moves") else []
	var labels := {"ring": "环", "fan": "扇", "charge": "冲", "homing": "追",
		"summon": "召", "laser": "激", "spiral": "旋", "mine": "雷"}
	for i in mv.size():
		UiKit.text(self, Vector2(x + w - 14.0 - i * 13.0, y + 17),
			String(labels.get(String(mv[i]), "?")), UiKit.F_TINY, Color(1, 0.92, 0.85, 0.75))
	if float(boss.telegraph) > 0.0:
		var a: float = clampf(float(boss.telegraph) / 0.75, 0.0, 1.0)
		UiKit.text_center(self, GameConfig.BASE_W * 0.5, y + 24, "阶段转换！", UiKit.F_SMALL,
			Color(1.0, 0.55, 0.55, a))


# ---------------- 挑战 ----------------
func _draw_challenge() -> void:
	if _challenge_title == "":
		return
	var txt := "挑战 · %s" % _challenge_desc
	var size := UiKit.F_TINY + int(round(2.0 * _challenge_pop))
	var col := UiKit.GOLD if _challenge_done else Color(1, 1, 1, 0.78)
	var w := UiKit.measure(txt, size) + 18.0
	var r := Rect2(GameConfig.BASE_W * 0.5 - w * 0.5, 4, w, 12)
	draw_style_box(UiKit.box(Color(0.10, 0.16, 0.28, 0.42), 6, Color(1, 1, 1, 0.2), 1, false), r)
	UiKit.text_center(self, r.get_center().x, r.get_center().y + 2.0, txt, size, col)


func _draw_toasts() -> void:
	if toast_time > 0.0:
		var a: float = clampf(toast_time, 0.0, 1.0)
		var w := UiKit.measure(toast_text, UiKit.F_H3) + 24.0
		var r := Rect2(GameConfig.BASE_W * 0.5 - w * 0.5, GameConfig.BASE_H * 0.30, w, 20)
		draw_style_box(UiKit.box(Color(1, 1, 1, 0.90 * a), 10, Color(1, 1, 1, 0.9 * a), 1, true), r)
		UiKit.text_center(self, r.get_center().x, r.get_center().y + 4.0, toast_text,
			UiKit.F_H3, Color(0.18, 0.26, 0.40, a))
	if combo_time > 0.0:
		var a2: float = clampf(combo_time, 0.0, 1.0)
		UiKit.text_center(self, GameConfig.BASE_W * 0.5, GameConfig.BASE_H * 0.38,
			combo_text, UiKit.F_SMALL, Color(0.95, 0.75, 0.25, a2))


func _draw_low_flash() -> void:
	var a: float = clampf(_low_flash / 0.7, 0.0, 1.0) * 0.45
	for i in 5:
		var d: float = 8.0 + i * 6.0
		var aa: float = a * (1.0 - float(i) / 5.0)
		draw_rect(Rect2(0, 0, GameConfig.BASE_W, d), Color(0.9, 0.1, 0.15, aa))
		draw_rect(Rect2(0, GameConfig.BASE_H - d, GameConfig.BASE_W, d), Color(0.9, 0.1, 0.15, aa))
		draw_rect(Rect2(0, 0, d, GameConfig.BASE_H), Color(0.9, 0.1, 0.15, aa))
		draw_rect(Rect2(GameConfig.BASE_W - d, 0, d, GameConfig.BASE_H), Color(0.9, 0.1, 0.15, aa))
