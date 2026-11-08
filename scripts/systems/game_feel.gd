extends Node
## 全局手感系统（autoload）
##
## 三档反馈：light 0.04s / medium 0.08s / heavy 0.12s（超过 0.12 会变成卡顿）
## 普通命中用 light，且带 0.16s 冷却，避免高射速下变成永久慢动作；
## 暴击/击杀用 medium，Boss 阶段与死亡用 heavy。

const DamageNumberScript = preload("res://scripts/fx/damage_number.gd")
const SparkScript = preload("res://scripts/fx/spark.gd")
const AfterimageScript = preload("res://scripts/fx/afterimage.gd")
const BulletScript = preload("res://scripts/weapons/bullet.gd")

const PRESETS := {
	"light": {"hitstop": 0.04, "shake": 0.05, "flash": 0.07, "spark": 4, "number": true},
	"medium": {"hitstop": 0.08, "shake": 0.18, "flash": 0.09, "spark": 7, "number": true},
	"heavy": {"hitstop": 0.12, "shake": 0.55, "flash": 0.14, "spark": 14, "number": true},
}

const HITSTOP_COOLDOWN := 0.16

## 手柄震动与三档对齐：duration / 强度
const VIBRATION := {
	"light": [0.05, 0.3],
	"medium": [0.15, 0.6],
	"heavy": [0.30, 1.0],
}

var trauma: float = 0.0
var trauma_decay: float = 1.55
var shake_strength: float = 7.5
var shake_scale: float = 0.7
var camera: Camera2D = null
## 方向性震动：受击方向的反方向偏移，避免全向乱抖
var shake_dir: Vector2 = Vector2.ZERO

const PARTICLE_CAP := 200

var _hitstop_token: int = 0
var _hitstop_lock: float = 0.0
var _bullet_pool: Array = []
var _spark_pool: Array = []
var _number_pool: Array = []
var _particle_live: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_hitstop_lock = maxf(0.0, _hitstop_lock - delta)
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - trauma_decay * delta)
		if camera != null and is_instance_valid(camera):
			var s: float = shake_strength * shake_scale * trauma * trauma
			if shake_dir == Vector2.ZERO:
				camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
			else:
				# 沿受击反方向回弹 + 轻微垂直抖动
				var back: float = s * randf_range(0.75, 1.0)
				var side: float = s * 0.28 * randf_range(-1.0, 1.0)
				camera.offset = shake_dir * back + Vector2(-shake_dir.y, shake_dir.x) * side
	elif camera != null and is_instance_valid(camera) and camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO


func register_camera(cam: Camera2D) -> void:
	camera = cam


# ---------------------------------------------------------------- 基础通道
## 时间缩放停顿；第 4 个参数必须为 true（ignore_time_scale），否则冻结会被自己减速
func hit_stop(duration: float, scale: float = 0.05) -> void:
	if duration <= 0.0:
		return
	if duration < 0.1 and _hitstop_lock > 0.0:
		return   # 轻击有冷却，防止高射速下持续冻结
	_hitstop_lock = HITSTOP_COOLDOWN
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if token == _hitstop_token:
		Engine.time_scale = 1.0


func screen_shake(amount: float, dir: Vector2 = Vector2.ZERO) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)
	shake_dir = dir.normalized() if dir.length() > 0.01 else Vector2.ZERO


## 重击 / Boss 阶段转换的短促色差
func aberrate(strength: float = 2.6, dur: float = 0.15) -> void:
	if ScreenFx != null:
		ScreenFx.aberrate(strength, dur)


## 全屏闪色：死亡闪红 / Boss 转换闪白
func screen_flash(color: Color, dur: float = 0.2, peak: float = 0.55) -> void:
	if ScreenFx != null:
		ScreenFx.flash(color, dur, peak)


## 手柄震动：统一走这里，强度跟随屏幕震动滑块
func vibrate(tier: String) -> void:
	if not Settings.vibration:
		return
	var v: Array = VIBRATION.get(tier, VIBRATION["light"])
	var amp: float = float(v[1]) * Settings.shake_scale
	if amp <= 0.02:
		return
	Input.start_joy_vibration(0, amp * 0.6, amp, float(v[0]))


func flash(node: Node, color: Color = Color(2.6, 2.6, 2.6), duration: float = 0.09) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.modulate = color
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", Color(1, 1, 1, 1), duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func knockback(node: Node, direction: Vector2, strength: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	if "knock_vel" in node:
		node.knock_vel = direction.normalized() * strength


