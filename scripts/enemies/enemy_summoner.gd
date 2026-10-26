extends EnemyBase
## 召唤者：躲在房间边缘，每 2.8s 召唤 3 只小型追踪怪，召唤前 0.45s 头顶亮召唤阵

const CYCLE := 2.8
const WARN := 0.45
const SUMMON_N := 3
const ChaserScene = preload("res://scenes/enemies/enemy_chaser.tscn")

var timer: float = 0.0
var warning: float = 0.0


func _setup() -> void:
	var st: EnemyStats = Stats.enemy("summoner")
	max_hp = st.max_hp * GameState.enemy_scale()
	hp = max_hp
	speed = st.speed
	radius = 11.0
	contact_damage = st.contact_damage
	coin_value = st.coin_value
	accent = Color("#7B57B0")
	timer = SeedManager.randf_range(0.9, 1.7)


func _ai(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	# 保持离玩家 260px 以上，并往房间边缘躲
	var away: Vector2 = (global_position - player.global_position).normalized()
	if global_position.distance_to(player.global_position) < 260.0:
		position += away * speed * slow_mult * delta
	else:
		position += away.orthogonal() * sin(t * 0.9) * speed * 0.4 * delta

	if warning > 0.0:
		warning -= delta
		if warning <= 0.0:
			_summon()
		return
	timer -= delta
	if timer <= 0.0:
		timer = CYCLE
		warning = WARN
		Sfx.play_at("summon_cast", global_position, -2.0, 1.0)


func _summon() -> void:
	if GameState.bullets_root == null:
		return
	for i in SUMMON_N:
		var e = ChaserScene.instantiate()
		e.mini = true
		var ang := SeedManager.randf() * TAU
		e.position = global_position + Vector2(cos(ang), sin(ang)) * 26.0
		GameState.bullets_root.add_child(e)
	Sfx.play_at("summon_pop", global_position, -2.0, 1.1)
	GameFeel.burst(global_position, Color(0.6, 0.95, 0.5), 8, 90.0, 0.3)


func _draw_body() -> void:
	var s := roundf(radius)
	var body := Color("#6D4B9E")
	var dark := Color("#3A2656")
	var edge := Color("#0D0714")
	var gold := Color("#E9C05C")
	var top := -17.0
	# 破损方尖碑：上窄下宽，逐层像素台阶
	_px_rects([
		Rect2(-4.0, top, 7.0, 4.0),
		Rect2(-6.0, top + 4.0, 12.0, 5.0),
		Rect2(-9.0, top + 9.0, 18.0, 7.0),
		Rect2(-11.0, top + 16.0, 22.0, 5.0),
	], body, edge)
	# 右上缺角：暗色 4×3 覆盖
	draw_rect(Rect2(2.0, top + 4.0, 4.0, 3.0), edge)
	# 裂纹：1px 台阶
	draw_rect(Rect2(-2.0, top + 9.0, 1.0, 5.0), dark)
	draw_rect(Rect2(-1.0, top + 14.0, 1.0, 4.0), dark)
	draw_rect(Rect2(1.0, top + 5.0, 1.0, 3.0), dark)
	# 金色召唤纹路：3 条 1px，蓄力时 2 帧闪
	var lit: bool = warning <= 0.0 or fmod(t, 0.1) < 0.05
	var rune := gold if lit else gold.darkened(0.35)
	for i in 3:
		var y := top + 7.0 + float(i) * 5.0
		draw_rect(Rect2(-5.0, y, 10.0, 1.0), rune)
		draw_rect(Rect2(-6.0 if i == 1 else -4.0, y - 1.0, 2.0, 2.0), rune)
	# 胸口金核
	draw_rect(Rect2(-1.0, top + 8.0, 2.0, 2.0), gold)
	# 召唤预警：头顶 4 角像素阵 + 中心闪点
	if warning > 0.0:
		var yy := top - 10.0
		_px_brackets(Color(0.86, 1.0, 0.72, 0.95), 6.0, yy)
		if fmod(t, 0.12) < 0.06:
			draw_rect(Rect2(-1.0, yy - 1.0, 2.0, 2.0), Color(1.0, 0.92, 0.62, 0.95))
