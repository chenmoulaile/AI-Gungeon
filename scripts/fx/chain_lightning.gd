extends Node2D
## 链式闪电视觉：紫色锯齿线，0.1s 后消失（不参与碰撞）

var points: PackedVector2Array = PackedVector2Array()
var color: Color = Color("#b98cff")
var life: float = 0.1
var _t: float = 0.0
var _seed_pts: Array = []


func setup(pts: PackedVector2Array) -> void:
	points = pts
	_seed_pts.clear()
	for i in range(maxi(0, pts.size() - 1)):
		var a := pts[i]
		var b := pts[i + 1]
		var seg: Array = [a]
		var n := 4
		for k in range(1, n):
			var t := float(k) / float(n)
			var p := a.lerp(b, t)
			p += Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
			seg.append(p)
		seg.append(b)
		_seed_pts.append(seg)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = 1.0 - clampf(_t / life, 0.0, 1.0)
	var c := color
	c.a = 0.9 * k
	for seg in _seed_pts:
		draw_polyline(PackedVector2Array(seg), c, 2.2)
		var glow := c
		glow.a = 0.28 * k
		draw_polyline(PackedVector2Array(seg), glow, 5.0)
