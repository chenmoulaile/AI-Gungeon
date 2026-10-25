extends Node2D
## 角色“活着的细节”：程序化像素配饰 + 离散整数帧摆动
## DeepSeek 鲸尾 / GPT 龙翼 / Claude 向日葵
## 全部用整数像素 rect 拼（禁止 polygon 与亚像素旋转）：摆动只切换 3 个整数偏移姿态，
## 和 1px 描边的角色帧放在一起才不会出现"平滑配饰 + 像素身体"的割裂感。

const TAIL_FILL := Color("#4c63c4")
const TAIL_DARK := Color("#1b2350")
const TAIL_LIGHT := Color("#8fa6ef")
const WING_FILL := Color("#b9c0e0")
const WING_EDGE := Color("#454a6b")
const WING_DARK := Color("#9aa0c4")
const PETAL := Color("#f2b13c")
const PETAL_DARK := Color("#b87a1c")
const SEED := Color("#6b4a1f")

## 向日葵花瓣中心的三个离散姿态（顺时针/正中/逆时针），整数坐标，不做旋转变换
const FLOWER_POSES := [
	[Vector2i(4, 0), Vector2i(3, 3), Vector2i(0, 4), Vector2i(-3, 3),
	 Vector2i(-4, 0), Vector2i(-3, -3), Vector2i(0, -4), Vector2i(3, -3)],
	[Vector2i(3, 1), Vector2i(1, 3), Vector2i(-1, 3), Vector2i(-3, 1),
	 Vector2i(-3, -1), Vector2i(-1, -3), Vector2i(1, -3), Vector2i(3, -1)],
	[Vector2i(3, -1), Vector2i(1, -3), Vector2i(-1, -3), Vector2i(-3, -1),
	 Vector2i(-3, 1), Vector2i(-1, 3), Vector2i(1, 3), Vector2i(3, 1)],
]

var char_id: String = "deepseek"
var sway: float = 0.0     # -1..1，Tween 驱动，取整后是 3 个姿态
var flap: float = 0.0     # 0..2，龙翼三档高度
var spin: float = 0.0     # -1..1，向日葵三档
var home := Vector2.ZERO  # 各角色的固定挂点，弹簧甩动只在它之上做整数偏移


func setup(id: String) -> void:
	char_id = id
	z_index = 0
	if char_id == "claude":
		z_index = 1
		position = Vector2(9, -41)
	elif char_id == "gpt":
		position = Vector2(0, -32)
	else:
		# 鲸尾拖在脚边：手持物在胸口/手部高度，不会再盖住尾巴
		position = Vector2(9, -8)
	home = position
	_start_tweens()


## 弹簧甩动：只做整数像素平移。配饰一旦整体旋转，像素方块就会变成模糊的斜线。
func set_shake(v: Vector2) -> void:
	position = home + Vector2(roundf(v.x), roundf(v.y))


func _start_tweens() -> void:
	match char_id:
		"deepseek":
			# 尾巴缓慢摆 ±1 帧（周期 2.5s）
			var tw := create_tween().set_loops()
			tw.tween_property(self, "sway", 1.0, 1.25)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(self, "sway", -1.0, 1.25)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"gpt":
			var tw2 := create_tween().set_loops()
			tw2.tween_property(self, "flap", 2.0, 1.5)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw2.tween_property(self, "flap", 0.0, 1.5)\
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
			_draw_tail(int(round(sway)))
		"gpt":
			_draw_wings(int(round(flap)))
		"claude":
			_draw_flower(int(round(spin)) + 1)


func _rect(x: int, y: int, w: int, h: int) -> Rect2:
	return Rect2(float(x), float(y), float(w), float(h))


## 一组整数 rect（Vector4i：x, y, w, h）：先铺 1px 深色（并集即外描边），再盖填充色
func _pixel_shape(parts: Array, fill: Color, edge: Color) -> void:
	for r: Vector4i in parts:
		draw_rect(_rect(r.x - 1, r.y - 1, r.z + 2, r.w + 2), edge)
	for r: Vector4i in parts:
		draw_rect(_rect(r.x, r.y, r.z, r.w), fill)


## 鲸尾：尾柄 + 上下两级鳍片，p=-1/0/1 时鳍片反向起伏 1px
func _draw_tail(p: int) -> void:
	var parts := [
		Vector4i(-2, 0, 5, 4),
		Vector4i(1, -1 - p, 4, 2),
		Vector4i(4, -3 - p, 4, 2),
		Vector4i(8, -4 - p, 3, 2),
		Vector4i(1, 3 + p, 4, 2),
		Vector4i(4, 4 + p, 4, 2),
		Vector4i(8, 5 + p, 3, 2),
	]
	_pixel_shape(parts, TAIL_FILL, TAIL_DARK)
	draw_rect(_rect(3, -2 - p, 3, 1), TAIL_LIGHT)
	draw_rect(_rect(6, -3 - p, 2, 1), TAIL_LIGHT)
	draw_rect(_rect(4, 4 + p, 3, 1), TAIL_LIGHT)


## 龙翼：左右各三级翼骨，p=0/1/2 时整体上下移动 1px
func _draw_wings(p: int) -> void:
	var lift: int = p - 1
	var bars := [
		Vector4i(12, -2, 4, 3),
		Vector4i(15, -5, 4, 3),
		Vector4i(18, -7, 3, 2),
	]
	for side in [-1, 1]:
		var parts := []
		for b: Vector4i in bars:
			var x: int = b.x if side > 0 else -b.x - b.z
			parts.append(Vector4i(x, b.y + lift, b.z, b.w))
		_pixel_shape(parts, WING_FILL, WING_EDGE)
		draw_rect(_rect(14 if side > 0 else -17, -1 + lift, 3, 1), WING_DARK)


## 向日葵：8 片 2x2 花瓣 + 花心，只用整数坐标切换姿态
func _draw_flower(pose: int) -> void:
	var petals: Array = FLOWER_POSES[clampi(pose, 0, 2)]
	for c in petals:
		draw_rect(_rect(c.x - 1, c.y - 1, 2, 2), PETAL)
	draw_rect(_rect(-2, -2, 4, 4), PETAL_DARK)
	draw_rect(_rect(-1, -1, 2, 2), SEED)
