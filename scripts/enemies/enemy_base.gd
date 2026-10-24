extends Node2D
class_name EnemyBase
## 敌人基类：血量、受击反馈（闪白/击退/硬直）、死亡爆散、掉落
## 精英怪：血量 ×1.55、体积略大，用外圈标出

const BulletScript = preload("res://scripts/weapons/bullet.gd")
const CoinScript = preload("res://scripts/systems/coin.gd")
const TelegraphScript = preload("res://scripts/fx/telegraph.gd")

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
var hit_off: float = 0.0
## 深度检索标记：标记期间受到的所有伤害 +15%
var mark_t: float = 0.0
## GPT「贪婪权杖」财富标记层数（0~3）
var wealth_stacks: int = 0
## Claude「律令」区域：区域内移速降低、受到伤害 +12%
var slow_mult: float = 1.0
var slow_t: float = 0.0
var law_t: float = 0.0


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
	max_hp *= SeedManager.diff("hp")
	contact_damage = maxi(1, int(round(float(contact_damage) * SeedManager.diff("dmg"))))
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
	mark_t = maxf(0.0, mark_t - delta)
	law_t = maxf(0.0, law_t - delta)
	if slow_t > 0.0:
		slow_t -= delta
		if slow_t <= 0.0:
			slow_mult = 1.0

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
	if mark_t > 0.0:
		dmg *= 1.15
	if law_t > 0.0:
		dmg *= 1.15
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
	_shake_hit()
	if hp <= 0.0:
		_die()


## 受击水平抖动 2~3px（Tween，不用手写插值）
func _shake_hit() -> void:
	var tw := create_tween()
	tw.tween_property(self, "hit_off", 3.0, 0.03)
	tw.tween_property(self, "hit_off", -2.5, 0.03)
	tw.tween_property(self, "hit_off", 0.0, 0.02)


func _die() -> void:
	if dead:
		return
	dead = true
	GameState.unregister_enemy(self)
	GameState.on_enemy_killed(last_hit_tag)
	if GameState.player != null and is_instance_valid(GameState.player):
		GameState.player.on_kill()
	# 碎成 6~8 个小方块，重力下坠 + 0.4s 淡出
	var shard_n: int = 10 if elite else 8
	GameFeel.shards(global_position + Vector2(0, -radius * 0.5), accent, shard_n, 160.0, 0.4)
	GameFeel.screen_shake(0.18 if elite else 0.12)
	_drop_coins()
	died.emit(self)
	queue_free()


func _drop_coins() -> void:
	if GameState.bullets_root == null:
		return
	var n: int = maxi(1, int(round(float(coin_value) * SeedManager.diff("coin"))))
	for i in n:
		var c: Node2D = CoinScript.new()
		c.value = 1
		c.global_position = global_position + Vector2(SeedManager.randf_range(-6, 6), SeedManager.randf_range(-6, 6))
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
	b.speed = speed * SeedManager.diff("bullet")
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
	# 枪口弹道线：让玩家一眼看出这一发的来向
	if GameState.bullets_root != null and is_instance_valid(GameState.bullets_root):
		var tg = TelegraphScript.new()
		GameState.bullets_root.add_child(tg)
		tg.setup(b.global_position, b.global_position + dir.normalized() * 70.0, 0.14,
			Color(1.0, 0.34, 0.40, 0.5), 1.0)


# ---------------- 绘制 ----------------
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2(0, radius * 0.7), radius * 1.05, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2(hit_off, 0), 0.0, Vector2.ONE)
	_draw_body()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 贪婪权杖：金币标记（最多 3 层）
	if wealth_stacks > 0:
		for i in wealth_stacks:
			var wx: float = -6.0 + float(i) * 6.0
			var wy: float = -radius - 6.0
			draw_rect(Rect2(wx - 2.0, wy - 2.0, 4.0, 4.0), Color(1.0, 0.84, 0.30, 0.95))
			draw_rect(Rect2(wx - 2.0, wy - 2.0, 4.0, 4.0), Color(0.42, 0.28, 0.04, 0.9), false, 1.0)
	# 律令标记：头顶陶土色圆环
	if law_t > 0.0:
		var ly: float = -radius - 13.0
		draw_arc(Vector2(0, ly), 4.2, 0.0, TAU, 12, Color(0.98, 0.74, 0.44, 0.9), 1.2, true)
		draw_circle(Vector2(0, ly), 1.4, Color(1.0, 0.90, 0.72, 0.95))
	if elite:
		var pulse: float = 0.35 + 0.2 * sin(t * 4.0)
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 24,
			Color(1.0, 0.82, 0.35, pulse), 1.5, true)
	# 深度检索标记：头顶蓝色三角，快消失时闪烁
	if mark_t > 0.0:
		var a: float = 1.0
		if mark_t < 0.8:
			a = 0.45 + 0.55 * absf(sin(t * 14.0))
		var ty := -radius - 8.0
		var tri := PackedVector2Array([
			Vector2(0, ty - 4.0), Vector2(3.4, ty + 1.6), Vector2(-3.4, ty + 1.6)])
		draw_colored_polygon(tri, Color(0.42, 0.68, 1.0, a))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]),
			Color(0.16, 0.32, 0.62, a * 0.9), 1.0)


## 数据故障碎片：沿轮廓撒几个 2px 亮点，随时间闪烁
func glitch_fragments(count: int, r: float, off: float = 0.0) -> void:
	for i in count:
		var a: float = TAU * float(i) / float(count) + t * 1.7 + off
		var rr: float = r * (0.85 + 0.30 * sin(t * 3.0 + float(i)))
		var p := Vector2(cos(a), sin(a)) * rr
		if fmod(t * 6.0 + float(i) * 0.37, 3.0) < 1.2:
			draw_rect(Rect2(p - Vector2(1.0, 1.0), Vector2(2.0, 2.0)),
				Color(accent.r, accent.g, accent.b, 0.9))


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
