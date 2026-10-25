extends "res://scripts/enemies/boss.gd"
## Boss B2「镜像回声」：周期展开镜面护盾
## 盾期完全免伤，并把来袭的玩家子弹反射成敌方弹打回玩家方向
## 招式池复用基类的扇/环/激光/雷/螺旋，只是配色与轮廓不同

const POOLS_MIRROR := {
	1: ["fan", "ring", "laser"],
	2: ["fan", "ring", "laser", "mine"],
	3: ["ring", "fan", "laser", "mine", "spiral"],
}

var shield_cd: float = 3.0
var shield_t: float = 0.0
var reflect_flash: float = 0.0
var spin: float = 0.0


func _setup() -> void:
	boss_key = "mirror"
	display_name = "镜像回声"
	subtitle = "MIRROR ECHO"
	intro_lines = [
		"它把你的火力原样折了回来，像一面会记仇的镜子。",
		"镜盾亮起时，任何子弹都只会成为它的回声。",
		"等镜面碎裂的那半秒，再扣扳机。",
	]
	accent_color = Color("#59d6ff")
	light_color = Color(0.30, 0.80, 1.0)
	max_hp = 160.0 * GameState.enemy_scale()
	hp = max_hp
	speed = 30.0
	radius = 27.0
	contact_damage = 2
	coin_value = 28
	_setup_common()


func _roll_moves() -> void:
	for p in [1, 2, 3]:
		var pool: Array = POOLS_MIRROR[p].duplicate()
		SeedManager.shuffle(pool)
		moves[p] = [pool[0], pool[1]]
	move_idx = 0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead:
		return
	spin += delta
	reflect_flash = maxf(0.0, reflect_flash - delta)
	if shield_t > 0.0:
		shield_t -= delta
		if shield_t <= 0.0:
			shield_cd = 4.6
	else:
		shield_cd -= delta
		if shield_cd <= 0.0:
			_open_shield()


func _open_shield() -> void:
	shield_t = 1.6
	GameFeel.screen_flash(Color(0.55, 0.9, 1.0), 0.10, 0.25)
	Sfx.play("skill", -3.0, 1.3)
	GameFeel.burst(global_position, Color(0.55, 0.92, 1.0), 12, 150.0, 0.32)
	GameFeel.screen_shake(0.16)


func take_damage(dmg: float, dir: Vector2 = Vector2.ZERO, tier: String = "medium",
		crit: bool = false, tag: String = "") -> void:
	if dead:
		return
	if shield_t > 0.0:
		reflect_flash = 0.18
		_reflect(dir)
		return
	super.take_damage(dmg, dir, tier, crit, tag)


## 把这一发“折回去”：朝玩家当前位置发射一颗青色敌弹
func _reflect(dir: Vector2) -> void:
	var target := dir
	if player != null and is_instance_valid(player):
		target = player.global_position - global_position
	if target.length() < 0.01:
		target = Vector2.RIGHT
	var d := target.normalized()
	var b = GameFeel.get_bullet()
	if b != null:
		b.friendly = false
		b.dir = d
		b.speed = 205.0
		b.damage = 1.0
		b.radius = 4.4
		b.color = Color("#8BE9FF") if not Settings.high_contrast else Color("#00E5FF")
		b.life = 3.2
		b.homing = 0.0
		b.homing_time = 0.0
		b.pierce = 0
		b.gen = 0
		b.trail = true
		b.crit = false
		b.tier = "medium"
		b.global_position = global_position + d * (radius + 8.0)
		b.prepare()
	Sfx.play_at("clang", global_position, -2.0, 1.35)
	GameFeel.burst(global_position, Color(0.6, 0.95, 1.0), 10, 170.0, 0.28)
	GameFeel.hit_stop(0.03, 0.05)
	if GameState.bullets_root != null and is_instance_valid(GameState.bullets_root):
		var tg = TelegraphScript.new()
		GameState.bullets_root.add_child(tg)
		tg.setup(global_position, global_position + d * 150.0, 0.16,
			Color(0.55, 0.92, 1.0, 0.55), 1.0)


