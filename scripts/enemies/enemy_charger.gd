extends EnemyBase
## 冲锋兵：蓄力 0.6s（闪白 + 地面红色箭头）→ 300px/s 直线冲锋 0.8s → 撞墙眩晕 1.0s

const WINDUP := 0.6
const DASH_TIME := 0.8
const DASH_SPEED := 300.0
const STUN_TIME := 1.0

var state: String = "idle"   # idle / windup / dash / stun
var timer: float = 0.0
var dash_dir: Vector2 = Vector2.RIGHT
var _hit_wall: bool = false


func _setup() -> void:
	var st: EnemyStats = Stats.enemy("charger")
	max_hp = st.max_hp * GameState.enemy_scale()
	hp = max_hp
	speed = st.speed
	radius = 10.0
	contact_damage = st.contact_damage
	coin_value = st.coin_value
	accent = Color("#ff5f4d")
	timer = SeedManager.randf_range(0.4, 1.2)


func _ai(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	timer -= delta
	match state:
		"idle":
			var dir: Vector2 = (player.global_position - global_position).normalized()
			position += dir * speed * slow_mult * delta
			if timer <= 0.0:
				state = "windup"
				timer = WINDUP
				dash_dir = dir
				Sfx.play_at("charge_windup", global_position, -2.0, 0.9)
		"windup":
			if timer <= 0.0:
				state = "dash"
				timer = DASH_TIME
				_hit_wall = false
				Sfx.play_at("dash", global_position, -2.0, 1.0)
		"dash":
			position += dash_dir * DASH_SPEED * delta
			# 撞到墙或障碍就眩晕
			var r := GameConfig.room_rect().grow(-GameConfig.WALL - radius)
			if not r.has_point(global_position) or _hit_obstacle():
				_hit_wall = true
			if _hit_wall or timer <= 0.0:
				state = "stun"
				timer = STUN_TIME
				knock_vel = -dash_dir * 90.0
				GameFeel.screen_shake(0.2)
				Sfx.play_at("hit", global_position, -2.0, 0.6)
		"stun":
			if timer <= 0.0:
				state = "idle"
				timer = SeedManager.randf_range(1.0, 1.8)


func _hit_obstacle() -> bool:
	for o in GameState.obstacles:
		if (o as Rect2).grow(radius).has_point(global_position):
			return true
	return false


func take_damage(dmg: float, dir: Vector2 = Vector2.ZERO, tier: String = "medium",
		crit: bool = false, tag: String = "") -> void:
	# 冲锋中免疫硬直，但照常掉血
	var was_dash := state == "dash"
	super.take_damage(dmg, dir, tier, crit, tag)
	if was_dash and not dead:
		stun = 0.0


func _draw_body() -> void:
	var c := accent
	if state == "windup":
		c = Color(1.0, 0.85, 0.4)
	elif state == "stun":
		c = Color(0.55, 0.5, 0.5)
	var dir := dash_dir
	if state == "idle" and player != null and is_instance_valid(player):
		dir = (player.global_position - global_position).normalized()
	draw_set_transform(Vector2.ZERO, dir.angle(), Vector2.ONE)
	# 尾部碎片：冲锋前向尾部聚集
	var gather := 1.0 if state == "windup" else 0.30
	for i in 4:
		var d := -radius - 4.0 - float(i) * 6.0 * (1.0 - gather)
		draw_rect(Rect2(d, -2.0 - float(i), 3.0, 3.0),
			Color(1.0, 0.55, 0.30, 0.35 + 0.4 * gather))
	# 尖锥数据冲撞体
	var cone := PackedVector2Array([
		Vector2(radius * 1.35, 0.0), Vector2(-radius * 0.45, -radius * 0.85),
		Vector2(-radius * 0.95, 0.0), Vector2(-radius * 0.45, radius * 0.85)])
	draw_colored_polygon(cone, c)
	draw_polyline(cone + PackedVector2Array([cone[0]]), Color(0, 0, 0, 0.85), 1.6)
	# 内部裂纹
	draw_line(Vector2(-radius * 0.3, 0.0), Vector2(radius * 0.5, 0.0),
		Color(0.1, 0.03, 0.02, 0.5), 1.0)
	draw_circle(Vector2(radius * 0.35, 0.0), radius * 0.18, Color(1, 1, 1, 0.9))
	if state == "stun":
		for i in 3:
			var a2 := t * 6.0 + TAU * float(i) / 3.0
			draw_circle(Vector2(cos(a2), sin(a2)) * (radius + 6.0), 1.6,
				Color(1.0, 0.9, 0.5, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
