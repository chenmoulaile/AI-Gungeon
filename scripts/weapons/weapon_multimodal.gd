extends "res://scripts/weapons/weapon_base.gd"
## GPT —— 贪婪权杖
## 左键：挥动短权杖发射金色财宝弹
##   命中无标记目标：造成基础伤害并 +1 层「财富标记」（最多 3 层）
##   命中已有标记目标：消耗 1 层，本次伤害额外 +20%
## 主动技能「涌现」：随机获得 伤害+40% / 射速+50% / 弹速+60%，持续 5s

const BUFF_VALUES := {"damage": 0.4, "fire_rate": 0.5, "bullet_speed": 0.6}
const MAX_STACKS := 3
const BONUS := 0.2

var _swing: float = 0.0
var _hit_flash: float = 0.0


func _ready() -> void:
	mode_name = "贪婪权杖"


func _process(delta: float) -> void:
	super._process(delta)
	_swing = maxf(0.0, _swing - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)


## R 键：权杖在手里转一圈（无战斗效果，纯动作反馈）
func on_switch_mode() -> void:
	if player == null or not is_instance_valid(player):
		return
	_swing = 0.25
	player.fire_anim = 0.14


func fire(dir: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	var ws: WeaponStats = Stats.weapon("multimodal")
	var rate: float = ws.fire_rate if ws != null else 7.5
	var dmg: float = ws.damage if ws != null else 4.2
	var spd: float = ws.bullet_speed if ws != null else 430.0
	cooldown = 1.0 / maxf(0.3, rate * fire_rate_mult())
	_swing = 0.12

	var origin: Vector2 = player.global_position + Vector2(0, -16) + dir * 10.0
	_shoot(origin, dir, dmg, spd)
	for off in proj_offsets():
		_shoot(origin, dir.rotated(off), dmg, spd)
	Sfx.play("shoot", -8.0, SeedManager.randf_range(0.92, 1.02))
	GameFeel.burst(origin, Color(1.0, 0.85, 0.35), 2, 50.0, 0.12)


func _shoot(origin: Vector2, dir: Vector2, dmg: float, spd: float) -> void:
	var b: Node = spawn_bullet(origin, dir, dmg, spd, Color("#ffcf5c"),
		{"radius": 3.0, "life": 1.7, "tier": "light", "trail": true})
	if b != null:
		b.tag = "wealth"
		b.hit_enemy.connect(_on_hit)


## 播种 / 收割
func _on_hit(enemy: Node, bullet: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or not ("wealth_stacks" in enemy):
		return
	var stacks: int = int(enemy.wealth_stacks)
	if stacks < MAX_STACKS:
		enemy.wealth_stacks = stacks + 1
		GameFeel.burst(enemy.global_position + Vector2(0, -12), Color(1.0, 0.84, 0.30),
			3, 60.0, 0.2)
		Sfx.play("coin", -16.0, 1.5)
	else:
		# 满层：收割，消耗 1 层并追加 20% 伤害
		enemy.wealth_stacks = stacks - 1
		enemy.take_damage(float(bullet.damage) * BONUS, bullet.dir, "light", false, "wealth_bonus")
		GameFeel.burst(enemy.global_position + Vector2(0, -12), Color(1.0, 0.72, 0.20),
			6, 110.0, 0.26)
		_hit_flash = 0.12
		Sfx.play("coin", -8.0, 0.9)


# ---------------- 技能：涌现 ----------------
func use_skill() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var kinds: Array = BUFF_VALUES.keys()
	var chosen: Array = []
	# 被动「上下文窗口」：满 20 token 时三种强化同时生效
	if player.tokens >= 20:
		player.tokens = 0
		chosen = kinds.duplicate()
	else:
		chosen = [kinds[SeedManager.randi() % kinds.size()]]
	for k in chosen:
		player.add_buff(k, BUFF_VALUES[k], 5.0)
	Sfx.play("skill")
	return true


func buff_text() -> String:
	if player == null or not is_instance_valid(player) or player.buff_timer <= 0.0:
		return ""
	var parts: Array = []
	for k in player.buffs.keys():
		var label := {"damage": "伤害", "fire_rate": "射速", "bullet_speed": "弹速"}
		parts.append("%s+%d%%" % [label.get(k, k), int(round(float(player.buffs[k]) * 100.0))])
	return " ".join(parts)


func mode_text() -> String:
	return "贪婪权杖"
