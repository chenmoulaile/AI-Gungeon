extends Node2D
## 铁盆挥击残影 / 要饭冲击环（v0.9）：全部用像素方块绘制。

var dir: Vector2 = Vector2.RIGHT
var reach: float = 40.0
var ratio: float = 0.0
var mode: String = "swing"
var color: Color = Color(0.55, 0.85, 1.0)
var life: float = 0.18

var _max_life: float = 0.18


func _ready() -> void:
	_max_life = life
	z_index = 3


func _process(delta: float) -> void:
	life -= delta
	queue_redraw()
	if life <= 0.0:
		queue_free()


func _draw() -> void:
	var k := clampf(life / maxf(0.001, _max_life), 0.0, 1.0)
	var a := color
	a.a *= k
	if mode == "beg":
		var rr := reach * (1.0 - 0.55 * k)
		for i in 16:
			var ang := TAU * float(i) / 16.0 + _max_life * 2.0
			var p := Vector2(roundf(cos(ang) * rr / 2.0) * 2.0,
				roundf(sin(ang) * rr / 2.0) * 2.0)
			draw_rect(Rect2(p - Vector2(2, 1), Vector2(4, 2)), a)
			if i % 2 == 0:
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, a.a * 0.8))
		return

	draw_set_transform(Vector2.ZERO, dir.angle(), Vector2.ONE)
	var arc := 1.15
	var steps := 13
	for i in steps:
		var t := float(i) / float(steps - 1)
		var ang := lerpf(-arc, arc, t)
		var p := Vector2(roundf(cos(ang) * reach / 2.0) * 2.0,
			roundf(sin(ang) * reach / 2.0) * 2.0)
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), a)
		var p2 := Vector2(roundf(cos(ang) * (reach - 8.0) / 2.0) * 2.0,
			roundf(sin(ang) * (reach - 8.0) / 2.0) * 2.0)
		draw_rect(Rect2(p2 - Vector2(1, 1), Vector2(2, 2)),
			Color(1.0, 1.0, 1.0, a.a * 0.55))
	# 满蓄力：外圈再补一层金色冲击
	if ratio > 0.7:
		for i in 7:
			var ang2 := lerpf(-arc, arc, float(i) / 6.0)
			var p3 := Vector2(roundf(cos(ang2) * (reach + 8.0) / 2.0) * 2.0,
				roundf(sin(ang2) * (reach + 8.0) / 2.0) * 2.0)
			draw_rect(Rect2(p3 - Vector2(2, 2), Vector2(4, 4)),
				Color(1.0, 0.82, 0.4, a.a * 0.75))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
