extends EnemyBase
## 远程敌人（直线弹）：保持距离，蓄力后攻击
## 第 2 层起切换为旋转弹模式（新弹幕，不新增敌种）

const KEEP_MIN := 150.0
const KEEP_MAX := 220.0

var fire_cd: float = 1.6
var telegraph: float = 0.0
var pattern: String = "aim"
var spin: float = 0.0


func _setup() -> void:
	var st: EnemyStats = Stats.enemy("shooter")
	max_hp = st.max_hp * GameState.enemy_scale()
	hp = max_hp
	speed = st.speed
	radius = 9.5
	contact_damage = st.contact_damage
	coin_value = st.coin_value
	accent = Color("#ff9f43")
	fire_cd = SeedManager.randf_range(1.0, 1.8)
	if GameState.floor_index >= 2:
		pattern = "spiral"
		spin = SeedManager.randf() * TAU


func _ai(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()
	if dist > KEEP_MAX:
		position += dir * speed * slow_mult * delta
	elif dist < KEEP_MIN:
		position -= dir * speed * slow_mult * delta

	fire_cd -= delta
	if telegraph > 0.0:
		telegraph -= delta
		if telegraph <= 0.0:
			if pattern == "spiral":
				spin += 0.7
				for i in 2:
					var a := spin + PI * i
					shoot_at(Vector2(cos(a), sin(a)), 165.0, 3.8)
			else:
				shoot_at(dir, 190.0, 3.8)
			Sfx.play_at("shoot", global_position, -6.0, 0.9)
	if fire_cd <= 0.0:
		fire_cd = SeedManager.randf_range(1.5, 2.2) if pattern == "aim" else SeedManager.randf_range(1.1, 1.6)
		telegraph = 0.5


func _draw_body() -> void:
	var ang := 0.0
	if player != null and is_instance_valid(player):
		ang = (player.global_position - global_position).angle()
	# 预警：红色瞄准线，越接近发射越亮
	if telegraph > 0.0:
		var kk := 1.0 - telegraph / 0.5
		var c := Color(1.0, 0.22, 0.26, 0.25 + 0.55 * kk)
		draw_line(Vector2.ZERO, Vector2(cos(ang), sin(ang)) * 320.0, c, 1.0 + 1.5 * kk)
	draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
	var s := radius
	var rec := 0.0
	if telegraph > 0.0:
		rec = -2.5 * (1.0 - telegraph / 0.5)
	# 断裂柱状炮台
	for i in 3:
		var y := -s + float(i) * s * 0.70
		var w := s * (1.0 - 0.12 * float(i))
		draw_rect(Rect2(-w + rec, y, w * 2.0, s * 0.62), accent.darkened(0.06 * float(i)))
		draw_line(Vector2(-w + rec, y), Vector2(w + rec, y), Color(0, 0, 0, 0.55), 1.0)
	draw_rect(Rect2(-s * 0.18 + rec, -s * 0.22, s * 0.42, s * 0.16), Color(0.10, 0.06, 0.04))
	# 炮口
	var mz := Vector2(s * 1.15 + rec, -1.0)
	draw_rect(Rect2(mz.x - 2.0, mz.y - 3.0, 6.0, 6.0), Color(0.24, 0.17, 0.12))
	draw_rect(Rect2(mz.x + 2.0, mz.y - 2.0, 3.0, 4.0), Color(1.0, 0.75, 0.35))
	if telegraph > 0.0:
		var k := 1.0 - telegraph / 0.5
		draw_arc(mz, 4.0 + 7.0 * k, 0.0, TAU, 16,
			Color(1.0, 0.55 + 0.35 * k, 0.20, 0.85), 1.6, true)
		draw_circle(mz, 1.6 + 2.4 * k, Color(1.0, 0.85, 0.5, 0.55))
	glitch_fragments(4, s + 5.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
