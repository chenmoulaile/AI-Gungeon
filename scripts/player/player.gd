extends CharacterBody2D
## 玩家：移动 / 瞄准 / 射击 / 翻滚 / 主动技能 / 受击
## 输入统一走 InputBuffer（0.10s 缓冲）：翻滚优先，射击在翻滚期间被缓冲

signal died

const ACCEL := 1500.0
const DECEL := 2100.0
const ROLL_GHOST_GAP := 0.045
const HURT_STUN := 0.12

var char_id: String = "deepseek"
var data: CharacterData = null
var anim: AnimatedSprite2D
var cam: Camera2D
var weapon = null
var sub = null
## 副武器长按等状态带来的额外移速倍率（与技能 move_mult 相乘）
var sub_move_mult: float = 1.0

## 转向/动画分层：pivot 只做倾斜，bob 做待机与走路起伏，recoil 做后坐/受击位移，
## breath 做呼吸缩放，anim 只负责帧与翻滚挤压
var pivot: Node2D
var bob: Node2D
var recoil: Node2D
var breath: Node2D
var accent: Node2D
var gun: Node2D
var key_light: PointLight2D

var _move_tween: Tween = null
var _breath_tween: Tween = null
var _turn_tw: Tween = null
var _anim_state: String = "idle"
var _walk_dur: float = -1.0

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
var hurt_stun: float = 0.0

var focus_target: Node = null
var focus_stacks: int = 0
var tokens: int = 0
var buffs: Dictionary = {}
var buff_timer: float = 0.0
var shield_hits: int = 0
var shield_t: float = 0.0

var fire_anim: float = 0.0
var charge_ratio: float = 0.0
var roll_buff: float = 0.0
var hit_chain: int = 0
var hit_chain_t: float = 0.0
var roll_speed_t: float = 0.0
var _low_hp_said: bool = false
var _shield_flash: float = 0.0

var _blink: float = 0.0
var _ghost_t: float = 0.0
var _bump_cd: float = 0.0
var _muzzle_cd: float = 0.0


func _ready() -> void:
	add_to_group("player")
	char_id = GameState.char_id
	data = GameState.char_data
	var cs: CharacterStats = Stats.char(char_id)
	if cs != null:
		max_hp = cs.max_hp + int(GameState.stat("max_hp_bonus", 0))
	GameState.max_hp = max_hp
	hp = GameState.hp if GameState.hp > 0 else max_hp
	_build_nodes()
	_build_weapon()
	_build_subweapon()
	GameState.player = self


func _input(event: InputEvent) -> void:
	# 只记录"按下"，实际消费在 _handle_actions，保证 0.10s 内不丢输入
	if event.is_action_pressed("roll"):
		InputBuffer.press("roll")
	elif event.is_action_pressed("shoot"):
		InputBuffer.press("shoot")


func _build_nodes() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = GameConfig.PLAYER_RADIUS
	shape.shape = circle
	shape.position = Vector2(0, -6)
	add_child(shape)

	pivot = Node2D.new()
	pivot.name = "Pivot"
	add_child(pivot)

	bob = Node2D.new()
	bob.name = "Bob"
	pivot.add_child(bob)

	recoil = Node2D.new()
	recoil.name = "Recoil"
	bob.add_child(recoil)

	breath = Node2D.new()
	breath.name = "Breath"
	recoil.add_child(breath)

	anim = AnimatedSprite2D.new()
	anim.sprite_frames = GameConfig.build_sprite_frames(char_id)
	anim.offset = Vector2(0, -29)
	anim.self_modulate = Color(1.32, 1.32, 1.38)
	anim.light_mask = 0   # 角色不参与 2D 光照，避免被自己的点光源打爆成白色
	anim.play("idle")
	# 暗色描边：浅色地面上白色系角色也能和背景分开
	if ResourceLoader.exists("res://shaders/sprite_outline.gdshader"):
		var om := ShaderMaterial.new()
		om.shader = load("res://shaders/sprite_outline.gdshader")
		anim.material = om
	breath.add_child(anim)

	# 配饰：鲸尾 / 龙翼 / 向日葵（程序化绘制，Tween 驱动）
	accent = Node2D.new()
	accent.name = "Accent"
	accent.set_script(load("res://scripts/player/char_accent.gd"))
	breath.add_child(accent)
	breath.move_child(accent, 0)   # 画在角色身后
	if accent.has_method("setup"):
		accent.setup(char_id)

	# 手持装置：精确指向瞄准方向
	gun = Node2D.new()
	gun.name = "Gun"
	gun.z_index = 2
	gun.set_script(load("res://scripts/player/hand_device.gd"))
	add_child(gun)
	gun.position = Vector2(0, -12)
	gun.scale = Vector2(0.75, 0.75)

	var light := PointLight2D.new()
	if ResourceLoader.exists("res://assets/fx/light_radial.png"):
		light.texture = load("res://assets/fx/light_radial.png")
	light.energy = 0.85
	light.texture_scale = 1.9
	light.color = Color(1.0, 0.96, 0.9)
	light.position = Vector2(0, -14)
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_NONE
	add_child(light)
	key_light = light

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
	GameFeel.register_camera(cam)
	_start_idle_loop()


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


