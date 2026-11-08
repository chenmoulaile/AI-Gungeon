extends EnemyBase
## 远程敌人（扇形弹）：靠近后打 5 发扇形
## 第 3 层起每第 3 轮改为 10 发环形弹（新弹幕，不新增敌种）

const KEEP := 165.0

var fire_cd: float = 2.4
var telegraph: float = 0.0
var volley: int = 0
var ring_mode: bool = false


func _setup() -> void:
	var st: EnemyStats = Stats.enemy("spreader")
	max_hp = st.max_hp * GameState.enemy_scale()
	hp = max_hp
	speed = st.speed
	radius = 10.5
	contact_damage = st.contact_damage
	coin_value = st.coin_value
	accent = Color("#E07A2E")
	fire_cd = SeedManager.randf_range(0.8, 1.4)
	ring_mode = GameState.floor_index >= 3


func _ai(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()
	if dist > KEEP + 20.0:
		position += dir * speed * slow_mult * delta
	elif dist < KEEP - 30.0:
		position -= dir * speed * slow_mult * delta
	position += dir.orthogonal() * sin(t * 1.4) * speed * 0.45 * delta

	fire_cd -= delta
	if telegraph > 0.0:
		telegraph -= delta
		if telegraph <= 0.0:
			volley += 1
			if ring_mode and volley % 3 == 0:
				for i in 12:
					var a := TAU * i / 12.0 + t
					shoot_at(Vector2(cos(a), sin(a)), 170.0, 3.6)
			else:
				for i in 7:
					var t2 := float(i) / 6.0 - 0.5
					shoot_at(dir.rotated(deg_to_rad(46.0 * t2)), 185.0, 4.0)
			Sfx.play_at("hit", global_position, -8.0, 0.9)
	if fire_cd <= 0.0:
		fire_cd = SeedManager.randf_range(1.55, 2.1)
		telegraph = 0.4


func _draw_body() -> void:
	var dir := Vector2.RIGHT
	if player != null and is_instance_valid(player):
		dir = _px_dir(player.global_position - global_position)
	var perp := dir.orthogonal()
	var s := roundf(radius)
	var body := Color("#E07A2E")
	var dark := Color("#7A3A12")
	var edge := Color("#1A0C05")
	var hot := Color("#FFC46B")
	var open := telegraph > 0.0
	# 三根炮管：中管 + 两根侧管，八方向方块
	var tip_len := s + (4.0 if open else 2.0)
	for i in [-1.0, 0.0, 1.0]:
		var bp: Vector2 = dir * tip_len + perp * i * 5.0
		_px_rects([Rect2(roundf(bp.x) - 2.0, roundf(bp.y) - 2.0, 4.0, 4.0)],
			dark.lightened(0.08), edge)
		draw_rect(Rect2(roundf(bp.x) - 1.0, roundf(bp.y) - 1.0, 2.0, 2.0),
			hot if open else Color(0.35, 0.16, 0.06))
	# 十字主体
	_px_rects([
		Rect2(-6.0, -s - 1.0, 12.0, 4.0),
		Rect2(-s, -4.0, s * 2.0, 8.0),
		Rect2(-6.0, s - 3.0, 12.0, 4.0),
	], body, edge)
	# 四角黑刺
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var pp := Vector2(cos(a), sin(a)) * (s + 2.0)
		draw_rect(Rect2(roundf(pp.x) - 1.0, roundf(pp.y) - 1.0, 2.0, 2.0), edge)
	# 中心核心
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), Color("#2A1408"))
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), hot)
	# 蓄力：炮口 2 帧高亮
	if open and fmod(t, 0.12) < 0.06:
		for i in [-1.0, 0.0, 1.0]:
			var bp2: Vector2 = dir * (s + 4.0) + perp * i * 5.0
			draw_rect(Rect2(roundf(bp2.x) - 2.0, roundf(bp2.y) - 2.0, 4.0, 4.0),
				Color(1.0, 0.52, 0.22, 0.95))
	# 环形弹模式：四个正方向红色预警方块
	if ring_mode and open:
		for i in 4:
			var a2 := TAU * float(i) / 4.0
			var rp := Vector2(cos(a2), sin(a2)) * (s + 14.0)
			draw_rect(Rect2(roundf(rp.x) - 1.0, roundf(rp.y) - 1.0, 2.0, 2.0),
				Color(1.0, 0.34, 0.40, 0.8))
	glitch_fragments(3, s + 4.0)
