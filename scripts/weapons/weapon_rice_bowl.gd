extends "res://scripts/weapons/weapon_base.gd"
## DeepSeek 初始武器「Token 饭盆」
## 左键投掷饭盆：抛物线飞出，落地碎裂对半径 50 内敌人造成伤害，并留下 2s 白饭减速区

const BowlScript = preload("res://scripts/weapons/bowl_projectile.gd")
const TEX := "res://assets/weapons/deepseek_starter.png"
const CD := 0.75
const DMG := 18.0


func setup(p: Node) -> void:
	super.setup(p)
	mode_name = "Token 饭盆"
	p.set_held(TEX, 0.0)


func fire(dir: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	cooldown = CD
	var b = BowlScript.new()
	b.dir = dir
	b.speed = 330.0
	b.travel = 150.0
	b.damage = DMG * damage_mult()
	b.radius = 50.0
	b.global_position = player.global_position + Vector2(0, -12) + dir * 10.0
	_bullet_root().add_child(b)
	player.fire_anim = 0.14
	if player.gun != null and is_instance_valid(player.gun):
		player.gun.flash()
	Sfx.play("whoosh", -12.0, 1.15)
