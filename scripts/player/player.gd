extends CharacterBody2D
## 玩家：移动 / 瞄准 / 射击 / 翻滚 / 主动技能 / 受击
## 角色差异全部通过 weapon 脚本 + data 资源驱动

signal died

var char_id: String = "deepseek"
var data: CharacterData = null
var anim: AnimatedSprite2D
var cam: Camera2D
var weapon = null

var hp: int = 6
var max_hp: int = 6
var alive: bool = true
var aim: Vector2 = Vector2.RIGHT
var facing: int = 1

var invuln: float = 0.0
var roll_t: float = 0.0
var roll_cd: float = 0.0
var roll_dir: Vector2 = Vector2.ZERO
var move_mult: float = 1.0

var focus_target: Node = null
var focus_stacks: int = 0
var tokens: int = 0
var buffs: Dictionary = {}
var buff_timer: float = 0.0
var shield_hits: int = 0
var shield_t: float = 0.0

var fire_anim: float = 0.0
var charge_ratio: float = 0.0
var _blink: float = 0.0


func _ready() -> void:
	add_to_group("player")
	char_id = GameState.char_id
	data = GameState.char_data
	max_hp = GameState.max_hp
	hp = GameState.hp
	_build_nodes()
	_build_weapon()
	GameState.player = self


func _build_nodes() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = GameConfig.PLAYER_RADIUS
	shape.shape = circle
	shape.position = Vector2(0, -6)
	add_child(shape)

	anim = AnimatedSprite2D.new()
	anim.sprite_frames = GameConfig.build_sprite_frames(char_id)
	anim.offset = Vector2(0, -29)
	anim.self_modulate = Color(1.2, 1.2, 1.3)
	anim.play("idle")
	add_child(anim)

	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	var r := GameConfig.room_rect()
	cam.limit_left = int(r.position.x)
	cam.limit_top = int(r.position.y)
	cam.limit_right = int(r.end.x)
	cam.limit_bottom = int(r.end.y)
	add_child(cam)
	cam.make_current()


func _build_weapon() -> void:
	if data == null or data.weapon_path == "":
		return
	if not ResourceLoader.exists(data.weapon_path):
		push_warning("武器脚本缺失: %s" % data.weapon_path)
		return
	var script: Script = load(data.weapon_path)
	if script == null:
		return
	weapon = Node2D.new()
	weapon.set_script(script)
	weapon.name = "Weapon"
	add_child(weapon)
	if weapon.has_method("setup"):
		weapon.setup(self)


# ---------------- 主循环 ----------------
func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		return

	_tick_timers(delta)

	var mouse := get_global_mouse_position()
	aim = (mouse - global_position).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	facing = -1 if aim.x < 0.0 else 1
	anim.flip_h = facing > 0

	if roll_t > 0.0:
		velocity = roll_dir * GameConfig.ROLL_SPEED
	else:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var spd: float = GameConfig.PLAYER_SPEED * GameState.stat("move_speed", 1.0) * move_mult
		velocity = input * spd
		_update_anim(input)

	move_and_slide()
	_clamp_room()
	_handle_actions()
	queue_redraw()


