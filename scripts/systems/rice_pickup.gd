extends Node2D
## 大白饭（v0.9）：要饭掉落物，飞向玩家并恢复 15 Token。

var amount: float = 15.0
var _vel: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _magnet: float = 0.0
var _spark: float = 0.0


func _ready() -> void:
	add_to_group("rice_pickups")
	z_index = 3
	_vel = Vector2(randf_range(-40.0, 40.0), randf_range(-70.0, -30.0))
	_spark = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	_magnet += delta
	var p = GameState.player
	if p == null or not is_instance_valid(p) or not p.alive:
		if _t > 8.0:
			queue_free()
		queue_redraw()
		return
	# 前 0.25s 向外抛，之后强磁吸
	if _magnet < 0.25:
		_vel = _vel.move_toward(Vector2.ZERO, 260.0 * delta)
		global_position += _vel * delta
	else:
		var to: Vector2 = p.global_position + Vector2(0, -18) - global_position
		if to.length() <= 12.0:
			_collect(p)
			return
		global_position += to.normalized() * minf(to.length(), 420.0 * delta)
	if _t > 8.0:
		queue_free()
	queue_redraw()


func _collect(p: Node) -> void:
	if p.has_method("add_token"):
		p.add_token(amount)
	if p.has_method("notify"):
		p.notify("大白饭 +%d Token" % int(amount), 1.0)
	Sfx.play("coin", -8.0, 1.45)
	GameFeel.burst(global_position, Color(1.0, 0.98, 0.9), 7, 70.0, 0.3)
	queue_free()


func _draw() -> void:
	var edge := Color("#7FB7E8")
	var rice := Color("#F4F6FF")
	var rice_lo := Color("#C9D4EE")
	# 1px 浅蓝描边 + 白饭堆
	draw_rect(Rect2(-3, -7, 7, 1), edge)
	draw_rect(Rect2(-4, -6, 9, 5), edge)
	draw_rect(Rect2(-3, -1, 7, 3), edge)
	draw_rect(Rect2(-3, -6, 7, 4), rice)
	draw_rect(Rect2(-2, -1, 5, 2), rice)
	draw_rect(Rect2(-2, -6, 5, 1), Color("#FFFFFF"))
	draw_rect(Rect2(-3, 1, 7, 1), rice_lo)
	# 闪烁星
	var a := _spark + _t * 4.0
	var sx := roundf(cos(a) * 6.0)
	var sy := roundf(sin(a) * 6.0) - 3.0
	draw_rect(Rect2(sx - 1, sy, 3, 1), Color("#8EE6FF"))
	draw_rect(Rect2(sx, sy - 1, 1, 3), Color("#8EE6FF"))
