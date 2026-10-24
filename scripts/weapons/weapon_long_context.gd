extends "res://scripts/weapons/weapon_base.gd"
## Claude —— 圣女法槌
## 左键：短距离敲击地面，生成半径 80px 的「律令」区域，持续 2s
##   区域内敌人移速 -30%，并附加律令标记（受到伤害 +12%）
##   法槌直接伤害约为普通子弹的 30%，主要价值在控场与增伤
## 主动技能「宪法规避」：吸收 6 发敌弹的护盾，持续 3s，每吸收 1 发回复 2 点生命

const LawZoneScript = preload("res://scripts/weapons/law_zone.gd")
const SWING_CD := 0.45
const REACH := 30.0
const ZONE_RADIUS := 80.0
const DIRECT_DAMAGE := 1.6

var _swing_t: float = 0.0
var _hammer: Node2D = null
## 同时只保留一个律令区域，避免多区域叠加导致伤害失控
var _zone: Node = null


func _ready() -> void:
	mode_name = "圣女法槌"
	_hammer = Node2D.new()
	_hammer.name = "Hammer"
	_hammer.z_index = 3
	_hammer.set_script(load("res://scripts/player/hammer_device.gd"))
	add_child(_hammer)


func _process(delta: float) -> void:
	super._process(delta)
	_swing_t = maxf(0.0, _swing_t - delta)
	if _hammer != null and is_instance_valid(_hammer) and _hammer.has_method("set_state"):
		_hammer.set_state(_swing_t, player)


func fire(dir: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	cooldown = SWING_CD / maxf(0.6, fire_rate_mult())
	_swing_t = 0.22

	var at: Vector2 = player.global_position + Vector2(0, -6) + dir * REACH
	# 直接伤害：区域内所有敌人吃一次轻击
	for e in GameState.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		if at.distance_to(e.global_position) <= ZONE_RADIUS:
			e.take_damage(DIRECT_DAMAGE * damage_mult(), dir, "light", false, "verdict")
	# 律令区域（同时只存在一个）
	if _zone != null and is_instance_valid(_zone):
		_zone.queue_free()
	var zone = LawZoneScript.new()
	zone.radius = ZONE_RADIUS
	zone.color = Color(0.96, 0.80, 0.55)
	zone.global_position = at
	_bullet_root().add_child(zone)
	_zone = zone

	player.fire_anim = 0.16
	Sfx.play("clang", -10.0, 0.85)
	Sfx.play("whoosh", -18.0, 1.4)
	GameFeel.screen_shake(0.08)
	GameFeel.burst(at, Color(0.98, 0.84, 0.62), 6, 90.0, 0.24)


## 护盾技能保持不变
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
