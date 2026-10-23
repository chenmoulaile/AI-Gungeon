extends Node2D
## 子弹：手写圆形碰撞 + 对象池（由 GameFeel 回收）
## 支持：反弹弹（撞墙反弹）、地雷弹（落地引爆）、追踪弹（可被击落）、盾卫格挡

signal hit_enemy(enemy: Node, bullet: Node)

var dir: Vector2 = Vector2.RIGHT
var speed: float = 320.0
var damage: float = 5.0
var radius: float = 3.0
var friendly: bool = true
var life: float = 2.2
var color: Color = Color("#8ee6ff")
var pierce: int = 0
var gen: int = 0
var homing: float = 0.0
var homing_time: float = 0.0
var crit: bool = false
var tier: String = "medium"
var trail: bool = false
var tag: String = ""

var bounce: int = 0            # 剩余反弹次数
var mine: bool = false         # 地雷弹
var mine_fuse: float = 1.5
var destructible: bool = false # 可被玩家子弹击落（追踪弹）
var shoot_down: bool = true    # 玩家子弹是否去击落 destructible 弹

var already_hit: Array = []
var _trail_pts: Array = []
var _t: float = 0.0
var _locked: float = 0.0


func prepare() -> void:
	already_hit.clear()
	_trail_pts.clear()
	_t = 0.0
	_locked = 0.3 if destructible else 0.0
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
	_locked = maxf(0.0, _locked - delta)

	# 地雷：停下引信，最后 0.5s 闪得更快
	if mine:
		mine_fuse -= delta
		if mine_fuse <= 0.0:
			_explode()
			return
		queue_redraw()
		return

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
				# 盾卫：正面格挡
				if e.has_method("blocks_hit") and e.blocks_hit(dir):
					e.on_blocked(global_position, dir)
					_despawn()
					return
				_damage_enemy(e)
				if pierce > 0:
					pierce -= 1
					already_hit.append(e)
				else:
					_despawn()
					return
		# 木箱
		for c in GameState.crates:
			if not is_instance_valid(c) or c.dead:
				continue
			if global_position.distance_to(c.global_position) < radius + 18.0:
				c.hit(damage, dir)
				_despawn()
				return
		# 玩家子弹可以击落追踪弹
		if shoot_down:
			for b in get_tree().get_nodes_in_group("enemy_bullets"):
				if b == self or not is_instance_valid(b) or not b.destructible:
					continue
				if global_position.distance_to(b.global_position) < radius + b.radius + 2.0:
					GameFeel.burst(b.global_position, Color(1.0, 0.8, 0.6), 4, 80.0, 0.2)
					b._despawn()
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
	var is_crit := crit
	var p = GameState.player
	if p != null and is_instance_valid(p) and p.focus_target == e and p.focus_stacks > 0:
		dmg *= 1.0 + 0.05 * float(p.focus_stacks)
	if bool(GameState.mods.get("first_hit_crit", false)) and float(e.hp) >= float(e.max_hp) - 0.01:
		is_crit = true
	var focus_at: int = int(GameState.mods.get("focus_crit_at", 0))
	if focus_at > 0 and p != null and is_instance_valid(p) \
			and p.focus_target == e and p.focus_stacks >= focus_at:
		is_crit = true
	if is_crit and not crit:
		dmg *= float(GameState.stat("crit_mult", 2.0))
	e.take_damage(dmg, dir, tier, is_crit, tag)
	if p != null and is_instance_valid(p):
		p.record_hit(e)
	hit_enemy.emit(e, self)


func _explode() -> void:
	var p = GameState.player
	if p != null and is_instance_valid(p):
		if global_position.distance_to(p.global_position) < 60.0 + GameConfig.PLAYER_RADIUS:
			p.take_damage(1)
	GameFeel.burst(global_position, Color(1.0, 0.55, 0.3), 14, 170.0, 0.4)
	GameFeel.screen_shake(0.22)
	Sfx.play("boss", -8.0, 1.5)
	_despawn()


func _check_bounds() -> void:
	# 障碍物：挡子弹（双方都挡），反弹弹则反弹
	for o in GameState.obstacles:
		var r: Rect2 = o
		if r.grow(radius).has_point(global_position):
			if bounce > 0:
				bounce -= 1
				_bounce_off(r)
				return
			GameFeel.burst(global_position, Color(0.8, 0.82, 0.9), 3, 60.0, 0.18)
			_despawn()
			return

	var room := GameConfig.room_rect()
	if not room.grow(48.0).has_point(global_position):
		_despawn()
		return
	# 房间墙：反弹弹反弹
	if bounce > 0:
		var inner := room.grow(-GameConfig.WALL)
		if not inner.has_point(global_position):
			bounce -= 1
			if global_position.x < inner.position.x or global_position.x > inner.end.x:
				dir.x = -dir.x
			if global_position.y < inner.position.y or global_position.y > inner.end.y:
				dir.y = -dir.y
			rotation = dir.angle()
			Sfx.play("ui", -6.0, 1.6)
			GameFeel.burst(global_position, color, 3, 70.0, 0.2)


func _bounce_off(r: Rect2) -> void:
	var c := r.get_center()
	var d := global_position - c
	if absf(d.x / r.size.x) > absf(d.y / r.size.y):
		dir.x = -dir.x
	else:
		dir.y = -dir.y
	rotation = dir.angle()
	Sfx.play("ui", -6.0, 1.6)


func _despawn() -> void:
	GameFeel.release_bullet(self)


func _draw() -> void:
	if mine:
		var k: float = 1.0 - clampf(mine_fuse / 1.5, 0.0, 1.0)
		var blink: float = 1.0 if mine_fuse > 0.5 else (0.35 + 0.65 * absf(sin(_t * 18.0)))
		draw_circle(Vector2.ZERO, radius + 4.0, Color(1.0, 0.4, 0.2, 0.18 * blink))
		draw_circle(Vector2.ZERO, radius, Color(0.9, 0.3, 0.15, blink))
		draw_arc(Vector2.ZERO, 8.0 + 26.0 * k, 0.0, TAU, 20, Color(1.0, 0.5, 0.3, 0.5), 1.0, true)
		return

	if trail and _trail_pts.size() > 1:
		for i in range(_trail_pts.size() - 1):
			var a: float = 1.0 - float(i) / float(_trail_pts.size())
			var c2 := color
			c2.a = a * 0.35
			draw_line(to_local(_trail_pts[i]), to_local(_trail_pts[i + 1]), c2,
				maxf(1.0, radius * 1.1 * a))

	if not friendly:
		var glow := color
		glow.a = 0.22
		draw_circle(Vector2.ZERO, radius + 3.2, glow)
		draw_circle(Vector2.ZERO, radius + 1.3, Color(0.1, 0.02, 0.06, 0.75))
		draw_circle(Vector2.ZERO, radius, color)
		# 锁定闪烁（追踪弹生成后 0.3s）
		if _locked > 0.0:
			var k2: float = 0.5 + 0.5 * sin(_t * 40.0)
			draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 16,
				Color(1, 1, 1, 0.6 * k2), 1.0, true)
		draw_circle(Vector2.ZERO, radius * 0.5, Color(1, 0.96, 0.98, 0.95))
	else:
		draw_circle(Vector2.ZERO, radius + 1.2, Color(0, 0, 0, 0.45))
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.45,
			Color(1, 1, 1, 0.92))
