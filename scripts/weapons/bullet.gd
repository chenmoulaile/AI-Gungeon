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
var _beep_t: float = 0.0


func prepare() -> void:
	already_hit.clear()
	_trail_pts.clear()
	_t = 0.0
	_locked = 0.3 if (destructible or homing > 0.0) else 0.0
	visible = true
	if friendly:
		remove_from_group("enemy_bullets")
		add_to_group("bullets")
	else:
		remove_from_group("bullets")
		add_to_group("enemy_bullets")
	rotation = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	_locked = maxf(0.0, _locked - delta)

	# 地雷：停下引信，最后 0.5s 闪得更快
	if mine:
		mine_fuse -= delta
		_beep_t -= delta
		if _beep_t <= 0.0:
			_beep_t = 0.12 if mine_fuse <= 0.5 else 0.35
			Sfx.play_at("mine_beep", global_position, -6.0, 1.0 + (0.5 - mine_fuse) * 0.6)
		if mine_fuse <= 0.0:
			_explode()
			return
		queue_redraw()
		return

	if life <= 0.0:
		_despawn()
		return

	if homing > 0.0 and homing_time > 0.0:
		homing_time -= delta
		var target: Node = null
		if friendly:
			target = _nearest_enemy(320.0)
		elif GameState.player != null and is_instance_valid(GameState.player):
			target = GameState.player
		if target != null and is_instance_valid(target):
			var want: Vector2 = (target.global_position - global_position).normalized()
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
		# 玩家子弹可以击落追踪弹（组扫描降频到每 2 帧一次）
		if shoot_down and Engine.get_physics_frames() % 2 == 0:
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
			if GameState.training:
				GameFeel.text_popup(p.global_position + Vector2(0, -22), "MISS")
				_despawn()
				return
			if p.try_absorb_bullet():
				_despawn()
				return
			p.take_damage(1)
			_despawn()


func _nearest_enemy(max_dist: float) -> Node:
	var best = null
	var bd := max_dist
	for e in GameState.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _damage_enemy(e: Node) -> void:
	var dmg := damage
	var is_crit := crit
	var p = GameState.player
	# 深度检索：穿透弹对已标记目标造成 2 倍伤害
	if tag == "retrieval_pierce" and float(e.mark_t) > 0.0:
		dmg *= 2.0
		GameFeel.burst(e.global_position, Color(0.45, 0.72, 1.0), 10, 150.0, 0.3)
		GameFeel.aberrate(2.0, 0.1)
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
	# 标记弹：命中即标记 3s
	if tag == "retrieval_mark":
		e.mark_t = maxf(float(e.mark_t), 3.0)
		GameFeel.burst(e.global_position, Color(0.45, 0.72, 1.0), 6, 90.0, 0.24)
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
	Sfx.play_at("boom", global_position, -2.0, 1.0)
	_despawn()


func _check_bounds() -> void:
	# 障碍物：挡子弹（双方都挡），反弹弹则反弹
	for o in GameState.obstacles:
		var r: Rect2 = o
		if r.grow(radius).has_point(global_position):
			if bounce > 0:
				bounce -= 1
				_bounce_off(r)
				Sfx.play_at("bounce", global_position, -4.0, 1.0 - 0.15 * float(2 - bounce))
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
			rotation = 0.0
			Sfx.play_at("bounce", global_position, -4.0, 1.0 - 0.15 * float(2 - bounce))
			GameFeel.burst(global_position, color, 3, 70.0, 0.2)


func _bounce_off(r: Rect2) -> void:
	var c := r.get_center()
	var d := global_position - c
	if absf(d.x / r.size.x) > absf(d.y / r.size.y):
		dir.x = -dir.x
	else:
		dir.y = -dir.y
	rotation = 0.0
	Sfx.play("ui", -6.0, 1.6)


func _despawn() -> void:
	GameFeel.release_bullet(self)


## 八方向整数单位向量：子弹朝向导出的方块不随角度旋转
func _px8(v: Vector2) -> Vector2:
	if v == Vector2.ZERO:
		return Vector2.RIGHT
	var step := roundf(v.angle() / (PI * 0.25))
	return Vector2(roundf(cos(step * PI * 0.25)), roundf(sin(step * PI * 0.25)))


