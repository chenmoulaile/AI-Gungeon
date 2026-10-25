extends Node2D
## 训练场静止靶：不移动、不攻击，只用来验证射击手感
## 挂进 GameState.enemies，玩家子弹可以正常命中

signal died(enemy: Node)

var hp: float = 9999.0
## 累计承伤（自动测试用）
var damage_taken: float = 0.0
var hits: int = 0
var max_hp: float = 9999.0
var radius: float = 13.0
var dead: bool = false
var mark_t: float = 0.0
var wealth_stacks: int = 0
var law_t: float = 0.0
var slow_mult: float = 1.0
var slow_t: float = 0.0
var accent: Color = Color("#7fd0ff")
var t: float = 0.0
var _hit: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("training_target")
	GameState.enemies.append(self)
	z_index = 1


func _process(delta: float) -> void:
	t += delta
	_hit = maxf(0.0, _hit - delta)
	mark_t = maxf(0.0, mark_t - delta)
	law_t = maxf(0.0, law_t - delta)
	queue_redraw()


func take_damage(dmg: float, _dir: Vector2 = Vector2.ZERO, _tier: String = "light",
		crit: bool = false, _tag: String = "") -> void:
	_hit = 0.12
	damage_taken += dmg
	hits += 1
	GameFeel.damage_number(global_position + Vector2(randf_range(-3, 3), -16), dmg, crit)
	GameFeel.burst(global_position, Color(0.75, 0.9, 1.0), 4, 80.0, 0.2)
	Sfx.play_hit(crit)


func blocks_hit(_dir: Vector2) -> bool:
	return false


func hp_ratio() -> float:
	return 1.0


const OUTLINE := Color("#0b0f18")
const WOOD := Color("#8a5a34")
const WOOD_D := Color("#5c3a22")
const BOARD := Color("#f2e6cf")
const RING := Color("#e2504f")


func _draw() -> void:
	# 硬阴影 + 木架 + 红白像素靶心（无半透明、无圆弧）
	draw_rect(Rect2(-8, 22, 16, 3), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-1, 10, 3, 12), WOOD_D)
	draw_rect(Rect2(-7, 21, 14, 2), WOOD_D)
	if _hit > 0.0:
		draw_rect(Rect2(-13, -13, 26, 26), OUTLINE)
		draw_rect(Rect2(-12, -12, 24, 24), Color(1, 1, 1, 1))
		return
	draw_rect(Rect2(-13, -13, 26, 26), OUTLINE)
	draw_rect(Rect2(-12, -12, 24, 24), BOARD)
	draw_rect(Rect2(-9, -9, 18, 18), RING)
	draw_rect(Rect2(-5, -5, 10, 10), BOARD)
	draw_rect(Rect2(-2, -2, 4, 4), RING)
