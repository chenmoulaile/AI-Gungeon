extends Control
## HUD（v0.7 P2）：像素终端风。左上 32 头像 + 10 段血条，右上楼层 + 8×6 小地图，
## 左下金币/专武进度，右下武器图标 + Q/E 像素冷却块。中间 70% 留给弹幕。

var toast_text: String = ""
var toast_time: float = 0.0
var combo_text: String = ""
var combo_time: float = 0.0

var _pop: Dictionary = {}
var _desc_uid: String = ""
var _desc_t: float = 0.0
var _low_flash: float = 0.0
var _excl_last: int = -1
var _excl_flash: float = 0.0
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
var _coin_pop: float = 0.0
var _last_coins: int = 0
var _t: float = 0.0


func _ready() -> void:
	add_to_group("hud")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.combo_activated.connect(_on_combo_activated)
	GameState.upgrades_changed.connect(_on_upgrades_changed)
	GameState.synergy_activated.connect(_on_synergy)
	GameState.low_health_triggered.connect(_on_low_health)
	ChallengeManager.challenge_changed.connect(_on_challenge)
	ChallengeManager.completed.connect(_on_challenge_done)
	_coins_shown = float(GameState.coins)
	_last_coins = GameState.coins


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
	_coin_pop = maxf(0.0, _coin_pop - delta)
	if GameState.coins != _last_coins:
		_last_coins = GameState.coins
		_coin_pop = 0.25
	if absf(_coins_shown - float(GameState.coins)) > 0.01:
		_coins_shown = move_toward(_coins_shown, float(GameState.coins),
			maxf(1.0, absf(float(GameState.coins) - _coins_shown) * 8.0) * delta)
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
		_draw_talent(p)
		_draw_weapon(p)
		_draw_mode(p)
	_draw_upgrades()
	_draw_relic_desc()
	_draw_boss()
	_draw_challenge()
	_draw_toasts()


# ---------------- 左上：头像 + 分段血条 ----------------
func _draw_hearts() -> void:
	var ratio: float = clampf(float(GameState.hp) / maxf(1.0, float(GameState.max_hp)), 0.0, 1.0)
	var panel := Rect2(8, 6, 196, 48)
	UiKit.frame(self, panel, Color(0.06, 0.09, 0.15, 0.90), UiKit.BORDER, UiKit.BORDER_HI, true)

	var av := UiKit.icon("res://assets/portraits/%s_pixel_avatar.png" % GameState.char_id)
	var ar := Rect2(14, 12, 32, 32)
	UiKit.inset(self, ar.grow(1), UiKit.VOID, UiKit.BORDER)
	if av != null:
		draw_texture_rect(av, ar, false)

	var name_txt: String = String(GameState.char_data.display_name) if GameState.char_data != null else "AI"
	UiKit.text(self, Vector2(52, 21), name_txt, 12, UiKit.TEXT)

	var bar := Rect2(52, 25, 144, 8)
	var col := UiKit.SUCCESS
	if ratio <= 0.3:
		col = UiKit.DANGER
	elif ratio <= 0.6:
		col = UiKit.GOLD
	UiKit.bar(self, bar, ratio, col)

	UiKit.text(self, Vector2(52, 46), "HP %d/%d" % [GameState.hp, GameState.max_hp], 12,
		UiKit.TEXT_DIM)
	if ratio <= 0.3 and fmod(_t, 0.6) < 0.3:
		UiKit.corner_brackets(self, bar.grow(2), UiKit.DANGER, 3)


