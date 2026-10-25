extends Node2D
## 子代里（v0.9）：DeepSeek 技能「鲸群集结」召唤物
## 形象是 DeepSeek 角色精灵的缩小版；跟随玩家、自动索敌吐泡泡；14s 后淡出。

const MINI_TEX: Texture2D = preload("res://assets/sprites/deepseek/idle.png")
## 子代里手上的武器：铁盆概率更高，饭盆概率较低（都按 2px 块画，和缩小版身体同风格）
const BASIN_CHANCE := 0.7

var player = null
var slot: int = 0
var life: float = 14.0
var fire_gap: float = 0.72
var damage: float = 4.0
var weapon_kind: String = "basin"

var _t: float = 0.0
var _fire_t: float = 0.3
var _dir: int = 1
var _bob: int = 0


func _ready() -> void:
	add_to_group("fish_minions")
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fire_t = 0.2 + 0.18 * float(slot % 4)
	# 每只子代里独立随机：铁盆 70%，饭盆 30%
	weapon_kind = "basin" if SeedManager.randf() < BASIN_CHANCE else "bowl"


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not player.alive:
		queue_free()
		return
	_t += delta
	life -= delta
	if life <= 0.0:
		_expire()
		return
	if life < 1.2:
		modulate.a = maxf(0.0, life / 1.2)

	var target := _nearest()
	var anchor: Vector2 = player.global_position + Vector2(0, -18)
	if target == null:
		var a := _t * 1.7 + float(slot) * 2.1
		anchor += Vector2(cos(a), sin(a) * 0.55) * (30.0 + float(slot % 3) * 10.0)
	else:
		var to: Vector2 = target.global_position - player.global_position
		var side := 1.0 if float(slot % 2) == 0.0 else -1.0
		anchor = target.global_position + to.normalized().orthogonal() * side * (34.0 + float(slot % 3) * 8.0)
		anchor.y -= 12.0
	global_position = global_position.lerp(anchor, 1.0 - exp(-5.0 * delta))
	if absf(anchor.x - global_position.x) > 2.0:
		_dir = 1 if anchor.x > global_position.x else -1
	_bob = int(_t * 6.0) % 2

	_fire_t -= delta
	if _fire_t <= 0.0 and target != null:
		_fire_t = fire_gap
		_shoot(target)
	queue_redraw()


func _nearest() -> Node:
	var best = null
	var bd := 240.0
	for e in GameState.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _shoot(target: Node) -> void:
	var b = GameFeel.get_bullet()
	if b == null:
		return
	b.friendly = true
	b.dir = (target.global_position - global_position).normalized()
	b.speed = 340.0
	b.damage = damage
	b.crit = false
	b.radius = 3.0
	b.life = 1.8
	b.color = Color("#8EE6FF")
	b.pierce = 0
	b.gen = 0
	b.homing = 1.8
	b.homing_time = 0.9
	b.tier = "light"
	b.trail = true
	b.tag = "fish"
	b.global_position = global_position
	b.prepare()
	Sfx.play("shoot", -18.0, 1.8)


func _expire() -> void:
	GameFeel.burst(global_position, Color(0.55, 0.85, 1.0), 6, 70.0, 0.3)
	queue_free()


func _draw() -> void:
	# 影子
	draw_rect(Rect2(-8, 9, 16, 3), Color(0.04, 0.06, 0.12, 0.35))
	# 缩小版角色（复用 DeepSeek 待机帧，两帧呼吸 + 朝向翻转）
	var region := Rect2(float(_bob % 2) * 64.0, 0, 64, 64)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(_dir), 1.0))
	draw_texture_rect_region(MINI_TEX, Rect2(-13, -14, 26, 26), region)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 手上武器：铁盆（多）/ 饭盆（少），随朝向翻到身体外侧
	_draw_held_prop()
	# 头顶小水泡
	if int(_t * 3.0) % 4 == 0:
		draw_rect(Rect2(7, -16, 2, 2), Color(0.78, 0.94, 1.0, 0.7))


## 手上小武器（整像素块）：铁盆 70% / 大白饭盆 30%
func _draw_held_prop() -> void:
	var edge := Color("#15224A")
	var blue := Color("#2E5BD0")
	var hi := Color("#86E3FF")
	var rice := Color("#F4F6FF")
	var ox := 7.0 * float(_dir)
	var oy := -1.0
	if weapon_kind == "basin":
		# 宽口浅盆：黑描边 + 蓝搪瓷 + 白饭
		draw_rect(Rect2(ox - 4, oy - 1, 9, 1), edge)
		draw_rect(Rect2(ox - 5, oy, 10, 1), edge)
		draw_rect(Rect2(ox - 4, oy + 1, 9, 3), edge)
		draw_rect(Rect2(ox - 3, oy + 4, 7, 1), edge)
		draw_rect(Rect2(ox - 4, oy, 9, 3), blue)
		draw_rect(Rect2(ox - 3, oy + 3, 7, 1), Color("#1B3A8F"))
		draw_rect(Rect2(ox - 4, oy, 9, 1), hi)
		draw_rect(Rect2(ox - 3, oy - 1, 7, 1), rice)
		draw_rect(Rect2(ox - 1, oy - 2, 4, 1), rice)
	else:
		# 大白饭碗：窄一圈的蓝碗
		draw_rect(Rect2(ox - 3, oy - 1, 7, 1), edge)
		draw_rect(Rect2(ox - 4, oy, 8, 4), edge)
		draw_rect(Rect2(ox - 3, oy + 4, 6, 1), edge)
		draw_rect(Rect2(ox - 3, oy, 7, 3), blue)
		draw_rect(Rect2(ox - 2, oy + 3, 5, 1), Color("#1B3A8F"))
		draw_rect(Rect2(ox - 3, oy, 7, 1), hi)
		draw_rect(Rect2(ox - 2, oy - 2, 6, 2), rice)
		draw_rect(Rect2(ox - 1, oy - 3, 4, 1), rice)
