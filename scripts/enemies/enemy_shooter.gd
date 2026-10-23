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
	max_hp = 14.0 * GameState.enemy_scale()
	hp = max_hp
	speed = 38.0
	radius = 9.5
	contact_damage = 1
	coin_value = 3
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
		position += dir * speed * delta
	elif dist < KEEP_MIN:
		position -= dir * speed * delta

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
		telegraph = 0.35


func _draw_body() -> void:
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
