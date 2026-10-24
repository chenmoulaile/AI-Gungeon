extends Node2D
## 手持装置：始终精确指向瞄准方向（不受角色朝向过渡影响）
## 纯程序化像素绘制，旋转轴在握把处，朝左时垂直翻转避免上下颠倒

const BODY := Color("#3b4560")
const EDGE := Color("#1a2033")
const GRIP := Color("#2a3147")
const TIP := Color("#7fe6ff")
const ACCENT := Color("#9fb6e8")

var flip: float = 1.0
var style: String = "gun"


func set_aim(dir: Vector2) -> void:
	rotation = dir.angle()
	# 朝左时上下翻转，保持握把在下
	scale.y = -1.0 if absf(dir.angle()) > PI * 0.5 else 1.0


func muzzle_local() -> Vector2:
	return Vector2(13, 0) * Vector2(1, scale.y)


func _draw() -> void:
	if style == "staff":
		_draw_staff()
		return
	# 握把
	draw_rect(Rect2(-2, 1, 3, 4), GRIP)
	# 机身
	draw_rect(Rect2(-5, -2, 9, 4), BODY)
	draw_rect(Rect2(-5, -2, 9, 1), ACCENT)
	# 枪管
	draw_rect(Rect2(4, -1, 7, 2), BODY)
	draw_rect(Rect2(4, -1, 7, 1), ACCENT)
	# 枪口
	draw_rect(Rect2(11, -1, 2, 3), TIP)
	# 描边
	draw_polyline(PackedVector2Array([
		Vector2(-5, 2), Vector2(4, 2), Vector2(4, 1), Vector2(13, 1)]), EDGE, 1.0)
	draw_line(Vector2(-5, -2), Vector2(4, -2), EDGE, 1.0)


## GPT：短权杖，顶端龙爪镶宝石
func _draw_staff() -> void:
	var wood := Color("#5a3a22")
	var wood_hi := Color("#7d5533")
	var gold := Color("#e8b64a")
	var gem := Color("#8fe6c8")
	# 杖身
	draw_rect(Rect2(-2, -1.5, 13, 3), wood)
	draw_rect(Rect2(-2, -1.5, 13, 1), wood_hi)
	draw_line(Vector2(-2, 1.5), Vector2(11, 1.5), Color(0.16, 0.09, 0.05), 1.0)
	# 龙爪托
	draw_colored_polygon(PackedVector2Array([
		Vector2(11, -4.5), Vector2(15, -1.0), Vector2(11, 1.0)]), gold)
	draw_colored_polygon(PackedVector2Array([
		Vector2(11, 4.5), Vector2(15, 1.0), Vector2(11, -1.0)]), gold.darkened(0.15))
	# 宝石
	draw_circle(Vector2(14, 0), 2.6, gem)
	draw_circle(Vector2(13.2, -0.8), 0.9, Color(1, 1, 1, 0.9))
	draw_arc(Vector2(14, 0), 2.6, 0.0, TAU, 12, Color(0.35, 0.62, 0.52), 0.8, true)