## 像素菱形：逐行 1px，宽度按行渐变
func _px_diamond(h: int, col: Color) -> void:
	for i in range(-h, h + 1):
		var w := 2 * (h - absi(i)) + 2
		draw_rect(Rect2(-float(w) * 0.5, float(i), float(w), 1.0), col)


func _draw() -> void:
	if mine:
		var k: float = 1.0 - clampf(mine_fuse / 1.5, 0.0, 1.0)
		var blink: bool = true if mine_fuse > 0.5 else fmod(_t, 0.16) < 0.08
		var hot := Color(1.0, 0.38, 0.22, 0.95 if blink else 0.35)
		var sz := roundf(radius) * 2.0
		draw_rect(Rect2(-sz * 0.5, -sz * 0.5, sz, sz), Color("#2A0E0A"))
		draw_rect(Rect2(-sz * 0.5, -sz * 0.5, sz, sz), hot, false, 1.0)
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), hot)
		# 引信：4 个 2×2 角标由内向外收束
		var r2 := 8.0 + 26.0 * k
		for i in 4:
			var a := TAU * float(i) / 4.0
			var p := Vector2(cos(a), sin(a)) * r2
			draw_rect(Rect2(roundf(p.x) - 1.0, roundf(p.y) - 1.0, 2.0, 2.0),
				Color(1.0, 0.5, 0.3, 0.55))
		return

	var d := _px8(dir)
	if trail and _trail_pts.size() > 1:
		# 最多 3 个 2px 残影方块，不做圆形复制
		var ghosts: int = mini(3, _trail_pts.size() - 1)
		for g in range(ghosts, 0, -1):
			var gp: Vector2 = to_local(_trail_pts[g])
			var gc := color
			gc.a = 0.20 * (1.0 - float(g) / float(ghosts + 1))
			var gs := 4.0 if g == 1 else 2.0
			draw_rect(Rect2(roundf(gp.x) - gs * 0.5, roundf(gp.y) - gs * 0.5, gs, gs), gc)

	if friendly:
		# 玩家子弹：6×6 亮块 + 2 帧长尾
		draw_rect(Rect2(-4.0, -4.0, 8.0, 8.0), color.darkened(0.72))
		draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), color)
		draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), Color(1, 1, 1, 0.95))
		for i in 2:
			var tp := -d * (5.0 + float(i) * 3.0)
			var ts := 4.0 - float(i) * 2.0
			draw_rect(Rect2(roundf(tp.x) - ts * 0.5, roundf(tp.y) - ts * 0.5, ts, ts),
				Color(color.r, color.g, color.b, 0.35 - 0.12 * float(i)))
	else:
		# 敌方子弹：深红像素菱形 + 亮核
		var h := maxi(1, int(roundf(radius)) - 2)
		_px_diamond(h + 1, color.darkened(0.78))
		_px_diamond(h, color)
		var pulse: bool = fmod(_t, 0.16) < 0.08
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0),
			Color(1, 1, 1, 0.95) if pulse else Color(1.0, 0.88, 0.92, 0.9))
		# 锁定闪烁：4 个 2×2 白角标
		if _locked > 0.0:
			var bl: bool = fmod(_t, 0.1) < 0.05
			var hh := float(h + 3)
			for i in 4:
				var a := TAU * float(i) / 4.0
				var p := Vector2(cos(a), sin(a)) * hh
				draw_rect(Rect2(roundf(p.x) - 1.0, roundf(p.y) - 1.0, 2.0, 2.0),
					Color(1, 1, 1, 0.75 if bl else 0.35))
		# 追踪弹：反向 2px 尾迹
		if homing > 0.0:
			for i in 2:
				var tp2 := -d * (5.0 + float(i) * 3.0)
				draw_rect(Rect2(roundf(tp2.x) - 1.0, roundf(tp2.y) - 1.0, 2.0, 2.0),
					Color(color.r, color.g, color.b, 0.35 - 0.12 * float(i)))
