extends "res://scripts/weapons/weapon_base.gd"
## GPT 专武「Codex」
## 左键发射金色代码符文：首次命中挂「财富印记」，再次命中消耗印记并追加一倍伤害

const TEX := "res://assets/weapons/excl_codex.png"
const DMG := 7.0
const RATE := 6.5


func setup(p: Node) -> void:
	super.setup(p)
	mode_name = "Codex"
	p.set_held(TEX, 0.0, Color(1, 1, 1, 1), "", Color(0.95, 0.75, 0.25, 1.0))


func fire(dir: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	cooldown = 1.0 / maxf(0.4, RATE * fire_rate_mult())
	var origin: Vector2 = player.global_position + Vector2(0, -16) + dir * 12.0
	_shoot(origin, dir)
	for off in proj_offsets():
		_shoot(origin, dir.rotated(off))
	player.fire_anim = 0.1
	if player.gun != null and is_instance_valid(player.gun):
		player.gun.flash()
	Sfx.play("shoot", -8.0, 0.88)
	GameFeel.burst(origin, Color(1.0, 0.84, 0.35), 2, 60.0, 0.14)


func _shoot(origin: Vector2, dir: Vector2) -> void:
	var b: Node = spawn_bullet(origin, dir, DMG, 460.0, Color("#ffd76a"),
		{"radius": 3.4, "life": 1.6, "tier": "light", "trail": true})
	if b != null:
		b.tag = "codex"
		b.hit_enemy.connect(_on_hit)


func _on_hit(enemy: Node, bullet: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or not ("wealth_stacks" in enemy):
		return
	if int(enemy.wealth_stacks) > 0:
		enemy.wealth_stacks = 0
		enemy.take_damage(float(bullet.damage), bullet.dir, "medium", true, "codex_burst")
		GameFeel.burst(enemy.global_position + Vector2(0, -10), Color(1.0, 0.80, 0.25),
			10, 150.0, 0.3)
		GameFeel.hit_stop(0.03, 0.03)
		Sfx.play("coin", -6.0, 0.85)
	else:
		enemy.wealth_stacks = 1
		GameFeel.burst(enemy.global_position + Vector2(0, -10), Color(1.0, 0.88, 0.40),
			4, 70.0, 0.2)
		Sfx.play("coin", -16.0, 1.4)
