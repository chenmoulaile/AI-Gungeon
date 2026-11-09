class_name BulletPattern
extends RefCounted
## 弹幕模式：无状态单帧出弹工具（静态函数，不持有任何跨帧状态）
##
## 硬约束 1：所有发射一律经参数传入的 shooter.shoot_at() 虚分派出弹，
## 绝不直连 shoot_from——boss_twins 覆写 shoot_at 换到双核枪口 _aim_origin，
## enemy_base.shoot_at 里带 SeedManager.diff("bullet") 速度缩放；
## 绕过虚分派会让双生 Boss 出弹点静默漂移、难度缩放失效。
##
## 硬约束 2：跨帧螺旋状态（spiral_left / spiral_t / spiral_angle）留在调用方，
## 本类只负责"发当前这一齿"，不建第二状态机。调用方每帧按自己的节奏推进角度
## 再调 spiral_step 即可（boss.gd / enemy_shooter.gd 均如此）。
##
## 出弹点统一在 shooter 身前 radius + 2px（见 enemy_base.shoot_at），
## 双生 Boss 的交叉双环（boss_twins._attack_cross）需要逐核指定枪口，
## 本就不走 shoot_at，不在本类职责内。


## 整圈均匀弹：count 发，起始相位 phase（弧度）。
## 现值迁移：Boss 环 18 发 165 速 4.2 半径（boss.gd._attack_ring）、
## 环形射手 18/20 发 150 速 3.8（enemy_ring_shooter._fire_ring）、
## 扩散者第 2 层起 14 发 170 速 3.6（enemy_spreader 环形模式）。
static func ring(shooter: Node, count: int, speed: float, bullet_radius: float = 3.8,
		phase: float = 0.0) -> void:
	for i in count:
		var a := TAU * float(i) / float(count) + phase
		shooter.shoot_at(Vector2(cos(a), sin(a)), speed, bullet_radius)


## 居中扇形：count 发，总张角 spread_deg（度），对称分布在 dir 两侧。
## count=1 时退化为直线单发。
## 现值迁移：Boss 扇 9 发 62° 195 速（boss.gd._attack_fan）、
## 扩散者 9 发 46° 185 速（enemy_spreader）、直线射手 1 层 3 发 24° 225 速。
static func fan(shooter: Node, dir: Vector2, count: int, spread_deg: float,
		speed: float, bullet_radius: float = 3.8) -> void:
	if count <= 1:
		shooter.shoot_at(dir, speed, bullet_radius)
		return
	for i in count:
		var t := float(i) / float(count - 1) - 0.5
		shooter.shoot_at(dir.rotated(deg_to_rad(spread_deg * t)), speed, bullet_radius)


## 瞄准弹：沿 dir 单发，可带角度偏移 offset_deg（度，狙击手第二发 +5°）。
static func aimed(shooter: Node, dir: Vector2, speed: float,
		bullet_radius: float = 3.8, offset_deg: float = 0.0) -> void:
	shooter.shoot_at(dir.rotated(deg_to_rad(offset_deg)), speed, bullet_radius)


## 螺旋单帧：只发 angle（弧度）方向这一齿。跨帧状态由调用方持有并推进。
## 现值迁移：Boss 螺旋 22/20 发、每 0.085s 推进 17°、170 速 4.0 半径
## （boss.gd._ai 螺旋块，双生/镜像继承）；enemy_shooter 第 2 层 4 向旋转弹
## （spin 每次 +0.7，齿间相隔 90°，188 速）。
static func spiral_step(shooter: Node, angle: float, speed: float,
		bullet_radius: float = 3.8) -> void:
	shooter.shoot_at(Vector2(cos(angle), sin(angle)), speed, bullet_radius)
