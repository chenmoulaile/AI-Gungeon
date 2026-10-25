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
	"summon": "召", "laser": "激", "spiral": "旋", "mine": "雷", "cross": "叉",
}

## 身份配置：登场界面与 HUD 都从这里取，子类在 _setup 里覆盖
var boss_key: String = "echo"
var display_name: String = "回响聚合体"
var subtitle: String = "ECHO AGGREGATE"
var intro_lines: Array = [
	"三个助手的推理回响，在这个房间里聚成了一个实体。",
	"它没有名字，只有你刚才打出的每一发子弹的记忆。",
	"清空它，才能进入下一层。",
]
var accent_color: Color = Color("#b45cff")
var light_color: Color = Color(0.72, 0.45, 1.0)

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
	_setup_common()


## 子类设完数值后调用：公共标记、点光源、招式抽取
func _setup_common() -> void:
	accent = accent_color
	is_boss = true
	add_to_group("boss")
	var light := PointLight2D.new()
	if ResourceLoader.exists("res://assets/fx/light_radial.png"):
		light.texture = load("res://assets/fx/light_radial.png")
	light.energy = 0.85
	light.texture_scale = 1.5
	light.color = light_color
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_NONE
	add_child(light)
	# 本体不参与 2D 光照：否则自己的点光会把像素体染色，看着像没做像素化
	light_mask = 0
	atk_cd = 1.8
	_roll_moves()


## 登场界面配置
func intro_config() -> Dictionary:
	return {
		"name": display_name,
		"subtitle": subtitle,
		"lines": intro_lines,
		"color": accent,
	}


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
		position += dir * speed * slow_mult * delta
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
		# 阶段转换：全屏闪白 0.15s + 2~3px 色差 0.15s
		GameFeel.screen_flash(Color(1, 1, 1), 0.15, 0.5)
		GameFeel.aberrate(3.0, 0.15)
		# 闪白 1 帧后整体提饱和，暗示"变强了"
		modulate = Color(3.0, 3.0, 3.0)
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color(1.15, 0.92, 1.18), 0.25)
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
## Boss 全像素化：阶梯晶体本体 + 2×2 旋转环 + 像素眼，不使用任何平滑圆/弧
func _draw_body() -> void:
	var c := accent
	match phase:
		2:
			c = Color("#ff7ad9")
		3:
			c = Color("#ff5b5b")
	var edge := Color("#14081F")

	# 外圈：三圈像素块，内圈 3×3 + 外两圈 2×2，转速不同，形成“回响”环
	for k in 3:
		var rr: float = radius + 7.0 + k * 5.0
		var count: int = 12 + k * 4
		var spin: float = t * (0.55 + k * 0.42)
		var a_ring: float = 0.78 - k * 0.16
		var sz: float = 3.0 if k == 0 else 2.0
		for i in count:
			var a := spin + TAU * float(i) / float(count)
			var px := roundf(cos(a) * rr * 0.5) * 2.0
			var py := roundf(sin(a) * rr * 0.5) * 2.0
			draw_rect(Rect2(px - sz * 0.5, py - sz * 0.5, sz, sz),
				Color(c.r, c.g, c.b, a_ring))

	# 本体：12 行阶梯矩形，拼成带尖顶的晶体
	var widths := [8.0, 18.0, 30.0, 42.0, 52.0, 58.0, 58.0, 52.0, 44.0, 34.0, 22.0, 10.0]
	var rects: Array = []
	for i in widths.size():
		var w := float(widths[i])
		rects.append(Rect2(-w * 0.5, -30.0 + float(i) * 4.0, w, 4.0))
	_px_rects(rects, c.darkened(0.18), edge)

	# 四角尖刺：让轮廓更凶
	var horns: Array = [
		Rect2(-32.0, -14.0, 6.0, 6.0),
		Rect2(26.0, -14.0, 6.0, 6.0),
		Rect2(-30.0, 8.0, 4.0, 8.0),
		Rect2(26.0, 8.0, 4.0, 8.0),
		Rect2(-4.0, -36.0, 8.0, 6.0),
	]
	_px_rects(horns, c.darkened(0.05), edge)

	# 晶体切面：左上高光、右下暗面
	draw_rect(Rect2(-22.0, -22.0, 14.0, 4.0), c.lightened(0.22))
	draw_rect(Rect2(-26.0, -18.0, 8.0, 4.0), c.lightened(0.10))
	draw_rect(Rect2(8.0, 2.0, 14.0, 4.0), c.darkened(0.36))
	draw_rect(Rect2(12.0, 6.0, 8.0, 4.0), c.darkened(0.36))
	draw_rect(Rect2(-2.0, 10.0, 10.0, 4.0), c.darkened(0.30))

	# 像素眼：菱形眼白 + 竖瞳
	_px_rects([
		Rect2(-3.0, -11.0, 6.0, 2.0),
		Rect2(-7.0, -9.0, 14.0, 2.0),
		Rect2(-9.0, -7.0, 18.0, 6.0),
		Rect2(-7.0, -1.0, 14.0, 2.0),
		Rect2(-3.0, 1.0, 6.0, 2.0),
	], Color("#F7F1FF"), Color("#3A2350"))
	draw_rect(Rect2(-2.0, -7.0, 4.0, 6.0), Color("#140A22"))
	draw_rect(Rect2(-2.0, -5.0, 1.0, 1.0), Color("#FFFFFF"))
	draw_rect(Rect2(1.0, -2.0, 1.0, 1.0), c.lightened(0.45))

	# 眼下的裂纹
	draw_rect(Rect2(-16.0, 5.0, 6.0, 2.0), c.darkened(0.48))
	draw_rect(Rect2(10.0, 5.0, 6.0, 2.0), c.darkened(0.48))
	draw_rect(Rect2(-10.0, 11.0, 4.0, 2.0), c.darkened(0.48))
	draw_rect(Rect2(6.0, 11.0, 4.0, 2.0), c.darkened(0.48))

	if telegraph > 0.0:
		var k: float = 1.0 - telegraph / 0.75
		var warn := Color(1.0, 0.35, 0.4, 0.55 * (1.0 - k * 0.6))
		var rr := radius + 14.0 + k * 26.0
		for i in 24:
			var a := TAU * float(i) / 24.0
			var px := roundf(cos(a) * rr * 0.5) * 2.0
			var py := roundf(sin(a) * rr * 0.5) * 2.0
			draw_rect(Rect2(px - 2.0, py - 2.0, 4.0, 4.0), warn)
		# 中心蓄力方块
		var ex := roundf(radius * 0.5)
		draw_rect(Rect2(-ex, -ex, ex * 2.0, ex * 2.0), Color(1.0, 0.3, 0.35, 0.16))

	if charge_t > 0.0:
		for i in 5:
			var p := charge_dir * (radius + 8.0 + float(i) * 9.0)
			var sz := maxf(2.0, 6.0 - float(i))
			var a := 0.55 - float(i) * 0.09
			draw_rect(Rect2(roundf(p.x * 0.5) * 2.0 - sz * 0.5,
				roundf(p.y * 0.5) * 2.0 - sz * 0.5, sz, sz),
				Color(1.0, 0.30, 0.25, maxf(0.08, a)))
