extends EnemyBase
## 远程敌人（直线弹）：保持距离，蓄力后攻击
## 第 2 层起切换为旋转弹模式（新弹幕，不新增敌种）

const KEEP_MIN := 150.0
const KEEP_MAX := 220.0

var fire_cd: float = 1.6
var telegraph: float = 0.0
var pattern: String = "aim"
var spin: float = 0.0


func _setup() -> void:
	var st: EnemyStats = Stats.enemy("shooter")
	max_hp = st.max_hp * GameState.enemy_scale()
	hp = max_hp
	speed = st.speed
	radius = 9.5
	contact_damage = st.contact_damage
	coin_value = st.coin_value
	accent = Color("#FF5A63")
	fire_cd = SeedManager.randf_range(0.6, 1.2)
	if GameState.floor_index >= 2:
		pattern = "spiral"
		spin = SeedManager.randf() * TAU


func _ai(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()
	if dist > KEEP_MAX:
		position += dir * speed * slow_mult * delta
	elif dist < KEEP_MIN:
		position -= dir * speed * slow_mult * delta

	fire_cd -= delta
	if telegraph > 0.0:
		telegraph -= delta
		if telegraph <= 0.0:
			if pattern == "spiral":
				spin += 0.7
				for i in 4:
					var a := spin + PI * 0.5 * i
					shoot_at(Vector2(cos(a), sin(a)), 188.0, 3.8)
			else:
				shoot_at(dir, 225.0, 3.8)
			Sfx.play_at("shoot", global_position, -6.0, 0.9)
	if fire_cd <= 0.0:
		fire_cd = SeedManager.randf_range(1.0, 1.5) if pattern == "aim" else SeedManager.randf_range(0.8, 1.2)
		telegraph = 0.42


func _draw_body() -> void:
	var dir := Vector2.RIGHT
	if player != null and is_instance_valid(player):
		dir = _px_dir(player.global_position - global_position)
	var s := roundf(radius)
	var body := Color("#49505C")
	var dark := Color("#2F353E")
	var edge := Color("#0A0D13")
	var red := Color("#FF5A63")
	var bob := 0.0 if fmod(t, 0.9) < 0.45 else 1.0
	# 三条支撑腿：两前一后，像素方柱
	_px_rects([
		Rect2(-s, -2.0 + bob, 4.0, 7.0),
		Rect2(s - 4.0, -2.0 + bob, 4.0, 7.0),
		Rect2(-2.0, bob, 4.0, 6.0),
	], dark, edge)
	# 炮台主体：上窄下宽的三层
	_px_rects([
		Rect2(-6.0, -s - 5.0 + bob, 12.0, 4.0),
		Rect2(-s, -s - 1.0 + bob, s * 2.0, 6.0),
		Rect2(-s + 1.0, -s + 5.0 + bob, s * 2.0 - 2.0, 3.0),
	], body, edge)
	# 单眼 3×3 + 深色瞳
	draw_rect(Rect2(-1.0, -s + bob, 3.0, 3.0), red)
	draw_rect(Rect2(0.0, -s + 1.0 + bob, 1.0, 1.0), Color("#2A0A0C"))
	# 炮口：八方向整数偏移，双层方块
	var mz := dir * (s + 4.0) + Vector2(0.0, -s * 0.35 + bob)
	_px_rects([Rect2(roundf(mz.x) - 2.0, roundf(mz.y) - 2.0, 4.0, 4.0)],
		Color("#616B79"), edge)
	draw_rect(Rect2(roundf(mz.x) - 1.0, roundf(mz.y) - 1.0, 2.0, 2.0), red.darkened(0.25))
	# 蓄力：1px 瞄准线 + 炮口 2 帧闪
	if telegraph > 0.0:
		var k := 1.0 - telegraph / 0.42
		var line_col := Color(1.0, 0.30, 0.34, 0.16 + 0.40 * k)
		draw_line(Vector2.ZERO, dir * (60.0 + 300.0 * k), line_col, 1.0)
		if fmod(t, 0.1) < 0.05:
			draw_rect(Rect2(roundf(mz.x) - 2.0, roundf(mz.y) - 2.0, 4.0, 4.0),
				Color(1.0, 0.55, 0.30, 0.95))
	glitch_fragments(4, s + 6.0)
