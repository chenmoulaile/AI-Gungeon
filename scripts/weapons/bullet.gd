extends Node2D
## 子弹：手写圆形碰撞（不用 Area2D，数量多时更稳、更好调）
## 敌人列表来自 GameState.enemies，玩家引用来自 GameState.player

signal hit_enemy(enemy: Node, bullet: Node)

var dir: Vector2 = Vector2.RIGHT
var speed: float = 320.0
var damage: float = 5.0
var radius: float = 3.0
var friendly: bool = true
var life: float = 2.2
var color: Color = Color("#8ee6ff")
var pierce: int = 0
var gen: int = 0              # 分裂代数（推理链用）
var homing: float = 0.0       # 追踪强度
var homing_time: float = 0.0
var already_hit: Array = []
var wobble: float = 0.0

var _t: float = 0.0


func _ready() -> void:
	add_to_group("bullets")
	if not friendly:
		add_to_group("enemy_bullets")
	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return

	# 追踪：只在前 homing_time 秒内生效
	if homing > 0.0 and homing_time > 0.0 and GameState.player != null:
		homing_time -= delta
		var want: Vector2 = (GameState.player.global_position - global_position).normalized()
		dir = dir.slerp(want, clampf(homing * delta, 0.0, 1.0)).normalized()
		rotation = dir.angle()

	var spd := speed
	# Claude 被动「细致阅读」：120 像素内敌弹速度 -25%
	if not friendly and GameState.player != null and GameState.player.char_id == "claude":
		if global_position.distance_to(GameState.player.global_position) < 120.0:
			spd *= 0.75

	position += dir * spd * delta
	_check_hit()
	_check_bounds()


func _check_hit() -> void:
	if friendly:
		for e in GameState.enemies.duplicate():
			if not is_instance_valid(e) or already_hit.has(e):
				continue
			if global_position.distance_to(e.global_position) < radius + float(e.radius):
				_damage_enemy(e)
				if pierce > 0:
					pierce -= 1
					already_hit.append(e)
				else:
					queue_free()
					return
	else:
		var p = GameState.player
		if p == null or not is_instance_valid(p) or not p.alive:
			return
		if global_position.distance_to(p.global_position) < radius + GameConfig.PLAYER_RADIUS:
			# 护盾优先吸收
			if p.try_absorb_bullet():
				queue_free()
				return
			p.take_damage(1)
			queue_free()


func _damage_enemy(e: Node) -> void:
	var dmg := damage
	var p = GameState.player
	# DeepSeek 被动「注意力聚焦」：对同一目标叠层加伤
	if p != null and is_instance_valid(p) and p.focus_target == e and p.focus_stacks > 0:
		dmg *= 1.0 + 0.05 * float(p.focus_stacks)
	e.take_damage(dmg)
	if p != null and is_instance_valid(p):
		p.record_hit(e)
	hit_enemy.emit(e, self)
	Sfx.play("hit", -4.0, randf_range(0.9, 1.15))


func _check_bounds() -> void:
	var r := GameConfig.room_rect().grow(48.0)
	if not r.has_point(global_position):
		queue_free()


func _draw() -> void:
	# 深色描边 + 亮色芯，保证弹幕可读性
	draw_circle(Vector2.ZERO, radius + 1.2, Color(0, 0, 0, 0.45))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.42,
		Color(1, 1, 1, 0.9))
