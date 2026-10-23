extends EnemyBase
## 环形射手：原地不动，每 3.0s 放一圈 12 发（120px/s），发射前 0.5s 收拢白色预警环

const CYCLE := 3.0
const WARN := 0.5
const BULLETS := 12

var timer: float = 0.0
var warning: float = 0.0
var spin: float = 0.0


func _setup() -> void:
	max_hp = 10.0 * GameState.enemy_scale()
	hp = max_hp
	speed = 0.0
	radius = 11.0
	contact_damage = 1
	coin_value = 4
	accent = Color("#8fb6ff")
	timer = randf_range(1.2, 2.4)
	spin = randf() * TAU


func _ai(delta: float) -> void:
	if warning > 0.0:
		warning -= delta
		if warning <= 0.0:
			_fire_ring()
		return
	timer -= delta
	if timer <= 0.0:
		timer = CYCLE
		warning = WARN
		Sfx.play_at("ring_warn", global_position, -4.0, 1.0)


func _fire_ring() -> void:
	spin += 0.26
	for i in BULLETS:
		var a := TAU * float(i) / float(BULLETS) + spin
		shoot_at(Vector2(cos(a), sin(a)), 120.0, 3.8)
	Sfx.play_at("hit", global_position, -6.0, 0.8)
	GameFeel.screen_shake(0.08)


func _draw_body() -> void:
	# 收拢预警环
	if warning > 0.0:
		var k: float = 1.0 - warning / WARN
		draw_arc(Vector2.ZERO, radius + 40.0 * (1.0 - k), 0.0, TAU, 40,
			Color(1, 1, 1, 0.55), 2.0, true)
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0 + t * 0.8
		pts.append(Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, accent)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0, 0, 0, 0.85), 1.6)
	draw_circle(Vector2.ZERO, radius * 0.42, Color(1, 1, 1, 0.95))
	draw_circle(Vector2.ZERO, radius * 0.22, Color(0.04, 0.06, 0.12))
