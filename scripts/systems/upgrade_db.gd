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

## 稀有度（v0.10）：0 白（纯数值）/ 1 蓝（条件触发）/ 2 紫（质变钩子）
const RARITY_PRICE := [18, 30, 48]
const RARITY_NAMES := ["白", "蓝", "紫"]
const RARITY_COLORS := ["#D8E0F0", "#63A9FF", "#B06BFF"]
## 带钩子的条件触发件 → 蓝档；mutation 的质变件 → 紫档；其余白档
const BLUE_IDS := [
	"sharp_round", "rapid_cycle", "feather_boots", "crit_lens",
	"roll_core", "extra_heart", "split_prism", "scholar_page",
]


func _ready() -> void:
	_load_all()


const FALLBACK_IDS := [
	"sharp_round", "rapid_cycle", "feather_boots", "extra_heart", "magnet_coil",
	"crit_lens", "piercing_nail", "vampire_chip", "roll_core", "cool_module",
	"split_prism", "scholar_page", "ds_homing_split", "ds_burn_zone",
	"gpt_echo_clone", "gpt_voice_haste", "cl_break_burst", "cl_overload",
]


func _load_all() -> void:
	var names: Array = []
	if DirAccess.dir_exists_absolute(UPGRADE_DIR):
		for f in DirAccess.get_files_at(UPGRADE_DIR):
			var n := String(f)
			if n.ends_with(".remap"):
				n = n.trim_suffix(".remap")
			if n.ends_with(".tres") or n.ends_with(".res"):
				names.append(n)
	# 兜底：导出包里目录列表可能拿不到，或文件名被重映射，固定清单保证 18 件都在
	for id in FALLBACK_IDS:
		if not names.has(id + ".tres"):
			names.append(id + ".tres")
	for n in names:
		var res = load("%s/%s" % [UPGRADE_DIR, n])
		if res == null:
			continue
		var rid = res.get("id")
		if rid != null and String(rid) != "":
			upgrades[String(rid)] = res


func get_upgrade(id: String) -> Upgrade:
	return upgrades.get(id, null)


func all_ids() -> Array:
	return upgrades.keys()


func rarity_of(up: Upgrade) -> int:
	if up == null:
		return 0
	if up.mutation:
		return 2
	if BLUE_IDS.has(up.id):
		return 1
	return 0


func rarity_of_id(id: String) -> int:
	return rarity_of(upgrades.get(id, null))


func price_of(up: Upgrade) -> int:
	return int(RARITY_PRICE[rarity_of(up)])


func pick_by_rarity(owned: Array, want: int) -> Upgrade:
	var exact: Array = []
	var fallback: Array = []
	for id in upgrades.keys():
		if owned.has(id):
			continue
		var r := rarity_of_id(String(id))
		if r == want:
			exact.append(id)
		if r >= want:
			fallback.append(id)
	var pool: Array = exact if not exact.is_empty() else fallback
	if pool.is_empty():
		for id in upgrades.keys():
			if not owned.has(id):
				pool.append(id)
	if pool.is_empty():
		return null
	SeedManager.shuffle(pool)
	return upgrades[String(pool[0])]


## 精英房必掉：至少蓝档，尽量不掉已持有的
func roll_rare(owned: Array, min_rarity: int = 1) -> Upgrade:
	return pick_by_rarity(owned, min_rarity)


func get_combo(combo_name: String) -> Dictionary:
	for c in COMBOS:
		if c["name"] == combo_name:
			return c
	return {}


## 加权抽取：与已持有藏品能凑成组合的权重 ×3，保证至少 1 个"有戏"的选项
func roll_offers(n: int, owned: Array) -> Array:
	var weighted: Array = []
	var hints: Array = []
	for id in upgrades.keys():
		if owned.has(id):
			continue
		var w := 1
		var related := false
		var up: Upgrade = upgrades[id]
		# 稀有度基础权重：白 4 / 蓝 2 / 紫 1，白档更容易上架
		w = maxi(w, [4, 2, 1][rarity_of(up)])
		# 已持有某角色 1 件专属藏品时，该角色另一件权重 ×2
		if up != null and up.char_tag != "" and up.char_tag == GameState.char_id:
			for owned_id in owned:
				var ou: Upgrade = upgrades.get(owned_id, null)
				if ou != null and ou.char_tag == up.char_tag:
					w = maxi(w, Stats.economy.char_weight if Stats.economy != null else 2)
					break
		for c in COMBOS:
			if (c["a"] == id and owned.has(c["b"])) or (c["b"] == id and owned.has(c["a"])):
				w = Stats.economy.combo_weight if Stats.economy != null else 3
				related = true
		weighted.append({"id": id, "w": w})
		if related:
			hints.append(id)
	var out: Array = []
	# 先把至少一个"能凑组合"的塞进第一格
	if hints.size() > 0:
		var pick: String = hints[SeedManager.randi() % hints.size()]
		out.append(upgrades[pick])
		weighted = weighted.filter(func(e): return e["id"] != pick)
	# 剩余按权重抽
	while out.size() < n and weighted.size() > 0:
		var total := 0
		for e in weighted:
			total += int(e["w"])
		var roll := SeedManager.randi() % maxi(total, 1)
		var acc := 0
		var chosen := 0
		for i in weighted.size():
			acc += int(weighted[i]["w"])
			if roll < acc:
				chosen = i
				break
		out.append(upgrades[weighted[chosen]["id"]])
		weighted.remove_at(chosen)
	return out


## 检查已持有藏品是否触发新的组合，返回新激活的组合名列表
func detect_combos(owned: Array) -> Array:
	var result: Array = []
	for c in COMBOS:
		if owned.has(c["a"]) and owned.has(c["b"]):
			result.append(c["name"])
	return result
