extends "res://scripts/weapons/weapon_base.gd"
## Claude 专武「法槌」
## 左键敲击地面：半径 80px 律令区域（减速 30%、受伤 +15%、持续伤害），直伤更高

const LawZoneScript = preload("res://scripts/weapons/law_zone.gd")
const SWING_CD := 0.45
const REACH := 30.0
const ZONE_RADIUS := 80.0
const DIRECT_DAMAGE := 8.0

var _swing_t: float = 0.0
var _zone: Node = null


const TEX := "res://assets/weapons/excl_hammer.png"


func setup(p: Node) -> void:
	super.setup(p)
	mode_name = "法槌"
	p.set_held(TEX, 0.0, Color(1, 1, 1, 1), "", Color(0.95, 0.80, 0.45, 1.0))


func _process(delta: float) -> void:
	super._process(delta)
	_swing_t = maxf(0.0, _swing_t - delta)


func fire(dir: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	cooldown = SWING_CD / maxf(0.6, fire_rate_mult())
	_swing_t = 0.22
	var at: Vector2 = player.global_position + Vector2(0, -6) + dir * REACH
	for e in GameState.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		if at.distance_to(e.global_position) <= ZONE_RADIUS:
			e.take_damage(DIRECT_DAMAGE * damage_mult(), dir, "medium", false, "verdict")
	if _zone != null and is_instance_valid(_zone):
		_zone.queue_free()
	var zone = LawZoneScript.new()
	zone.radius = ZONE_RADIUS
	zone.dps = 10.0 * damage_mult()
	zone.color = Color(0.96, 0.80, 0.55)
	zone.global_position = at
	_bullet_root().add_child(zone)
	_zone = zone
	player.fire_anim = 0.16
	if player.gun != null and is_instance_valid(player.gun):
		player.gun.flash()
	Sfx.play("clang", -10.0, 0.85)
	GameFeel.screen_shake(0.08)
	GameFeel.burst(at, Color(0.98, 0.84, 0.62), 6, 90.0, 0.24)


func use_skill() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	player.shield_hits = 6
	player.shield_t = 3.0
	for i in 6:
		var ang := TAU * float(i) / 6.0 - PI / 2.0
		GameFeel.burst(player.global_position + Vector2(0, -14) + Vector2(cos(ang), sin(ang)) * 26.0,
			Color(1.0, 0.88, 0.55), 2, 34.0, 0.28)
	Sfx.play("skill")
	return true
