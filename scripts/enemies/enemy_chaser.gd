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
	accent = Color("#B06BFF")
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
	# 2 帧整数浮动，不做连续位移
	var bob := 0.0 if fmod(t, 0.7) < 0.35 else 1.0
	var w1 := roundf(radius * 0.75)
	var w2 := roundf(radius * 1.35)
	var w3 := roundf(radius * 1.55)
	var rects := [
		Rect2(-w1 * 0.5, -radius - 1.0 + bob, w1, 3.0),
		Rect2(-w2 * 0.5, -radius + 2.0 + bob, w2, 3.0),
		Rect2(-w3 * 0.5, -radius + 5.0 + bob, w3, 5.0),
		Rect2(-w2 * 0.5, -radius + 10.0 + bob, w2, 3.0),
		Rect2(-w1 * 0.5, -radius + 13.0 + bob, w1, 2.0),
	]
	_px_rects(rects, accent, accent.darkened(0.68))
	# 青色双眼
	draw_rect(Rect2(-3.0, -radius + 5.0 + bob, 2.0, 2.0), Color("#7FE3FF"))
	draw_rect(Rect2(1.0, -radius + 5.0 + bob, 2.0, 2.0), Color("#7FE3FF"))
	# 三颗牙
	draw_rect(Rect2(-4.0, -radius + 13.0 + bob, 2.0, 2.0), Color("#FFF3D6"))
	draw_rect(Rect2(-1.0, -radius + 14.0 + bob, 2.0, 2.0), Color("#FFF3D6"))
	draw_rect(Rect2(2.0, -radius + 13.0 + bob, 2.0, 2.0), Color("#FFF3D6"))
	# 青色尾迹：2 个 2×2 方块，40% 透明
	var back := Vector2.LEFT
	if player != null and is_instance_valid(player):
		back = -_px_dir(player.global_position - global_position)
	for i in 2:
		var p := back * (radius + 3.0 + float(i) * 4.0) + Vector2(0.0, 2.0 + float(i) * 2.0)
		draw_rect(Rect2(roundf(p.x), roundf(p.y), 2.0, 2.0),
			Color(0.50, 0.89, 1.0, 0.4))
