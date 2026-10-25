extends "res://scripts/weapons/subweapon_base.gd"
## DeepSeek 副武器「铁盆」（v0.9）
## 参考 BV1gVHA6mEbS：短按小挥击；长按蓄力，伤害/范围/音效随蓄力提升；
## 连续 3 次落空触发【要饭】，敌人有概率抛出大白饭（+15 Token）。

const CHARGE_MAX := 1.1
const COST_CHARGED := 6.0
const SHORT_TIME := 0.18
const ARC_COS := 0.42   # ±65°
const MISS_LIMIT := 3

const SwingScript = preload("res://scripts/weapons/basin_swing.gd")
const RiceScript = preload("res://scripts/systems/rice_pickup.gd")

var _charging: bool = false
var _charge: float = 0.0
var _misses: int = 0
var _fx_t: float = 0.0


func _configure() -> void:
	display_name = "铁盆"
	color = Color("#FFD166")
	cd_total = 1.0
	icon_path = "res://assets/weapons/basin_icon.png"


func _process(delta: float) -> void:
	super._process(delta)
	if _charging:
		if player == null or not is_instance_valid(player) or not player.alive:
			_cancel()
		else:
			queue_redraw()


func set_active(v: bool) -> void:
	# 切走时取消蓄力，避免松开鼠标时凭空挥一下
	if not v and _charging:
		_cancel()
	super.set_active(v)


func handle_input(delta: float) -> void:
	if _charging:
		# 蓄力中：保持在副武器槽且按住左键才继续，否则挥出
		var holding: bool = active and (Input.is_action_pressed("shoot")
			or InputBuffer.peek("shoot"))
		if holding:
			InputBuffer.clear("shoot")
			_charge = minf(CHARGE_MAX, _charge + delta)
			if player != null and is_instance_valid(player):
				player.charge_ratio = clampf(_charge / CHARGE_MAX, 0.0, 1.0)
				player.sub_move_mult = 0.78
			_fx_t -= delta
			if _fx_t <= 0.0 and player != null and is_instance_valid(player):
				_fx_t = 0.08
				var a := randf() * TAU
				GameFeel.burst(player.global_position + Vector2(0, -14)
					+ Vector2(cos(a), sin(a)) * randf_range(20.0, 32.0),
					Color(1.0, 0.82, 0.4, 0.65), 1, 20.0, 0.25)
		else:
			_release()
		return
	if not active:
		return
	if ready() and (InputBuffer.consume("shoot") or Input.is_action_just_pressed("shoot")):
		_start_charge()


func _start_charge() -> void:
	_charging = true
	_charge = 0.0
	_fx_t = 0.0
	if player != null and is_instance_valid(player):
		player.sub_move_mult = 0.78
		player.charge_ratio = 0.0
		if player.gun != null and is_instance_valid(player.gun):
			player.gun.visible = false
	Sfx.play("clang", -22.0, 0.62)
	queue_redraw()


func _cancel() -> void:
	_charging = false
	_charge = 0.0
	if player != null and is_instance_valid(player):
		player.charge_ratio = 0.0
		player.sub_move_mult = 1.0
		if player.gun != null and is_instance_valid(player.gun):
			player.gun.visible = true
	queue_redraw()


func _release() -> void:
	var ratio := clampf(_charge / CHARGE_MAX, 0.0, 1.0)
	var short := _charge < SHORT_TIME
	_charging = false
	_charge = 0.0
	if player == null or not is_instance_valid(player):
		return
	player.charge_ratio = 0.0
	player.sub_move_mult = 1.0
	if player.gun != null and is_instance_valid(player.gun):
		player.gun.visible = true

	if short:
		ratio = 0.06
	elif not player.spend_token(COST_CHARGED):
		player.notify("Token 不足 · 只能轻挥", 1.2)
		ratio = 0.12

	var dmg := 7.0 + 22.0 * ratio
	var reach := 34.0 + 34.0 * ratio
	var dir: Vector2 = player.aim
	var hit_any := false
	var origin: Vector2 = player.global_position + Vector2(0, -12)
	for e in GameState.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.global_position - origin
		var dist := to.length()
		var rr := reach + float(e.radius) * 0.55
		if dist > rr:
			continue
		if dist > 6.0 and dir.dot(to.normalized()) < ARC_COS:
			continue
		e.take_damage(dmg, dir, "heavy" if ratio > 0.65 else "medium", false, "basin")
		e.knock_vel += dir * (60.0 + 170.0 * ratio)
		player.record_hit(e)
		GameFeel.hit_stop(0.03 + 0.05 * ratio, 0.05)
		hit_any = true

	var fx = SwingScript.new()
	fx.dir = dir
	fx.reach = reach
	fx.ratio = ratio
	fx.mode = "swing"
	fx.color = Color("#8EE6FF") if ratio < 0.7 else Color("#FFD166")
	fx.global_position = player.global_position + Vector2(0, -12)
	GameState.bullets_root.add_child(fx) if GameState.bullets_root != null else null
	if fx.get_parent() == null:
		fx.queue_free()

	GameFeel.screen_shake(0.10 + 0.25 * ratio)
	GameFeel.burst(origin + dir * reach * 0.7, Color(0.9, 0.95, 1.0),
		3 + int(ratio * 5.0), 80.0 + 90.0 * ratio, 0.22)
	Sfx.play("whoosh", -24.0 + 18.0 * ratio, 0.9 + 0.35 * ratio)
	if hit_any:
		Sfx.play("clang", -18.0 + 14.0 * ratio, 0.9 if ratio < 0.6 else 0.72)
		_misses = 0
	else:
		_misses += 1
		if _misses >= MISS_LIMIT:
			_beg()

	player.fire_anim = 0.16
	start_cd(0.75 + 0.45 * ratio)
	queue_redraw()


