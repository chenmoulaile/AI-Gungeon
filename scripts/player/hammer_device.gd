extends Node2D
## Claude 的圣女法槌：木质短柄 + 陶土色槌头，敲击时向下挥动

var _swing: float = 0.0


func set_state(swing: float, player) -> void:
	_swing = swing
	if player != null and is_instance_valid(player):
		var aim: Vector2 = player.aim
		position = Vector2(0, -12) + aim * 11.0
		var swing_k: float = clampf(1.0 - swing / 0.22, 0.0, 1.0) if swing > 0.0 else 1.0
		rotation = aim.angle() + (lerpf(-0.9, 0.5, swing_k) if swing > 0.0 else 0.0)
		scale = Vector2(0.8, 0.8)
	queue_redraw()


func _draw() -> void:
	var wood := Color("#8a5a34")
	var wood_dark := Color("#5f3a1f")
	var clay := Color("#c98b62")
	var clay_hi := Color("#e0a97f")
	var gold := Color("#e6c07a")
	# 木柄
	draw_rect(Rect2(-10, -1.5, 12, 3), wood)
	draw_rect(Rect2(-10, -1.5, 12, 1), Color("#a06a40"))
	draw_line(Vector2(-10, 1.5), Vector2(2, 1.5), wood_dark, 1.0)
	# 槌头
	draw_rect(Rect2(1, -5, 9, 10), clay)
	draw_rect(Rect2(1, -5, 9, 2), clay_hi)
	draw_rect(Rect2(1, 3, 9, 2), clay.darkened(0.2))
	draw_rect(Rect2(1, -5, 9, 10), Color(0.35, 0.20, 0.12), false, 1.0)
	# 金色箍环
	draw_rect(Rect2(3.5, -5, 1.6, 10), gold)
	# 敲击时的冲击弧
	if _swing > 0.0:
		var k: float = 1.0 - _swing / 0.22
		draw_arc(Vector2(14, 0), 6.0 + k * 10.0, -0.9, 0.9, 10,
			Color(0.98, 0.85, 0.6, (1.0 - k) * 0.8), 1.6)
