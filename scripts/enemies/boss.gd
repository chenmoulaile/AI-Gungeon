extends EnemyBase
## Boss「回响聚合体」
## 三阶段固定，但每个阶段从行为池随机抽 2 个招式循环使用；同一局内固定，不同局不同
## 阶段转换：0.75s 预警 + 0.5s 停火喘息，预警开始即停止召唤

const ChaserScene = preload("res://scenes/enemies/enemy_chaser.tscn")
const LaserScene = preload("res://scripts/weapons/laser_sweep.gd")

const POOLS := {
	1: ["ring", "fan", "charge"],
	2: ["homing", "summon", "laser", "fan"],
	3: ["ring", "fan", "charge", "homing", "summon", "laser", "spiral", "mine"],
}

const MOVE_LABEL := {
	"ring": "环", "fan": "扇", "charge": "冲", "homing": "追",
	"summon": "召", "laser": "激", "spiral": "旋", "mine": "雷",
}

var phase: int = 1
var atk_cd: float = 1.6
var summon_cd: float = 5.0
var summon_lock: float = 0.0
var ring_angle: float = 0.0
var telegraph: float = 0.0
var pending_phase: int = 0

var moves: Dictionary = {1: [], 2: [], 3: []}
var move_idx: int = 0
var spiral_left: int = 0
var spiral_t: float = 0.0
var spiral_angle: float = 0.0
var charge_t: float = 0.0
var charge_dir: Vector2 = Vector2.RIGHT


func _setup() -> void:
	max_hp = 150.0 * GameState.enemy_scale()
	hp = max_hp
	speed = 26.0
	radius = 27.0
	contact_damage = 2
	coin_value = 26
	accent = Color("#b45cff")
	is_boss = true
	add_to_group("boss")
	var light := PointLight2D.new()
	if ResourceLoader.exists("res://assets/fx/light_radial.png"):
		light.texture = load("res://assets/fx/light_radial.png")
	light.energy = 1.1
	light.texture_scale = 2.4
	light.color = Color(0.78, 0.45, 1.0)
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_NONE
	add_child(light)
	atk_cd = 1.8
	_roll_moves()


## 每个阶段抽 2 个不重复招式
func _roll_moves() -> void:
	for p in [1, 2, 3]:
		var pool: Array = POOLS[p].duplicate()
		SeedManager.shuffle(pool)
		moves[p] = [pool[0], pool[1]]
	move_idx = 0


func current_moves() -> Array:
	return moves.get(phase, [])


