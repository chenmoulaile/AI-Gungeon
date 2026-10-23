extends EnemyBase
## 盾卫：正面 180° 免疫子弹（叮 + 火花 + light 硬直），背面吃 1.5 倍伤害
## 移动缓慢，靠近后 0.4s 前摇挥击

const MELEE_RANGE := 34.0
const WINDUP := 0.4

var shield_normal: Vector2 = Vector2.RIGHT
var melee_cd: float = 0.0
var swing: float = 0.0


func _setup() -> void:
	max_hp = 26.0 * GameState.enemy_scale()
	hp = max_hp
	speed = 26.0
	radius = 12.0
	contact_damage = 1
	coin_value = 5
	accent = Color("#c9c2a8")
	melee_cd = SeedManager.randf_range(0.6, 1.2)


func _ai(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var to_player: Vector2 = player.global_position - global_position
	shield_normal = to_player.normalized()
	melee_cd = maxf(0.0, melee_cd - delta)
	if swing > 0.0:
		swing -= delta
		if swing <= 0.0 and global_position.distance_to(player.global_position) < MELEE_RANGE:
			player.take_damage(1)
			Sfx.play_at("hit", global_position, -2.0, 0.7)
			GameFeel.screen_shake(0.15)
		return
	if to_player.length() > MELEE_RANGE * 0.8:
		position += shield_normal * speed * delta
	elif melee_cd <= 0.0:
		melee_cd = 1.6
		swing = WINDUP


## 子弹从正面来（与盾面法线相反）时被挡下
func blocks_hit(bullet_dir: Vector2) -> bool:
	return bullet_dir.dot(shield_normal) < -0.15


func take_damage(dmg: float, dir: Vector2 = Vector2.ZERO, tier: String = "medium",
		crit: bool = false, tag: String = "") -> void:
	var amount := dmg
	# 背面受击 1.5 倍
	if dir.dot(shield_normal) > 0.15:
		amount *= 1.5
	super.take_damage(amount, dir, tier, crit, tag)


func _draw_body() -> void:
	var c := accent
	if swing > 0.0:
		c = Color(1.0, 0.75, 0.55)
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, c)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0, 0, 0, 0.85), 1.6)
	# 正面盾牌（半圆）
	var base := shield_normal.angle()
	draw_arc(Vector2.ZERO, radius + 5.0, base - 1.35, base + 1.35, 20,
		Color(0.92, 0.96, 1.0, 0.85), 3.0, true)
	draw_arc(Vector2.ZERO, radius + 5.0, base - 1.35, base + 1.35, 20,
		Color(0.55, 0.62, 0.75, 0.55), 1.0, true)
	draw_circle(Vector2.ZERO, radius * 0.34, Color(1, 1, 1, 0.9))
	if swing > 0.0:
		draw_arc(Vector2.ZERO, MELEE_RANGE, 0.0, TAU, 24, Color(1.0, 0.5, 0.35, 0.5), 2.0, true)
