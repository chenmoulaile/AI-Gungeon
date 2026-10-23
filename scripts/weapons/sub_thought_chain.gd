extends "res://scripts/weapons/subweapon_base.gd"
## GPT「思维链」
## 发射一道链式闪电，在敌人之间弹射最多 3 次，每次伤害递减 20%（100% / 80% / 64%）
## 紫色锯齿线，弹射时在敌人之间短暂显示 0.1s，被击中的敌人闪紫

const ChainFx = preload("res://scripts/fx/chain_lightning.gd")
const BASE_DMG := 9.0
const CHAIN_RANGE := 190.0
const FIRST_RANGE := 420.0


func _configure() -> void:
	display_name = "思维链"
	color = Color("#b98cff")
	cd_total = 6.0


func _use() -> bool:
	var first = nearest_enemy(FIRST_RANGE)
	if first == null:
		GameFeel.text_popup(player.global_position + Vector2(0, -26), "无目标",
			Color(0.75, 0.62, 1.0))
		return false
	var hits: Array = [first]
	var cur = first
	var bounces := 2
	if GameState.upgrades.has("gpt_echo_clone"):
		bounces = 3
	for i in bounces:
		var nxt = _nearest_to(cur.global_position, CHAIN_RANGE, hits)
		if nxt == null:
			break
		hits.append(nxt)
		cur = nxt

	var pts := PackedVector2Array()
	pts.append(player.global_position + Vector2(0, -14))
	var dmg := BASE_DMG * (1.0 + float(GameState.stat("damage", 1.0)) * 0.2)
	for i in hits.size():
		var e = hits[i]
		var mult: float = pow(0.8, float(i))
		pts.append(e.global_position + Vector2(0, -6))
		e.take_damage(dmg * mult, Vector2.RIGHT, "medium", false, "thought_chain")
		GameFeel.flash(e, Color(1.4, 0.9, 2.4), 0.12)
		GameFeel.burst(e.global_position, Color(0.72, 0.55, 1.0), 5, 80.0, 0.22)

	var fx = ChainFx.new()
	if GameState.bullets_root != null and is_instance_valid(GameState.bullets_root):
		GameState.bullets_root.add_child(fx)
		fx.setup(pts)
	Sfx.play("skill", -4.0, 1.25)
	Sfx.play("hit", -6.0, 0.7)
	GameFeel.screen_shake(0.16)
	start_cd(6.0)
	return true


func _nearest_to(from: Vector2, max_dist: float, exclude: Array) -> Node:
	var best = null
	var bd := max_dist
	for e in GameState.enemies:
		if not is_instance_valid(e) or e.dead or exclude.has(e):
			continue
		var d: float = from.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best