## 连续 3 次落空：要饭，敌人抛大白饭
func _beg() -> void:
	_misses = 0
	var origin: Vector2 = player.global_position
	var count := 0
	var spawned := 0
	for e in GameState.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		if origin.distance_to(e.global_position) > 120.0:
			continue
		count += 1
		if randf() <= 0.55:
			var rice = RiceScript.new()
			rice.global_position = e.global_position
			rice.amount = 15.0
			GameState.bullets_root.add_child(rice) if GameState.bullets_root != null else null
			if rice.get_parent() == null:
				rice.queue_free()
				continue
			spawned += 1
			GameFeel.burst(e.global_position, Color(1.0, 0.92, 0.55), 5, 60.0, 0.3)
	var ring = SwingScript.new()
	ring.mode = "beg"
	ring.reach = 120.0
	ring.color = Color("#FFD166")
	ring.life = 0.36
	ring.global_position = origin
	GameState.bullets_root.add_child(ring) if GameState.bullets_root != null else null
	if ring.get_parent() == null:
		ring.queue_free()
	if count == 0:
		player.notify("要饭失败 · 周围没人理你", 1.3)
	elif spawned == 0:
		player.notify("要饭失败 · 他们没带饭", 1.3)
	else:
		player.notify("要饭成功 · 大白饭 x%d" % spawned, 1.5)
	Sfx.play("coin", -6.0, 0.8)
	Sfx.play("ui", -12.0, 0.7)


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	if _charging or active:
		_draw_held_basin()
	else:
		_draw_head_basin()


## 平时：铁盆缩小戴在头顶（呼应原作被动）
func _draw_head_basin() -> void:
	var edge := Color("#15224A")
	var blue := Color("#2E5BD0")
	var hi := Color("#86E3FF")
	var bob := -1.0 if fmod(Time.get_ticks_msec() / 1000.0, 1.6) < 0.8 else 0.0
	var y := -58.0 + bob
	draw_rect(Rect2(-8, y, 16, 2), edge)
	draw_rect(Rect2(-7, y + 2, 14, 3), edge)
	draw_rect(Rect2(-6, y, 12, 2), blue)
	draw_rect(Rect2(-6, y + 1, 12, 1), hi)
	draw_rect(Rect2(-5, y + 2, 10, 1), Color("#1B3A8F"))
	draw_rect(Rect2(-2, y - 1, 4, 1), Color("#F4F6FF"))


## 蓄力：铁盆出现在手前，越满越亮
func _draw_held_basin() -> void:
	var edge := Color("#15224A")
	var blue := Color("#2E5BD0")
	var hi := Color("#86E3FF")
	var rice := Color("#F4F6FF")
	var ratio := clampf(_charge / CHARGE_MAX, 0.0, 1.0)
	var aim: Vector2 = player.aim
	var local: Vector2 = aim * (20.0 + 6.0 * ratio) + Vector2(0, -12)
	draw_set_transform(local.round(), aim.angle(), Vector2.ONE)
	# 盆体外框（宽口浅盆）
	draw_rect(Rect2(-10, -6, 30, 3), edge)
	draw_rect(Rect2(-12, -3, 34, 12), edge)
	draw_rect(Rect2(-9, 9, 28, 2), edge)
	draw_rect(Rect2(-11, -4, 32, 10), blue)
	draw_rect(Rect2(-9, 6, 28, 2), Color("#1B3A8F"))
	draw_rect(Rect2(-11, -4, 32, 1), hi if ratio < 0.7 else Color("#FFD166"))
	draw_rect(Rect2(-10, -6, 30, 2), rice)
	draw_rect(Rect2(-6, -7, 20, 2), rice)
	draw_rect(Rect2(-3, -7, 3, 1), Color("#FFFFFF"))
	# 手柄
	draw_rect(Rect2(-14, -1, 4, 7), edge)
	draw_rect(Rect2(-13, 0, 2, 5), Color("#5A4630"))
	# 蓄力环
	if ratio > 0.05:
		var glow := Color(1.0, 0.82, 0.4, 0.35 + 0.45 * ratio)
		for i in 8:
			var a := TAU * float(i) / 8.0 + _charge * 3.0
			var p := Vector2(roundf(cos(a) * 20.0 / 2.0) * 2.0, roundf(sin(a) * 14.0 / 2.0) * 2.0)
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), glow)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