func damage_number(pos: Vector2, amount: float, crit: bool = false) -> void:
	var node := _take_number()
	if node != null:
		node.show_number(pos, amount, crit)


func text_popup(pos: Vector2, s: String, color: Color = Color(1, 1, 1, 0.9)) -> void:
	var node := _take_number()
	if node != null:
		node.show_text(pos, s)


func release_number(node: Node2D) -> void:
	if node != null and is_instance_valid(node):
		PoolManager.recycle(node)


func burst(pos: Vector2, color: Color, count: int = 6, speed: float = 90.0,
		life: float = 0.32) -> void:
	if _particle_live >= PARTICLE_CAP:
		return
	_particle_live += count
	var node := _take_spark()
	if node != null:
		node.mode = "spark"
		node.gravity = 0.0
		node.burst(pos, color, count, speed, life)


## 碎块：死亡碎裂，重力下坠 + 自旋 + 0.4s 淡出
func shards(pos: Vector2, color: Color, count: int = 8, speed: float = 150.0,
		life: float = 0.4) -> void:
	if _particle_live >= PARTICLE_CAP:
		return
	_particle_live += count
	var node := _take_spark()
	if node != null:
		node.mode = "shard"
		node.gravity = 520.0
		node.burst(pos, color, count, speed, life)


func release_spark(node: Node2D) -> void:
	if node != null and is_instance_valid(node):
		_particle_live = maxi(0, _particle_live - int(node.particle_count()))
		PoolManager.recycle(node)


func afterimage(texture: Texture2D, pos: Vector2, flip: bool, tint: Color,
		duration: float = 0.15, rot: float = 0.0, offset: Vector2 = Vector2.ZERO) -> void:
	if texture == null:
		return
	var layer := _fx_root()
	if layer == null:
		return
	var ghost: Sprite2D = AfterimageScript.new()
	ghost.texture = texture
	ghost.flip_h = flip
	ghost.modulate = tint
	ghost.rotation = rot
	ghost.offset = offset
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
func impact(preset: String, world_pos: Vector2, node: Node, dir: Vector2,
		amount: float = 0.0, crit: bool = false, flash_color: Color = Color(2.6, 2.6, 2.6),
		spark_color: Color = Color(1, 0.85, 0.6)) -> void:
	var p: Dictionary = PRESETS.get(preset, PRESETS["light"])
	flash(node, flash_color, float(p["flash"]))
	screen_shake(float(p["shake"]))
	burst(world_pos, spark_color, int(p["spark"]), 70.0 + float(p["spark"]) * 9.0, 0.3)
	if bool(p["number"]) and amount > 0.0:
		damage_number(world_pos + Vector2(randf_range(-3, 3), -12), amount, crit)
	# 命中音效与 hit-stop 在同一帧开始，听感与画面同步
	Sfx.play_hit(crit)
	vibrate(preset)
	if float(p["hitstop"]) > 0.0:
		hit_stop(float(p["hitstop"]))
	if preset == "heavy":
		aberrate(2.6, 0.15)
	if node != null and is_instance_valid(node) and dir != Vector2.ZERO:
		knockback(node, dir, 46.0 if preset != "light" else 26.0)


# ---------------------------------------------------------------- 对象池
func get_bullet() -> Node:
	var b: Node = null
	while _bullet_pool.size() > 0:
		var cand = _bullet_pool.pop_back()
		if is_instance_valid(cand):
			b = cand
			break
	var layer := _fx_root()
	if layer == null:
		return null
	if b == null:
		b = BulletScript.new()
		layer.add_child(b)
	elif b.get_parent() != layer:
		if b.get_parent() != null:
			b.get_parent().remove_child(b)
		layer.add_child(b)
	PoolManager.revive(b)
	b.visible = true
	return b


func release_bullet(b: Node) -> void:
	if b == null or not is_instance_valid(b):
		return
	for conn in b.hit_enemy.get_connections():
		b.hit_enemy.disconnect(conn["callable"])
	PoolManager.recycle(b)
	_bullet_pool.append(b)


func _take_number() -> Node2D:
	for i in range(_number_pool.size() - 1, -1, -1):
		var n = _number_pool[i]
		if not is_instance_valid(n):
			_number_pool.remove_at(i)
			continue
		if not n.visible:
			PoolManager.revive(n)
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
			PoolManager.revive(s)
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
	_hitstop_token += 1
	_hitstop_lock = 0.0
	_bullet_pool.clear()
	_spark_pool.clear()
	_number_pool.clear()
	if camera != null and is_instance_valid(camera):
		camera.offset = Vector2.ZERO
