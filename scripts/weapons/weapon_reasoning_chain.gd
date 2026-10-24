extends "res://scripts/weapons/weapon_base.gd"
## DeepSeek —— DeepSeek Harness（黑色虎鲸虚影）
## 左键：召唤 Harness 沿瞄准方向冲刺，对路径上的敌人造成撞击伤害后消散，冷却 3s
## 被动「吃 token」：每击杀 1 敌 +1 token，满 10 层时下一击伤害翻倍并附带小范围吞噬
## 主动技能「深度思考」：蓄力 1.5s（移速 -50%、额外无敌）后释放贯穿全屏光束

const BeamScript = preload("res://scripts/weapons/beam.gd")
const DamageZone = preload("res://scripts/weapons/damage_zone.gd")
const HarnessScript = preload("res://scripts/weapons/harness_phantom.gd")
const CHARGE_TIME := 1.5
const TOKEN_FULL := 10
const BASE_DAMAGE := 110.0
const HARNESS_CD := 3.0

var charging: bool = false
var charge_t: float = 0.0
var _pt: float = 0.0
var token_ready: bool = false


func _ready() -> void:
	mode_name = "Harness"


func _process(delta: float) -> void:
	super._process(delta)
	if charging:
		charge_t += delta
		if player != null and is_instance_valid(player):
			player.charge_ratio = clampf(charge_t / CHARGE_TIME, 0.0, 1.0)
			_charge_particle(delta)
		if charge_t >= CHARGE_TIME:
			_release_charge()


## 每 0.09s 生成一个从外圈向角色中心收拢的光点
func _charge_particle(delta: float) -> void:
	_pt -= delta
	if _pt > 0.0:
		return
	_pt = 0.09
	var ang := randf() * TAU
	var r := randf_range(26.0, 40.0)
	GameFeel.burst(player.global_position + Vector2(0, -14) + Vector2(cos(ang), sin(ang)) * r,
		Color(0.55, 0.75, 1.0), 1, 26.0, 0.3)


## 左键：Harness 冲刺
func fire(dir: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	var full: bool = int(player.tokens) >= TOKEN_FULL
	if full:
		player.tokens = 0
	token_ready = full

	var h = HarnessScript.new()
	h.damage = BASE_DAMAGE * damage_mult() * (2.0 if full else 1.0)
	h.hit_radius = 26.0 if full else 18.0
	h.devour = full
	h.speed = 560.0
	h.life = 0.44 if full else 0.42
	h.setup(player.global_position + Vector2(0, -16) + dir * 8.0, dir, h.speed, h.life)
	_bullet_root().add_child(h)

	cooldown = HARNESS_CD
	player.fire_anim = 0.18
	Sfx.play("whoosh", -2.0, 0.85 if full else 1.0)
	if full:
		Sfx.play("boss", -10.0, 1.5)
		GameFeel.screen_shake(0.22)
		GameFeel.burst(player.global_position + Vector2(0, -16), Color(0.20, 0.35, 0.70),
			12, 150.0, 0.34)


# ---------------- 技能：深度思考 ----------------
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
	var mult := 1.0 + 2.0 * ratio      # 最高 3 倍
	var beam: Node = BeamScript.new()
	beam.instant = true
	beam.origin = player.global_position + Vector2(0, -16)
	beam.dir = player.aim
	beam.length = 1400.0
	beam.width = 10.0
	beam.dps = 36.0 * mult * damage_mult()
	beam.color = Color("#7fb2ff")
	beam.life = 0.16
	_bullet_root().add_child(beam)
	# 藏品：光束路径上留下持续伤害区域
	if bool(GameState.mods.get("beam_burn", false)):
		for d in [180.0, 340.0, 500.0]:
			var zone := DamageZone.new()
			zone.radius = 34.0
			zone.dps = 26.0 * damage_mult()
			zone.global_position = beam.origin + beam.dir * float(d)
			_bullet_root().add_child(zone)
	Sfx.play("boss", -6.0, 1.6)