# ---------------- 左上：角色天赋 ----------------
## DeepSeek 蓝条 Token / GPT 上下文窗口 / Claude 细致阅读
func _draw_talent(p) -> void:
	var r := Rect2(8, 58, 196, 18)
	var title := "TALENT"
	var value := ""
	var col := UiKit.CYAN
	var ratio := 1.0
	match String(p.char_id):
		"deepseek":
			title = "TOKEN"
			ratio = float(p.token_ratio())
			value = "%d/%d" % [int(round(float(p.token))), int(p.token_max)]
			col = UiKit.CYAN
			if ratio <= 0.2:
				col = UiKit.DANGER if fmod(_t, 0.5) < 0.25 else UiKit.GOLD
		"gpt":
			title = "CONTEXT"
			ratio = clampf(float(p.tokens) / 20.0, 0.0, 1.0)
			value = "FULL" if int(p.tokens) >= 20 else "%d/20" % int(p.tokens)
			col = UiKit.PURPLE
		_:
			title = "TALENT"
			ratio = 1.0
			value = "细致阅读"
			col = UiKit.GOLD
	UiKit.frame(self, r, Color(0.06, 0.09, 0.15, 0.90), UiKit.BORDER, Color(0, 0, 0, 0), false)
	UiKit.text(self, r.position + Vector2(6, 13), title, 12, col)
	UiKit.bar(self, Rect2(r.position.x + 60, r.position.y + 6, 76, 7), ratio, col)
	UiKit.text_right(self, r.end.x - 6, r.position.y + 13, value, 12, col)


# ---------------- 左下：金币 ----------------
func _draw_coins() -> void:
	var r := Rect2(8, 328, 96, 22)
	UiKit.frame(self, r, Color(0.06, 0.09, 0.15, 0.90), UiKit.BORDER, UiKit.BORDER_HI, true)
	# 金币图标 12×12：外圈 + 高光，硬边像素
	var c := Vector2(r.position.x + 10, r.position.y + 5)
	draw_rect(Rect2(c, Vector2(12, 12)), UiKit.GOLD)
	draw_rect(Rect2(c + Vector2(3, 3), Vector2(6, 6)), Color("#B8860B"))
	draw_rect(Rect2(c + Vector2(2, 2), Vector2(2, 2)), Color("#FFF3C4"))
	var num := str(int(round(_coins_shown)))
	UiKit.text(self, Vector2(r.position.x + 28, r.position.y + 15), num, 12,
		UiKit.GOLD if _coin_pop > 0.0 else UiKit.TEXT)
	UiKit.text(self, Vector2(r.position.x + 57, r.position.y + 15), "COIN", 12,
		Color(0.45, 0.5, 0.6))


# ---------------- 右上：楼层 + 小地图 ----------------
func _draw_room_info() -> void:
	var s := "B%d - %02d" % [GameState.floor_index, GameState.room_index]
	UiKit.text_right(self, 632, 20, s, 12, UiKit.CYAN)
	# 小地图 48×32：3×2 房间格
	var mr := Rect2(584, 24, 48, 32)
	UiKit.frame(self, mr, UiKit.VOID, UiKit.BORDER, Color(0, 0, 0, 0), false)
	var total := 5
	for i in total:
		var gx := int(i % 3)
		var gy := int(i / 3)
		var cell := Rect2(mr.position + Vector2(2 + gx * 15, 2 + gy * 15), Vector2(13, 13))
		var here: bool = (i + 1) == GameState.room_index
		draw_rect(cell, UiKit.RAISED if here else Color(0.10, 0.13, 0.21))
		if here:
			draw_rect(cell, UiKit.CYAN, false, 1.0)
			draw_rect(Rect2(cell.get_center() - Vector2(1, 1), Vector2(3, 3)), UiKit.WHITE)
		else:
			draw_rect(cell, UiKit.BORDER, false, 1.0)


