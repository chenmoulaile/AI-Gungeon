extends Node
## 中断续玩（Autoload）：进房/拿藏品/买藏品/血量变化 >1 时自动存盘

const PATH := "user://run_save.cfg"

var _last_hp: int = -1
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func has_save() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return false
	return bool(cfg.get_value("run", "active", false))


func clear() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "active", false)
	cfg.save(PATH)
	_last_hp = -1


func save_run() -> void:
	if _busy or GameState.char_data == null:
		return
	_busy = true
	var cfg := ConfigFile.new()
	cfg.set_value("run", "active", true)
	cfg.set_value("run", "seed", SeedManager.seed_string)
	cfg.set_value("run", "difficulty", SeedManager.difficulty)
	cfg.set_value("run", "char", GameState.char_id)
	cfg.set_value("run", "floor", GameState.floor_index)
	cfg.set_value("run", "room", GameState.room_index)
	cfg.set_value("run", "hp", GameState.hp)
	cfg.set_value("run", "coins", GameState.coins)
	cfg.set_value("run", "kills", GameState.kills)
	cfg.set_value("run", "time", GameState.run_time)
	cfg.set_value("run", "upgrades", GameState.upgrades)
	cfg.set_value("run", "combos", GameState.combos)
	var mode := 0
	if GameState.player != null and is_instance_valid(GameState.player):
		var w = GameState.player.weapon
		if w != null and "mode" in w:
			mode = int(w.mode)
	cfg.set_value("run", "weapon_mode", mode)
	cfg.set_value("run", "challenge", ChallengeManager.current.id
		if ChallengeManager.current != null else "")
	cfg.save(PATH)
	_last_hp = GameState.hp
	_busy = false


func note_hp(hp: int) -> void:
	if _last_hp < 0:
		_last_hp = hp
		return
	if absi(hp - _last_hp) >= 2:
		save_run()


func load_run() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return {}
	if not bool(cfg.get_value("run", "active", false)):
		return {}
	return {
		"seed": String(cfg.get_value("run", "seed", "")),
		"difficulty": int(cfg.get_value("run", "difficulty", 1)),
		"char": String(cfg.get_value("run", "char", "deepseek")),
		"floor": int(cfg.get_value("run", "floor", 1)),
		"room": int(cfg.get_value("run", "room", 1)),
		"hp": int(cfg.get_value("run", "hp", 6)),
		"coins": int(cfg.get_value("run", "coins", 0)),
		"kills": int(cfg.get_value("run", "kills", 0)),
		"time": float(cfg.get_value("run", "time", 0.0)),
		"upgrades": cfg.get_value("run", "upgrades", []),
		"combos": cfg.get_value("run", "combos", []),
		"weapon_mode": int(cfg.get_value("run", "weapon_mode", 0)),
		"challenge": String(cfg.get_value("run", "challenge", "")),
	}
