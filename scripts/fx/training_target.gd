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


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2(0, radius * 0.8), radius * 0.9, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var c := Color(1, 1, 1, 1) if _hit > 0.0 else accent
	draw_circle(Vector2.ZERO, radius, Color(c.r, c.g, c.b, 0.28))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, c, 2.0, true)
	draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 18, Color(c.r, c.g, c.b, 0.7), 1.2, true)
	draw_circle(Vector2.ZERO, 2.4, Color(1, 1, 1, 0.9))
