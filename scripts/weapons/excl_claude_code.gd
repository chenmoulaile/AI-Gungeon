extends "res://scripts/weapons/weapon_base.gd"
## Claude 专武「Claude Code」
## 左键发射代码行穿透弹：基础穿透 2，每第 3 发「编译完成」暴击（伤害翻倍、金色弹体）。
## 被动：护盾每吸收 1 发敌弹攒 1 层缓存，下次射击最多追加 3 层穿透。
## 技能沿用「宪法规避」：展开吸收 6 发敌弹的护盾，持续 3s。

const TEX := "res://assets/weapons/excl_claude_code.png"
const DMG := 6.5
const RATE := 5.0
const MAX_CACHE := 3
const PIERCE_BASE := 2

var shot_i: int = 0
var cache: int = 0
var _shield_seen: int = 0


func setup(p: Node) -> void:
	super.setup(p)
	mode_name = "Claude Code"
	p.set_held(TEX, 0.0, Color(1, 1, 1, 1), "", Color(1.0, 0.72, 0.36, 1.0))
	_shield_seen = int(p.shield_hits)


func _process(delta: float) -> void:
	super._process(delta)
	if player == null or not is_instance_valid(player):
		return
	var hits := int(player.shield_hits)
	if hits < _shield_seen and player.shield_t > 0.0:
		cache = mini(MAX_CACHE, cache + (_shield_seen - hits))
	_shield_seen = hits


func fire(dir: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	cooldown = 1.0 / maxf(0.4, RATE * fire_rate_mult())
	shot_i += 1
	var compile := shot_i % 3 == 0
	var pierce := PIERCE_BASE + cache
	cache = 0
	var origin: Vector2 = player.global_position + Vector2(0, -16) + dir * 12.0
	var col := Color("#ffd166") if compile else Color("#7fe3ff")
	var b: Node = spawn_bullet(origin, dir, DMG * (2.0 if compile else 1.0), 560.0, col,
		{"radius": 3.2 if compile else 2.6, "life": 1.3, "tier": "light",
		"trail": true, "pierce": pierce})
	if b != null:
		b.tag = "claude_code"
		b.crit = compile
	for off in proj_offsets():
		spawn_bullet(origin, dir.rotated(off), DMG, 560.0, Color("#7fe3ff"),
			{"radius": 2.6, "life": 1.3, "tier": "light", "trail": true, "pierce": pierce})
	player.fire_anim = 0.1
	if player.gun != null and is_instance_valid(player.gun):
		player.gun.flash()
	GameFeel.burst(origin, Color(1.0, 0.80, 0.40) if compile else Color(0.50, 0.89, 1.0),
		3 if compile else 2, 70.0, 0.16)
	if compile:
		Sfx.play("coin", -12.0, 0.9)
	else:
		Sfx.play("shoot", -10.0, 1.05)


func use_skill() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	player.shield_hits = 6
	player.shield_t = 3.0
	for i in 6:
		var ang := TAU * float(i) / 6.0 - PI / 2.0
		GameFeel.burst(player.global_position + Vector2(0, -14)
			+ Vector2(cos(ang), sin(ang)) * 26.0, Color(1.0, 0.88, 0.55), 2, 34.0, 0.28)
	Sfx.play("skill")
	return true


func buff_text() -> String:
	if cache <= 0:
		return ""
	return "缓存 +%d 穿透" % cache
