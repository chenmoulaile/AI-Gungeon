extends EnemyBase
## 狙击手：保持 250~350px，每 2.5s 打一发 400px/s 高速弹，发射前 0.5s 红色细线预警

const MIN_D := 250.0
const MAX_D := 350.0
const CYCLE := 2.5
const WARN := 0.5

var timer: float = 0.0
var warning: float = 0.0
var aim_dir: Vector2 = Vector2.RIGHT


func _setup() -> void:
	var st: EnemyStats = Stats.enemy("sniper")
	max_hp = st.max_hp * GameState.enemy_scale()
	hp = max_hp
	speed = st.speed
	radius = 9.0
	contact_damage = st.contact_damage
	coin_value = st.coin_value
	accent = Color("#ff8fb1")
	timer = SeedManager.randf_range(1.0, 2.0)


func _ai(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	aim_dir = to_player.normalized()

	if warning > 0.0:
		warning -= delta
		if warning <= 0.0:
			shoot_at(aim_dir, 400.0, 3.4)
			Sfx.play_at("shoot", global_position, -2.0, 0.65)
			GameFeel.screen_shake(0.06)
		return

	# 走位保持距离
	if dist > MAX_D:
		position += aim_dir * speed * slow_mult * delta
	elif dist < MIN_D:
		position -= aim_dir * speed * slow_mult * delta
	else:
		position += aim_dir.orthogonal() * sin(t * 1.1) * speed * 0.5 * delta

	timer -= delta
	if timer <= 0.0:
		timer = CYCLE
		warning = WARN
		Sfx.play_at("warn_high", global_position, -6.0, 1.6)


func _draw_body() -> void:
	# 瞄准线：预警时变粗并由白转红
	if warning > 0.0:
		var k: float = 1.0 - warning / WARN
		var col := Color(1.0, 0.95 - 0.7 * k, 0.9 - 0.65 * k, 0.30 + 0.55 * k)
		draw_line(Vector2.ZERO, aim_dir * 600.0, col, 1.0 + 2.0 * k)
	draw_set_transform(Vector2.ZERO, aim_dir.angle(), Vector2.ONE)
	# 细长数据狙击单元
	var body := PackedVector2Array([
		Vector2(radius * 1.5, 0.0), Vector2(radius * 0.5, -radius * 0.42),
		Vector2(-radius * 1.1, -radius * 0.30), Vector2(-radius * 1.1, radius * 0.30),
		Vector2(radius * 0.5, radius * 0.42)])
	draw_colored_polygon(body, accent.darkened(0.1))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0, 0, 0, 0.85), 1.4)
	# 枪管
	draw_rect(Rect2(radius * 1.4, -1.2, radius * 0.9, 2.4), Color(0.22, 0.10, 0.14))
	# 散热鳍片
	for i in 3:
		var x := -radius * 0.7 + float(i) * radius * 0.42
		draw_line(Vector2(x, -radius * 0.36), Vector2(x, radius * 0.36),
			Color(0, 0, 0, 0.45), 1.0)
	# 目镜
	draw_circle(Vector2(radius * 0.15, 0.0), radius * 0.20, Color(1, 1, 1, 0.95))
	draw_circle(Vector2(radius * 0.22, 0.0), radius * 0.10, Color(0.75, 0.10, 0.16))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
