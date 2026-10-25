extends Node2D
## 投掷中的大白饭：抛物线飞行（像素 2 帧浮动），落地炸开并留下白饭减速区

const ZoneScript = preload("res://scripts/weapons/slow_zone.gd")

var dir: Vector2 = Vector2.RIGHT
var speed: float = 330.0
var travel: float = 150.0
var damage: float = 18.0
var radius: float = 50.0

var _t: float = 0.0
var _total: float = 0.45
var _start: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("bullets")
	_start = global_position
	_total = maxf(0.12, travel / speed)
	z_index = 2


func _process(delta: float) -> void:
	_t += delta
	var k: float = clampf(_t / _total, 0.0, 1.0)
	global_position = _start + dir * travel * k
	if _t >= _total:
		_land()
		return
	queue_redraw()


func _land() -> void:
	for e in GameState.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		if global_position.distance_to(e.global_position) <= radius + float(e.radius) * 0.5:
			e.take_damage(damage, dir, "medium", false, "rice_bowl")
			if GameState.player != null and is_instance_valid(GameState.player):
				GameState.player.record_hit(e)
	var zone = ZoneScript.new()
	zone.radius = radius
	zone.life = 2.0
	zone.slow = 0.55
	zone.color = Color(0.95, 0.97, 1.0)
	zone.global_position = global_position
	GameState.bullets_root.add_child(zone)
	GameFeel.burst(global_position, Color(1.0, 0.98, 0.92), 10, 120.0, 0.3)
	GameFeel.shards(global_position, Color(0.85, 0.90, 1.0), 6, 130.0, 0.3)
	Sfx.play("bounce", -4.0, 0.8)
	Sfx.play("crack", -8.0, 1.2)
	queue_free()


func _draw() -> void:
	var k: float = clampf(_t / _total, 0.0, 1.0)
	var arc: float = sin(k * PI) * 26.0
	# 地面投影：3 行硬边像素，不用圆
	draw_rect(Rect2(-5, 14, 10, 1), Color(0, 0, 0, 0.24))
	draw_rect(Rect2(-7, 15, 14, 1), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(-4, 16, 8, 1), Color(0, 0, 0, 0.12))
	# 抛出的白饭团：2 帧上下浮动，不旋转，保持像素网格
	var y := -roundf(arc) - float(int(_t * 18.0) % 2)
	var edge := Color("#7FB7E8")
	var rice := Color("#F4F6FF")
	var rice_lo := Color("#C9D4EE")
	var blue := Color("#2E5BD0")
	# 1px 浅蓝描边（阶梯轮廓）
	draw_rect(Rect2(-4, y - 9, 8, 2), edge)
	draw_rect(Rect2(-7, y - 7, 14, 4), edge)
	draw_rect(Rect2(-8, y - 3, 16, 7), edge)
	draw_rect(Rect2(-6, y + 4, 12, 3), edge)
	draw_rect(Rect2(-3, y + 7, 6, 1), edge)
	# 白饭
	draw_rect(Rect2(-3, y - 8, 6, 2), rice)
	draw_rect(Rect2(-6, y - 6, 12, 4), rice)
	draw_rect(Rect2(-7, y - 2, 14, 5), rice)
	draw_rect(Rect2(-5, y + 3, 10, 2), rice)
	draw_rect(Rect2(-3, y + 5, 6, 1), rice_lo)
	# 饭粒与蓝色粮票
	draw_rect(Rect2(-5, y - 5, 2, 1), Color("#FFFFFF"))
	draw_rect(Rect2(-1, y - 3, 1, 2), Color("#D6DEFA"))
	draw_rect(Rect2(1, y, 2, 1), Color("#FFFFFF"))
	draw_rect(Rect2(-6, y + 1, 2, 2), blue)
	draw_rect(Rect2(4, y + 2, 2, 2), blue)
	draw_rect(Rect2(-2, y + 4, 4, 1), rice_lo)
