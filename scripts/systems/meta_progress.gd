extends Node
## 局外记录（Autoload）：只记录，不解锁，不做排行榜

const PATH := "user://meta.cfg"
const IDS := ["deepseek", "gpt", "claude"]

var seen_relics: Array = []
var max_floor: int = 0
var total_kills: int = 0
var total_time: float = 0.0
var clears: Dictionary = {"deepseek": 0, "gpt": 0, "claude": 0}
var char_uses: Dictionary = {"deepseek": 0, "gpt": 0, "claude": 0}
var char_best: Dictionary = {"deepseek": 0, "gpt": 0, "claude": 0}
var relic_counts: Dictionary = {}
var floor_by_difficulty: Array = [0, 0, 0]
var challenges_done: int = 0
## 新手引导状态（meta.cfg 的 tutorial 节）：moved / shot / rolled / sub / training_done
## 以及 seen_select_tip / seen_shop_tip / seen_room_hint
var tutorial: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_meta()


func load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	seen_relics = cfg.get_value("collection", "seen", [])
	max_floor = int(cfg.get_value("stats", "max_floor", 0))
	total_kills = int(cfg.get_value("stats", "total_kills", 0))
	total_time = float(cfg.get_value("stats", "total_time", 0.0))
	var c = cfg.get_value("stats", "clears", {})
	if c is Dictionary:
		for k in IDS:
			clears[k] = int(c.get(k, 0))
	var u = cfg.get_value("stats", "char_uses", {})
	if u is Dictionary:
		for k in IDS:
			char_uses[k] = int(u.get(k, 0))
	var b = cfg.get_value("stats", "char_best", {})
	if b is Dictionary:
		for k in IDS:
			char_best[k] = int(b.get(k, 0))
	var rc = cfg.get_value("collection", "relic_counts", {})
	if rc is Dictionary:
		relic_counts = rc
	var fd = cfg.get_value("stats", "floor_by_difficulty", [])
	if fd is Array and fd.size() >= 3:
		floor_by_difficulty = [int(fd[0]), int(fd[1]), int(fd[2])]
	challenges_done = int(cfg.get_value("stats", "challenges_done", 0))
	var tut = cfg.get_value("tutorial", "flags", {})
	if tut is Dictionary:
		tutorial = tut


func save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("collection", "seen", seen_relics)
	cfg.set_value("collection", "relic_counts", relic_counts)
	cfg.set_value("stats", "max_floor", max_floor)
	cfg.set_value("stats", "total_kills", total_kills)
	cfg.set_value("stats", "total_time", total_time)
	cfg.set_value("stats", "clears", clears)
	cfg.set_value("stats", "char_uses", char_uses)
	cfg.set_value("stats", "char_best", char_best)
	cfg.set_value("stats", "floor_by_difficulty", floor_by_difficulty)
	cfg.set_value("stats", "challenges_done", challenges_done)
	cfg.set_value("tutorial", "flags", tutorial)
	cfg.save(PATH)


func see_relic(uid: String) -> void:
	if not seen_relics.has(uid):
		seen_relics.append(uid)
	relic_counts[uid] = int(relic_counts.get(uid, 0)) + 1
	save_meta()


func note_kill(n: int = 1) -> void:
	total_kills += n


func start_run(char_id: String) -> void:
	char_uses[char_id] = int(char_uses.get(char_id, 0)) + 1
	save_meta()


## 结算：返回是否新纪录
func note_challenge() -> void:
	challenges_done += 1
	save_meta()


func finish_run(char_id: String, floor_reached: int, cleared: bool, seconds: float,
		difficulty: int = 1) -> bool:
	total_time += seconds
	var is_record := floor_reached > max_floor
	if is_record:
		max_floor = floor_reached
	if floor_reached > int(char_best.get(char_id, 0)):
		char_best[char_id] = floor_reached
	var di: int = clampi(difficulty, 0, 2)
	if floor_reached > int(floor_by_difficulty[di]):
		floor_by_difficulty[di] = floor_reached
	if cleared:
		clears[char_id] = int(clears.get(char_id, 0)) + 1
	save_meta()
	return is_record


func top_relics(n: int = 3) -> Array:
	var arr: Array = []
	for k in relic_counts.keys():
		arr.append({"id": k, "count": int(relic_counts[k])})
	arr.sort_custom(func(a, b): return a["count"] > b["count"])
	return arr.slice(0, n)


# ---------------- 新手引导 ----------------
func tutorial_flag(key: String) -> bool:
	return bool(tutorial.get(key, false))


func set_tutorial_flag(key: String, value: bool = true) -> void:
	if tutorial_flag(key) == value:
		return
	tutorial[key] = value
	save_meta()


func training_done() -> bool:
	return tutorial_flag("training_done")


func mark_training_done() -> void:
	tutorial["moved"] = true
	tutorial["shot"] = true
	tutorial["rolled"] = true
	tutorial["sub"] = true
	tutorial["training_done"] = true
	save_meta()