# ---------------- 左下：专武解锁 ----------------
func _draw_exclusive() -> void:
	var d = GameState.char_data
	if d == null:
		return
	var ready: bool = GameState.exclusive_ready()
	var r := Rect2(8, 300, 156, 24)
	UiKit.frame(self, r, Color(0.06, 0.09, 0.15, 0.86), UiKit.BORDER, Color(0, 0, 0, 0), false)
	var pv: int = int(round(GameState.exclusive_ratio() * 100.0))
	if pv != _excl_last:
		_excl_last = pv
		_excl_flash = 0.6
	_excl_flash = maxf(0.0, _excl_flash - get_process_delta_time())
	var title := "%s %s" % [d.exclusive_name, "OK" if ready else GameState.exclusive_progress()]
	UiKit.text(self, r.position + Vector2(6, 12), UiKit.fit(title, r.size.x - 12, 12), 12,
		UiKit.GOLD if ready or _excl_flash > 0.0 else UiKit.TEXT_DIM)
	var bar := Rect2(r.position.x + 6, r.position.y + 17, r.size.x - 12, 4)
	draw_rect(bar, UiKit.VOID)
	var ratio: float = GameState.exclusive_ratio()
	var segs := 24
	var lit := int(round(ratio * segs))
	for i in segs:
		if i < lit:
			draw_rect(Rect2(bar.position.x + i * 6, bar.position.y, 5, 4),
				UiKit.GOLD if ready else UiKit.CYAN)


# ---------------- 右下：武器 + 键帽冷却 ----------------
func _draw_weapon(p) -> void:
	var r := Rect2(396, 312, 236, 42)
	UiKit.frame(self, r, Color(0.06, 0.09, 0.15, 0.88), UiKit.BORDER, UiKit.BORDER_HI, true)
	var w = p.weapon
	var icon_rect := Rect2(r.position + Vector2(6, 9), Vector2(24, 24))
	if not UiKit.draw_icon(self, "res://assets/icons/weapons/%s.png" % GameState.char_id, icon_rect):
		_draw_gun_placeholder(icon_rect, GameConfig.char_color(GameState.char_id))
	var nm := "武器"
	if w != null and GameState.char_data != null:
		nm = String(GameState.char_data.weapon_name)
	UiKit.text(self, Vector2(r.position.x + 36, r.position.y + 15), UiKit.fit(nm, 118, 12),
		12, UiKit.TEXT)
	var hint := "左键射击 · Q 副武器"
	var hint_col := Color(0.42, 0.48, 0.58)
	match String(p.char_id):
		"deepseek":
			hint = "大白饭 -7 · 铁盆"
		"gpt":
			hint = "龙息 · 思维链"
		"claude":
			hint = "光束 · 对齐"
	if float(p.charge_ratio) > 0.0:
		hint = "铁盆蓄力 %d%%" % int(round(float(p.charge_ratio) * 100.0))
		hint_col = UiKit.GOLD
	UiKit.text(self, Vector2(r.position.x + 36, r.position.y + 31),
		UiKit.fit(hint, 118, 12), 12, hint_col)

	# E / Q：像素键帽 + 3px 冷却条（8 段散点环放大后像噪点，已弃用）
	var e_c := Vector2(r.position.x + 170, r.position.y + 16)
	var q_c := Vector2(r.position.x + 208, r.position.y + 16)
	if w != null:
		var cd: float = float(w.skill_cd_left)
		var total: float = 8.0
		if p.data != null:
			total = maxf(0.5, p.data.skill_cd)
		_key(e_c, clampf(1.0 - cd / total, 0.0, 1.0),
			GameConfig.char_color(GameState.char_id), "E", cd <= 0.0, _skill_pulse)
	var sub = p.sub
	if sub != null and is_instance_valid(sub):
		var sready: bool = sub.ready()
		if sready and not _sub_was_ready:
			_sub_pulse = 0.45
		_sub_was_ready = sready
		_key(q_c, sub.ratio(), sub.color, "Q", sready, _sub_pulse)
	else:
		_key(q_c, 0.0, Color(0.4, 0.45, 0.55), "Q", false, 0.0)


