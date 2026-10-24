extends "res://scripts/weapons/weapon_base.gd"
## DeepSeek 专武「Harness」
## 左键召唤黑色虎鲸虚影冲刺撕咬，冷却 3s；被动满 10 token 时下一击翻倍并吞噬

const HarnessScript = preload("res://scripts/weapons/harness_phantom.gd")
const BeamScript = preload("res://scripts/weapons/beam.gd")
const CHARGE_TIME := 1.5
const TOKEN_FULL := 10
const BASE_DAMAGE := 110.0
const CD := 3.0

var charging: bool = false
var charge_t: float = 0.0
var _pt: float = 0.0


func setup(p: Node) -> void:
	super.setup(p)
	mode_name = "Harness"
	p.set_held("", 0.0, Color(1, 1, 1, 1), "orca", Color(0.35, 0.55, 0.95, 1.0))


func _process(delta: float) -> void:
	super._process(delta)
	if charging:
		charge_t += delta
		if player != null and is_instance_valid(player):
			player.charge_ratio = clampf(charge_t / CHARGE_TIME, 0.0, 1.0)
			_charge_particle(delta)
		if charge_t >= CHARGE_TIME:
			_release_charge()


func _charge_particle(delta: float) -> void:
	_pt -= delta
	if _pt > 0.0:
		return
	_pt = 0.09
	var ang := randf() * TAU
	var r := randf_range(26.0, 40.0)
	GameFeel.burst(player.global_position + Vector2(0, -14) + Vector2(cos(ang), sin(ang)) * r,
		Color(0.55, 0.75, 1.0), 1, 26.0, 0.3)


func fire(dir: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	var full: bool = int(player.tokens) >= TOKEN_FULL
	if full:
		player.tokens = 0
	var h = HarnessScript.new()
	h.damage = BASE_DAMAGE * damage_mult() * (2.0 if full else 1.0)
	h.hit_radius = 26.0 if full else 18.0
	h.devour = full
	h.setup(player.global_position + Vector2(0, -16) + dir * 8.0, dir, 560.0, 0.44 if full else 0.42)
	_bullet_root().add_child(h)
	cooldown = CD
	player.fire_anim = 0.18
	if player.gun != null and is_instance_valid(player.gun):
		player.gun.flash()
	Sfx.play("whoosh", -2.0, 0.85 if full else 1.0)
	if full:
		Sfx.play("boss", -10.0, 1.5)
		GameFeel.screen_shake(0.22)
		GameFeel.burst(player.global_position + Vector2(0, -16), Color(0.20, 0.35, 0.70),
			12, 150.0, 0.34)


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
