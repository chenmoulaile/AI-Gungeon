extends Node2D
## 角色“活着的细节”：程序化像素配饰 + Tween 摆动
## DeepSeek 鲸尾（局部旋转 ±8°）/ GPT 龙翼（局部缩放 1.00→1.08）/ Claude 向日葵（±5°）
## 全部用矩形块绘制，保持像素风；不依赖额外美术资源

const TAIL_FILL := Color("#4c63c4")
const TAIL_DARK := Color("#1b2350")
const TAIL_LIGHT := Color("#8fa6ef")
const WING_FILL := Color("#b9c0e0")
const WING_EDGE := Color("#454a6b")
const WING_DARK := Color("#9aa0c4")
const PETAL := Color("#f2b13c")
const PETAL_DARK := Color("#b87a1c")
const SEED := Color("#6b4a1f")

var char_id: String = "deepseek"
var sway: float = 0.0     # -1..1，Tween 驱动
var flap: float = 1.0     # 龙翼缩放
var spin: float = 0.0     # 向日葵摆动


func setup(id: String) -> void:
	char_id = id
	z_index = 0
	if char_id == "claude":
		z_index = 1
		position = Vector2(9, -41)
	elif char_id == "gpt":
		position = Vector2(0, -32)
	else:
		position = Vector2(8, -10)
	_start_tweens()


func _start_tweens() -> void:
	match char_id:
		"deepseek":
			# 尾巴缓慢摆 ±8°（周期 2.5s），偶尔快速扇一下
			var tw := create_tween().set_loops()
			tw.tween_property(self, "sway", 1.0, 1.25)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(self, "sway", -1.0, 1.25)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"gpt":
			var tw2 := create_tween().set_loops()
			tw2.tween_property(self, "flap", 1.08, 1.5)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw2.tween_property(self, "flap", 1.0, 1.5)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"claude":
			var tw3 := create_tween().set_loops()
			tw3.tween_property(self, "spin", 1.0, 1.0)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw3.tween_property(self, "spin", -1.0, 1.0)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	match char_id:
		"deepseek":
			_draw_tail()
		"gpt":
			_draw_wings()
		"claude":
			_draw_flower()


## 鲸尾：三节鳍片，绕根部旋转 ±8°
func _draw_tail() -> void:
	draw_set_transform(Vector2.ZERO, deg_to_rad(sway * 8.0), Vector2.ONE)
	# 尾柄
	draw_rect(Rect2(-2, 0, 5, 4), TAIL_FILL)
	# 鳍片：两段，向斜上方展开
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, 1), Vector2(12, -2), Vector2(15, -8), Vector2(7, -7)]), TAIL_FILL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, 5), Vector2(10, 5), Vector2(13, 1), Vector2(3, 1)]), TAIL_FILL)
	draw_polyline(PackedVector2Array([
		Vector2(-2, 4), Vector2(2, 1), Vector2(12, -2), Vector2(15, -8)]), TAIL_DARK, 1.2)
	draw_polyline(PackedVector2Array([
		Vector2(-2, 4), Vector2(2, 5), Vector2(10, 5), Vector2(13, 1)]), TAIL_DARK, 1.2)
	draw_line(Vector2(4, 0), Vector2(9, -5), TAIL_LIGHT, 1.0)
	draw_line(Vector2(4, 3), Vector2(9, 3), TAIL_LIGHT, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 龙翼：左右各一片，缩放扇动
func _draw_wings() -> void:
	for side in [-1.0, 1.0]:
		var base := Vector2(side * 5.0, 0)
		var pts := PackedVector2Array([
			base,
			base + Vector2(side * 8.0, -8.0) * flap,
			base + Vector2(side * 12.0, -4.0) * flap,
			base + Vector2(side * 10.0, -1.0) * flap,
			base + Vector2(side * 12.0, 4.0) * flap,
			base + Vector2(side * 6.0, 6.0) * flap,
		])
		draw_colored_polygon(pts, WING_FILL)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, WING_EDGE, 1.2)
		draw_line(base, base + Vector2(side * 10.0, 0.0) * flap, WING_DARK, 1.0)


## 向日葵：8 片花瓣 + 花心，整体 ±5°
func _draw_flower() -> void:
	draw_set_transform(Vector2.ZERO, deg_to_rad(spin * 5.0), Vector2.ONE)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var c := Vector2(cos(a), sin(a)) * 3.6
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), PETAL)
	draw_rect(Rect2(-2, -2, 4, 4), PETAL_DARK)
	draw_rect(Rect2(-1, -1, 2, 2), SEED)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