## 专属副武器：每个角色一把，只有对应角色能用
func _build_subweapon() -> void:
	var path := ""
	match char_id:
		"deepseek":
			path = "res://scripts/weapons/sub_deep_retrieval.gd"
		"gpt":
			path = "res://scripts/weapons/sub_thought_chain.gd"
		"claude":
			path = "res://scripts/weapons/sub_alignment_protocol.gd"
	if path == "" or not ResourceLoader.exists(path):
		return
	sub = Node2D.new()
	sub.set_script(load(path))
	sub.name = "SubWeapon"
	add_child(sub)
	if sub.has_method("setup"):
		sub.setup(self)


# ---------------- 主循环 ----------------
func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		return

	_tick_timers(delta)

	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > 0.25:
		aim = stick.normalized()
	else:
		var mouse := get_global_mouse_position()
		aim = (mouse - global_position).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	_update_facing()
	_update_lean(delta)
	gun.set_aim(aim)
	gun.position = Vector2(0, -12) + aim * 7.0

	if roll_t > 0.0:
		velocity = roll_dir * GameConfig.ROLL_SPEED
		_spawn_ghost(delta)
	else:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var base_spd: float = GameConfig.PLAYER_SPEED
		var cs2: CharacterStats = Stats.char(char_id)
		if cs2 != null:
			base_spd = cs2.move_speed
		var spd: float = base_spd * GameState.stat("move_speed", 1.0) * move_mult * sub_move_mult
		if roll_speed_t > 0.0:
			spd *= 1.0 + float(GameState.mods.get("roll_speed", 0.0))
		var target := input * spd
		var rate := ACCEL if input.length() > 0.1 else DECEL
		velocity = velocity.move_toward(target, rate * delta)
		_update_anim(input)

	move_and_slide()
	_wall_bump()
	_clamp_room()
	_handle_actions()
	queue_redraw()


