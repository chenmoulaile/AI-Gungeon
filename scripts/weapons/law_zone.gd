extends Node2D
## Claude「律令」区域：半径 80，持续 2s
## 区域内敌人移速 -30%，并附加律令标记（受到伤害 +12%）
## 视觉：缓慢旋转的六边形线框 + 书页轮廓，浅金/陶土色

const RADIUS := 80.0
const LIFE := 2.0
const SLOW := 0.70

var radius: float = RADIUS
var life: float = LIFE
var color: Color = Color(0.95, 0.78, 0.52)

var _t: float = 0.0
var _tick: float = 0.0
## 区域内每秒伤害（每 0.5s 结算一次）
var dps: float = 6.0


func _ready() -> void:
	add_to_group("law_zone")
	z_index = 0


func _process(delta: float) -> void:
	_t += delta
	life -= delta
	for e in GameState.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		if global_position.distance_to(e.global_position) <= radius:
			e.slow_mult = minf(float(e.slow_mult), SLOW)
			e.slow_t = maxf(float(e.slow_t), 0.18)
			e.law_t = maxf(float(e.law_t), 0.18)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		for e2 in GameState.enemies:
			if is_instance_valid(e2) and not e2.dead \
					and global_position.distance_to(e2.global_position) <= radius:
				e2.take_damage(dps * 0.5, Vector2.ZERO, "light", false, "law_zone")
				if GameState.player != null and is_instance_valid(GameState.player):
					GameState.player.record_hit(e2)
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = clampf(life / LIFE, 0.0, 1.0)
	var open: float = clampf((LIFE - life) / 0.18, 0.0, 1.0)   # 展开
	var close: float = clampf(life / 0.25, 0.0, 1.0)            # 收束
	var rr: float = radius * open * (0.75 + 0.25 * close)
	var alpha: float = 0.55 * close
	var spin: float = _t * 0.6

	# 地面填充
	draw_circle(Vector2.ZERO, rr, Color(color.r, color.g, color.b, 0.06 * close))
	# 六边形线框（双层，反向旋转）
	for layer in 2:
		var r2: float = rr * (1.0 - 0.12 * float(layer))
		var a2: float = alpha * (1.0 if layer == 0 else 0.55)
		var rot: float = spin if layer == 0 else -spin * 0.7
		var hex := PackedVector2Array()
		for i in 7:
			var ang: float = TAU * float(i % 6) / 6.0 + rot
			hex.append(Vector2(cos(ang), sin(ang)) * r2)
		draw_polyline(hex, Color(color.r, color.g, color.b, a2), 1.6 if layer == 0 else 1.0)
	# 书页轮廓：中间竖线 + 两侧页边
	draw_line(Vector2(0, -rr * 0.55), Vector2(0, rr * 0.55),
		Color(color.r, color.g, color.b, alpha * 0.7), 1.0)
	for side in [-1.0, 1.0]:
		draw_arc(Vector2(side * rr * 0.30, 0), rr * 0.34, -1.2, 1.2, 10,
			Color(color.r, color.g, color.b, alpha * 0.45), 1.0)
	# 边缘刻度
	for i in 12:
		var ang2: float = TAU * float(i) / 12.0 - spin * 1.4
		var p1: Vector2 = Vector2(cos(ang2), sin(ang2)) * rr
		var p2: Vector2 = Vector2(cos(ang2), sin(ang2)) * (rr + 4.0)
		draw_line(p1, p2, Color(color.r, color.g, color.b, alpha * 0.8), 1.2)
