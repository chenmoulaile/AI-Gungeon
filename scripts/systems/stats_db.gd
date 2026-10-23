extends Node
## 数值资源库（Autoload）：所有策划数值都从这里读，脚本里只留逻辑

const CHAR_IDS := ["deepseek", "gpt", "claude"]
const WEAPON_IDS := ["reasoning_chain", "multimodal", "long_context"]
const ENEMY_IDS := ["chaser", "shooter", "spreader", "charger", "ring_shooter",
	"summoner", "shield_bearer", "splitter", "sniper"]
const RELIC_IDS := ["ds_homing_split", "ds_burn_zone", "gpt_echo_clone",
	"gpt_voice_haste", "cl_break_burst", "cl_overload"]

var chars: Dictionary = {}
var weapons: Dictionary = {}
var enemies: Dictionary = {}
var relics: Array = []
var economy: EconomyConfig = null
var difficulty: DifficultyConfig = null


func _ready() -> void:
	for id in CHAR_IDS:
		var r = load("res://resources/stats/characters/%s.tres" % id)
		if r != null:
			chars[id] = r
	for id in WEAPON_IDS:
		var r = load("res://resources/stats/weapons/%s.tres" % id)
		if r != null:
			weapons[id] = r
	for id in ENEMY_IDS:
		var r = load("res://resources/stats/enemies/%s.tres" % id)
		if r != null:
			enemies[id] = r
	for id in RELIC_IDS:
		var r = load("res://resources/relics/%s.tres" % id)
		if r != null:
			relics.append(r)
	economy = load("res://resources/stats/economy.tres")
	difficulty = load("res://resources/stats/difficulty.tres")


func char(id: String) -> CharacterStats:
	return chars.get(id, null)


func weapon(id: String) -> WeaponStats:
	return weapons.get(id, null)


func enemy(id: String) -> EnemyStats:
	return enemies.get(id, null)


func coin_mult() -> float:
	return float(difficulty.coin_mult[SeedManager.difficulty])
