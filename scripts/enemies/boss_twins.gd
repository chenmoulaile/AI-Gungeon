extends "res://scripts/enemies/boss.gd"
## Boss B3「双生回响」：两个核心共享一条血条
## 每次出招在左右核心之间交替；第 3 阶段加入双核心交叉环形弹

const POOLS_TWIN := {
	1: ["fan", "ring", "homing"],
	2: ["fan", "ring", "homing", "spiral"],
	3: ["ring", "fan", "homing", "spiral", "cross"],
}

const CORE_OFFSET := 34.0

var _side: float = -1.0
var _aim_origin: Vector2 = Vector2.ZERO


func _setup() -> void:
	boss_key = "twins"
	display_name = "双生回响"
	subtitle = "TWIN ECHO"
	intro_lines = [
		"同一段推理被复制了两次，左边和右边都在等你犯错。",
		"它们共享一副身体，却坚持轮流说话。",
		"别盯着一个核心看，另一边的子弹已经上路了。",
	]
	accent_color = Color("#ff7a4d")
	light_color = Color(1.0, 0.42, 0.22)
	max_hp = 460.0 * GameState.enemy_scale()
	hp = max_hp
	speed = 34.0
	# 双核心整体较宽，碰撞半径要覆盖到两侧核心边缘
	radius = 48.0
	contact_damage = 2
	coin_value = 50
	_setup_common()


func _roll_moves() -> void:
	for p in [1, 2, 3]:
		var pool: Array = POOLS_TWIN[p].duplicate()
		SeedManager.shuffle(pool)
		moves[p] = [pool[0], pool[1]]
	move_idx = 0


func _core_pos(side: float) -> Vector2:
	return global_position + Vector2(CORE_OFFSET * side, sin(t * 2.0 + side) * 2.0)


func _next_side() -> float:
	_side = -_side
	return _side


## 覆盖基类的枪口坐标：每次出招前由 _do_move 指定当前核心
func shoot_at(dir: Vector2, speed: float = 155.0, bullet_radius: float = 3.8,
		homing: float = 0.0, homing_time: float = 0.0) -> void:
	var d := dir.normalized()
	var origin := _aim_origin + d * 6.0
	shoot_from(origin, d, speed, bullet_radius, homing, homing_time)


func _do_move(dir: Vector2) -> void:
	_aim_origin = _core_pos(_next_side())
	var list := current_moves()
	if list.is_empty():
		_attack_ring()
		return
	var mv: String = list[move_idx % list.size()]
	move_idx += 1
	match mv:
		"ring":
			_attack_ring()
		"fan":
			_attack_fan(dir)
		"homing":
			_attack_homing(dir)
		"spiral":
			spiral_left = 20
			spiral_t = 0.0
			spiral_angle = dir.angle()
			Sfx.play("warn_high", -2.0, 0.9)
			Sfx.play("spiral_fire", -6.0, 1.0)
		"cross":
			_attack_cross()
		_:
			_attack_ring()


## 第 3 阶段：左右核心同时甩出反向错位的双环
func _attack_cross() -> void:
	var n := 14
	for side in [-1.0, 1.0]:
		var o := _core_pos(side)
		var off := 0.0 if side < 0.0 else TAU / float(n * 2)
		for i in n:
			var a := TAU * float(i) / float(n) + off + ring_angle
			var d := Vector2(cos(a), sin(a))
			shoot_from(o + d * 8.0, d, 175.0, 4.0)
	ring_angle += 0.16
	Sfx.play("hit", -7.0, 0.6)
	GameFeel.screen_shake(0.1)


## 追踪弹从当前核心出发
func _spawn_homing(a: Vector2) -> void:
	var b = GameFeel.get_bullet()
	if b == null:
		return
	b.friendly = false
	b.dir = a
	b.speed = 120.0
	b.damage = 1.0
	b.radius = 4.6
	b.color = Color("#ffa24d")
	b.life = 6.0
	b.homing = 2.6
	b.homing_time = 3.0
	b.destructible = true
	b.pierce = 0
	b.gen = 0
	b.trail = true
	b.crit = false
	b.tier = "medium"
	b.global_position = _aim_origin + a * 6.0
	b.prepare()


