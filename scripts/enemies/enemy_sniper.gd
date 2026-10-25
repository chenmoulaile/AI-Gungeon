extends EnemyBase
## 狙击手：保持 250~350px，每 2.5s 打一发 400px/s 高速弹，发射前 0.5s 红色细线预警

const MIN_D := 250.0
const MAX_D := 350.0
const CYCLE := 2.5
const WARN := 0.5

var timer: float = 0.0
var warning: float = 0.0
var aim_dir: Vector2 = Vector2.RIGHT


func _setup() -> void:
	var st: EnemyStats = Stats.enemy("sniper")
	max_hp = st.max_hp * GameState.enemy_scale()
	hp = max_hp
	speed = st.speed
	radius = 9.0
	contact_damage = st.contact_damage
	coin_value = st.coin_value
	accent = Color("#3E6350")
	timer = SeedManager.randf_range(1.0, 2.0)


func _ai(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	aim_dir = to_player.normalized()

	if warning > 0.0:
		warning -= delta
		if warning <= 0.0:
			shoot_at(aim_dir, 400.0, 3.4)
			Sfx.play_at("shoot", global_position, -2.0, 0.65)
			GameFeel.screen_shake(0.06)
		return

	# 走位保持距离
	if dist > MAX_D:
		position += aim_dir * speed * slow_mult * delta
	elif dist < MIN_D:
		position -= aim_dir * speed * slow_mult * delta
	else:
		position += aim_dir.orthogonal() * sin(t * 1.1) * speed * 0.5 * delta

	timer -= delta
	if timer <= 0.0:
		timer = CYCLE
		warning = WARN
		Sfx.play_at("warn_high", global_position, -6.0, 1.6)


func _draw_body() -> void:
	var dir := _px_dir(aim_dir)
	var s := roundf(radius)
	var body := Color("#2E4A3C")
	var dark := Color("#16281F")
	var edge := Color("#050D08")
	var red := Color("#FF4658")
	# 预警瞄准线：1px，由白转红
	if warning > 0.0:
		var k: float = 1.0 - warning / WARN
		draw_line(Vector2.ZERO, aim_dir * 600.0,
			Color(1.0, 0.92 - 0.62 * k, 0.86 - 0.58 * k, 0.28 + 0.55 * k), 1.0)
	# 机体：细长三段深绿
	_px_rects([
		Rect2(-4.0, -s - 4.0, 8.0, 4.0),
		Rect2(-5.0, -s, 10.0, 7.0),
		Rect2(-3.0, -s + 7.0, 6.0, 4.0),
	], body, edge)
	# 散热鳍：1px 暗线
	for i in 3:
		draw_rect(Rect2(-3.0 + float(i) * 3.0, -s + 1.0, 1.0, 5.0), dark)
	# 枪管：两节 4×4 / 2×2
	var b1 := dir * (s + 3.0)
	var b2 := dir * (s + 7.0)
	_px_rects([
		Rect2(roundf(b1.x) - 2.0, roundf(b1.y) - 2.0, 4.0, 4.0),
		Rect2(roundf(b2.x) - 1.0, roundf(b2.y) - 1.0, 2.0, 2.0),
	], dark, edge)
	# 目镜：红色 3×2 + 白点
	draw_rect(Rect2(-1.0, -s - 4.0, 3.0, 2.0), red)
	draw_rect(Rect2(0.0, -s - 3.0, 1.0, 1.0), Color("#FFD9DE"))
	# 蓄力：枪口 2 帧闪
	if warning > 0.0 and fmod(t, 0.1) < 0.05:
		draw_rect(Rect2(roundf(b2.x) - 1.0, roundf(b2.y) - 1.0, 2.0, 2.0),
			Color(1.0, 0.75, 0.8, 0.95))
