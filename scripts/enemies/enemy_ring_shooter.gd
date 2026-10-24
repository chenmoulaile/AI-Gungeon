extends EnemyBase
## 环形射手：原地不动，每 3.0s 放一圈 12 发（120px/s），发射前 0.5s 收拢白色预警环

const CYCLE := 3.0
const WARN := 0.5
const BULLETS := 12

var timer: float = 0.0
var warning: float = 0.0
var spin: float = 0.0


func _setup() -> void:
	var st: EnemyStats = Stats.enemy("ring_shooter")
	max_hp = st.max_hp * GameState.enemy_scale()
	hp = max_hp
	speed = st.speed
	radius = 11.0
	contact_damage = st.contact_damage
	coin_value = st.coin_value
	accent = Color("#8fb6ff")
	timer = SeedManager.randf_range(1.2, 2.4)
	spin = SeedManager.randf() * TAU


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
	# 旋转外环
	var spin_a := t * 1.6
	var outer := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0 + spin_a
		var rr := radius * (1.18 if i % 2 == 0 else 1.02)
		outer.append(Vector2(cos(a), sin(a)) * rr)
	draw_polyline(outer + PackedVector2Array([outer[0]]), Color(accent.r, accent.g, accent.b, 0.55), 1.4)
	# 浮动碎片：发射时向外弹开
	var burst := 0.0
	if warning > 0.0:
		burst = 6.0 * (1.0 - warning / WARN)
	for i in 6:
		var a2 := TAU * float(i) / 6.0 - spin_a * 0.8
		var p := Vector2(cos(a2), sin(a2)) * (radius * 0.62 + burst)
		draw_rect(Rect2(p - Vector2(1.6, 1.6), Vector2(3.2, 3.2)),
			Color(accent.r, accent.g, accent.b, 0.9))
	# 环形核心
	draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 22, accent, 3.2, true)
	draw_arc(Vector2.ZERO, radius * 0.52, spin_a * 0.6, spin_a * 0.6 + 4.4, 14,
		Color(1, 1, 1, 0.75), 1.6, true)
	draw_circle(Vector2.ZERO, radius * 0.22, Color(1, 1, 1, 0.95))
