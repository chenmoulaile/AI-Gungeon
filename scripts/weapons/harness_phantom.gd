extends Node2D
## DeepSeek Harness：黑色虎鲸虚影
## 沿瞄准方向冲刺，对路径上的敌人造成一次撞击伤害后消散；带残影

var dir: Vector2 = Vector2.RIGHT
var speed: float = 560.0
var damage: float = 110.0
var hit_radius: float = 18.0
var life: float = 0.42
var devour: bool = false
var color: Color = Color(0.06, 0.10, 0.20)

var _t: float = 0.0
var _hit: Dictionary = {}
var _ghosts: Array = []
var _ghost_t: float = 0.0


func setup(origin: Vector2, p_dir: Vector2, p_speed: float = 560.0, p_life: float = 0.42) -> void:
	global_position = origin
	dir = p_dir.normalized()
	speed = p_speed
	life = p_life
	rotation = dir.angle()
	add_to_group("harness")
	add_to_group("bullets")


func _process(delta: float) -> void:
	_t += delta
	life -= delta
	global_position += dir * speed * delta
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		_ghost_t = 0.03
		_ghosts.append({"pos": global_position, "a": 0.5})
		if _ghosts.size() > 6:
			_ghosts.pop_front()
	for g in _ghosts:
		g["a"] = float(g["a"]) - delta * 2.2
	for e in GameState.enemies:
		if not is_instance_valid(e) or e.dead or _hit.has(e):
			continue
		if global_position.distance_to(e.global_position) < hit_radius + float(e.radius):
			_hit[e] = true
			e.take_damage(damage, dir, "heavy", false, "harness")
			if GameState.player != null and is_instance_valid(GameState.player):
				GameState.player.record_hit(e)
			GameFeel.burst(e.global_position, Color(0.25, 0.45, 0.85), 8, 130.0, 0.3)
			GameFeel.hit_stop(0.05, 0.04)
			if devour:
				# 吞噬：以撞击点为中心再造成一次小范围伤害
				for e2 in GameState.enemies:
					if is_instance_valid(e2) and not e2.dead and e2 != e \
							and e2.global_position.distance_to(e.global_position) < 52.0:
						e2.take_damage(damage * 0.35, dir, "medium", false, "harness_devour")
				GameFeel.burst(e.global_position, Color(0.10, 0.18, 0.35), 12, 170.0, 0.42)
	if life <= 0.0:
		_dissipate()
	queue_redraw()


func _dissipate() -> void:
	GameFeel.burst(global_position, Color(0.20, 0.35, 0.70), 10, 120.0, 0.3)
	queue_free()


func _draw() -> void:
	for g in _ghosts:
		var a: float = maxf(0.0, float(g["a"]))
		if a <= 0.01:
			continue
		draw_set_transform((g["pos"] as Vector2) - global_position, 0.0, Vector2.ONE)
		draw_circle(Vector2.ZERO, 11.0, Color(0.16, 0.28, 0.55, a * 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var fade: float = clampf(life / 0.12, 0.0, 1.0)
	var body := Color(color.r, color.g, color.b, 0.92 * fade)
	# 身体：前圆后尖
	draw_circle(Vector2(2, 0), 11.0, body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, -10.5), Vector2(-22, 0), Vector2(-2, 10.5)]), body)
	# 尾鳍
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, 0), Vector2(-30, -9), Vector2(-27, 0), Vector2(-30, 9)]),
		Color(color.r, color.g, color.b, 0.85 * fade))
	# 背鳍
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -9), Vector2(-14, -19), Vector2(-1, -10)]), body)
	# 白色眼斑 + 眼
	draw_circle(Vector2(6, -3.5), 3.4, Color(0.92, 0.96, 1.0, 0.9 * fade))
	draw_circle(Vector2(6.6, -3.5), 1.4, Color(0.05, 0.08, 0.14, fade))
	# 腹部高光
	draw_arc(Vector2(1, 2), 7.0, 0.2, 2.6, 10, Color(0.45, 0.62, 0.95, 0.35 * fade), 1.2)
	if devour:
		draw_arc(Vector2.ZERO, 16.0 + sin(_t * 20.0) * 1.5, 0.0, TAU, 20,
			Color(1.0, 0.72, 0.30, 0.55 * fade), 1.4, true)
