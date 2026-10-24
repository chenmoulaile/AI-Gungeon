extends Node2D
## 障碍物视觉：原点在底边中点，配合 Y-Sort 与角色互相遮挡

var size: Vector2 = Vector2(50, 50)
var theme: Dictionary = {}


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var rr := Rect2(-size.x * 0.5, -size.y, size.x, size.y)
	# 地面投影
	draw_rect(Rect2(rr.position.x + 3.0, -6.0, rr.size.x, 7.0), Color(0, 0, 0, 0.20))
	var base: Color = theme.get("wall", Color(0.2, 0.22, 0.3))
	draw_rect(rr, base.lightened(0.04))
	draw_rect(rr, base.lightened(0.22), false, 2.0)
	draw_rect(Rect2(rr.position, Vector2(rr.size.x, 6)), base.lightened(0.30))
	draw_rect(Rect2(rr.position.x, -8.0, rr.size.x, 8.0), base.darkened(0.28))
	# 数据故障小方块
	for i in 3:
		var x := rr.position.x + 6.0 + float(i) * (rr.size.x - 12.0) / 2.0
		draw_rect(Rect2(x, rr.position.y + 10.0, 4.0, 4.0), base.lightened(0.45))