# ---------------- 绘制 ----------------
## 镜面菱形 + 反向旋转碎片环；盾期额外一圈八边形像素镜盾
func _draw_body() -> void:
	var c := accent
	if phase == 2:
		c = Color("#7FE1FF")
	elif phase >= 3:
		c = Color("#B9F3FF")
	var edge := Color("#041821")

	# 外圈 3 圈像素碎片，正反交替旋转
	for k in 3:
		var rr: float = radius + 7.0 + k * 5.0
		var count: int = 12 + k * 4
		var sgn: float = 1.0 if k % 2 == 0 else -0.7
		var a_ring: float = 0.55 - k * 0.10
		var sz: float = 3.0 if k == 0 else 2.0
		for i in count:
			var a := spin * 0.7 * sgn + TAU * float(i) / float(count)
			var px := roundf(cos(a) * rr * 0.5) * 2.0
			var py := roundf(sin(a) * rr * 0.5) * 2.0
			draw_rect(Rect2(px - sz * 0.5, py - sz * 0.5, sz, sz),
				Color(c.r, c.g, c.b, a_ring))

	# 镜面菱形本体
	var widths := [6.0, 12.0, 20.0, 30.0, 38.0, 44.0, 44.0, 38.0, 30.0, 20.0, 12.0, 6.0]
	var rects: Array = []
	for i in widths.size():
		var w := float(widths[i])
		rects.append(Rect2(-w * 0.5, -24.0 + float(i) * 4.0, w, 4.0))
	_px_rects(rects, c.darkened(0.30), edge)

	# 左亮右暗：镜面高光
	draw_rect(Rect2(-18.0, -20.0, 12.0, 4.0), c.lightened(0.45))
	draw_rect(Rect2(-22.0, -16.0, 10.0, 4.0), c.lightened(0.28))
	draw_rect(Rect2(-24.0, -12.0, 8.0, 8.0), c.lightened(0.42))
	draw_rect(Rect2(-16.0, -4.0, 6.0, 8.0), c.lightened(0.20))
	draw_rect(Rect2(10.0, -12.0, 12.0, 4.0), c.darkened(0.42))
	draw_rect(Rect2(14.0, -8.0, 8.0, 8.0), c.darkened(0.46))
	draw_rect(Rect2(8.0, 4.0, 10.0, 4.0), c.darkened(0.38))
	# 中缝
	draw_rect(Rect2(-1.0, -22.0, 2.0, 44.0), c.lightened(0.55))

	# 竖瞳
	_px_rects([
		Rect2(-8.0, -8.0, 16.0, 2.0),
		Rect2(-10.0, -6.0, 20.0, 10.0),
		Rect2(-8.0, 4.0, 16.0, 2.0),
	], Color("#F2FDFF"), edge)
	draw_rect(Rect2(-2.0, -7.0, 4.0, 10.0), Color("#062430"))
	draw_rect(Rect2(-1.0, -6.0, 1.0, 2.0), Color(1, 1, 1, 0.9))

	# 镜盾：亮青八边形像素点阵
	if shield_t > 0.0:
		var sa := clampf(shield_t / 1.6, 0.0, 1.0)
		var rr := radius + 16.0
		for i in 28:
			var ang := TAU * float(i) / 28.0 + spin * 2.2
			var dv := Vector2(cos(ang), sin(ang))
			# 把方向量化成 45° 台阶，得到硬边八边形
			var oct := Vector2(roundf(dv.x * 1.25) / 1.25,
				roundf(dv.y * 1.25) / 1.25).normalized()
			var p := oct * rr
			var px := roundf(p.x * 0.5) * 2.0
			var py := roundf(p.y * 0.5) * 2.0
			var sz := 4.0 if i % 2 == 0 else 2.0
			draw_rect(Rect2(px - sz * 0.5, py - sz * 0.5, sz, sz),
				Color(0.62, 0.95, 1.0, 0.35 + 0.45 * sa))

	# 反射瞬间的白闪碎片
	if reflect_flash > 0.0:
		var fa := reflect_flash / 0.18
		for i in 16:
			var a := TAU * float(i) / 16.0
			var p := Vector2(cos(a), sin(a)) * (radius + 6.0)
			draw_rect(Rect2(roundf(p.x * 0.5) * 2.0 - 2.0,
				roundf(p.y * 0.5) * 2.0 - 2.0, 4.0, 4.0),
				Color(1, 1, 1, 0.55 * fa))

	if telegraph > 0.0:
		var k: float = 1.0 - telegraph / 0.75
		var warn := Color(1.0, 0.35, 0.4, 0.55 * (1.0 - k * 0.6))
		var wr := radius + 14.0 + k * 26.0
		for i in 24:
			var a := TAU * float(i) / 24.0
			var px := roundf(cos(a) * wr * 0.5) * 2.0
			var py := roundf(sin(a) * wr * 0.5) * 2.0
			draw_rect(Rect2(px - 2.0, py - 2.0, 4.0, 4.0), warn)
		var ex := roundf(radius * 0.5)
		draw_rect(Rect2(-ex, -ex, ex * 2.0, ex * 2.0), Color(1.0, 0.3, 0.35, 0.14))
