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
	position += (dir + side).normalized() * speed * slow_mult * delta


func _draw_body() -> void:
	var wob := sin(t * 6.0 + _wobble) * 0.10
	# 拖尾碎片：移动时身后 3 个像素碎片
	for i in 3:
		var a := PI * 0.5 + float(i) * 0.42 - 0.42
		var p := Vector2(cos(a), sin(a)) * (radius + 4.0 + float(i) * 2.0)
		var fa := 0.42 - float(i) * 0.11
		draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)),
			Color(accent.r, accent.g, accent.b, fa))
	# 三段锯齿椭圆
	for seg in 3:
		var y := -radius * 0.75 + float(seg) * radius * 0.72
		var w := radius * (1.0 - 0.16 * float(seg)) * (1.0 + wob)
		var pts := PackedVector2Array([
			Vector2(-w, y), Vector2(-w * 0.55, y - radius * 0.42),
			Vector2(w * 0.55, y - radius * 0.42), Vector2(w, y),
			Vector2(w * 0.58, y + radius * 0.36), Vector2(-w * 0.58, y + radius * 0.36)])
		draw_colored_polygon(pts, accent.darkened(0.07 * float(seg)))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.85), 1.2)
	# 左右摆动短足
	for side in [-1.0, 1.0]:
		for i in 2:
			var yy := radius * 0.28 + float(i) * 5.0
			var xx: float = side * radius * 0.82
			var kick := sin(t * 12.0 + float(i) + (0.0 if side > 0.0 else 1.5)) * 1.8
			draw_line(Vector2(xx, yy), Vector2(xx + side * 4.0, yy + 4.0 + kick),
				accent.darkened(0.35), 1.6)
	# 眼
	draw_circle(Vector2(0, -radius * 0.42), radius * 0.30, Color(1, 1, 1, 0.95))
	draw_circle(Vector2(0, -radius * 0.42), radius * 0.14, Color(0.12, 0.02, 0.06))
