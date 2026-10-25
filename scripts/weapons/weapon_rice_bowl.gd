extends "res://scripts/weapons/weapon_base.gd"
## DeepSeek 主武器「大白饭」（v0.9）
## 左键投掷大白饭：抛物线飞出，落地碎裂造成伤害并留下白饭减速区。
## 每发消耗 7 Token；Token 不足时只能靠铁盆短挥/要饭回蓝。

const BowlScript = preload("res://scripts/weapons/bowl_projectile.gd")
const FishScript = preload("res://scripts/fx/fish_minion.gd")
const CD := 0.75
const DMG := 18.0
const COST := 7.0
const SUMMON_COST := 20.0
const SUMMON_CAP := 8


func setup(p: Node) -> void:
	super.setup(p)
	mode_name = "大白饭"
	p.set_held("", 0.0, Color.WHITE, "rice_bowl", Color("#8EE6FF"), 32.0)


func fire(dir: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not player.can_afford(COST):
		player.notify("Token 不足 · 用铁盆要饭", 1.3)
		Sfx.play("ui", -12.0, 0.7)
		cooldown = 0.3
		return
	player.spend_token(COST)
	cooldown = CD
	var origin: Vector2 = player.global_position + Vector2(0, -12) + dir * 10.0
	if player.gun != null and is_instance_valid(player.gun):
		origin = player.gun.to_global(player.gun.muzzle_local())
	var b = BowlScript.new()
	b.dir = dir
	b.speed = 330.0
	b.travel = 150.0
	b.damage = DMG * damage_mult()
	b.radius = 50.0
	b.global_position = origin
	_bullet_root().add_child(b)
	player.fire_anim = 0.14
	if player.gun != null and is_instance_valid(player.gun):
		player.gun.flash()
	Sfx.play("whoosh", -12.0, 1.15)


# ---------------- 技能「鲸群集结」：召唤小肥鱼 ----------------
func use_skill() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if skill_cd_left > 0.0:
		return false
	var alive := get_tree().get_nodes_in_group("fish_minions").size()
	if alive >= SUMMON_CAP:
		player.notify("鲸群已满（%d）" % SUMMON_CAP, 1.2)
		return false
	if not player.can_afford(SUMMON_COST):
		player.notify("Token 不足 · 召唤需要 %d" % int(SUMMON_COST), 1.4)
		Sfx.play("ui", -12.0, 0.7)
		return false
	player.spend_token(SUMMON_COST)
	var f = FishScript.new()
	f.player = player
	f.slot = alive
	f.global_position = player.global_position + Vector2(
		randf_range(-18.0, 18.0), randf_range(-22.0, -6.0))
	var parent: Node = player.get_parent()
	if parent == null or not is_instance_valid(parent):
		parent = _bullet_root()
	parent.add_child(f)
	player.fire_anim = 0.18
	player.grant_invuln(0.22)
	GameFeel.burst(f.global_position, Color(0.55, 0.85, 1.0), 10, 90.0, 0.4)
	Sfx.play("skill", -4.0, 1.25)
	return true
