extends Node2D
## 武器基类：冷却、伤害结算、子弹生成
## 子类实现 fire(dir) / use_skill()

const BulletScript = preload("res://scripts/weapons/bullet.gd")

var player = null
var cooldown: float = 0.0
var skill_cd_left: float = 0.0
var mode_name: String = ""


func setup(p: Node) -> void:
	player = p


func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	skill_cd_left = maxf(0.0, skill_cd_left - delta)


# ---------------- 数值 ----------------
func stat(key: String, default_value: float = 0.0) -> float:
	return float(GameState.stat(key, default_value))


func damage_mult() -> float:
	var m := stat("damage", 1.0)
	if player != null and is_instance_valid(player):
		m *= 1.0 + float(player.get_buff("damage", 0.0))
	return m


func fire_rate_mult() -> float:
	var m := stat("fire_rate", 1.0)
	if player != null and is_instance_valid(player):
		m *= 1.0 + float(player.get_buff("fire_rate", 0.0))
	return maxf(0.15, m)


func bullet_speed_mult() -> float:
	var m := stat("bullet_speed", 1.0)
	if player != null and is_instance_valid(player):
		m *= 1.0 + float(player.get_buff("bullet_speed", 0.0))
	return m


## 返回 {dmg, crit}
func calc_damage(base: float) -> Dictionary:
	var dmg := base * damage_mult()
	var crit := randf() < stat("crit", 0.0)
	if crit:
		dmg *= stat("crit_mult", 2.0)
	return {"dmg": dmg, "crit": crit}


## 分裂棱镜等藏品带来的额外弹道角度
func proj_offsets() -> Array:
	var out: Array = []
	var n: int = int(GameState.stat("proj", 0))
	for i in n:
		var side := 1.0 if i % 2 == 0 else -1.0
		out.append(deg_to_rad(11.0) * side * (1.0 + float(i / 2)))
	return out


# ---------------- 子弹 ----------------
func spawn_bullet(pos: Vector2, dir: Vector2, base_damage: float, speed: float,
		color: Color, opts: Dictionary = {}) -> Node:
	var info := calc_damage(base_damage)
	if bool(opts.get("raw", false)):
		info = {"dmg": base_damage, "crit": false}
	var b: Node = BulletScript.new()
	b.dir = dir.normalized()
	b.speed = speed * bullet_speed_mult()
	b.damage = float(info["dmg"])
	b.radius = float(opts.get("radius", 3.0))
	b.life = float(opts.get("life", 2.2))
	b.color = color
	b.friendly = bool(opts.get("friendly", true))
	b.pierce = int(opts.get("pierce", stat("pierce", 0)))
	b.gen = int(opts.get("gen", 0))
	b.homing = float(opts.get("homing", 0.0))
	b.homing_time = float(opts.get("homing_time", 0.0))
	b.global_position = pos
	_bullet_root().add_child(b)
	return b


func _bullet_root() -> Node:
	if GameState.bullets_root != null and is_instance_valid(GameState.bullets_root):
		return GameState.bullets_root
	return get_tree().current_scene


# ---------------- 虚函数 ----------------
func fire(_dir: Vector2) -> void:
	pass


func try_fire(dir: Vector2) -> void:
	if cooldown <= 0.0:
		fire(dir)


func use_skill() -> bool:
	return false


func on_switch_mode() -> void:
	pass


func mode_text() -> String:
	return mode_name


func skill_ready() -> bool:
	return skill_cd_left <= 0.0


func start_skill_cd() -> void:
	var cd: float = 8.0
	if player != null and is_instance_valid(player) and player.data != null:
		cd = player.data.skill_cd
	skill_cd_left = cd * stat("skill_cd_mult", 1.0)
