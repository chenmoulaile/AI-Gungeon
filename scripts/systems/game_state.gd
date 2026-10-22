extends Node
## 单局运行状态（autoload）：角色、生命、金币、藏品、统计与数值结算

signal coins_changed(value: int)
signal hp_changed(hp: int, max_hp: int)
signal upgrades_changed()
signal combo_activated(combo_name: String)
signal run_ended()

const PLAYER_MAX_HP := 6

var char_id: String = "deepseek"
var char_data: CharacterData = null

var hp: int = PLAYER_MAX_HP
var max_hp: int = PLAYER_MAX_HP
var coins: int = 0
var floor_index: int = 1
var room_index: int = 1
var kills: int = 0
var run_time: float = 0.0

var upgrades: Array = []      # 已持有藏品 id
var combos: Array = []        # 已激活组合名
var stats: Dictionary = {}

# 场景内引用（由 game.gd / player.gd 维护）
var player: Node2D = null
var bullets_root: Node2D = null
var enemies: Array = []


func _ready() -> void:
	recalc_stats()


func start_run(id: String) -> void:
	char_id = id
	char_data = load_character(id)
	hp = PLAYER_MAX_HP
	max_hp = PLAYER_MAX_HP
	coins = 0
	floor_index = 1
	room_index = 1
	kills = 0
	run_time = 0.0
	upgrades = []
	combos = []
	enemies = []
	player = null
	recalc_stats()
	hp = max_hp
	coins_changed.emit(coins)
	hp_changed.emit(hp, max_hp)
	upgrades_changed.emit()


func load_character(id: String) -> CharacterData:
	var path := "res://resources/characters/%s.tres" % id
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is CharacterData:
			return res
	# 兜底：资源缺失时用代码构造，保证游戏能跑
	var d := CharacterData.new()
	d.id = id
	d.display_name = id.capitalize()
	d.weapon_path = "res://scripts/weapons/weapon_reasoning_chain.gd"
	d.accent = GameConfig.char_color(id)
	return d


# ---------------- 数值结算 ----------------
func recalc_stats() -> void:
	var s := {
		"damage": 1.0,
		"fire_rate": 1.0,
		"move_speed": 1.0,
		"bullet_speed": 1.0,
		"max_hp_bonus": 0,
		"crit": 0.0,
		"crit_mult": 2.0,
		"pierce": 0,
		"proj": 0,
		"roll_cd_mult": 1.0,
		"skill_cd_mult": 1.0,
		"lifesteal_every": 0,
		"magnet": 34.0,
	}
	for uid in upgrades:
		var up: Upgrade = UpgradeDB.get_upgrade(uid)
		if up != null:
			_apply_effects(s, up.effects)
	for cname in combos:
		var c: Dictionary = UpgradeDB.get_combo(cname)
		if not c.is_empty():
			_apply_effects(s, c["effects"])
	stats = s
	max_hp = PLAYER_MAX_HP + int(s["max_hp_bonus"])
	if hp > max_hp:
		hp = max_hp


func _apply_effects(s: Dictionary, effects: Dictionary) -> void:
	for k in effects.keys():
		if not s.has(k):
			continue
		var v = effects[k]
		if k == "lifesteal_every":
			if v > 0:
				s[k] = v if s[k] <= 0 else mini(s[k], int(v))
		elif k == "pierce" or k == "proj" or k == "max_hp_bonus":
			s[k] = int(s[k]) + int(v)
		else:
			s[k] = s[k] + v


func stat(key: String, default_value = 0.0):
	return stats.get(key, default_value)


# ---------------- 藏品与金币 ----------------
func add_upgrade(uid: String) -> Array:
	if upgrades.has(uid):
		return []
	upgrades.append(uid)
	var new_combos: Array = []
	var found: Array = UpgradeDB.detect_combos(upgrades)
	for cname in found:
		if not combos.has(cname):
			combos.append(cname)
			new_combos.append(cname)
	recalc_stats()
	upgrades_changed.emit()
	for cname in new_combos:
		combo_activated.emit(cname)
	return new_combos


func try_buy(up: Upgrade) -> bool:
	if up == null or coins < up.price or upgrades.has(up.id):
		return false
	coins -= up.price
	coins_changed.emit(coins)
	add_upgrade(up.id)
	return true


func add_coins(n: int) -> void:
	coins += n
	coins_changed.emit(coins)


func heal(n: int) -> void:
	hp = mini(max_hp, hp + n)
	hp_changed.emit(hp, max_hp)


func hurt(n: int) -> bool:
	hp -= n
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		hp = 0
		run_ended.emit()
		return true
	return false


func register_enemy(e: Node) -> void:
	if not enemies.has(e):
		enemies.append(e)


func unregister_enemy(e: Node) -> void:
	enemies.erase(e)


func on_enemy_killed() -> void:
	kills += 1
	var every := int(stat("lifesteal_every", 0))
	if every > 0 and kills % every == 0:
		heal(1)


func enemy_scale() -> float:
	# 每层敌人血量 +20%
	return pow(1.2, float(floor_index - 1))
