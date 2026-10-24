extends EnemyBase
## 召唤者：躲在房间边缘，每 4.0s 召唤 2 只小型追踪怪，召唤前 0.5s 头顶亮召唤阵

const CYCLE := 4.0
const WARN := 0.5
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
	accent = Color("#9be36b")
	timer = SeedManager.randf_range(1.4, 2.6)


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
	for i in 2:
		var e = ChaserScene.instantiate()
		e.mini = true
		var ang := SeedManager.randf() * TAU
		e.position = global_position + Vector2(cos(ang), sin(ang)) * 26.0
		GameState.bullets_root.add_child(e)
	Sfx.play_at("summon_pop", global_position, -2.0, 1.1)
	GameFeel.burst(global_position, Color(0.6, 0.95, 0.5), 8, 90.0, 0.3)


func _draw_body() -> void:
	var s := radius
	# 破损方尖碑：上窄下宽的梯形，右上角缺一块
	var body := PackedVector2Array([
		Vector2(-s * 0.55, s * 1.15), Vector2(-s * 0.42, -s * 0.95),
		Vector2(s * 0.10, -s * 1.35), Vector2(s * 0.46, -s * 0.70),
		Vector2(s * 0.55, s * 1.15)])
	draw_colored_polygon(body, accent.darkened(0.15))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0, 0, 0, 0.85), 1.6)
	# 表面裂纹
	draw_line(Vector2(-s * 0.10, -s * 1.10), Vector2(s * 0.14, -s * 0.10),
		Color(0.10, 0.04, 0.06, 0.75), 1.0)
	draw_line(Vector2(s * 0.14, -s * 0.10), Vector2(-s * 0.18, s * 0.55),
		Color(0.10, 0.04, 0.06, 0.65), 1.0)
	# 缺口
	draw_colored_polygon(PackedVector2Array([
		Vector2(s * 0.10, -s * 1.35), Vector2(s * 0.52, -s * 0.60),
		Vector2(s * 0.18, -s * 0.62)]), Color(0.06, 0.03, 0.05))
	# 召唤纹路：召唤时高亮
	var lit: float = 0.35 if warning <= 0.0 else 0.6 + 0.4 * sin(t * 18.0)
	for i in 3:
		var y := -s * 0.55 + float(i) * s * 0.55
		draw_line(Vector2(-s * 0.30, y), Vector2(s * 0.30, y),
			Color(0.75, 1.0, 0.70, lit), 1.2)
	draw_circle(Vector2(0, -s * 0.55), s * 0.16, Color(0.85, 1.0, 0.75, lit))
	if warning > 0.0:
		var k: float = 1.0 - warning / WARN
		var yy := -s * 1.55
		var r := 7.0 + 2.0 * sin(t * 18.0)
		draw_arc(Vector2(0, yy), r, 0.0, TAU, 16, Color(0.7, 1.0, 0.6, 0.9), 1.5, true)
		for i in 3:
			var a2 := t * 3.0 + TAU * float(i) / 3.0
			draw_circle(Vector2(0, yy) + Vector2(cos(a2), sin(a2)) * r, 1.4,
				Color(0.85, 1.0, 0.7, 0.6 + 0.4 * k))
