extends Node2D
class_name EnemyBase
## 敌人基类：血量、受击反馈（闪白/击退/硬直）、死亡爆散、掉落
## 具体行为由子类覆写 _setup() / _ai()

const BulletScript = preload("res://scripts/weapons/bullet.gd")
const CoinScript = preload("res://scripts/systems/coin.gd")

signal died(enemy: Node)

var max_hp: float = 12.0
var hp: float = 12.0
var speed: float = 44.0
var radius: float = 9.0
var contact_damage: int = 1
var accent: Color = Color("#ff6b8b")
var coin_value: int = 2
var is_boss: bool = false
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
	GameState.register_enemy(self)
	queue_redraw()


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

	# 受击硬直期间不行动，但仍会被击退
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


func _touch_player() -> void:
	if contact_cd > 0.0 or player == null or not is_instance_valid(player):
		return
	if not player.alive:
		return
	if global_position.distance_to(player.global_position) < radius + GameConfig.PLAYER_RADIUS:
		contact_cd = 0.7
		player.take_damage(contact_damage)


func hp_ratio() -> float:
	return clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)


## dir / tier / crit 由子弹传入，决定反馈强度
func take_damage(dmg: float, dir: Vector2 = Vector2.ZERO, tier: String = "medium",
		crit: bool = false, tag: String = "") -> void:
	if dead:
		return
	if tag != "":
		last_hit_tag = tag
	hp -= dmg
	GameFeel.impact(tier, global_position + Vector2(0, -radius * 0.7), self, dir, dmg,
		crit, Color(2.8, 2.8, 2.8), accent.lightened(0.45))
	if tier != "small" and not is_boss:
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
	# 死亡爆散：一次大粒子 + 轻微震屏
	GameFeel.burst(global_position + Vector2(0, -radius * 0.5), accent, 14, 150.0, 0.42)
	GameFeel.screen_shake(0.12)
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
	b.color = Color("#ff5d7a")
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
