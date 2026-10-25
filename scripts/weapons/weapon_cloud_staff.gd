extends "res://scripts/weapons/weapon_base.gd"
## GPT 初始武器「云端龙息杖」
## 左键挥杖发射蓝色云团飞弹，飞弹带轻微追踪

const DMG := 5.0
const RATE := 5.5
## 参考图导出的像素杖（云灵杖头 + 紫穗），32×32 三帧
const TEX := "res://assets/weapons/gpt_starter.png"


func setup(p: Node) -> void:
	super.setup(p)
	mode_name = "云端龙息"
	# 直接用参考图的像素杖贴图，不再程序化画 88px 长杖（之前过大且压脸）
	p.set_held(TEX, 0.0, Color.WHITE, "", Color("#B06BFF"), 44.0)


func fire(dir: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	cooldown = 1.0 / maxf(0.4, RATE * fire_rate_mult())
	var origin: Vector2 = player.global_position + Vector2(0, -16) + dir * 12.0
	if player.gun != null and is_instance_valid(player.gun):
		origin = player.gun.to_global(player.gun.muzzle_local())
	var b: Node = spawn_bullet(origin, dir, DMG, 380.0, Color("#8fd0ff"),
		{"radius": 5.0, "life": 1.9, "tier": "light", "trail": true,
		"homing": 1.1, "homing_time": 0.7})
	if b != null:
		b.tag = "cloud"
	for off in proj_offsets():
		spawn_bullet(origin, dir.rotated(off), DMG, 380.0, Color("#8fd0ff"),
			{"radius": 4.4, "life": 1.9, "tier": "light", "trail": true,
			"homing": 1.1, "homing_time": 0.7})
	player.fire_anim = 0.1
	if player.gun != null and is_instance_valid(player.gun):
		player.gun.flash()
	GameFeel.burst(origin, Color(0.75, 0.88, 1.0), 3, 60.0, 0.16)
	Sfx.play("shoot", -10.0, 1.12)


# ---------------- 技能「涌现」 ----------------
const BUFF_VALUES := {"damage": 0.4, "fire_rate": 0.5, "bullet_speed": 0.6}


func use_skill() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var kinds: Array = BUFF_VALUES.keys()
	var chosen: Array = []
	if player.tokens >= 20:
		player.tokens = 0
		chosen = kinds.duplicate()
	else:
		chosen = [kinds[SeedManager.randi() % kinds.size()]]
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
