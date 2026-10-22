extends Node
## 全局手感系统（autoload）
##
## 集中管理：hit-stop / 屏幕震动 / 受击闪白 / 击退 / 伤害数字 / 粒子 / 子弹对象池。
## 武器与敌人只调用这里的三档预设（small / medium / large），不要各写一套。

const DamageNumberScript = preload("res://scripts/fx/damage_number.gd")
const SparkScript = preload("res://scripts/fx/spark.gd")
const AfterimageScript = preload("res://scripts/fx/afterimage.gd")
const BulletScript = preload("res://scripts/weapons/bullet.gd")

## 三档反馈预设：普通命中用 medium，禁止对每一次普通命中用 large
const PRESETS := {
	"small": {"hitstop": 0.0, "shake": 0.05, "flash": 0.07, "spark": 3, "number": true},
	"medium": {"hitstop": 0.028, "shake": 0.16, "flash": 0.09, "spark": 6, "number": true},
	"large": {"hitstop": 0.11, "shake": 0.55, "flash": 0.14, "spark": 14, "number": true},
}

var trauma: float = 0.0
var trauma_decay: float = 1.55
var shake_strength: float = 7.5
var camera: Camera2D = null

var _hitstop_token: int = 0
var _bullet_pool: Array = []
var _spark_pool: Array = []
var _number_pool: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - trauma_decay * delta)
		if camera != null and is_instance_valid(camera):
			var s: float = shake_strength * trauma * trauma
			camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
	elif camera != null and is_instance_valid(camera) and camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO


func register_camera(cam: Camera2D) -> void:
	camera = cam


# ---------------------------------------------------------------- 基础通道
## 时间缩放停顿；用真实时间计时，不会因为自身缩放而卡住，也不阻塞输入
func hit_stop(duration: float, scale: float = 0.04) -> void:
	if duration <= 0.0:
		return
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if token == _hitstop_token:
		Engine.time_scale = 1.0


## trauma 衰减式震屏：只改 Camera2D.offset，不影响任何碰撞体
func screen_shake(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## 受击闪白/闪红（Tween 缓动回白）
func flash(node: Node, color: Color = Color(2.6, 2.6, 2.6), duration: float = 0.09) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.modulate = color
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", Color(1, 1, 1, 1), duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 缓动击退：写入节点自己的 knock_vel，由节点逐帧衰减
func knockback(node: Node, direction: Vector2, strength: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	if "knock_vel" in node:
		node.knock_vel = direction.normalized() * strength


## 伤害数字：上浮 + 轻微下坠 + 淡出
func damage_number(pos: Vector2, amount: float, crit: bool = false) -> void:
	var node := _take_number()
	if node != null:
		node.show_number(pos, amount, crit)


func release_number(node: Node2D) -> void:
	if node != null and is_instance_valid(node):
		node.visible = false
		node.set_process(false)


## 粒子爆散（对象池）
func burst(pos: Vector2, color: Color, count: int = 6, speed: float = 90.0,
		life: float = 0.32) -> void:
	var node := _take_spark()
	if node != null:
		node.burst(pos, color, count, speed, life)


func release_spark(node: Node2D) -> void:
	if node != null and is_instance_valid(node):
		node.visible = false
		node.set_process(false)


## 翻滚残影
func afterimage(texture: Texture2D, pos: Vector2, flip: bool, tint: Color,
		duration: float = 0.15) -> void:
	if texture == null:
		return
	var layer := _fx_root()
	if layer == null:
		return
	var ghost: Sprite2D = AfterimageScript.new()
	ghost.texture = texture
	ghost.flip_h = flip
	ghost.modulate = tint
	ghost.global_position = pos
	layer.add_child(ghost)
	var tw := ghost.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", Vector2(0.9, 0.9), duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(ghost.queue_free)


# ---------------------------------------------------------------- 组合预设
## 一次调用打满一整档反馈
func impact(preset: String, world_pos: Vector2, node: Node, dir: Vector2,
		amount: float = 0.0, crit: bool = false, flash_color: Color = Color(2.6, 2.6, 2.6),
		spark_color: Color = Color(1, 0.85, 0.6)) -> void:
	var p: Dictionary = PRESETS.get(preset, PRESETS["medium"])
	flash(node, flash_color, float(p["flash"]))
	screen_shake(float(p["shake"]))
	burst(world_pos, spark_color, int(p["spark"]), 70.0 + float(p["spark"]) * 9.0, 0.3)
	if bool(p["number"]) and amount > 0.0:
		damage_number(world_pos + Vector2(randf_range(-3, 3), -12), amount, crit)
	if float(p["hitstop"]) > 0.0:
		hit_stop(float(p["hitstop"]))
	if node != null and is_instance_valid(node) and dir != Vector2.ZERO:
		knockback(node, dir, 46.0 if preset == "medium" else 22.0)


# ---------------------------------------------------------------- 对象池
func get_bullet() -> Node:
	var b: Node = null
	while _bullet_pool.size() > 0:
		var cand: Node = _bullet_pool.pop_back()
		if is_instance_valid(cand):
			b = cand
			break
	var layer := _fx_root()
	if b == null:
		b = BulletScript.new()
		if layer == null:
			return null
		layer.add_child(b)
	elif b.get_parent() != layer and layer != null:
		if b.get_parent() != null:
			b.get_parent().remove_child(b)
		layer.add_child(b)
	b.set_physics_process(true)
	b.visible = true
	return b


func release_bullet(b: Node) -> void:
	if b == null or not is_instance_valid(b):
		return
	for conn in b.hit_enemy.get_connections():
		b.hit_enemy.disconnect(conn["callable"])
	b.visible = false
	b.set_physics_process(false)
	if b.get_parent() != null:
		b.get_parent().remove_child(b)
	_bullet_pool.append(b)


func _take_number() -> Node2D:
	for i in range(_number_pool.size() - 1, -1, -1):
		var n = _number_pool[i]
		if not is_instance_valid(n):
			_number_pool.remove_at(i)
			continue
		if not n.visible:
			return n
	var layer := _fx_root()
	if layer == null:
		return null
	var node: Node2D = DamageNumberScript.new()
	layer.add_child(node)
	_number_pool.append(node)
	return node


func _take_spark() -> Node2D:
	for i in range(_spark_pool.size() - 1, -1, -1):
		var s = _spark_pool[i]
		if not is_instance_valid(s):
			_spark_pool.remove_at(i)
			continue
		if not s.visible:
			return s
	var layer := _fx_root()
	if layer == null:
		return null
	var node: Node2D = SparkScript.new()
	layer.add_child(node)
	_spark_pool.append(node)
	return node


func _fx_root() -> Node2D:
	if GameState.bullets_root != null and is_instance_valid(GameState.bullets_root):
		return GameState.bullets_root
	var scene := get_tree().current_scene
	if scene is Node2D:
		return scene
	return null


func reset() -> void:
	Engine.time_scale = 1.0
	trauma = 0.0
	_bullet_pool.clear()
	_spark_pool.clear()
	_number_pool.clear()
	if camera != null and is_instance_valid(camera):
		camera.offset = Vector2.ZERO
