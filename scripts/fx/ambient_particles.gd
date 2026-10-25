extends Node2D
## 氛围粒子：每屏 3~8 个，按层主题改变行为
## mote 漂浮光点 / data 数据流短线 / ember 上升灰烬
## 纯视觉，不参与碰撞；位置跟随相机视野，离开视野后从另一侧重生

var kind: String = "mote"
var color: Color = Color(1, 1, 1, 0.5)

var _parts: Array = []
var _t: float = 0.0


func setup(p_kind: String, p_color: Color) -> void:
	kind = p_kind
	color = p_color
	var n := 4
	match kind:
		"data":
			n = 3
		"ember":
			n = 7
		_:
			n = 4
	_parts.clear()
	for i in n:
		_parts.append(_spawn(true))
	set_process(true)


func _view_rect() -> Rect2:
	var xf := get_viewport().get_canvas_transform()
	var inv := xf.affine_inverse()
	return Rect2(inv * Vector2.ZERO, inv * Vector2(GameConfig.BASE_W, GameConfig.BASE_H)).abs()


func _spawn(initial: bool) -> Dictionary:
	var v := _view_rect()
	match kind:
		"data":
			var y := v.position.y + randf() * v.size.y
			return {
				"pos": Vector2(v.position.x + (randf() * v.size.x if initial else -20.0), y),
				"vel": Vector2(randf_range(150.0, 230.0), 0.0),
				"size": randf_range(8.0, 18.0),
				"life": 0.0,
				"max": 2.2,
				"phase": randf() * TAU,
			}
		"ember":
			return {
				"pos": Vector2(v.position.x + randf() * v.size.x,
					v.position.y + v.size.y - randf() * v.size.y * (0.0 if initial else 1.0)),
				"vel": Vector2(randf_range(-6.0, 6.0), -randf_range(14.0, 26.0)),
				"size": float(randi_range(2, 3)),
				"life": randf() * 4.0 if initial else 0.0,
				"max": 6.0,
				"phase": randf() * TAU,
			}
		_:
			return {
				"pos": Vector2(v.position.x + randf() * v.size.x,
					v.position.y + randf() * v.size.y),
				"vel": Vector2(randf_range(-4.0, 4.0), -randf_range(5.0, 9.0)),
				"size": float(randi_range(2, 3)),
				"life": randf() * 6.0 if initial else 0.0,
				"max": 8.0,
				"phase": randf() * TAU,
			}


func _process(delta: float) -> void:
	_t += delta
	var v := _view_rect().grow(40.0)
	for i in _parts.size():
		var p: Dictionary = _parts[i]
		p["life"] = float(p["life"]) + delta
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		var pos: Vector2 = p["pos"]
		var dead := false
		if kind == "data":
			dead = pos.x > v.end.x + 20.0
		else:
			dead = not v.has_point(pos) or float(p["life"]) > float(p["max"])
		if dead:
			_parts[i] = _spawn(false)
	queue_redraw()


func _draw() -> void:
	for p in _parts:
		var pos: Vector2 = p["pos"]
		var life: float = float(p["life"])
		var mx: float = float(p["max"])
		var fade: float = clampf(minf(life / 0.8, (mx - life) / 0.8), 0.0, 1.0)
		if fade <= 0.0:
			continue
		var c := color
		match kind:
			"data":
				var ln: float = float(p["size"])
				c.a = color.a * fade * 0.85
				draw_line(pos, pos + Vector2(ln, 0.0), c, 1.0)
				draw_line(pos + Vector2(ln * 0.55, 0.0), pos + Vector2(ln, 0.0),
					Color(c.r, c.g, c.b, c.a * 1.4), 1.6)
			"ember":
				var flick: float = 0.45 + 0.55 * absf(sin(_t * 3.0 + float(p["phase"])))
				c.a = color.a * fade * flick
				var s: float = float(p["size"])
				var ip := Vector2(roundf(pos.x), roundf(pos.y))
				draw_rect(Rect2(ip - Vector2(s, s) * 0.5, Vector2(s, s)), c)
			_:
				# 漂浮光点：2/3px 实心方块，不做圆光晕
				var pulse: float = 0.55 + 0.45 * sin(_t * 1.6 + float(p["phase"]))
				c.a = color.a * fade * pulse
				var s2: float = float(p["size"])
				var ip2 := Vector2(roundf(pos.x), roundf(pos.y))
				draw_rect(Rect2(ip2 - Vector2(s2, s2) * 0.5, Vector2(s2, s2)), c)
