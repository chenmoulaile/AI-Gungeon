extends Node2D
## 激光扫射：0.5s 红线预警 → 0.8s 旋转激光（±45°），命中玩家掉 1 点

const WARN := 0.5
const FIRE := 0.8
const SWEEP := 0.78      # 总扫射角度（弧度，约 ±22.5°）
const LENGTH := 520.0

var origin: Vector2 = Vector2.ZERO
var base_angle: float = 0.0
var timer: float = 0.0
var firing: bool = false
var _hit_cd: float = 0.0


func _ready() -> void:
	add_to_group("beams")
	global_position = origin
	timer = WARN


func _physics_process(delta: float) -> void:
	timer -= delta
	_hit_cd = maxf(0.0, _hit_cd - delta)
	if not firing and timer <= 0.0:
		firing = true
		timer = FIRE
		Sfx.play("boss", -6.0, 1.4)
	if firing:
		var k: float = 1.0 - clampf(timer / FIRE, 0.0, 1.0)
		var ang := base_angle - SWEEP * 0.5 + SWEEP * k
		_apply(ang)
		if timer <= 0.0:
			queue_free()
	queue_redraw()


func _apply(ang: float) -> void:
	var p = GameState.player
	if p == null or not is_instance_valid(p) or _hit_cd > 0.0:
		return
	var a := global_position
	var b := global_position + Vector2(cos(ang), sin(ang)) * LENGTH
	var ab := b - a
	var t2: float = clampf((p.global_position - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	if p.global_position.distance_to(a + ab * t2) < 9.0 + GameConfig.PLAYER_RADIUS:
		_hit_cd = 0.5
		p.take_damage(1)


func _draw() -> void:
	if not firing:
		var k: float = 1.0 - clampf(timer / WARN, 0.0, 1.0)
		draw_line(Vector2.ZERO, Vector2(cos(base_angle), sin(base_angle)) * LENGTH,
			Color(1.0, 0.3, 0.3, 0.25 + 0.5 * k), 1.0)
		return
	var k2: float = clampf(timer / FIRE, 0.0, 1.0)
	var ang := base_angle - SWEEP * 0.5 + SWEEP * (1.0 - k2)
	var b := Vector2(cos(ang), sin(ang)) * LENGTH
	draw_line(Vector2.ZERO, b, Color(1.0, 0.25, 0.2, 0.28), 14.0)
	draw_line(Vector2.ZERO, b, Color(1.0, 0.45, 0.35, 0.9), 5.0)
	draw_line(Vector2.ZERO, b, Color(1, 1, 1, 0.85), 2.0)
