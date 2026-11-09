extends Node2D
## 金币掉落物：靠近自动吸附
## M2：支持带初速度撒落（清场金币雨），磁吸命中后 Tween 加速飞入 + "+1" 飘字

var value: int = 1
## 撒落初速度：摩擦衰减到近 0 后回归纯磁吸
var vel: Vector2 = Vector2.ZERO
## 精英掉落磁吸：true 时无视磁吸半径直接向玩家飞（精英击杀的战利品真空，COIN 计数肉眼可见地涨）
var force_magnet: bool = false
var _player: Node2D = null
var _t: float = 0.0
var _picked: bool = false
var _fly_tw: Tween = null


func _ready() -> void:
	add_to_group("coins")
	_player = GameState.player
	_t = randf() * TAU


## 出池重置：池化复用时清掉上一枚的拾取状态、目标与摆动相位
## （首次生成走 _ready，复用走这里，由 GameFeel.get_coin 调用）
func prepare(v: int = 1) -> void:
	value = v
	_picked = false
	vel = Vector2.ZERO
	force_magnet = false
	_player = GameState.player
	_t = randf() * TAU
	if _fly_tw != null and _fly_tw.is_valid():
		_fly_tw.kill()
	_fly_tw = null


## 金币雨撒落：给一枚初速度（方向 * 速率），随摩擦衰减滑行后停下
func launch(v: Vector2) -> void:
	vel = v


func _physics_process(delta: float) -> void:
	_t += delta * 6.0
	if _picked:
		return
	if vel.length() > 8.0:
		position += vel * delta
		vel = vel.lerp(Vector2.ZERO, clampf(delta * 3.2, 0.0, 1.0))
		# 滑行不越过房间边界（多留 30px，别压到墙沿书架贴图上）
		var r := GameConfig.room_rect().grow(-GameConfig.WALL - 30.0)
		global_position = global_position.clamp(r.position, r.end)
	if _player == null or not is_instance_valid(_player):
		_player = GameState.player
	if _player != null and is_instance_valid(_player):
		var d := global_position.distance_to(_player.global_position)
		var magnet := float(GameState.stat("magnet", 34.0))
		if force_magnet or d < magnet:
			global_position = global_position.move_toward(_player.global_position, 260.0 * delta)
			_start_fly()
		if d < 13.0:
			_collect()
	queue_redraw()


## 磁吸命中：在 260px/s move_toward 之上叠加一段 Tween 加速飞入
## （tween_method 逐帧向玩家插值，k² ease-in 越飞越快；0.22s 后若未拾取则回归 move_toward）
func _start_fly() -> void:
	if _fly_tw != null and _fly_tw.is_valid():
		return
	_fly_tw = create_tween()
	_fly_tw.tween_method(_fly_step, 0.0, 1.0, 0.22)


func _fly_step(k: float) -> void:
	if _picked or _player == null or not is_instance_valid(_player):
		return
	var target: Vector2 = _player.global_position
	global_position = global_position.lerp(target, clampf(0.05 + k * k * 0.30, 0.0, 1.0))


func _collect() -> void:
	_picked = true
	if _fly_tw != null and _fly_tw.is_valid():
		_fly_tw.kill()
	GameState.add_coins(value)
	# "+1" 拾取飘字：金色（经 text_popup -> damage_number.show_text 透传）
	GameFeel.text_popup(global_position, "+1", GameConfig.COL_GOLD)
	Sfx.play("coin", -10.0, randf_range(0.95, 1.2))
	_spawn_trail()
	# 入池而非销毁：出弹侧 get_coin / 入池侧 release 必须成对
	GameFeel.release_coin(self)


## 拾取粒子：从拾取点飞向 HUD 金币图标
func _spawn_trail() -> void:
	if GameState.bullets_root == null or not is_instance_valid(GameState.bullets_root):
		return
	var xf := get_viewport().get_canvas_transform()
	var hud_pos: Vector2 = xf.affine_inverse() * Vector2(18, GameConfig.BASE_H - 17)
	var fx = load("res://scripts/fx/pickup_trail.gd").new()
	GameState.bullets_root.add_child(fx)
	fx.setup(global_position, hud_pos, GameConfig.COL_GOLD, 2)


func _draw() -> void:
	var bob := sin(_t) * 1.2
	var c := GameConfig.COL_GOLD
	draw_circle(Vector2(0, bob), 4.6, Color(0, 0, 0, 0.35))
	var pts := PackedVector2Array([
		Vector2(0, -3.4 + bob), Vector2(3.0, bob), Vector2(0, 3.4 + bob), Vector2(-3.0, bob),
	])
	draw_colored_polygon(pts, c)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
		Color(0.45, 0.3, 0.05, 0.9), 1.0)
	draw_circle(Vector2(-0.8, -1.0 + bob), 0.9, Color(1, 1, 1, 0.85))
