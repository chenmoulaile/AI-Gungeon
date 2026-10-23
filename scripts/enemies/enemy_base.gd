extends Node2D
class_name EnemyBase
## 敌人基类：血量、受击反馈（闪白/击退/硬直）、死亡爆散、掉落
## 精英怪：血量 ×1.55、体积略大，用外圈标出

const BulletScript = preload("res://scripts/weapons/bullet.gd")
const CoinScript = preload("res://scripts/systems/coin.gd")

signal died(enemy: Node)

static var _pixel_mat: ShaderMaterial = null

var max_hp: float = 12.0
var hp: float = 12.0
var speed: float = 44.0
var radius: float = 9.0
var contact_damage: int = 1
var accent: Color = Color("#ff6b8b")
var coin_value: int = 2
var is_boss: bool = false
var elite: bool = false
var mini: bool = false
var mini_speed_scale: float = 1.0
var hp_scale: float = 1.0
var dead: bool = false

var player = null
var t: float = 0.0
var contact_cd: float = 0.0
var knock_vel: Vector2 = Vector2.ZERO
var stun: float = 0.0
var last_hit_tag: String = ""


func _ready() -> void:
	add_to_group("enemies")
	player = GameState.player
	_setup()
	if elite:
		max_hp *= 1.55
		radius *= 1.08
		coin_value += 2
	if hp_scale != 1.0:
		max_hp *= hp_scale
	if mini:
		max_hp = maxf(3.0, max_hp * 0.22)
		radius *= 0.62
		speed *= mini_speed_scale
		coin_value = 1
	hp = max_hp
	GameState.register_enemy(self)
	queue_redraw()


func _apply_pixel_light() -> void:
	if _pixel_mat == null:
		var path := "res://shaders/pixel_light.gdshader"
		if ResourceLoader.exists(path):
			_pixel_mat = ShaderMaterial.new()
			_pixel_mat.shader = load(path)
			_pixel_mat.set_shader_parameter("pixel_size", 2.0)
	if _pixel_mat != null:
		material = _pixel_mat


## 子类初始化数值
func _setup() -> void:
	pass


func _physics_process(delta: float) -> void:
	if dead:
		return
	t += delta
	contact_cd = maxf(0.0, contact_cd - delta)
	stun = maxf(0.0, stun - delta)

	if player == null or not is_instance_valid(player):
		player = GameState.player

	if stun <= 0.0:
		_ai(delta)

	if knock_vel.length() > 1.0:
		position += knock_vel * delta
		knock_vel = knock_vel.lerp(Vector2.ZERO, clampf(delta * 11.0, 0.0, 1.0))
	else:
		knock_vel = Vector2.ZERO

	_clamp_in_room()
	_touch_player()
	queue_redraw()


func _ai(_delta: float) -> void:
	pass


func _clamp_in_room() -> void:
	var r := GameConfig.room_rect().grow(-GameConfig.WALL - radius)
	position.x = clampf(position.x, r.position.x, r.end.x)
	position.y = clampf(position.y, r.position.y, r.end.y)
	# 障碍物：从最近的一边推出去
	for o in GameState.obstacles:
		var rect: Rect2 = o
		if rect.grow(radius).has_point(global_position):
			var c := rect.get_center()
			var d := global_position - c
			if absf(d.x / rect.size.x) > absf(d.y / rect.size.y):
				global_position.x = rect.position.x - radius if d.x < 0.0 \
					else rect.end.x + radius
			else:
				global_position.y = rect.position.y - radius if d.y < 0.0 \
					else rect.end.y + radius


func _touch_player() -> void:
	if contact_cd > 0.0 or player == null or not is_instance_valid(player):
		return
	if not player.alive:
		return
	if global_position.distance_to(player.global_position) < radius + GameConfig.PLAYER_RADIUS:
		contact_cd = 0.7
		player.take_damage(contact_damage)


## 盾卫等正面免伤的敌人覆写这个方法
func blocks_hit(_bullet_dir: Vector2) -> bool:
	return false


## 子弹被挡下时的反馈（金属叮 + 火花 + light 硬直）
func on_blocked(pos: Vector2, _dir: Vector2) -> void:
	Sfx.play_at("clang", pos, 0.0, 1.0)
	GameFeel.burst(pos, Color(1.0, 0.95, 0.7), 6, 110.0, 0.22)
	GameFeel.hit_stop(0.04, 0.08)


func hp_ratio() -> float:
	return clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)


func take_damage(dmg: float, dir: Vector2 = Vector2.ZERO, tier: String = "medium",
		crit: bool = false, tag: String = "") -> void:
	if dead:
		return
	if tag != "":
		last_hit_tag = tag
	hp -= dmg
	var preset := tier
	if preset == "small":
		preset = "light"
	elif preset == "large":
		preset = "heavy"
	GameFeel.impact(preset, global_position + Vector2(0, -radius * 0.7), self, dir, dmg,
		crit, Color(2.8, 2.8, 2.8), accent.lightened(0.45))
	if preset != "light" and not is_boss:
		stun = 0.055
	if hp <= 0.0:
		_die()


func _die() -> void:
	if dead:
		return
	dead = true
	GameState.unregister_enemy(self)
	GameState.on_enemy_killed(last_hit_tag)
	if GameState.player != null and is_instance_valid(GameState.player):
		GameState.player.on_kill()
	GameFeel.burst(global_position + Vector2(0, -radius * 0.5), accent,
		20 if elite else 14, 150.0, 0.42)
	GameFeel.screen_shake(0.18 if elite else 0.12)
	_drop_coins()
	died.emit(self)
	queue_free()


func _drop_coins() -> void:
	if GameState.bullets_root == null:
		return
	for i in coin_value:
		var c: Node2D = CoinScript.new()
		c.value = 1
		c.global_position = global_position + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		GameState.bullets_root.add_child(c)


# ---------------- 敌方子弹 ----------------
func shoot_at(dir: Vector2, speed: float = 155.0, bullet_radius: float = 3.8,
		homing: float = 0.0, homing_time: float = 0.0) -> void:
	if GameState.bullets_root == null:
		return
	var b: Node = GameFeel.get_bullet()
	if b == null:
		return
	b.friendly = false
	b.dir = dir.normalized()
	b.speed = speed
	b.damage = 1.0
	b.radius = bullet_radius
	b.color = Color("#ff5d7a") if not Settings.high_contrast else Color("#ff2d55")
	b.life = 4.5
	b.homing = homing
	b.homing_time = homing_time
	b.pierce = 0
	b.gen = 0
	b.trail = false
	b.crit = false
	b.tier = "medium"
	b.global_position = global_position + dir.normalized() * (radius + 2.0)
	b.prepare()


# ---------------- 绘制 ----------------
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2(0, radius * 0.7), radius * 1.05, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_body()
	if elite:
		var pulse: float = 0.35 + 0.2 * sin(t * 4.0)
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 24,
			Color(1.0, 0.82, 0.35, pulse), 1.5, true)


func _draw_body() -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0 + t * 0.6
		pts.append(Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, accent)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0, 0, 0, 0.85), 1.6)
	draw_circle(Vector2(0, -1), radius * 0.38, Color(1, 1, 1, 0.95))
	draw_circle(Vector2(0, -1), radius * 0.2, Color(0.05, 0.03, 0.08, 1.0))
