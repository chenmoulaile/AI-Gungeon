extends Node2D
## 通用减速区域（白饭 / 律令都可用）：区域内敌人移速按 slow 倍率计算

var radius: float = 50.0
var life: float = 2.0
var slow: float = 0.55
var color: Color = Color(0.95, 0.97, 1.0)
var dps: float = 0.0

var _t: float = 0.0
var _tick: float = 0.0


func _ready() -> void:
	add_to_group("slow_zone")
	z_index = 0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	life -= delta
	for e in GameState.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		if global_position.distance_to(e.global_position) <= radius:
			e.slow_mult = minf(float(e.slow_mult), slow)
			e.slow_t = maxf(float(e.slow_t), 0.15)
	if dps > 0.0:
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.5
			for e2 in GameState.enemies:
				if is_instance_valid(e2) and not e2.dead \
						and global_position.distance_to(e2.global_position) <= radius:
					e2.take_damage(dps * 0.5, Vector2.ZERO, "light", false, "zone")
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = clampf(life / 0.3, 0.0, 1.0)
	var open: float = clampf((2.0 - life) / 0.15, 0.0, 1.0)
	var r: float = radius * open
	var a: float = 0.16 * k
	draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, a))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color.r, color.g, color.b, 0.55 * k), 1.2, true)
	# 米饭颗粒
	for i in 10:
		var ang: float = TAU * float(i) / 10.0 + _t * 0.5
		var rr: float = r * (0.35 + 0.5 * fmod(float(i) * 0.37, 1.0))
		draw_circle(Vector2(cos(ang), sin(ang)) * rr, 1.4,
			Color(1, 1, 1, 0.55 * k))
