extends Node2D
## 障碍物视觉：原点在底边中点，配合 Y-Sort 与角色互相遮挡

var size: Vector2 = Vector2(50, 50)
var theme: Dictionary = {}


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var rr := Rect2(-size.x * 0.5, -size.y, size.x, size.y)
	# 地面投影（硬边）
	draw_rect(Rect2(rr.position.x + 3.0, -6.0, rr.size.x, 6.0), Color(0, 0, 0, 0.26))
	var base: Color = theme.get("wall", Color("#162326"))
	var top: Color = theme.get("wall_top", Color("#2B3F44"))
	var edge: Color = theme.get("wall_edge", Color("#05090A"))
	draw_rect(rr, base.lightened(0.06))
	draw_rect(Rect2(rr.position, Vector2(rr.size.x, 6.0)), top)
	draw_rect(Rect2(rr.position, Vector2(rr.size.x, 1.0)), top.lightened(0.12))
	draw_rect(rr, edge, false, 1.0)
	draw_rect(Rect2(rr.position.x, -2.0, rr.size.x, 2.0), edge)
	# 数据故障小方块（整数 4×4）
	for i in 3:
		var x := rr.position.x + 6.0 + float(i) * (rr.size.x - 12.0) / 2.0
		draw_rect(Rect2(x, rr.position.y + 10.0, 4.0, 4.0), top.lightened(0.30))
