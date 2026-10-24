extends EnemyBase
## 远程敌人（扇形弹）：靠近后打 5 发扇形
## 第 3 层起每第 3 轮改为 10 发环形弹（新弹幕，不新增敌种）

const KEEP := 165.0

var fire_cd: float = 2.4
var telegraph: float = 0.0
var volley: int = 0
var ring_mode: bool = false


func _setup() -> void:
	var st: EnemyStats = Stats.enemy("spreader")
	max_hp = st.max_hp * GameState.enemy_scale()
	hp = max_hp
	speed = st.speed
	radius = 10.5
	contact_damage = st.contact_damage
	coin_value = st.coin_value
	accent = Color("#c76bff")
	fire_cd = SeedManager.randf_range(1.2, 2.0)
	ring_mode = GameState.floor_index >= 3


func _ai(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()
	if dist > KEEP + 20.0:
		position += dir * speed * slow_mult * delta
	elif dist < KEEP - 30.0:
		position -= dir * speed * slow_mult * delta
	position += dir.orthogonal() * sin(t * 1.4) * speed * 0.45 * delta

	fire_cd -= delta
	if telegraph > 0.0:
		telegraph -= delta
		if telegraph <= 0.0:
			volley += 1
			if ring_mode and volley % 3 == 0:
				for i in 10:
					var a := TAU * i / 10.0 + t
					shoot_at(Vector2(cos(a), sin(a)), 150.0, 3.6)
			else:
				for i in 5:
					var t2 := float(i) / 4.0 - 0.5
					shoot_at(dir.rotated(deg_to_rad(30.0 * t2)), 165.0, 4.0)
			Sfx.play_at("hit", global_position, -8.0, 0.9)
	if fire_cd <= 0.0:
		fire_cd = SeedManager.randf_range(2.3, 3.0)
		telegraph = 0.45


func _draw_body() -> void:
	var ang := 0.0
	if player != null and is_instance_valid(player):
		ang = (player.global_position - global_position).angle()
	draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
	var open := 1.0 if telegraph > 0.0 else 0.55
	# 三条能量触须
	for i in 3:
		var a := (-0.55 + float(i) * 0.55) * open + sin(t * 3.0 + float(i)) * 0.08
		var ln := radius + 5.0 + (6.0 if telegraph > 0.0 else 0.0)
		var tip := Vector2(cos(a), sin(a)) * ln
		draw_line(Vector2(2.0, 0.0), tip, accent.lightened(0.25), 1.6)
		draw_circle(tip, 1.9, accent.lightened(0.45))
	# 扇形辐射核心
	var pts := PackedVector2Array([Vector2(-2.0, 0.0)])
	for i in 9:
		var a2 := -0.95 * open + float(i) * (0.21 * open)
		pts.append(Vector2(cos(a2), sin(a2)) * radius)
	draw_colored_polygon(pts, accent)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.85), 1.4)
	# 中心放射
	for i in 3:
		var a3 := -0.5 + float(i) * 0.5
		draw_line(Vector2.ZERO, Vector2(cos(a3), sin(a3)) * radius * 0.7,
			Color(1, 1, 1, 0.35), 1.0)
	draw_circle(Vector2.ZERO, radius * 0.22, Color(1, 1, 1, 0.95))
	glitch_fragments(3, radius + 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
