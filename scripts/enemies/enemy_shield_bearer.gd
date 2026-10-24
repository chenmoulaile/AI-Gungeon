extends EnemyBase
## 盾卫：正面 180° 免疫子弹（叮 + 火花 + light 硬直），背面吃 1.5 倍伤害
## 移动缓慢，靠近后 0.4s 前摇挥击

const MELEE_RANGE := 34.0
const WINDUP := 0.4

var shield_normal: Vector2 = Vector2.RIGHT
var melee_cd: float = 0.0
var swing: float = 0.0


func _setup() -> void:
	var st: EnemyStats = Stats.enemy("shield_bearer")
	max_hp = st.max_hp * GameState.enemy_scale()
	hp = max_hp
	speed = st.speed
	radius = 12.0
	contact_damage = st.contact_damage
	coin_value = st.coin_value
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
		position += shield_normal * speed * slow_mult * delta
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
	# 后方发光核心
	draw_circle(Vector2.ZERO, radius * 0.46, Color(c.r, c.g, c.b, 0.85))
	draw_circle(Vector2.ZERO, radius * 0.24, Color(1, 1, 1, 0.95))
	# 厚重破碎盾面：正面朝向玩家
	var base := shield_normal.angle()
	var pts := PackedVector2Array()
	for i in 7:
		var a := base - 1.25 + float(i) * 0.42
		var rr := radius + 7.0 + (2.0 if i % 2 == 0 else 0.0)
		pts.append(Vector2(cos(a), sin(a)) * rr)
	pts.append(Vector2(cos(base + 1.25), sin(base + 1.25)) * (radius * 0.72))
	pts.append(Vector2(cos(base - 1.25), sin(base - 1.25)) * (radius * 0.72))
	draw_colored_polygon(pts, Color(0.55, 0.60, 0.70))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.85), 1.6)
	# 金属裂纹
	for i in 2:
		var a2 := base - 0.6 + float(i) * 1.1
		var p1 := Vector2(cos(a2), sin(a2)) * (radius + 2.0)
		var p2 := Vector2(cos(a2 + 0.15), sin(a2 + 0.15)) * (radius * 0.55)
		draw_line(p1, p2, Color(0.15, 0.18, 0.24, 0.85), 1.2)
	# 正面边缘高光
	draw_arc(Vector2.ZERO, radius + 6.0, base - 1.2, base + 1.2, 16,
		Color(0.92, 0.96, 1.0, 0.9), 1.4, true)
	if swing > 0.0:
		draw_arc(Vector2.ZERO, MELEE_RANGE, 0.0, TAU, 24, Color(1.0, 0.5, 0.35, 0.5), 2.0, true)
