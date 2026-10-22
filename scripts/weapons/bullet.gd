extends Node2D
## 子弹：手写圆形碰撞 + 对象池（由 GameFeel 回收）
## 敌方子弹用暖红/品红 + 外发光，玩家子弹用青/紫，色相明确区分

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
var crit: bool = false
var tier: String = "medium"   # 反馈档位 small / medium / large
var tag: String = ""          # 伤害来源（协同钩子用）
var trail: bool = false
var already_hit: Array = []
var _trail_pts: Array = []
var _t: float = 0.0


func prepare() -> void:
	already_hit.clear()
	_trail_pts.clear()
	_t = 0.0
	visible = true
	if friendly:
		remove_from_group("enemy_bullets")
		add_to_group("bullets")
	else:
		remove_from_group("bullets")
		add_to_group("enemy_bullets")
	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		_despawn()
		return

	if homing > 0.0 and homing_time > 0.0 and GameState.player != null:
		homing_time -= delta
		var want: Vector2 = (GameState.player.global_position - global_position).normalized()
		dir = dir.slerp(want, clampf(homing * delta, 0.0, 1.0)).normalized()

	var spd := speed
	# Claude 被动「细致阅读」：120 像素内敌弹速度 -25%
	if not friendly and GameState.player != null and GameState.player.char_id == "claude":
		if global_position.distance_to(GameState.player.global_position) < 120.0:
			spd *= 0.75

	position += dir * spd * delta
	if trail:
		_trail_pts.push_front(global_position)
		if _trail_pts.size() > 4:
			_trail_pts.pop_back()
	_check_hit()
	_check_bounds()
	queue_redraw()


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
					_despawn()
					return
	else:
		var p = GameState.player
		if p == null or not is_instance_valid(p) or not p.alive:
			return
		if global_position.distance_to(p.global_position) < radius + GameConfig.PLAYER_RADIUS:
			if p.try_absorb_bullet():
				_despawn()
				return
			p.take_damage(1)
			_despawn()


func _damage_enemy(e: Node) -> void:
	var dmg := damage
	var p = GameState.player
	# DeepSeek 被动「注意力聚焦」：对同一目标叠层加伤
	if p != null and is_instance_valid(p) and p.focus_target == e and p.focus_stacks > 0:
		dmg *= 1.0 + 0.05 * float(p.focus_stacks)
	e.take_damage(dmg, dir, tier, crit, tag)
	if p != null and is_instance_valid(p):
		p.record_hit(e)
	hit_enemy.emit(e, self)


func _check_bounds() -> void:
	var r := GameConfig.room_rect().grow(48.0)
	if not r.has_point(global_position):
		_despawn()


func _despawn() -> void:
	GameFeel.release_bullet(self)


func _draw() -> void:
	if trail and _trail_pts.size() > 1:
		for i in range(_trail_pts.size() - 1):
			var a: float = 1.0 - float(i) / float(_trail_pts.size())
			var c := color
			c.a = a * 0.35
			draw_line(to_local(_trail_pts[i]), to_local(_trail_pts[i + 1]), c,
				maxf(1.0, radius * 1.1 * a))

	if not friendly:
		# 危险色外发光，保证在深色地板上依然醒目
		var glow := color
		glow.a = 0.22
		draw_circle(Vector2.ZERO, radius + 3.2, glow)
		draw_circle(Vector2.ZERO, radius + 1.3, Color(0.1, 0.02, 0.06, 0.75))
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2.ZERO, radius * 0.5, Color(1, 0.96, 0.98, 0.95))
	else:
		draw_circle(Vector2.ZERO, radius + 1.2, Color(0, 0, 0, 0.45))
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.45,
			Color(1, 1, 1, 0.92))
