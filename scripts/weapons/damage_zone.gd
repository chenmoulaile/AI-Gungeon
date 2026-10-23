extends Node2D
## 持续伤害区域（DeepSeek「余温记录」）：1.5s 内每 0.25s 结算一次

var radius: float = 34.0
var dps: float = 28.0
var life: float = 1.5
var color: Color = Color(1.0, 0.55, 0.25)

var _t: float = 0.0
var _tick: float = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	_tick += delta
	if _tick >= 0.25:
		_tick = 0.0
		for e in GameState.enemies.duplicate():
			if not is_instance_valid(e):
				continue
			if global_position.distance_to(e.global_position) < radius + float(e.radius):
				e.take_damage(dps * 0.25, Vector2.ZERO, "light", false, "burn")
	if life <= 0.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a: float = clampf(life / 1.5, 0.0, 1.0)
	var c := color
	c.a = 0.18 * a
	draw_circle(Vector2.ZERO, radius, c)
	c.a = 0.55 * a
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, c, 1.5, true)
	for i in 5:
		var ang := TAU * i / 5.0 + _t * 1.4
		draw_circle(Vector2(cos(ang), sin(ang)) * radius * 0.55, 2.0,
			Color(1.0, 0.72, 0.4, 0.55 * a))