## 单个键帽：20×20 硬框 + 字母 + 底部 16×3 冷却条；就绪时白色角括号脉冲
func _key(c: Vector2, ratio: float, col: Color, key: String, ready: bool,
		pulse: float) -> void:
	var cap := Rect2((c - Vector2(10, 10)).round(), Vector2(20, 20))
	UiKit.frame(self, cap, Color(0.09, 0.13, 0.21) if ready else Color(0.07, 0.09, 0.14),
		col if ready else UiKit.BORDER, Color(0, 0, 0, 0), false)
	UiKit.text_center(self, c.x, c.y + 4.0, key, 12,
		UiKit.WHITE if ready else UiKit.TEXT_DIM)
	var bar := Rect2(cap.position.x + 2, cap.end.y + 2, 16, 3)
	draw_rect(bar, UiKit.VOID)
	var lit: int = int(round(clampf(ratio, 0.0, 1.0) * 16.0))
	if lit > 0:
		draw_rect(Rect2(bar.position, Vector2(lit, 3)),
			col if ready else col.darkened(0.45))
	if ready and pulse > 0.0:
		UiKit.corner_brackets(self, cap.grow(1), Color(1, 1, 1, pulse * 1.2), 3)


func _draw_gun_placeholder(rect: Rect2, accent: Color) -> void:
	UiKit.inset(self, rect, UiKit.VOID, UiKit.BORDER)
	var c := rect.position
	draw_rect(Rect2(c + Vector2(4, 7), Vector2(13, 4)), accent)
	draw_rect(Rect2(c + Vector2(14, 10), Vector2(4, 7)), accent)
	draw_rect(Rect2(c + Vector2(7, 11), Vector2(5, 3)), accent.darkened(0.25))


func _draw_mode(p) -> void:
	if p.char_id != "gpt" or p.weapon == null:
		return
	var w = p.weapon
	var txt := String(w.mode_text())
	var b: String = w.buff_text() if w.has_method("buff_text") else ""
	if b != "":
		txt += "  ·  " + b
	var wd := UiKit.measure(txt, 12) + 16.0
	var r := Rect2(GameConfig.BASE_W * 0.5 - wd * 0.5, 294, wd, 18)
	UiKit.frame(self, r, Color(0.16, 0.12, 0.26, 0.86), UiKit.PURPLE, Color(0, 0, 0, 0), false)
	UiKit.text_center(self, r.get_center().x, r.get_center().y + 4.0, txt, 12, UiKit.WHITE)


# ---------------- 右侧：藏品 ----------------
func _draw_upgrades() -> void:
	var x := GameConfig.BASE_W - 26.0
	var y := 64.0
	for uid in GameState.upgrades:
		var up: Upgrade = UpgradeDB.get_upgrade(uid)
		if up == null:
			continue
		var pop: float = float(_pop.get(uid, 0.0))
		var r := Rect2(x, y, 18, 18)
		UiKit.frame(self, r, UiKit.PANEL, UiKit.GOLD if pop > 0.0 else UiKit.BORDER,
			Color(0, 0, 0, 0), false)
		UiKit.draw_icon(self, up.icon_path, r.grow(-1))
		y += 21.0
		if y > GameConfig.BASE_H - 74.0:
			break


func _draw_relic_desc() -> void:
	if _desc_t <= 0.0 or _desc_uid == "":
		return
	var up: Upgrade = UpgradeDB.get_upgrade(_desc_uid)
	if up == null:
		return
	var a: float = clampf(_desc_t / 0.6, 0.0, 1.0)
	var w := 164.0
	var r := Rect2(GameConfig.BASE_W - w - 8.0,
		64.0 + minf(GameState.upgrades.size(), 8) * 21.0 + 4.0, w, 44)
	UiKit.frame(self, r, Color(0.06, 0.09, 0.15, 0.94 * a), UiKit.GOLD, UiKit.BORDER, true)
	UiKit.text(self, r.position + Vector2(7, 13), up.title, 12, Color(1, 0.82, 0.4, a))
	UiKit.text_block(self, r.position + Vector2(7, 27), up.desc, w - 14, 12,
		Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, a), 2)


