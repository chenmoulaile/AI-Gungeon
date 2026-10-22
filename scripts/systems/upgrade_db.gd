extends Node
## 藏品数据库（autoload）：读取 resources/upgrades/*.tres，并提供组合效果表

const UPGRADE_DIR := "res://resources/upgrades"

## 12 组组合效果（两件藏品同时持有时触发）
const COMBOS := [
	{"a": "sharp_round", "b": "crit_lens", "name": "精准推理", "desc": "暴击伤害 +50%",
		"effects": {"crit_mult": 0.5}},
	{"a": "rapid_cycle", "b": "split_prism", "name": "多路并行", "desc": "射速再 +15%",
		"effects": {"fire_rate": 0.15}},
	{"a": "piercing_nail", "b": "scholar_page", "name": "贯穿论证", "desc": "穿透 +1",
		"effects": {"pierce": 1}},
	{"a": "extra_heart", "b": "vampire_chip", "name": "续航协议", "desc": "每 5 次击杀回复 1 点生命",
		"effects": {"lifesteal_every": 5}},
	{"a": "feather_boots", "b": "roll_core", "name": "闪避本能", "desc": "翻滚冷却 -20%",
		"effects": {"roll_cd_mult": -0.2}},
	{"a": "cool_module", "b": "rapid_cycle", "name": "算力超频", "desc": "技能冷却 -15%",
		"effects": {"skill_cd_mult": -0.15}},
	{"a": "sharp_round", "b": "piercing_nail", "name": "穿甲推理", "desc": "伤害 +10%",
		"effects": {"damage": 0.10}},
	{"a": "crit_lens", "b": "split_prism", "name": "并行采样", "desc": "暴击率 +8%",
		"effects": {"crit": 0.08}},
	{"a": "extra_heart", "b": "cool_module", "name": "稳态系统", "desc": "生命上限 +1",
		"effects": {"max_hp_bonus": 1}},
	{"a": "vampire_chip", "b": "feather_boots", "name": "掠食步法", "desc": "移速 +10%",
		"effects": {"move_speed": 0.10}},
	{"a": "scholar_page", "b": "sharp_round", "name": "深读精析", "desc": "伤害 +8%",
		"effects": {"damage": 0.08}},
	{"a": "magnet_coil", "b": "split_prism", "name": "场域牵引", "desc": "拾取范围 +40",
		"effects": {"magnet": 40.0}},
]

var upgrades: Dictionary = {}   # id -> Upgrade


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	var files: PackedStringArray = []
	if DirAccess.dir_exists_absolute(UPGRADE_DIR):
		files = DirAccess.get_files_at(UPGRADE_DIR)
	if files.is_empty():
		# 导出包里 DirAccess 偶发拿不到，退化为固定清单
		files = PackedStringArray([
			"sharp_round.tres", "rapid_cycle.tres", "feather_boots.tres",
			"extra_heart.tres", "magnet_coil.tres", "crit_lens.tres",
			"piercing_nail.tres", "vampire_chip.tres", "roll_core.tres",
			"cool_module.tres", "split_prism.tres", "scholar_page.tres",
		])
	for f in files:
		if not f.ends_with(".tres"):
			continue
		var res: Resource = load("%s/%s" % [UPGRADE_DIR, f])
		if res is Upgrade and res.id != "":
			upgrades[res.id] = res


func get_upgrade(id: String) -> Upgrade:
	return upgrades.get(id, null)


func all_ids() -> Array:
	return upgrades.keys()


func get_combo(combo_name: String) -> Dictionary:
	for c in COMBOS:
		if c["name"] == combo_name:
			return c
	return {}


## 随机抽取 n 个未持有的藏品作为商店货架
func roll_offers(n: int, owned: Array) -> Array:
	var pool: Array = []
	for id in upgrades.keys():
		if not owned.has(id):
			pool.append(upgrades[id])
	pool.shuffle()
	var out: Array = []
	for i in min(n, pool.size()):
		out.append(pool[i])
	return out


## 检查已持有藏品是否触发新的组合，返回新激活的组合名列表
func detect_combos(owned: Array) -> Array:
	var result: Array = []
	for c in COMBOS:
		if owned.has(c["a"]) and owned.has(c["b"]):
			result.append(c["name"])
	return result
