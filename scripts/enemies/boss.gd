extends EnemyBase
## Boss「回响聚合体」
## 三阶段：100%~60% 环形弹 / 60%~25% 追踪弹 / 25%~0% 扇形弹 + 召唤

const ChaserScene = preload("res://scenes/enemies/enemy_chaser.tscn")

var phase: int = 1
var atk_cd: float = 1.6
var summon_cd: float = 5.0
var ring_angle: float = 0.0


func _setup() -> void:
	max_hp = 150.0 * GameState.enemy_scale()
	hp = max_hp
	speed = 26.0
	radius = 27.0
	contact_damage = 2
	coin_value = 26
	accent = Color("#b45cff")
	is_boss = true
	add_to_group("boss")
	atk_cd = 1.8


func _ai(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_update_phase()
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()
	if dist > 130.0:
		position += dir * speed * delta
	else:
		position += dir.orthogonal() * speed * 0.5 * delta

	atk_cd -= delta
	if atk_cd <= 0.0:
		match phase:
			1:
				_attack_ring()
				atk_cd = 1.7
			2:
				_attack_homing(dir)
				atk_cd = 1.25
			_:
				_attack_fan(dir)
				atk_cd = 1.05

	if phase >= 3:
		summon_cd -= delta
		if summon_cd <= 0.0:
			summon_cd = 6.0
			_summon()


func _update_phase() -> void:
	var ratio := hp_ratio()
	var new_phase := 1
	if ratio <= 0.25:
		new_phase = 3
	elif ratio <= 0.6:
		new_phase = 2
	if new_phase != phase:
		phase = new_phase
		atk_cd = 0.7
		Sfx.play("boss", -4.0, 1.2 + 0.15 * phase)


# 阶段 1：环形弹
func _attack_ring() -> void:
	var count := 14
	ring_angle += 0.22
	for i in count:
		var a := TAU * i / count + ring_angle
		shoot_at(Vector2(cos(a), sin(a)), 132.0, 4.2)
	Sfx.play("hit", -8.0, 0.7)


# 阶段 2：追踪弹
func _attack_homing(dir: Vector2) -> void:
	for i in 3:
		var a := dir.rotated(deg_to_rad(-18.0 + 18.0 * i))
		shoot_at(a, 118.0, 4.6, 2.2, 1.4)
	Sfx.play("hit", -8.0, 1.1)


# 阶段 3：扇形弹
func _attack_fan(dir: Vector2) -> void:
	for i in 7:
		var t2 := float(i) / 6.0 - 0.5
		shoot_at(dir.rotated(deg_to_rad(52.0 * t2)), 172.0, 4.0)
	Sfx.play("hit", -8.0, 0.85)


func _summon() -> void:
	if GameState.bullets_root == null:
		return
	for i in 2:
		var e: Node2D = ChaserScene.instantiate()
		var ang := randf() * TAU
		e.position = global_position + Vector2(cos(ang), sin(ang)) * 60.0
		GameState.bullets_root.add_child(e)


# ---------------- 绘制 ----------------
func _draw_body() -> void:
	var c := accent
	match phase:
		2:
			c = Color("#ff7ad9")
		3:
			c = Color("#ff5b5b")
	# 外圈旋转环
	for k in 3:
		var rr := radius + 6.0 + k * 5.0
		var a0 := t * (0.8 + k * 0.5)
		draw_arc(Vector2.ZERO, rr, a0, a0 + PI * 1.3, 20,
			Color(c.r, c.g, c.b, 0.45 - k * 0.1), 2.0, true)
	# 核心多边形
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0 + t * 0.5
		var rr := radius * (1.0 if i % 2 == 0 else 0.58)
		pts.append(Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, c)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0, 0, 0, 0.9), 2.0)
	draw_circle(Vector2.ZERO, radius * 0.44, Color(1, 1, 1, 0.95))
	draw_circle(Vector2.ZERO, radius * 0.24, Color(0.1, 0.02, 0.15, 1.0))
