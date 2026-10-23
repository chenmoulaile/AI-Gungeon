extends EnemyBase
## 分裂体：本体缓慢、血厚；死亡分裂成 2 只小型分裂体（不再分裂）

const ChaserScene = preload("res://scenes/enemies/enemy_chaser.tscn")

var can_split: bool = true


func _setup() -> void:
	var st: EnemyStats = Stats.enemy("splitter")
	max_hp = st.max_hp * GameState.enemy_scale()
	hp = max_hp
	speed = st.speed
	radius = 13.0
	contact_damage = st.contact_damage
	coin_value = st.coin_value
	accent = Color("#7de0c0")


func _ai(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var dir: Vector2 = (player.global_position - global_position).normalized()
	position += dir * speed * delta
	# 呼吸式缩放，暗示"要裂开"
	scale = Vector2.ONE * (1.0 + 0.04 * sin(t * 3.0))


func _die() -> void:
	if can_split and not dead:
		_split()
	super._die()


func _split() -> void:
	if GameState.bullets_root == null:
		return
	for i in 2:
		var e = ChaserScene.instantiate()
		e.mini = true
		e.mini_speed_scale = 1.4
		var ang := TAU * float(i) / 2.0 + SeedManager.randf() * 0.5
		e.position = global_position + Vector2(cos(ang), sin(ang)) * 16.0
		GameState.bullets_root.add_child(e)
	Sfx.play_at("crack", global_position, -2.0, 1.0)
	GameFeel.burst(global_position, Color(0.55, 0.95, 0.8), 12, 130.0, 0.35)


func _draw_body() -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0 + t * 0.4
		var rr := radius * (1.0 if i % 2 == 0 else 0.72)
		pts.append(Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, accent)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0, 0, 0, 0.85), 1.6)
	draw_circle(Vector2.ZERO, radius * 0.3, Color(1, 1, 1, 0.95))
	draw_line(Vector2(-radius * 0.5, 0), Vector2(radius * 0.5, 0), Color(0.1, 0.3, 0.25, 0.6), 1.0)