func _ai(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()

	# 冲锋中
	if charge_t > 0.0:
		charge_t -= delta
		position += charge_dir * 300.0 * delta
		if charge_t <= 0.0:
			GameFeel.screen_shake(0.2)
		return

	# 螺旋弹持续发射
	if spiral_left > 0:
		spiral_t -= delta
		if spiral_t <= 0.0:
			spiral_t = 0.1
			spiral_left -= 1
			spiral_angle += deg_to_rad(20.0)
			shoot_at(Vector2(cos(spiral_angle), sin(spiral_angle)), 150.0, 4.0)
		if spiral_left <= 0:
			atk_cd = 0.8
		return

	if dist > 130.0:
		position += dir * speed * delta
	else:
		position += dir.orthogonal() * speed * 0.5 * delta

	summon_lock = maxf(0.0, summon_lock - delta)

	# 阶段转换预警
	if telegraph > 0.0:
		telegraph -= delta
		if telegraph <= 0.0 and pending_phase > 0:
			phase = pending_phase
			pending_phase = 0
			atk_cd = 0.55
			summon_lock = 0.5
			move_idx = 0
			GameFeel.screen_shake(0.3)
		return

	atk_cd -= delta
	if atk_cd <= 0.0:
		_do_move(dir)
		atk_cd = 1.5

	if phase >= 3 and summon_lock <= 0.0:
		summon_cd -= delta
		if summon_cd <= 0.0:
			summon_cd = 8.0
			_do_summon()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not dead:
		_update_phase()


func _update_phase() -> void:
	var ratio := hp_ratio()
	var new_phase := 1
	if ratio <= 0.25:
		new_phase = 3
	elif ratio <= 0.6:
		new_phase = 2
	if new_phase != phase and pending_phase == 0 and telegraph <= 0.0:
		pending_phase = new_phase
		telegraph = 0.75
		atk_cd = 1.2
		summon_lock = 0.75 + 0.5
		GameFeel.hit_stop(0.12, 0.05)
		GameFeel.screen_shake(0.55)
		GameFeel.burst(global_position, Color(1.0, 0.35, 0.45), 16, 190.0, 0.5)
		Sfx.play("boss", -2.0, 1.1)


func _do_move(dir: Vector2) -> void:
	var list := current_moves()
	if list.is_empty():
		_attack_ring()
		return
	var mv: String = list[move_idx % list.size()]
	move_idx += 1
	match mv:
		"ring":
			_attack_ring()
		"fan":
			_attack_fan(dir)
		"charge":
			charge_dir = dir
			charge_t = 0.6
			Sfx.play("charge_windup", -2.0, 0.8)
		"homing":
			_attack_homing(dir)
		"summon":
			_do_summon()
		"laser":
			var l = LaserScene.new()
			l.origin = global_position
			l.base_angle = dir.angle()
			GameState.bullets_root.add_child(l)
			Sfx.play("laser_charge", -2.0, 1.0)
		"spiral":
			spiral_left = 15
			spiral_t = 0.0
			spiral_angle = dir.angle()
			Sfx.play("warn_high", -2.0, 0.9)
			Sfx.play("spiral_fire", -6.0, 1.0)
		"mine":
			_drop_mines()
		_:
			_attack_ring()


func _attack_ring() -> void:
	var count := 14
	ring_angle += 0.22
	for i in count:
		var a := TAU * i / count + ring_angle
		shoot_at(Vector2(cos(a), sin(a)), 132.0, 4.2)
	Sfx.play("hit", -8.0, 0.7)


func _attack_homing(dir: Vector2) -> void:
	Sfx.play("lock_beep", -4.0, 1.0)
	for i in 3:
		var a := dir.rotated(deg_to_rad(-18.0 + 18.0 * i))
		_spawn_homing(a)
	Sfx.play("whoosh", -4.0, 0.9)


func _attack_fan(dir: Vector2) -> void:
	for i in 7:
		var t2 := float(i) / 6.0 - 0.5
		shoot_at(dir.rotated(deg_to_rad(52.0 * t2)), 172.0, 4.0)
	Sfx.play("hit", -8.0, 0.85)


## 追踪弹：可被玩家子弹击落
func _spawn_homing(a: Vector2) -> void:
	var b = GameFeel.get_bullet()
	if b == null:
		return
	b.friendly = false
	b.dir = a
	b.speed = 100.0
	b.damage = 1.0
	b.radius = 4.6
	b.color = Color("#ff8a4d")
	b.life = 6.0
	b.homing = 2.2
	b.homing_time = 2.5
	b.destructible = true
	b.pierce = 0
	b.gen = 0
	b.trail = true
	b.crit = false
	b.tier = "medium"
	b.global_position = global_position + a * (radius + 4.0)
	b.prepare()


func _drop_mines() -> void:
	for i in 3:
		var b = GameFeel.get_bullet()
		if b == null:
			return
		var ang := SeedManager.randf() * TAU
		var dist := SeedManager.randf_range(70.0, 170.0)
		b.friendly = false
		b.dir = Vector2.ZERO
		b.speed = 0.0
		b.damage = 1.0
		b.radius = 5.0
		b.color = Color("#ff6b3d")
		b.life = 4.0
		b.mine = true
		b.mine_fuse = 1.5
		b.pierce = 0
		b.gen = 0
		b.trail = false
		b.crit = false
		b.tier = "medium"
		b.global_position = global_position + Vector2(cos(ang), sin(ang)) * dist
		b.prepare()
	Sfx.play("mine_drop", -4.0, 0.9)


func _do_summon() -> void:
	if GameState.bullets_root == null:
		return
	for i in 2:
		var e = ChaserScene.instantiate()
		var ang := SeedManager.randf() * TAU
		e.position = global_position + Vector2(cos(ang), sin(ang)) * 60.0
		GameState.bullets_root.add_child(e)
	Sfx.play("skill", -8.0, 1.4)


# ---------------- 绘制 ----------------
func _draw_body() -> void:
	var c := accent
	match phase:
		2:
			c = Color("#ff7ad9")
		3:
			c = Color("#ff5b5b")
	for k in 3:
		var rr := radius + 6.0 + k * 5.0
		var a0 := t * (0.8 + k * 0.5)
		draw_arc(Vector2.ZERO, rr, a0, a0 + PI * 1.3, 20,
			Color(c.r, c.g, c.b, 0.45 - k * 0.1), 2.0, true)
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0 + t * 0.5
		var rr := radius * (1.0 if i % 2 == 0 else 0.58)
		pts.append(Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, c)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0, 0, 0, 0.9), 2.0)
	if telegraph > 0.0:
		var k: float = 1.0 - telegraph / 0.75
		var warn := Color(1.0, 0.35, 0.4, 0.55 * (1.0 - k * 0.6))
		draw_arc(Vector2.ZERO, radius + 14.0 + k * 26.0, 0.0, TAU, 40, warn, 2.0, true)
		draw_circle(Vector2.ZERO, radius * 0.5, Color(1.0, 0.3, 0.35, 0.25))
	if charge_t > 0.0:
		draw_line(Vector2.ZERO, charge_dir * (radius + 30.0), Color(1.0, 0.3, 0.25, 0.5), 3.0)
	draw_circle(Vector2.ZERO, radius * 0.44, Color(1, 1, 1, 0.95))
	draw_circle(Vector2.ZERO, radius * 0.24, Color(0.1, 0.02, 0.15, 1.0))
