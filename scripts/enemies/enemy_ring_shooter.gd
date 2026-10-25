extends EnemyBase
## 环形射手：原地不动，每 3.0s 放一圈 12 发（120px/s），发射前 0.5s 收拢白色预警环

const CYCLE := 3.0
const WARN := 0.5
const BULLETS := 12

var timer: float = 0.0
var warning: float = 0.0
var spin: float = 0.0


func _setup() -> void:
	var st: EnemyStats = Stats.enemy("ring_shooter")
	max_hp = st.max_hp * GameState.enemy_scale()
	hp = max_hp
	speed = st.speed
	radius = 11.0
	contact_damage = st.contact_damage
	coin_value = st.coin_value
	accent = Color("#E4485F")
	timer = SeedManager.randf_range(1.2, 2.4)
	spin = SeedManager.randf() * TAU


func _ai(delta: float) -> void:
	if warning > 0.0:
		warning -= delta
		if warning <= 0.0:
			_fire_ring()
		return
	timer -= delta
	if timer <= 0.0:
		timer = CYCLE
		warning = WARN
		Sfx.play_at("ring_warn", global_position, -4.0, 1.0)


func _fire_ring() -> void:
	spin += 0.26
	for i in BULLETS:
		var a := TAU * float(i) / float(BULLETS) + spin
		shoot_at(Vector2(cos(a), sin(a)), 120.0, 3.8)
	Sfx.play_at("hit", global_position, -6.0, 0.8)
	GameFeel.screen_shake(0.08)


func _draw_body() -> void:
	var s := roundf(radius)
	var body := Color("#3A1B22")
	var red := Color("#E4485F")
	var edge := Color("#0B0406")
	# 外环：8 个 2×2 方块，2 帧旋转
	var frame := 0.0 if fmod(t, 0.5) < 0.25 else PI * 0.125
	var rr := s + 3.0
	for i in 8:
		var a := TAU * float(i) / 8.0 + frame
		var p := Vector2(cos(a), sin(a)) * rr
		_px_rects([Rect2(roundf(p.x) - 1.0, roundf(p.y) - 1.0, 2.0, 2.0)], red, edge)
	# 核心：8×8 暗红方块 + 十字红纹
	_px_rects([Rect2(-4.0, -4.0, 8.0, 8.0)], body, edge)
	draw_rect(Rect2(-4.0, -1.0, 8.0, 2.0), red.darkened(0.15))
	draw_rect(Rect2(-1.0, -4.0, 2.0, 8.0), red.darkened(0.15))
	draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), Color("#FFF0F2"))
	# 内环：4 个 2×2 反向旋转
	for i in 4:
		var a2 := TAU * float(i) / 4.0 - frame * 2.0 + PI * 0.25
		var p2 := Vector2(cos(a2), sin(a2)) * roundf(s * 0.62)
		draw_rect(Rect2(roundf(p2.x) - 1.0, roundf(p2.y) - 1.0, 2.0, 2.0),
			Color(1.0, 0.45, 0.52, 0.9))
	# 预警：8 个 2×2 白块从外收拢，2 帧闪
	if warning > 0.0:
		var k := 1.0 - warning / WARN
		var rad := s + 40.0 * (1.0 - k)
		var bl: bool = fmod(t, 0.12) < 0.06
		for i in 8:
			var a3 := TAU * float(i) / 8.0
			var p3 := Vector2(cos(a3), sin(a3)) * rad
			draw_rect(Rect2(roundf(p3.x) - 1.0, roundf(p3.y) - 1.0, 2.0, 2.0),
				Color(1, 1, 1, 0.55 if bl else 0.30))
