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
	accent = Color("#66C97A")


func _ai(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var dir: Vector2 = (player.global_position - global_position).normalized()
	position += dir * speed * slow_mult * delta
	# 呼吸式缩放：2 帧整数，避免像素边缘抖动
	scale = Vector2.ONE * (1.03 if sin(t * 3.0) > 0.0 else 1.0)


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
		e.mini_speed_scale = 1.5
		var ang := TAU * float(i) / 2.0 + SeedManager.randf() * 0.5
		e.position = global_position + Vector2(cos(ang), sin(ang)) * 16.0
		GameState.bullets_root.add_child(e)
	Sfx.play_at("crack", global_position, -2.0, 1.0)
	GameFeel.burst(global_position, Color(0.55, 0.95, 0.8), 12, 130.0, 0.35)


func _draw_body() -> void:
	var s := roundf(radius)
	var body := Color("#56B56A")
	var dark := Color("#2F6B3C")
	var hi := Color("#F2D45C")
	var edge := Color("#07130A")
	# 呼吸：2 帧宽度变化，不做连续缩放
	var wide := 0.0 if fmod(t, 0.5) < 0.25 else 2.0
	_px_rects([
		Rect2(-8.0 - wide, -s - 2.0, 16.0 + wide * 2.0, 4.0),
		Rect2(-s - 2.0, -s + 2.0, s * 2.0 + 4.0, 5.0),
		Rect2(-s - 4.0 + wide, -s + 7.0, s * 2.0 + 8.0 - wide * 2.0, 6.0),
		Rect2(-s - 1.0, -s + 13.0, s * 2.0 + 2.0, 4.0),
		Rect2(-s + 3.0, -s + 17.0, s * 2.0 - 6.0, 3.0),
	], body, edge)
	# 脉络：1px 暗绿台阶
	draw_rect(Rect2(-6.0, -s + 3.0, 3.0, 1.0), dark)
	draw_rect(Rect2(-3.0, -s + 4.0, 1.0, 4.0), dark)
	draw_rect(Rect2(-3.0, -s + 8.0, 5.0, 1.0), dark)
	draw_rect(Rect2(2.0, -s + 9.0, 1.0, 3.0), dark)
	# 两个将要分裂的黄色胚核（2 帧闪）
	var cc := hi if fmod(t, 0.8) < 0.4 else hi.darkened(0.25)
	draw_rect(Rect2(-6.0, -s + 8.0, 3.0, 3.0), cc)
	draw_rect(Rect2(4.0, -s + 10.0, 2.0, 2.0), cc)
	# 中央单眼
	draw_rect(Rect2(-2.0, -s + 5.0, 4.0, 3.0), Color("#0B1A0E"))
	draw_rect(Rect2(-1.0, -s + 6.0, 2.0, 1.0), hi)
