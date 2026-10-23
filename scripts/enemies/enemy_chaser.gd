extends EnemyBase
## 追踪敌人：直线扑向玩家，靠接触造成伤害

var _wobble: float = 0.0


func _setup() -> void:
	var st: EnemyStats = Stats.enemy("chaser")
	max_hp = st.max_hp * GameState.enemy_scale()
	hp = max_hp
	speed = st.speed + 6.0 * float(GameState.floor_index - 1)
	radius = 9.0
	contact_damage = st.contact_damage
	coin_value = st.coin_value
	accent = Color("#ff7a9c")
	_wobble = SeedManager.randf() * TAU


func _ai(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_wobble += delta * 4.0
	var to_player: Vector2 = player.global_position - global_position
	var dir := to_player.normalized()
	# 轻微左右摆动，避免完全直线导致的"排队"观感
	var side := dir.orthogonal() * sin(_wobble) * 0.28
	position += (dir + side).normalized() * speed * delta


func _draw_body() -> void:
	# 尖刺圆：四角带刺的菱形
	var pts := PackedVector2Array()
	var spikes := 8
	for i in spikes:
		var a := TAU * i / spikes + t * 1.2
		var rr := radius * (1.25 if i % 2 == 0 else 0.82)
		pts.append(Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, accent)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0, 0, 0, 0.85), 1.4)
	draw_circle(Vector2(0, -1), radius * 0.42, Color(1, 1, 1, 0.92))
	draw_circle(Vector2(0, -1), radius * 0.22, Color(0.15, 0.02, 0.05, 1.0))
