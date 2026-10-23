extends Node2D
## 弹道提示线：激光预警 / 枪口方向轨迹
## 纯视觉节点，不参与碰撞，life 秒后自动释放

var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
var color: Color = Color(1.0, 0.32, 0.38, 0.65)
var life: float = 0.16
var width: float = 1.0
var _t: float = 0.0


func setup(a: Vector2, b: Vector2, dur: float = 0.16, col: Color = Color(1.0, 0.32, 0.38, 0.65),
		w: float = 1.0) -> void:
	from = a
	to = b
	life = dur
	color = col
	width = w
	global_position = Vector2.ZERO
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
	c.a = color.a * k
	draw_line(from, to, c, width)
	var glow := c
	glow.a = c.a * 0.25
	draw_line(from, to, glow, width + 2.0)
