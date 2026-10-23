extends "res://scripts/weapons/subweapon_base.gd"
## DeepSeek「深度检索」
## 短按：标记弹（400px/s），命中后标记敌人 3s，期间该敌人受到的所有伤害 +15%，冷却 4s
## 长按 1s：穿透弹（300px/s），对路径上所有被标记的敌人造成 2 倍伤害，冷却 8s
## 长按期间移速 -30%

const HOLD_TIME := 1.0
const MARK_TIME := 3.0

var _holding: bool = false
var _hold_t: float = 0.0


func _configure() -> void:
	display_name = "深度检索"
	color = Color("#6ea8ff")
	cd_total = 4.0


func handle_input(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not player.alive:
		return
	if cd_left > 0.0:
		_release_hold()
		return
	if Input.is_action_just_pressed("sub_weapon"):
		_holding = true
		_hold_t = 0.0
	if not _holding:
		return
	_hold_t += delta
	player.sub_move_mult = 0.7
	if _hold_t >= HOLD_TIME:
		_holding = false
		player.sub_move_mult = 1.0
		_fire_pierce()
		return
	if not Input.is_action_pressed("sub_weapon"):
		_holding = false
		player.sub_move_mult = 1.0
		if _hold_t < HOLD_TIME:
			_fire_mark()


func _release_hold() -> void:
	if _holding:
		_holding = false
		player.sub_move_mult = 1.0


func _fire_mark() -> void:
	var dir: Vector2 = player.aim
	var b = GameFeel.get_bullet()
	if b == null:
		return
	b.friendly = true
	b.dir = dir
	b.speed = 400.0
	b.damage = 4.0 * (1.0 + float(GameState.stat("damage", 1.0)) * 0.25)
	b.crit = false
	b.radius = 3.6
	b.life = 2.0
	b.color = Color("#6ea8ff")
	b.pierce = 0
	b.gen = 0
	b.tier = "light"
	b.trail = true
	b.tag = "retrieval_mark"
	b.global_position = player.global_position + Vector2(0, -14) + dir * 10.0
	b.prepare()
	Sfx.play("shoot", -4.0, 0.72)
	start_cd(4.0)
	GameFeel.burst(b.global_position, Color(0.55, 0.75, 1.0), 4, 70.0, 0.16)


func _fire_pierce() -> void:
	var dir: Vector2 = player.aim
	var b = GameFeel.get_bullet()
	if b == null:
		return
	b.friendly = true
	b.dir = dir
	b.speed = 300.0
	b.damage = 9.0
	b.crit = false
	b.radius = 7.0
	b.life = 2.4
	b.color = Color("#4f8cff")
	b.pierce = 99
	b.gen = 0
	b.tier = "heavy"
	b.trail = true
	b.tag = "retrieval_pierce"
	b.global_position = player.global_position + Vector2(0, -14) + dir * 12.0
	b.prepare()
	Sfx.play("skill", -4.0, 0.8)
	Sfx.play("boss", -10.0, 1.4)
	start_cd(8.0)
	GameFeel.screen_shake(0.18)
	GameFeel.aberrate(2.2, 0.12)
	GameFeel.burst(b.global_position, Color(0.45, 0.70, 1.0), 10, 120.0, 0.24)


## 标记视觉由 enemy_base 读取：mark_t > 0 时头顶画蓝色三角
static func apply_mark(enemy: Node, dur: float = MARK_TIME) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if "mark_t" in enemy:
		enemy.mark_t = maxf(float(enemy.mark_t), dur)
