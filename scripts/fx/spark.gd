extends Node2D
## 像素粒子（由 GameFeel 对象池管理，单节点批量绘制）
## mode = "spark" 火花四散；"shard" 碎块（重力下坠 + 自旋），用于死亡碎裂

const MAX_PARTICLES := 18

var mode: String = "spark"
var gravity: float = 0.0

var _parts: Array = []
var _active: bool = false
var _t: float = 0.0


func burst(pos: Vector2, color: Color, count: int, speed: float, life: float) -> void:
	global_position = pos
	_parts.clear()
	var n: int = mini(count, MAX_PARTICLES)
	for i in n:
		var ang := randf() * TAU
		var spd := speed * randf_range(0.45, 1.0)
		var size := randf_range(1.0, 2.0)
		if mode == "shard":
			size = randf_range(2.0, 3.6)
		_parts.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": life * randf_range(0.6, 1.0),
			"max": life,
			"size": size,
			"rot": randf() * TAU,
			"spin": randf_range(-9.0, 9.0),
			"color": color,
		})
	_active = true
	visible = true
	_t = 0.0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	var alive := 0
	for p in _parts:
		p["life"] -= delta
		if p["life"] <= 0.0:
			continue
		alive += 1
		p["vel"] *= 0.90
		if gravity != 0.0:
			p["vel"] += Vector2(0.0, gravity * delta)
		p["pos"] += p["vel"] * delta
		p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
	_active = alive > 0
	if not _active:
		GameFeel.release_spark(self)
		return
	queue_redraw()


func particle_count() -> int:
	return _parts.size()


func _draw() -> void:	for p in _parts:
		if p["life"] <= 0.0:
			continue
		var t: float = clampf(p["life"] / p["max"], 0.0, 1.0)
		var c: Color = p["color"]
		c.a = t
		var sz: float = float(p["size"]) * (0.4 + t * 0.6)
		if mode == "shard":
			draw_set_transform(p["pos"], p["rot"], Vector2.ONE)
			draw_rect(Rect2(-sz * 0.5, -sz * 0.5, sz, sz), c)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_rect(Rect2(p["pos"] - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), c)
