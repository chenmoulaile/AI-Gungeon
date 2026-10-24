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


# ---------------- 技能「深度思考」：蓄力后贯穿光束 ----------------
const BeamScript = preload("res://scripts/weapons/beam.gd")
const CHARGE_TIME := 1.5

var charging: bool = false
var charge_t: float = 0.0
var _pt: float = 0.0


func _process(delta: float) -> void:
	super._process(delta)
	if charging:
		charge_t += delta
		if player != null and is_instance_valid(player):
			player.charge_ratio = clampf(charge_t / CHARGE_TIME, 0.0, 1.0)
			_pt -= delta
			if _pt <= 0.0:
				_pt = 0.09
				var ang := randf() * TAU
				GameFeel.burst(player.global_position + Vector2(0, -14)
					+ Vector2(cos(ang), sin(ang)) * randf_range(26.0, 40.0),
					Color(0.55, 0.75, 1.0), 1, 26.0, 0.3)
		if charge_t >= CHARGE_TIME:
			_release_charge()


func use_skill() -> bool:
	if charging:
		return false
	charging = true
	charge_t = 0.0
	if player != null and is_instance_valid(player):
		player.move_mult = 0.5
		player.grant_invuln(CHARGE_TIME + 0.25)
	Sfx.play("skill")
	return true


func _release_charge() -> void:
	charging = false
	if player == null or not is_instance_valid(player):
		return
	player.move_mult = 1.0
	player.charge_ratio = 0.0
	var ratio := clampf(charge_t / CHARGE_TIME, 0.0, 1.0)
	var beam: Node = BeamScript.new()
	beam.instant = true
	beam.origin = player.global_position + Vector2(0, -16)
	beam.dir = player.aim
	beam.length = 1400.0
	beam.width = 10.0
	beam.dps = 36.0 * (1.0 + 2.0 * ratio) * damage_mult()
	beam.color = Color("#7fb2ff")
	beam.life = 0.16
	_bullet_root().add_child(beam)
	Sfx.play("boss", -6.0, 1.6)
