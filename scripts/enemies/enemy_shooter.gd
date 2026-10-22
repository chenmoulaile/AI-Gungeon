extends EnemyBase
## 远程敌人（直线弹）：保持距离，蓄力后朝玩家打一发直线弹

const KEEP_MIN := 150.0
const KEEP_MAX := 220.0

var fire_cd: float = 1.6
var telegraph: float = 0.0


func _setup() -> void:
	max_hp = 14.0 * GameState.enemy_scale()
	hp = max_hp
	speed = 38.0
	radius = 9.5
	contact_damage = 1
	coin_value = 3
	accent = Color("#ff9f43")
	fire_cd = randf_range(1.0, 1.8)


func _ai(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()
	if dist > KEEP_MAX:
		position += dir * speed * delta
	elif dist < KEEP_MIN:
		position -= dir * speed * delta

	fire_cd -= delta
	if telegraph > 0.0:
		telegraph -= delta
		if telegraph <= 0.0:
			shoot_at(dir, 190.0, 3.8)
			Sfx.play("hit", -14.0, 1.6)
	if fire_cd <= 0.0:
		fire_cd = randf_range(1.5, 2.2)
		telegraph = 0.35


func _draw_body() -> void:
	# 方形核心 + 旋转外框
	var s := radius
	var pts := PackedVector2Array([
		Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s),
	])
	draw_colored_polygon(pts, accent)
	draw_rect(Rect2(-s, -s, s * 2.0, s * 2.0), Color(0, 0, 0, 0.85), false, 1.5)
	var a := t * 1.8
	var outer := PackedVector2Array()
	for i in 4:
		var ang := TAU * i / 4.0 + a
		outer.append(Vector2(cos(ang), sin(ang)) * (radius + 4.0))
	draw_polyline(outer + PackedVector2Array([outer[0]]), Color(1, 0.75, 0.4, 0.7), 1.2)
	draw_circle(Vector2(0, -1), s * 0.4, Color(1, 1, 1, 0.92))
	if telegraph > 0.0:
		draw_circle(Vector2.ZERO, radius + 8.0, Color(1, 0.5, 0.2, 0.18))
