extends Node
## 种子（Autoload）：全局唯一 RNG，所有随机都走这里，保证同种子同结果

const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var rng := RandomNumberGenerator.new()
var seed_string: String = ""
var difficulty: int = 1          # 0 简单 / 1 普通 / 2 困难

const DIFFICULTY_NAME := ["简单", "普通", "困难"]
## 血量 / 伤害 / 弹速 / 金币 / 额外波次
const DIFFICULTY_PARAMS := [
	{"hp": 0.8, "dmg": 0.7, "bullet": 0.85, "coin": 1.2, "wave": 0},
	{"hp": 1.0, "dmg": 1.0, "bullet": 1.0, "coin": 1.0, "wave": 0},
	{"hp": 1.25, "dmg": 1.3, "bullet": 1.15, "coin": 0.9, "wave": 1},
]


func _ready() -> void:
	rng.randomize()


func start_run(seed_text: String = "") -> String:
	var t := seed_text.strip_edges().to_upper()
	if t != "":
		seed_string = t
	else:
		seed_string = random_seed_string()
	rng.seed = hash(seed_string)
	return seed_string


func random_seed_string() -> String:
	var out := ""
	for i in 6:
		out += CHARS[rng.randi() % CHARS.length()]
	return out


func set_difficulty(d: int) -> void:
	difficulty = clampi(d, 0, 2)
	Settings.difficulty = difficulty
	Settings.save_settings()


func diff(key: String) -> float:
	var d: DifficultyConfig = Stats.difficulty if Stats != null else null
	if d != null:
		var arr: Array = []
		match key:
			"hp":
				arr = d.hp_mult
			"dmg":
				arr = d.dmg_mult
			"bullet":
				arr = d.bullet_mult
			"coin":
				arr = d.coin_mult
			"wave":
				arr = d.extra_waves
		if arr.size() > difficulty:
			return float(arr[difficulty])
	return float(DIFFICULTY_PARAMS[difficulty].get(key, 1.0))


func difficulty_name() -> String:
	return DIFFICULTY_NAME[difficulty]


# ---------------- 统一随机接口 ----------------
func randf() -> float:
	return rng.randf()


func randf_range(a: float, b: float) -> float:
	return rng.randf_range(a, b)


func randi() -> int:
	return rng.randi()


func randi_range(a: int, b: int) -> int:
	return rng.randi_range(a, b)


func pick(arr: Array):
	if arr.is_empty():
		return null
	return arr[rng.randi() % arr.size()]


func shuffle(arr: Array) -> Array:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr


func copy_seed() -> void:
	DisplayServer.clipboard_set(seed_string)