# ---------------- Boss ----------------
func _draw_boss() -> void:
	var boss = get_tree().get_first_node_in_group("boss")
	if boss == null or not is_instance_valid(boss) or boss.dead:
		return
	var w := 240.0
	var x := (GameConfig.BASE_W - w) * 0.5
	var y := 16.0
	UiKit.text(self, Vector2(x, y + 10), "回响聚合体 · 第 %d 阶段" % boss.phase, 12, UiKit.TEXT)
	# 2 段血条，段间 2px
	var seg_w := (w - 2) * 0.5
	for i in 2:
		UiKit.bar(self, Rect2(x + i * (seg_w + 2), y + 16, seg_w, 8), boss.hp_ratio(),
			UiKit.DANGER if boss.phase >= 2 else Color("#E45C7A"), UiKit.VOID)
	for mark in [0.6, 0.25]:
		var mx: float = x + w * float(mark)
		draw_line(Vector2(mx, y + 16), Vector2(mx, y + 24), UiKit.DEEP, 1.0)
	var mv: Array = boss.current_moves() if boss.has_method("current_moves") else []
	var labels := {"ring": "环", "fan": "扇", "charge": "冲", "homing": "追",
		"summon": "召", "laser": "激", "spiral": "旋", "mine": "雷"}
	for i in mv.size():
		UiKit.text(self, Vector2(x + w - 14.0 - i * 15.0, y + 34),
			String(labels.get(String(mv[i]), "?")), 12, Color(1, 0.92, 0.85, 0.75))
	if float(boss.telegraph) > 0.0:
		var a: float = clampf(float(boss.telegraph) / 0.75, 0.0, 1.0)
		UiKit.text_center(self, GameConfig.BASE_W * 0.5, y + 46, "阶段转换！", 12,
			Color(1.0, 0.36, 0.47, a))


# ---------------- 挑战横幅 ----------------
func _draw_challenge() -> void:
	if _challenge_title == "":
		return
	var txt := "挑战 · %s" % _challenge_desc
	var col := UiKit.GOLD if _challenge_done else UiKit.TEXT_DIM
	var w := UiKit.measure(txt, 12) + 18.0
	var r := Rect2(GameConfig.BASE_W * 0.5 - w * 0.5, 66, w, 18)
	UiKit.frame(self, r, Color(0.06, 0.09, 0.15, 0.86),
		UiKit.GOLD if _challenge_done else UiKit.BORDER, Color(0, 0, 0, 0), false)
	UiKit.text_center(self, r.get_center().x, r.get_center().y + 4.0, txt, 12, col)
	if _challenge_done and _challenge_pop > 0.0:
		UiKit.corner_brackets(self, r.grow(1), Color(1, 1, 1, _challenge_pop), 4)


# ---------------- Toast / 组合 ----------------
func _draw_toasts() -> void:
	if toast_time > 0.0:
		var a: float = clampf(toast_time, 0.0, 1.0)
		var w := UiKit.measure(toast_text, 12) + 24.0
		var r := Rect2(GameConfig.BASE_W * 0.5 - w * 0.5, 96, w, 22)
		UiKit.frame(self, r, Color(0.06, 0.09, 0.15, 0.94 * a), UiKit.CYAN, UiKit.BORDER, true)
		UiKit.text_center(self, r.get_center().x, r.get_center().y + 4.0, toast_text, 12,
			Color(1, 1, 1, a))
	if combo_time > 0.0:
		var a2: float = clampf(combo_time, 0.0, 1.0)
		UiKit.text_center(self, GameConfig.BASE_W * 0.5, 130, combo_text, 12,
			Color(1.0, 0.82, 0.4, a2))


# ---------------- 低血：4×4 抖动红边 ----------------
func _draw_low_flash() -> void:
	var a: float = clampf(_low_flash / 0.7, 0.0, 1.0)
	var col := Color(0.9, 0.12, 0.22, 0.18 * a)
	var band := 6
	UiKit.dither_rect(self, Rect2(0, 0, GameConfig.BASE_W, band), col, 2)
	UiKit.dither_rect(self, Rect2(0, GameConfig.BASE_H - band, GameConfig.BASE_W, band), col, 2)
	UiKit.dither_rect(self, Rect2(0, 0, band, GameConfig.BASE_H), col, 2)
	UiKit.dither_rect(self, Rect2(GameConfig.BASE_W - band, 0, band, GameConfig.BASE_H), col, 2)
