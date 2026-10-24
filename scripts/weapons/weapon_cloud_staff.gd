extends "res://scripts/weapons/weapon_base.gd"
## GPT 初始武器「云端龙息杖」
## 左键挥杖发射蓝色云团飞弹，飞弹带轻微追踪

const TEX := "res://assets/weapons/gpt_starter.png"
const DMG := 5.0
const RATE := 5.5


func setup(p: Node) -> void:
	super.setup(p)
	mode_name = "云端龙息"
	p.set_held(TEX, 45.0)


func fire(dir: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	cooldown = 1.0 / maxf(0.4, RATE * fire_rate_mult())
	var origin: Vector2 = player.global_position + Vector2(0, -16) + dir * 12.0
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
