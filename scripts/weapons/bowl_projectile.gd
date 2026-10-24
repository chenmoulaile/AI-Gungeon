extends Node2D
## 投掷中的饭盆：抛物线飞行 + 自旋，落地后炸开并留下白饭减速区

const BowlTex := "res://assets/weapons/deepseek_starter.png"
const ZoneScript = preload("res://scripts/weapons/slow_zone.gd")

var dir: Vector2 = Vector2.RIGHT
var speed: float = 330.0
var travel: float = 150.0
var damage: float = 18.0
var radius: float = 50.0

var _t: float = 0.0
var _total: float = 0.45
var _start: Vector2 = Vector2.ZERO
var _tex: Texture2D = null
var _spin: float = 0.0


func _ready() -> void:
	if ResourceLoader.exists(BowlTex):
		_tex = load(BowlTex)
	add_to_group("bullets")
	_start = global_position
	_total = maxf(0.12, travel / speed)
	z_index = 2


func _process(delta: float) -> void:
	_t += delta
	_spin += delta * 14.0
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
	# 地面投影
	draw_set_transform(Vector2(0, 14), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2(0, -arc), _spin, Vector2.ONE)
	if _tex != null:
		draw_texture_rect(_tex, Rect2(-9, -9, 18, 18), false)
	else:
		draw_circle(Vector2.ZERO, 8.0, Color(0.92, 0.95, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
