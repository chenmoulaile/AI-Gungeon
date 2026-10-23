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
		position += away * speed * delta
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
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0 - PI / 2.0 + t * 0.5
		pts.append(Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, accent)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0, 0, 0, 0.85), 1.6)
	draw_circle(Vector2.ZERO, radius * 0.4, Color(1, 1, 1, 0.95))
	# 召唤阵
	if warning > 0.0:
		var k: float = 1.0 - warning / WARN
		var yy := -radius - 16.0
		var r := 7.0 + 2.0 * sin(t * 18.0)
		draw_arc(Vector2(0, yy), r, 0.0, TAU, 16, Color(0.7, 1.0, 0.6, 0.9), 1.5, true)
		for i in 3:
			var a2 := t * 3.0 + TAU * i / 3.0
			draw_circle(Vector2(0, yy) + Vector2(cos(a2), sin(a2)) * r, 1.4,
				Color(0.85, 1.0, 0.7, 0.6 + 0.4 * k))