# ---------------- 绘制 ----------------
## 左右两颗晶体 + 中间的数据脉冲；血条是共享的
func _draw_body() -> void:
	var c := accent
	if phase == 2:
		c = Color("#ff9066")
	elif phase >= 3:
		c = Color("#ff5a4a")
	var edge := Color("#1E0A06")
	var half := CORE_OFFSET

	# 共享光环：把两颗核心框成一个整体
	for i in 26:
		var a := TAU * float(i) / 26.0 + t * 0.45
		var px := roundf(cos(a) * 62.0 * 0.5) * 2.0
		var py := roundf(sin(a) * 62.0 * 0.5) * 2.0
		draw_rect(Rect2(px - 1.0, py - 1.0, 2.0, 2.0), Color(c.r, c.g, c.b, 0.34))

	# 连接束：两核心之间的像素脉冲
	var pulse := 0.42 + 0.30 * sin(t * 6.0)
	for x in range(-int(half) + 4, int(half) - 3, 4):
		var py := roundf(sin(t * 8.0 + float(x) * 0.3) * 2.0)
		draw_rect(Rect2(float(x) - 1.0, py - 1.0, 2.0, 2.0),
			Color(c.r, c.g, c.b, pulse))
	# 中心联接核心
	draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), c.lightened(0.38))
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), Color("#FFF1E8"))

	# 两颗核心
	for s in [-1.0, 1.0]:
		var cx: float = half * s
		var widths := [6.0, 12.0, 20.0, 28.0, 30.0, 30.0, 28.0, 20.0, 12.0, 6.0]
		var rects: Array = []
		for i in widths.size():
			var w := float(widths[i])
			rects.append(Rect2(cx - w * 0.5, -20.0 + float(i) * 4.0, w, 4.0))
		_px_rects(rects, c.darkened(0.22 if s < 0.0 else 0.34), edge)
		# 切面
		draw_rect(Rect2(cx - 10.0, -14.0, 8.0, 4.0), c.lightened(0.35))
		draw_rect(Rect2(cx + 2.0, 6.0, 8.0, 4.0), c.darkened(0.40))
		# 眼：一条横缝
		_px_rects([
			Rect2(cx - 5.0, -5.0, 10.0, 2.0),
			Rect2(cx - 7.0, -3.0, 14.0, 5.0),
			Rect2(cx - 5.0, 2.0, 10.0, 2.0),
		], Color("#FFF1E8"), edge)
		draw_rect(Rect2(cx - 4.0, -2.0, 8.0, 2.0), Color("#3A0E06"))
		draw_rect(Rect2(cx - 4.0, -2.0, 2.0, 1.0), Color(1, 1, 1, 0.8))

	# 第 3 阶段：外圈交叉脉冲
	if phase >= 3:
		var rr := radius + 12.0
		for i in 20:
			var a := TAU * float(i) / 20.0 + t * 1.4
			var p := Vector2(cos(a), sin(a)) * rr
			draw_rect(Rect2(roundf(p.x * 0.5) * 2.0 - 1.0,
				roundf(p.y * 0.5) * 2.0 - 1.0, 2.0, 2.0),
				Color(c.r, c.g, c.b, 0.5))

	if telegraph > 0.0:
		var k: float = 1.0 - telegraph / 0.75
		var warn := Color(1.0, 0.35, 0.4, 0.55 * (1.0 - k * 0.6))
		var wr := radius + 14.0 + k * 24.0
		for s in [-1.0, 1.0]:
			var cx: float = half * s
			for i in 16:
				var a := TAU * float(i) / 16.0
				var px := roundf((cx + cos(a) * wr) * 0.5) * 2.0
				var py := roundf(sin(a) * wr * 0.5) * 2.0
				draw_rect(Rect2(px - 2.0, py - 2.0, 4.0, 4.0), warn)
