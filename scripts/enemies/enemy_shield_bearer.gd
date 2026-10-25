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
	accent = Color("#7FA0BC")
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
	var dir := _px_dir(shield_normal)
	var perp := dir.orthogonal()
	var s := roundf(radius)
	var body := Color("#6E8AA6")
	var plate := Color("#A8C6DD")
	var edge := Color("#0A1016")
	var white := Color("#E8F2FA")
	var hot := Color("#FFB08A")
	# 后方能量核心：2 帧亮
	draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), Color("#2C3C4E"))
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), hot if swing > 0.0 else white)
	# 机体：偏向来向的方块
	_px_rects([
		Rect2(roundf(-s * 0.55 + dir.x * 2.0), roundf(-s * 0.8 + dir.y * 2.0),
			roundf(s * 1.1), roundf(s * 1.6)),
	], body, edge)
	# 盾面：三块 6×6 沿侧向排开，明确朝向
	var base := dir * (s + 3.0)
	for i in [-1.0, 0.0, 1.0]:
		var bp: Vector2 = base + perp * i * 8.0
		_px_rects([Rect2(roundf(bp.x) - 3.0, roundf(bp.y) - 3.0, 6.0, 6.0)], plate, edge)
		# 正面 1px 白边
		var fp: Vector2 = bp + dir * 2.0
		draw_rect(Rect2(roundf(fp.x) - 1.0, roundf(fp.y) - 1.0, 2.0, 2.0), white)
	# 盾面裂纹：1px 台阶
	draw_rect(Rect2(roundf(base.x) - 1.0, roundf(base.y) - 4.0, 1.0, 3.0), edge)
	draw_rect(Rect2(roundf(base.x), roundf(base.y) + 1.0, 1.0, 3.0), edge)
	# 挥击预警：4 个 2×2 红色角标由内向外（2 帧闪）
	if swing > 0.0:
		var kk := 1.0 - swing / WINDUP
		var blink: bool = fmod(t, 0.16) < 0.08
		for i in 4:
			var a2 := TAU * float(i) / 4.0 + PI * 0.25
			var rp := Vector2(cos(a2), sin(a2)) * (MELEE_RANGE * (0.45 + 0.25 * kk))
			draw_rect(Rect2(roundf(rp.x) - 1.0, roundf(rp.y) - 1.0, 2.0, 2.0),
				Color(1.0, 0.5, 0.32, 0.85 if blink else 0.55))
