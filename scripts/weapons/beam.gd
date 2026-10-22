extends Node2D
## 光束：同时支持「瞬间贯穿」（DeepSeek 技能）与「持续激光」（Claude 主武器）

var origin: Vector2 = Vector2.ZERO
var dir: Vector2 = Vector2.RIGHT
var length: float = 620.0
var width: float = 4.0
var dps: float = 30.0
var color: Color = Color("#8ee6ff")
var instant: bool = false
var life: float = 0.14
var tick_interval: float = 0.08
var tag: String = "beam"

var _tick: float = 0.0
var _fade: float = 1.0


func _ready() -> void:
	add_to_group("beams")
	global_position = origin
	if instant:
		_apply_damage(1.0)


func set_beam(from: Vector2, direction: Vector2) -> void:
	origin = from
	dir = direction.normalized()
	global_position = from
	queue_redraw()


func _physics_process(delta: float) -> void:
	if instant:
		life -= delta
		_fade = clampf(life / 0.14, 0.0, 1.0)
		if life <= 0.0:
			queue_free()
		queue_redraw()
		return

	_tick += delta
	if _tick >= tick_interval:
		_apply_damage(_tick)
		_tick = 0.0
	queue_redraw()


func _apply_damage(dt: float) -> void:
	var dmg := dps * dt
	for e in GameState.enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var d := _dist_to_segment(e.global_position)
		if d <= width * 0.5 + float(e.radius):
			e.take_damage(dmg, Vector2.ZERO, "medium", false, tag)


func _dist_to_segment(p: Vector2) -> float:
	var a := origin
	var b := origin + dir * length
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _draw() -> void:
	var a := Vector2.ZERO
	var b := dir * length
	var c := color
	c.a = 0.22 * _fade
	draw_line(a, b, c, width + 6.0)
	c.a = 0.85 * _fade
	draw_line(a, b, c, width)
	draw_line(a, b, Color(1, 1, 1, 0.9 * _fade), maxf(1.0, width * 0.35))
