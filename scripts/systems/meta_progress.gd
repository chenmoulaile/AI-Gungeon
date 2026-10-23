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
	var c = cfg.get_value("stats", "clears", null)
	if c is Dictionary:
		for k in IDS:
			clears[k] = int(c.get(k, 0))
	var u = cfg.get_value("stats", "char_uses", null)
	if u is Dictionary:
		for k in IDS:
			char_uses[k] = int(u.get(k, 0))
	var b = cfg.get_value("stats", "char_best", null)
	if b is Dictionary:
		for k in IDS:
			char_best[k] = int(b.get(k, 0))
	var rc = cfg.get_value("collection", "relic_counts", null)
	if rc is Dictionary:
		relic_counts = rc


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
func finish_run(char_id: String, floor_reached: int, cleared: bool, seconds: float) -> bool:
	total_time += seconds
	var is_record := floor_reached > max_floor
	if is_record:
		max_floor = floor_reached
	if floor_reached > int(char_best.get(char_id, 0)):
		char_best[char_id] = floor_reached
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