func _tick_timers(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	roll_t = maxf(0.0, roll_t - delta)
	roll_cd = maxf(0.0, roll_cd - delta)
	fire_anim = maxf(0.0, fire_anim - delta)
	shield_t = maxf(0.0, shield_t - delta)
	if shield_t <= 0.0:
		shield_hits = 0
	if buff_timer > 0.0:
		buff_timer -= delta
		if buff_timer <= 0.0:
			buffs.clear()

	# 无敌帧闪烁
	_blink += delta
	if invuln > 0.0 and fmod(_blink, 0.12) < 0.06:
		anim.modulate.a = 0.35
	else:
		anim.modulate.a = 1.0


func _update_anim(input: Vector2) -> void:
	if fire_anim > 0.0 and anim.sprite_frames.has_animation("attack"):
		if anim.animation != "attack":
			anim.play("attack")
		return
	if input.length() > 0.1:
		if anim.animation != "walk":
			anim.play("walk")
	else:
		if anim.animation != "idle":
			anim.play("idle")


func _clamp_room() -> void:
	var r := GameConfig.room_rect()
	var pad := GameConfig.WALL + 4.0
	global_position.x = clampf(global_position.x, r.position.x + pad, r.end.x - pad)
	global_position.y = clampf(global_position.y, r.position.y + pad, r.end.y - pad)


func _handle_actions() -> void:
	if Input.is_action_just_pressed("roll"):
		_try_roll()
	if Input.is_action_just_pressed("switch_mode") and weapon != null:
		weapon.on_switch_mode()
		Sfx.play("ui", -6.0)
	if Input.is_action_just_pressed("skill"):
		_try_skill()
	if Input.is_action_pressed("shoot") and weapon != null and roll_t <= 0.0:
		weapon.try_fire(aim)
		fire_anim = 0.12


# ---------------- 翻滚 ----------------
func _try_roll() -> void:
	if roll_cd > 0.0 or roll_t > 0.0:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	roll_dir = input.normalized() if input.length() > 0.1 else aim
	roll_t = GameConfig.ROLL_TIME
	roll_cd = GameConfig.ROLL_CD * GameState.stat("roll_cd_mult", 1.0)
	grant_invuln(GameConfig.ROLL_TIME + 0.02)
	if anim.sprite_frames.has_animation("roll"):
		anim.play("roll")
	Sfx.play("roll")


func _try_skill() -> void:
	if weapon == null or not weapon.skill_ready():
		return
	if weapon.use_skill():
		weapon.start_skill_cd()
		fire_anim = 0.2


# ---------------- 状态接口 ----------------
func grant_invuln(t: float) -> void:
	invuln = maxf(invuln, t)


func try_absorb_bullet() -> bool:
	if shield_hits <= 0:
		return false
	shield_hits -= 1
	GameState.heal(2)
	hp = GameState.hp
	Sfx.play("coin", -8.0, 1.4)
	return true


func take_damage(amount: int) -> void:
	if invuln > 0.0 or not alive:
		return
	invuln = GameConfig.INVULN_TIME
	hp -= amount
	GameState.hp = maxi(0, hp)
	GameState.hp_changed.emit(GameState.hp, GameState.max_hp)
	Sfx.play("hurt")
	if hp <= 0:
		_die()


func _die() -> void:
	alive = false
	hp = 0
	GameState.hp = 0
	anim.modulate = Color(1, 1, 1, 0.4)
	Sfx.play("die")
	died.emit()
	GameState.run_ended.emit()


func record_hit(e: Node) -> void:
	if focus_target == e:
		focus_stacks = mini(10, focus_stacks + 1)
	else:
		focus_target = e
		focus_stacks = 1


func on_kill() -> void:
	tokens = mini(20, tokens + 1)


func add_buff(kind: String, value: float, dur: float) -> void:
	buffs[kind] = value
	buff_timer = maxf(buff_timer, dur)


func get_buff(kind: String, default_value: float = 0.0) -> float:
	if buff_timer <= 0.0:
		return default_value
	return float(buffs.get(kind, default_value))


# ---------------- 绘制（护盾 / 蓄力） ----------------
func _draw() -> void:
	# 落地阴影（画在精灵下方，先绘制）
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2(0, 2), 9.0, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if shield_hits > 0:
		var a: float = 0.35 + 0.25 * sin(Time.get_ticks_msec() / 90.0)
		draw_circle(Vector2(0, -14), 26.0, Color(0.98, 0.75, 0.35, 0.10))
		draw_arc(Vector2(0, -14), 26.0, 0.0, TAU, 32, Color(0.98, 0.78, 0.4, a), 2.0, true)
		for i in shield_hits:
			var ang := TAU * i / 6.0
			draw_circle(Vector2(0, -14) + Vector2(cos(ang), sin(ang)) * 26.0, 1.8,
				Color(1.0, 0.86, 0.5, 0.9))
	if charge_ratio > 0.0:
		draw_arc(Vector2(0, -14), 20.0, -PI / 2.0, -PI / 2.0 + TAU * charge_ratio, 24,
			Color(0.55, 0.75, 1.0, 0.95), 2.0, true)
