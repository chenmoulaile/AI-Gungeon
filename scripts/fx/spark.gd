extends Node2D
## 像素粒子爆散（由 GameFeel 对象池管理，单节点批量绘制，限制粒子数）

const MAX_PARTICLES := 16

var _parts: Array = []
var _active: bool = false


func burst(pos: Vector2, color: Color, count: int, speed: float, life: float) -> void:
	global_position = pos
	_parts.clear()
	var n: int = mini(count, MAX_PARTICLES)
	for i in n:
		var ang := randf() * TAU
		var spd := speed * randf_range(0.45, 1.0)
		_parts.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": life * randf_range(0.6, 1.0),
			"max": life,
			"size": randf_range(1.0, 2.0),
			"color": color,
		})
	_active = true
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	var alive := 0
	for p in _parts:
		p["life"] -= delta
		if p["life"] <= 0.0:
			continue
		alive += 1
		p["vel"] *= 0.90
		p["pos"] += p["vel"] * delta
	_active = alive > 0
	if not _active:
		GameFeel.release_spark(self)
		return
	queue_redraw()


func _draw() -> void:
	for p in _parts:
		if p["life"] <= 0.0:
			continue
		var t: float = clampf(p["life"] / p["max"], 0.0, 1.0)
		var c: Color = p["color"]
		c.a = t
		draw_rect(Rect2(p["pos"] - Vector2(p["size"], p["size"]) * 0.5,
			Vector2(p["size"], p["size"]) * (0.4 + t * 0.6)), c)