func _tick_timers(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	roll_t = maxf(0.0, roll_t - delta)
	roll_cd = maxf(0.0, roll_cd - delta)
	fire_anim = maxf(0.0, fire_anim - delta)
	shield_t = maxf(0.0, shield_t - delta)
	hurt_stun = maxf(0.0, hurt_stun - delta)
	_shield_flash = maxf(0.0, _shield_flash - delta)
	roll_speed_t = maxf(0.0, roll_speed_t - delta)
	if hit_chain_t > 0.0:
		hit_chain_t -= delta
		if hit_chain_t <= 0.0:
			hit_chain = 0
	_bump_cd = maxf(0.0, _bump_cd - delta)
	_muzzle_cd = maxf(0.0, _muzzle_cd - delta)
	if shield_t <= 0.0:
		shield_hits = 0
	if buff_timer > 0.0:
		buff_timer -= delta
		if buff_timer <= 0.0:
			buffs.clear()

	_blink += delta
	if invuln > 0.0 and fmod(_blink, 0.12) < 0.06:
		anim.modulate.a = 0.35
	else:
		anim.modulate.a = 1.0


func _update_anim(input: Vector2) -> void:
	if _anim_state == "roll":
		_anim_state = ""
	var next := "idle"
	if fire_anim > 0.0 and anim.sprite_frames.has_animation("attack"):
		next = "attack"
	elif input.length() > 0.1:
		next = "walk"
	if next == _anim_state:
		return
	_anim_state = next
	if anim.sprite_frames.has_animation(next):
		anim.play(next)
	if next == "idle":
		_start_idle_loop()
	elif next == "walk":
		_start_walk_loop()


## 待机：上下 1px 浮动 + 呼吸缩放 1.00→1.02，周期 1.7s
func _start_idle_loop() -> void:
	_kill_move_tween()
	_move_tween = create_tween().set_loops()
	_move_tween.tween_property(bob, "position:y", -1.0, 0.85)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(bob, "position:y", 0.0, 0.85)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath_tween = create_tween().set_loops()
	_breath_tween.tween_property(breath, "scale", Vector2(1.02, 1.02), 0.85)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath_tween.tween_property(breath, "scale", Vector2.ONE, 0.85)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 走路：左右摆 ±1px + 上下弹跳，频率随移速变化
func _start_walk_loop() -> void:
	var spd: float = maxf(40.0, velocity.length())
	var dur: float = clampf(0.34 * (120.0 / spd), 0.15, 0.34)
	if absf(dur - _walk_dur) < 0.02 and _move_tween != null and _move_tween.is_valid():
		return
	_walk_dur = dur
	_kill_move_tween()
	_move_tween = create_tween().set_loops()
	_move_tween.tween_property(bob, "position", Vector2(-1.0, -1.5), dur * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(bob, "position", Vector2(1.0, 0.0), dur * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _kill_move_tween() -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	if _breath_tween != null and _breath_tween.is_valid():
		_breath_tween.kill()
	_move_tween = null
	_breath_tween = null
	_walk_dur = -1.0
	if bob != null:
		bob.position = Vector2.ZERO
	if breath != null:
		breath.scale = Vector2.ONE


## 方向切换：滞回阈值避免鼠标在正上方时反复翻转，切换瞬间挤压回弹
func _update_facing() -> void:
	var f := facing
	if aim.x > 0.16:
		f = 1
	elif aim.x < -0.16:
		f = -1
	if f == facing:
		return
	facing = f
	anim.flip_h = facing > 0
	if accent != null:
		accent.scale.x = -1.0 if anim.flip_h else 1.0
	if _turn_tw != null and _turn_tw.is_valid():
		_turn_tw.kill()
	_turn_tw = create_tween()
	_turn_tw.tween_property(anim, "scale", Vector2(0.88, 1.06), 0.04)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_turn_tw.tween_property(anim, "scale", Vector2.ONE, 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 身体向瞄准方向轻微倾斜（平滑 14，差值 <2° 直接吸附）
func _update_lean(delta: float) -> void:
	var target := 0.0
	if absf(aim.y) < 0.8:
		target = aim.x * 0.055
	pivot.rotation = lerp_angle(pivot.rotation, target, 1.0 - exp(-14.0 * delta))
	if absf(pivot.rotation - target) < 0.02:
		pivot.rotation = target


## 射击后坐：向后 2px 再回弹（0.08s）
func _recoil_kick() -> void:
	if recoil == null:
		return
	recoil.position = -aim * 2.0
	var tw := recoil.create_tween()
	tw.tween_property(recoil, "position", Vector2.ZERO, 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)



func _wall_bump() -> void:
	if _bump_cd > 0.0 or roll_t > 0.0:
		return
	if not is_on_wall():
		return
	if velocity.length() < GameConfig.PLAYER_SPEED * 0.6:
		return
	_bump_cd = 0.35
	GameFeel.screen_shake(0.06)
	GameFeel.burst(global_position + Vector2(-facing * 6, 0), Color(0.7, 0.75, 0.85),
		3, 45.0, 0.2)


func _clamp_room() -> void:
	var r := GameConfig.room_rect()
	var pad := GameConfig.WALL + 4.0
	global_position.x = clampf(global_position.x, r.position.x + pad, r.end.x - pad)
	global_position.y = clampf(global_position.y, r.position.y + pad, r.end.y - pad)


func _handle_actions() -> void:
	# 1) 翻滚优先：受击硬直期间不接受翻滚，但移动照常
	if InputBuffer.peek("roll"):
		if hurt_stun <= 0.0 and roll_t <= 0.0 and roll_cd <= 0.0:
			InputBuffer.consume("roll")
			_try_roll()
		elif hurt_stun > 0.0:
			InputBuffer.clear("roll")

	if Input.is_action_just_pressed("switch_mode") and weapon != null:
		weapon.on_switch_mode()
		Sfx.play("ui", -6.0)
	if Input.is_action_just_pressed("skill"):
		_try_skill()
	if sub != null and is_instance_valid(sub):
		sub.handle_input(get_physics_process_delta_time())

	# 2) 射击：按住即射；翻滚期间的按下被缓冲，翻滚结束当帧释放
	var want_fire: bool = Input.is_action_pressed("shoot") or InputBuffer.peek("shoot")
	if want_fire and weapon != null and roll_t <= 0.0:
		InputBuffer.clear("shoot")
		weapon.try_fire(aim)
		fire_anim = 0.12
		_muzzle_flash()


func _muzzle_flash() -> void:
	if _muzzle_cd > 0.0:
		return
	_muzzle_cd = 0.05
	var muzzle: Vector2 = gun.global_position + aim * 11.0
	GameFeel.burst(muzzle, Color(1.0, 0.95, 0.75), 3, 60.0, 0.1)
	_recoil_kick()


# ---------------- 翻滚 ----------------
func _try_roll() -> void:
	if roll_cd > 0.0 or roll_t > 0.0:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	roll_dir = input.normalized() if input.length() > 0.1 else aim
	roll_t = GameConfig.ROLL_TIME
	var rcd: float = GameConfig.ROLL_CD
	var cs3: CharacterStats = Stats.char(char_id)
	if cs3 != null:
		rcd = cs3.roll_cd
	roll_cd = rcd * GameState.stat("roll_cd_mult", 1.0)
	grant_invuln(GameConfig.ROLL_TIME + 0.02)
	if anim.sprite_frames.has_animation("roll"):
		anim.play("roll")
	_anim_state = "roll"
	_kill_move_tween()
	_ghost_t = 0.0
	ChallengeManager.on_roll()
	roll_buff = float(GameState.mods.get("roll_shot_bonus", 0.0))
	if float(GameState.mods.get("roll_speed", 0.0)) > 0.0:
		roll_speed_t = 1.2
	Sfx.play("roll")
	anim.scale = Vector2(1.15, 0.85)
	var tw := anim.create_tween()
	tw.tween_property(anim, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _spawn_ghost(delta: float) -> void:
	_ghost_t -= delta
	if _ghost_t > 0.0:
		return
	_ghost_t = ROLL_GHOST_GAP
	if anim.sprite_frames == null:
		return
	var tex: Texture2D = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	GameFeel.afterimage(tex, global_position, anim.flip_h,
		Color(0.62, 0.78, 1.0, 0.5), 0.15)


func _try_skill() -> void:
	if weapon == null or not weapon.skill_ready():
		return
	if weapon.use_skill():
		weapon.start_skill_cd()
		ChallengeManager.on_skill()
		fire_anim = 0.2


# ---------------- 状态接口 ----------------
func grant_invuln(t: float) -> void:
	invuln = maxf(invuln, t)


func try_absorb_bullet() -> bool:
	if shield_hits <= 0:
		return false
	shield_hits -= 1
	_shield_flash = 0.12
	GameState.heal(2)
	hp = GameState.hp
	GameFeel.burst(global_position + Vector2(0, -14), Color(1.0, 0.85, 0.45), 5, 90.0, 0.25)
	Sfx.play("coin", -8.0, 1.4)
	if bool(GameState.mods.get("shield_counter", false)):
		_counter_shot()
	# 藏品：护盾碎掉时向四周还手
	if shield_hits == 0 and bool(GameState.mods.get("shield_break_burst", false)):
		_shield_break_burst()
	return true


func _shield_break_burst() -> void:
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var b = GameFeel.get_bullet()
		if b == null:
			return
		b.friendly = true
		b.dir = Vector2(cos(ang), sin(ang))
		b.speed = 380.0
		b.damage = 7.0
		b.crit = false
		b.radius = 3.0
		b.life = 0.9
		b.color = Color("#ffd166")
		b.pierce = 0
		b.gen = 0
		b.tier = "light"
		b.trail = true
		b.tag = "counter"
		b.global_position = global_position + Vector2(0, -14)
		b.prepare()


func _counter_shot() -> void:
	var nearest = null
	var best := 9999.0
	for e in GameState.enemies:
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best:
			best = d
			nearest = e
	if nearest == null:
		return
	var b = GameFeel.get_bullet()
	if b == null:
		return
	var dir: Vector2 = (nearest.global_position - global_position).normalized()
	b.friendly = true
	b.dir = dir
	b.speed = 420.0
	b.damage = 6.0
	b.crit = false
	b.radius = 3.2
	b.life = 1.4
	b.color = Color("#ffd166")
	b.pierce = 0
	b.gen = 0
	b.tier = "light"
	b.trail = true
	b.tag = "counter"
	b.global_position = global_position + Vector2(0, -14)
	b.prepare()


func take_damage(amount: int) -> void:
	if invuln > 0.0 or not alive:
		return
	invuln = GameConfig.INVULN_TIME
	hp -= amount
	GameState.hp = maxi(0, hp)
	GameState.hp_changed.emit(GameState.hp, GameState.max_hp)
	RunSave.note_hp(GameState.hp)
	# 受击硬直：不接受翻滚，但仍然可以移动
	hurt_stun = HURT_STUN
	ChallengeManager.on_damage()
	InputBuffer.clear("roll")

	GameFeel.flash(anim, Color(2.6, 0.6, 0.7), 0.14)
	# 后仰 3px 再回弹
	recoil.position = Vector2(-3.0 * float(facing), 0)
	var tw := recoil.create_tween()
	tw.tween_property(recoil, "position", Vector2.ZERO, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	GameFeel.screen_shake(0.45, -aim)
	GameFeel.hit_stop(0.08, 0.06)
	GameFeel.vibrate("light")
	GameFeel.burst(global_position + Vector2(0, -14), Color(1.0, 0.35, 0.45), 8, 110.0, 0.3)
	Sfx.play("hurt")
	# 低血量：一次性台词 + HUD 边缘闪红，不暂停
	if hp > 0 and hp <= 2 and not _low_hp_said:
		_low_hp_said = true
		GameState.low_health_triggered.emit()
		GameFeel.vibrate("medium")
		DialogueManager.say(char_id, "low_hp", 2.4)
	if hp <= 0:
		_die()


func _die() -> void:
	alive = false
	hp = 0
	GameState.hp = 0
	_kill_move_tween()
	GameFeel.flash(anim, Color(3.0, 3.0, 3.0), 0.06)
	var tw := anim.create_tween()
	tw.tween_interval(0.06)
	tw.tween_property(anim, "modulate:a", 0.0, 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(anim, "scale", Vector2(1.1, 0.9), 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 闪白一帧后碎成 8 个小方块，向四周飞散 + 重力 + 0.4s 淡出
	GameFeel.shards(global_position + Vector2(0, -16), GameConfig.char_color(char_id), 8, 170.0, 0.4)
	GameFeel.screen_shake(0.8)
	GameFeel.hit_stop(0.12, 0.05)
	GameFeel.screen_flash(Color(0.95, 0.25, 0.3), 0.2, 0.5)
	Sfx.play("die")
	died.emit()
	GameState.run_ended.emit()


func record_hit(e: Node) -> void:
	hit_chain += 1
	hit_chain_t = 2.0
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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2(0, 2), 9.0, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if shield_hits > 0:
		var a: float = 0.35 + 0.25 * sin(Time.get_ticks_msec() / 90.0)
		if _shield_flash > 0.0:
			a = 1.0
		draw_circle(Vector2(0, -14), 26.0, Color(0.98, 0.75, 0.35, 0.10))
		draw_arc(Vector2(0, -14), 26.0, 0.0, TAU, 32, Color(0.98, 0.78, 0.4, a), 2.0, true)
		# 六边形边框：展开时从中心扩散
		var k: float = clampf((3.0 - shield_t) / 0.3, 0.0, 1.0)
		var hex_r: float = 26.0 * (0.35 + 0.65 * k)
		var hex := PackedVector2Array()
		for i in 7:
			var ang2 := TAU * float(i % 6) / 6.0 - PI / 2.0
			hex.append(Vector2(0, -14) + Vector2(cos(ang2), sin(ang2)) * hex_r)
		draw_polyline(hex, Color(1.0, 0.86, 0.5, 0.35 + 0.5 * _shield_flash / 0.12), 1.5)
		for i in shield_hits:
			var ang := TAU * i / 6.0
			draw_circle(Vector2(0, -14) + Vector2(cos(ang), sin(ang)) * 26.0, 1.8,
				Color(1.0, 0.86, 0.5, 0.9))
	if charge_ratio > 0.0:
		draw_arc(Vector2(0, -14), 20.0, -PI / 2.0, -PI / 2.0 + TAU * charge_ratio, 24,
			Color(0.55, 0.75, 1.0, 0.95), 2.0, true)
