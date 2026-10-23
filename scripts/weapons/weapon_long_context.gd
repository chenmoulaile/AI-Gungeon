extends "res://scripts/weapons/weapon_base.gd"
## Claude —— 长上下文光束
## 按住左键持续激光，宽度 1s 内由细变粗、伤害同步提升；松开进入 1.2s 冷却
## 主动技能「宪法规避」：吸收 6 发敌弹的护盾，持续 3s，每吸收 1 发回复 2 点生命

const BeamScript = preload("res://scripts/weapons/beam.gd")
const GROW_TIME := 1.0
const RELEASE_CD := 1.2
const MIN_WIDTH := 3.0
const MAX_WIDTH := 13.0
const MIN_DPS := 26.0
const MAX_DPS := 78.0

var beam: Node = null
var grow: float = 0.0
var hold_t: float = 0.0
var overloaded: bool = false


func _ready() -> void:
	mode_name = "长上下文"


func _process(delta: float) -> void:
	super._process(delta)
	if player == null or not is_instance_valid(player) or not player.alive:
		_stop_beam()
		return

	var holding := Input.is_action_pressed("shoot") and not get_tree().paused
	if holding and cooldown <= 0.0:
		if beam == null or not is_instance_valid(beam):
			beam = BeamScript.new()
			beam.instant = false
			beam.color = Color("#f0a35a")
			beam.tick_interval = 0.1
			_bullet_root().add_child(beam)
		grow = minf(GROW_TIME, grow + delta)
		hold_t += delta
		var ratio := grow / GROW_TIME
		# 藏品：持续 3s 后过载，宽度翻倍、伤害提升，冷却变长
		if bool(GameState.mods.get("beam_overload", false)) and hold_t >= 3.0:
			overloaded = true
		beam.length = 560.0
		beam.width = lerpf(MIN_WIDTH, MAX_WIDTH, ratio) * (2.0 if overloaded else 1.0)
		beam.dps = lerpf(MIN_DPS, MAX_DPS, ratio) * damage_mult() * (1.6 if overloaded else 1.0)
		beam.set_beam(player.global_position + Vector2(0, -16), player.aim)
		player.fire_anim = 0.1
	elif beam != null:
		var cd := RELEASE_CD * (1.5 if overloaded else 1.0)
		_stop_beam()
		cooldown = cd


func _stop_beam() -> void:
	if beam != null and is_instance_valid(beam):
		beam.queue_free()
	beam = null
	grow = 0.0
	hold_t = 0.0
	overloaded = false


## 光束走自己的 _process，fire() 只做占位
func fire(_dir: Vector2) -> void:
	pass


func use_skill() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	player.shield_hits = 6
	player.shield_t = 3.0
	Sfx.play("skill")
	return true
