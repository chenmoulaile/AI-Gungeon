extends Node2D
## Claude「对齐协议」的浮游炮：白色书页，绕角色圆周运动（半径 40，周期 3s），自动索敌射击

var player = null
var life: float = 8.0
var fire_gap: float = 0.5
var damage: float = 3.0
var radius: float = 40.0
var period: float = 3.0

var _t: float = 0.0
var _fire_t: float = 0.0
var _angle: float = 0.0
var _burst_on_end: bool = false


func setup(p: Node, dur: float = 8.0) -> void:
	player = p
	life = dur
	_fire_t = 0.35


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not player.alive:
		queue_free()
		return
	_t += delta
	life -= delta
	_angle += TAU / period * delta
	global_position = player.global_position + Vector2(0, -16) \
		+ Vector2(cos(_angle), sin(_angle)) * radius
	if life <= 0.0:
		_expire()
		return
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = fire_gap
		_shoot()
	queue_redraw()


func _shoot() -> void:
	var target = _nearest()
	if target == null:
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	var b = GameFeel.get_bullet()
	if b == null:
		return
	b.friendly = true
	b.dir = dir
	b.speed = 400.0
	b.damage = damage
	b.crit = false
	b.radius = 2.4
	b.life = 1.4
	b.color = Color("#f4f7ff")
	b.pierce = 0
	b.gen = 0
	b.tier = "light"
	b.trail = true
	b.tag = "alignment"
	b.global_position = global_position
	b.prepare()
	Sfx.play("shoot", -14.0, 1.7)


func _nearest() -> Node:
	var best = null
	var bd := 240.0
	for e in GameState.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _expire() -> void:
	if _burst_on_end:
		for i in 6:
			var ang := TAU * float(i) / 6.0
			var b = GameFeel.get_bullet()
			if b == null:
				break
			b.friendly = true
			b.dir = Vector2(cos(ang), sin(ang))
			b.speed = 300.0
			b.damage = damage
			b.crit = false
			b.radius = 2.2
			b.life = 0.8
			b.color = Color("#ffe6b0")
			b.pierce = 0
			b.gen = 0
			b.tier = "light"
			b.trail = true
			b.tag = "alignment"
			b.global_position = global_position
			b.prepare()
	GameFeel.burst(global_position, Color(1.0, 0.95, 0.8), 6, 90.0, 0.25)
	queue_free()


func _draw() -> void:
	var pulse: float = 0.7 + 0.3 * sin(_t * 6.0)
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.95, 0.8, 0.12 * pulse))
	draw_arc(Vector2.ZERO, 7.5, 0.0, TAU, 18, Color(1.0, 0.92, 0.72, 0.45 * pulse), 1.0, true)
	# 书页
	var page := PackedVector2Array([
		Vector2(-3.5, -4.5), Vector2(3.5, -4.5), Vector2(3.5, 4.5), Vector2(-3.5, 4.5)])
	draw_colored_polygon(page, Color(0.99, 0.99, 1.0))
	draw_polyline(PackedVector2Array([page[0], page[1], page[2], page[3], page[0]]),
		Color(0.62, 0.68, 0.82), 1.0)
	draw_line(Vector2(0, -4.0), Vector2(0, 4.0), Color(0.78, 0.82, 0.9), 1.0)
	for i in 3:
		var y := -2.4 + i * 2.2
		draw_line(Vector2(-2.2, y), Vector2(-0.6, y), Color(0.80, 0.84, 0.92), 0.8)
		draw_line(Vector2(0.6, y), Vector2(2.2, y), Color(0.80, 0.84, 0.92), 0.8)
