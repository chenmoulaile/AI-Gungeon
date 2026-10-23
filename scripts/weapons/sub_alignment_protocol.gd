extends "res://scripts/weapons/subweapon_base.gd"
## Claude「对齐协议」
## 在身边生成一个缓慢移动的浮游炮（书页），自动攻击最近的敌人（2/s，伤害 3），持续 8s，冷却 15s
## 浮游炮绕角色做圆周运动（半径 40，周期 3s）

const DroneScript = preload("res://scripts/fx/drone.gd")

var drone: Node = null


func _configure() -> void:
	display_name = "对齐协议"
	color = Color("#ffd9a0")
	cd_total = 15.0


func _use() -> bool:
	if drone != null and is_instance_valid(drone):
		drone.queue_free()
	drone = DroneScript.new()
	var root = GameState.bullets_root
	if root == null or not is_instance_valid(root):
		root = player.get_parent()
	root.add_child(drone)
	drone.setup(player, 8.0)
	drone.damage = 3.0 + float(GameState.stat("damage", 1.0)) * 0.6
	drone.fire_gap = 0.5
	if GameState.upgrades.has("cl_overload"):
		drone.fire_gap = 0.33
		drone.damage *= 1.15
	drone._burst_on_end = GameState.upgrades.has("cl_break_burst")
	drone.global_position = player.global_position + Vector2(40, -16)
	# 展开：六边形顶点粒子
	for i in 6:
		var ang := TAU * float(i) / 6.0 - PI / 2.0
		GameFeel.burst(player.global_position + Vector2(0, -14) + Vector2(cos(ang), sin(ang)) * 26.0,
			Color(1.0, 0.92, 0.7), 3, 40.0, 0.26)
	Sfx.play("skill", -6.0, 1.4)
	Sfx.play("summon_pop", -8.0, 1.2)
	start_cd(15.0)
	return true
