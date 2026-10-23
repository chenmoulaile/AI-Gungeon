extends Node2D
## 拾取轨迹：从拾取点飞向 HUD 对应图标（金币 / 藏品），0.3s 淡出

var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
var color: Color = Color(1.0, 0.85, 0.4)
var count: int = 3
var _k: float = 0.0
var _dots: Array = []


func setup(a: Vector2, b: Vector2, col: Color = Color(1.0, 0.85, 0.4), n: int = 3) -> void:
	from = a
	to = b
	color = col
	count = n
	global_position = Vector2.ZERO
	for i in count:
		_dots.append({"off": Vector2(randf_range(-6, 6), randf_range(-6, 6)),
			"delay": float(i) * 0.05})
	var tw := create_tween()
	tw.tween_property(self, "_k", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for d in _dots:
		var k: float = clampf((_k - float(d["delay"])) / 0.25, 0.0, 1.0)
		if k <= 0.0:
			continue
		var p: Vector2 = from + (to - from) * k + d["off"] * (1.0 - k)
		p.y -= sin(k * PI) * 26.0
		var c := color
		c.a = 1.0 - k * 0.75
		draw_circle(p, 2.6 * (1.0 - k * 0.4), c)
