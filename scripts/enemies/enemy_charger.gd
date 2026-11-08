extends EnemyBase
## 冲锋兵：蓄力 0.42s（闪白 + 地面红色箭头）→ 340px/s 直线冲锋 0.75s → 撞墙眩晕 0.85s

const WINDUP := 0.42
const DASH_TIME := 0.75
const DASH_SPEED := 340.0
const STUN_TIME := 0.85

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
	accent = Color("#E04A38")
	timer = SeedManager.randf_range(0.3, 0.9)


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
				timer = SeedManager.randf_range(0.8, 1.4)


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
	var s := roundf(radius)
	var body := Color("#C9A24A")
	var dark := Color("#8A6A2A")
	var edge := Color("#1A1206")
	var red := Color("#E04A38")
	if state == "windup":
		# 蓄力闪白：2 帧
		body = Color("#F2D45C") if fmod(t, 0.1) < 0.05 else Color("#D9B34F")
	elif state == "stun":
		body = Color("#8A7A63")
	var dir := dash_dir
	if state == "idle" and player != null and is_instance_valid(player):
		dir = player.global_position - global_position
	dir = _px_dir(dir)
	var perp := dir.orthogonal()
	# 冲锋预警：1px 直线 + 像素箭头（2 帧闪）
	if state == "windup":
		var k := 1.0 - timer / WINDUP
		var head := dir * 54.0
		draw_line(Vector2.ZERO, head, Color(0.90, 0.24, 0.20, 0.30 + 0.45 * k), 1.0)
		if fmod(t, 0.16) < 0.08:
			var hx := roundf(head.x)
			var hy := roundf(head.y)
			draw_rect(Rect2(hx - 3.0, hy - 1.0, 6.0, 2.0), red)
			draw_rect(Rect2(hx - 2.0, hy - 4.0, 4.0, 2.0), red)
			draw_rect(Rect2(hx - 2.0, hy + 2.0, 4.0, 2.0), red)
			draw_rect(Rect2(hx - 1.0, hy - 6.0, 2.0, 2.0), red)
			draw_rect(Rect2(hx - 1.0, hy + 4.0, 2.0, 2.0), red)
	# 尾部碎片：蓄力时向尾部聚集，全部 2×2 方块
	var gather := 1.0 if state == "windup" else 0.30
	for i in 3:
		var p := -dir * (s + 4.0 + float(i) * 4.0 * (1.0 - gather)) + perp * float(i - 1) * 3.0
		draw_rect(Rect2(roundf(p.x) - 1.0, roundf(p.y) - 1.0, 2.0, 2.0),
			Color(0.95, 0.62, 0.30, 0.35 + 0.45 * gather))
	# 双蹄
	_px_rects([
		Rect2(roundf(-s * 0.8 + perp.x * 4.0), roundf(-1.0 + perp.y * 4.0), 4.0, 6.0),
		Rect2(roundf(-s * 0.8 - perp.x * 4.0), roundf(-1.0 - perp.y * 4.0), 4.0, 6.0),
	], dark, edge)
	# 主体：上下两段土黄方块
	_px_rects([
		Rect2(-roundf(s * 0.9), -s - 4.0, roundf(s * 1.8), 7.0),
		Rect2(-roundf(s * 0.75), -s + 3.0, roundf(s * 1.5), 7.0),
	], body, edge)
	# 前撞角 + 两颗白獠牙
	var hp := dir * (s + 1.0)
	_px_rects([Rect2(roundf(hp.x) - 3.0, roundf(hp.y) - 3.0, 6.0, 6.0)],
		body.lightened(0.06), edge)
	for tip in [-1.0, 1.0]:
		var tp: Vector2 = hp + perp * tip * 5.0 + dir * 3.0
		draw_rect(Rect2(roundf(tp.x) - 1.0, roundf(tp.y) - 1.0, 2.0, 2.0),
			Color("#FFF3D6"))
	# 眼睛：朝向前方的 2×2 白点
	var ep := dir * 2.0 + perp * 2.0
	draw_rect(Rect2(roundf(ep.x) - 1.0, roundf(ep.y) - 1.0, 2.0, 2.0), Color(1, 1, 1, 0.95))
	# 眩晕：3 个 2×2 像素星绕头
	if state == "stun":
		for i in 3:
			var a2 := t * 6.0 + TAU * float(i) / 3.0
			var sp := Vector2(cos(a2), sin(a2)) * (s + 6.0) + Vector2(0.0, -s * 0.8)
			draw_rect(Rect2(roundf(sp.x) - 1.0, roundf(sp.y) - 1.0, 2.0, 2.0),
				Color(1.0, 0.9, 0.5, 0.85))
