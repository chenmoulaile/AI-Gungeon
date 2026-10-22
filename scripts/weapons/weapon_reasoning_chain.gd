extends "res://scripts/weapons/weapon_base.gd"
## DeepSeek —— 推理链
## 主弹命中后分裂为 2 枚小弹，最多 3 代，每代伤害 -30%
## 主动技能「深度思考」：蓄力 1.5s（移速 -50%、额外无敌）后释放贯穿全屏光束

const BeamScript = preload("res://scripts/weapons/beam.gd")
const CHARGE_TIME := 1.5
const MAX_GEN := 2          # gen 0/1/2 共 3 代
const SPLIT_DMG := 0.7      # 每代衰减 30%

var charging: bool = false
var charge_t: float = 0.0


func _ready() -> void:
	mode_name = "推理链"


func _process(delta: float) -> void:
	super._process(delta)
	if charging:
		charge_t += delta
		if player != null and is_instance_valid(player):
			player.charge_ratio = clampf(charge_t / CHARGE_TIME, 0.0, 1.0)
		if charge_t >= CHARGE_TIME:
			_release_charge()


func fire(dir: Vector2) -> void:
	var rate := 4.6 * fire_rate_mult()
	cooldown = 1.0 / rate
	var origin: Vector2 = player.global_position + Vector2(0, -16) + dir * 10.0
	_shoot_one(origin, dir)
	for off in proj_offsets():
		_shoot_one(origin, dir.rotated(off))
	Sfx.play("shoot", -6.0, randf_range(0.95, 1.08))


func _shoot_one(origin: Vector2, dir: Vector2) -> void:
	var b: Node = spawn_bullet(origin, dir, 6.0, 330.0, Color("#8ee6ff"),
		{"radius": 3.4, "gen": 0, "life": 2.0})
	b.hit_enemy.connect(_on_bullet_hit)


## 命中分裂：每代衰减 30%，最多 3 代
func _on_bullet_hit(enemy: Node, bullet: Node) -> void:
	if bullet.gen >= MAX_GEN:
		return
	var base_dmg: float = bullet.damage * SPLIT_DMG
	# 藏品协同：裂开的小弹继承穿透
	var inherit_pierce: int = 0
	if bool(GameState.mods.get("split_inherit_pierce", false)):
		inherit_pierce = maxi(1, int(bullet.pierce) + 1)
	for i in 2:
		var ang := deg_to_rad(38.0) * (1.0 if i == 0 else -1.0)
		var d: Vector2 = bullet.dir.rotated(ang)
		var nb: Node = spawn_bullet(bullet.global_position, d, base_dmg, 300.0,
			Color("#a9f0ff"),
			{"radius": 2.6, "gen": int(bullet.gen) + 1, "life": 0.85, "raw": true,
			"pierce": inherit_pierce, "tier": "small"})
		nb.hit_enemy.connect(_on_bullet_hit)


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
	Sfx.play("boss", -6.0, 1.6)
