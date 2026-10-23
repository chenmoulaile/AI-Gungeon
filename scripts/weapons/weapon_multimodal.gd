extends "res://scripts/weapons/weapon_base.gd"
## GPT —— 多模态切换
## R 键循环：A 文本（高射速单发）/ B 图像（5 发扇形）/ C 语音（短距锥形冲击波）
## 主动技能「涌现」：随机获得 伤害+40% / 射速+50% / 弹速+60%，持续 5s

const BeamScript = preload("res://scripts/weapons/beam.gd")
const MODE_NAMES := ["文本", "图像", "语音"]
const BUFF_VALUES := {"damage": 0.4, "fire_rate": 0.5, "bullet_speed": 0.6}

var mode: int = 0


func _ready() -> void:
	mode_name = MODE_NAMES[mode]


func on_switch_mode() -> void:
	var old_mode := mode
	mode = (mode + 1) % 3
	mode_name = MODE_NAMES[mode]
	if player != null and is_instance_valid(player):
		player.fire_anim = 0.16
	# 藏品：切换瞬间留下残影，0.25s 后替玩家打一次旧模式
	if bool(GameState.mods.get("echo_clone", false)) and player.anim != null:
		var tex: Texture2D = player.anim.sprite_frames.get_frame_texture(
			player.anim.animation, player.anim.frame)
		GameFeel.afterimage(tex, player.global_position, player.anim.flip_h,
			Color(0.72, 0.66, 1.0, 0.55), 0.35)
		var timer := get_tree().create_timer(0.25)
		timer.timeout.connect(func() -> void: _echo_fire(old_mode))


func _echo_fire(old_mode: int) -> void:
	if player == null or not is_instance_valid(player) or not player.alive:
		return
	var saved_mode := mode
	var saved_cd := cooldown
	mode = old_mode
	var dir: Vector2 = player.aim
	match old_mode:
		0:
			_fire_text(dir)
		1:
			_fire_image(dir)
		_:
			_fire_voice(dir)
	mode = saved_mode
	cooldown = saved_cd


func fire(dir: Vector2) -> void:
	match mode:
		0:
			_fire_text(dir)
		1:
			_fire_image(dir)
		_:
			_fire_voice(dir)


# ---------------- A 文本：高射速单发 ----------------
func _fire_text(dir: Vector2) -> void:
	cooldown = 1.0 / (8.5 * fire_rate_mult())
	var origin: Vector2 = player.global_position + Vector2(0, -16) + dir * 10.0
	_shot(origin, dir, 4.2, 430.0, 2.7)
	for off in proj_offsets():
		_shot(origin, dir.rotated(off), 4.2, 430.0, 2.7)
	Sfx.play("shoot", -8.0, randf_range(1.0, 1.15))


# ---------------- B 图像：5 发扇形 ----------------
func _fire_image(dir: Vector2) -> void:
	cooldown = 1.0 / (2.4 * fire_rate_mult())
	var origin: Vector2 = player.global_position + Vector2(0, -16) + dir * 10.0
	var spread := 34.0
	for i in 5:
		var t := float(i) / 4.0 - 0.5
		_shot(origin, dir.rotated(deg_to_rad(spread * t)), 3.6, 340.0, 3.0)
	for off in proj_offsets():
		_shot(origin, dir.rotated(off), 3.6, 340.0, 3.0)
	Sfx.play("shoot", -6.0, 0.9)


# ---------------- C 语音：短距锥形冲击波 ----------------
func _fire_voice(dir: Vector2) -> void:
	cooldown = 0.6
	var beam: Node = BeamScript.new()
	beam.instant = true
	beam.origin = player.global_position + Vector2(0, -16)
	beam.dir = dir
	beam.length = 104.0
	beam.width = 34.0
	beam.dps = 11.0 * damage_mult()
	beam.color = Color("#c9b6ff")
	beam.tag = "voice"
	beam.life = 0.14
	_bullet_root().add_child(beam)
	Sfx.play("skill", -12.0, 1.8)


func _shot(origin: Vector2, dir: Vector2, dmg: float, spd: float, radius: float) -> void:
	spawn_bullet(origin, dir, dmg, spd, Color("#c9b6ff"),
		{"radius": radius, "life": 1.6})


# ---------------- 技能：涌现 ----------------
func use_skill() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var kinds: Array = BUFF_VALUES.keys()
	var chosen: Array = []
	# 被动「上下文窗口」：满 20 token 时三种强化同时生效
	if player.tokens >= 20:
		player.tokens = 0
		chosen = kinds.duplicate()
	else:
		chosen = [kinds[randi() % kinds.size()]]
	for k in chosen:
		player.add_buff(k, BUFF_VALUES[k], 5.0)
	Sfx.play("skill")
	return true


func buff_text() -> String:
	if player == null or not is_instance_valid(player) or player.buff_timer <= 0.0:
		return ""
	var parts: Array = []
	for k in player.buffs.keys():
		var label := {"damage": "伤害", "fire_rate": "射速", "bullet_speed": "弹速"}
		parts.append("%s+%d%%" % [label.get(k, k), int(round(float(player.buffs[k]) * 100.0))])
	return " ".join(parts)
