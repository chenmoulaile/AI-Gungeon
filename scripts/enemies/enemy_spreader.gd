extends EnemyBase
## 远程敌人（扇形弹）：靠近后打 5 发扇形
## 第 3 层起每第 3 轮改为 10 发环形弹（新弹幕，不新增敌种）

const KEEP := 165.0

var fire_cd: float = 2.4
var telegraph: float = 0.0
var volley: int = 0
var ring_mode: bool = false


func _setup() -> void:
	max_hp = 18.0 * GameState.enemy_scale()
	hp = max_hp
	speed = 30.0
	radius = 10.5
	contact_damage = 1
	coin_value = 4
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
		position += dir * speed * delta
	elif dist < KEEP - 30.0:
		position -= dir * speed * delta
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
	var pts := PackedVector2Array()
	for i in 5:
		var a := TAU * i / 5.0 - PI / 2.0 + sin(t * 1.1) * 0.15
		pts.append(Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, accent)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0, 0, 0, 0.85), 1.6)
	var tri := PackedVector2Array([
		Vector2(0, -radius * 0.5), Vector2(radius * 0.45, radius * 0.3),
		Vector2(-radius * 0.45, radius * 0.3),
	])
	draw_colored_polygon(tri, Color(1, 1, 1, 0.92))
	if telegraph > 0.0:
		draw_circle(Vector2.ZERO, radius + 9.0, Color(0.8, 0.4, 1.0, 0.16))
