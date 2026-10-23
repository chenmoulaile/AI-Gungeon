extends Node
## 单局挑战（Autoload）：开局从 8 个挑战里抽 1 个（跟种子绑定），事件驱动判定

signal completed(title: String)
signal challenge_changed(title: String, desc: String)

const DIR := "res://resources/challenges"
const IDS := ["no_skill_floor", "no_damage_room", "fast_room", "base_weapon_floor",
	"kill_50", "relic_5", "boss_hp4", "roll_100"]

var current: Challenge = null
var done: bool = false

var _skill_used_floor: bool = false
var _switched_mode: bool = false
var _damaged_room: bool = false
var _room_start: float = 0.0
var _floor_start: float = 0.0
var _rolls: int = 0
var _last_floor: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_run() -> void:
	done = false
	_skill_used_floor = false
	_switched_mode = false
	_damaged_room = false
	_rolls = 0
	_last_floor = 0
	var pool: Array = []
	for id in IDS:
		var p := "%s/%s.tres" % [DIR, id]
		var res = load(p)
		if res != null and String(res.get("id")) != "":
			pool.append(res)
	if pool.is_empty():
		return
	current = SeedManager.pick(pool)
	challenge_changed.emit(current.title, current.desc)


# ---------------- 事件 ----------------
func on_room_start(floor_index: int) -> void:
	_damaged_room = false
	_room_start = Time.get_ticks_msec() / 1000.0
	if floor_index != _last_floor:
		_last_floor = floor_index
		_skill_used_floor = false
		_switched_mode = false


func on_damage() -> void:
	_damaged_room = true


func on_skill() -> void:
	_skill_used_floor = true


func on_mode_switch() -> void:
	_switched_mode = true


func on_roll() -> void:
	_rolls += 1
	if current != null and current.id == "roll_100" and _rolls >= 100:
		_finish()


func on_room_cleared() -> void:
	var dt: float = Time.get_ticks_msec() / 1000.0 - _room_start
	if current == null or done:
		return
	match current.id:
		"no_damage_room":
			if not _damaged_room:
				_finish()
		"fast_room":
			if dt <= 60.0:
				_finish()
		"kill_50":
			if GameState.kills >= 50:
				_finish()
		"relic_5":
			if GameState.upgrades.size() >= 5:
				_finish()


func on_boss_killed(player_hp: int) -> void:
	if current == null or done:
		return
	match current.id:
		"no_skill_floor":
			if not _skill_used_floor:
				_finish()
		"base_weapon_floor":
			if not _switched_mode:
				_finish()
		"boss_hp4":
			if player_hp >= 4:
				_finish()


func _finish() -> void:
	if done:
		return
	done = true
	MetaProgress.note_challenge()
	completed.emit(current.title if current != null else "")
