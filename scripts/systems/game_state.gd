extends Node
## 单局运行状态（autoload）：角色、生命、金币、藏品、统计与数值结算

signal coins_changed(value: int)
signal hp_changed(hp: int, max_hp: int)
signal upgrades_changed()
signal combo_activated(combo_name: String)
signal synergy_activated(synergy_name: String)
signal low_health_triggered
signal run_ended()
signal ai_state_changed()
signal ai_depleted_changed(depleted: bool)

const PLAYER_MAX_HP := 100

## ---------------- 额度系统（GPT / Claude） ----------------
## 参考真实订阅：免费档滚动 5h 窗口额度、Plus/Pro 依次扩容并缩短重置，
## 额度耗尽后全面降级；额度重置卡可立即跳过等待。
const GPT_PLANS := [
	{"name": "FREE", "cap": 120.0, "reset": 180.0, "price": 0},
	{"name": "PLUS", "cap": 300.0, "reset": 150.0, "price": 70},
	{"name": "PRO", "cap": 600.0, "reset": 110.0, "price": 180},
]
const GPT_MODES := [
	{"name": "LUNA", "cn": "轻量", "plan": 0, "dmg": 1.0, "rate": 1.06,
		"bullet": 1.0, "move": 1.0, "cost": 0.12},
	{"name": "SOL", "cn": "标准", "plan": 1, "dmg": 1.35, "rate": 1.0,
		"bullet": 1.05, "move": 1.0, "cost": 0.24},
	{"name": "ASTRA", "cn": "深度", "plan": 2, "dmg": 1.85, "rate": 0.90,
		"bullet": 1.10, "move": 1.0, "cost": 0.45},
]
const CLAUDE_PLANS := [
	{"name": "FREE", "cap": 120.0, "reset": 180.0, "price": 0},
	{"name": "PRO", "cap": 300.0, "reset": 150.0, "price": 80},
	{"name": "MAX 5X", "cap": 450.0, "reset": 120.0, "price": 200},
	{"name": "MAX 20X", "cap": 700.0, "reset": 90.0, "price": 420},
]
const CLAUDE_MODES := [
	{"name": "SONNET", "cn": "均衡", "plan": 0, "dmg": 1.0, "rate": 1.0,
		"bullet": 1.0, "move": 1.0, "cost": 0.55},
	{"name": "OPUS", "cn": "深度", "plan": 1, "dmg": 1.55, "rate": 0.95,
		"bullet": 1.0, "move": 1.0, "cost": 1.15},
]
## 额度耗尽惩罚：伤害/射速/弹速/移速全面下滑
const DEPLETED_DMG := 0.45
const DEPLETED_RATE := 0.60
const DEPLETED_BULLET := 0.75
const DEPLETED_MOVE := 0.55
const RESET_CARD_PRICE := 45
const RESET_CARD_MAX := 3

var char_id: String = "deepseek"
var char_data: CharacterData = null

var hp: int = PLAYER_MAX_HP
var max_hp: int = PLAYER_MAX_HP
var coins: int = 0
var floor_index: int = 1
var room_index: int = 1
## 当前层的分支地图与所在节点（v0.10）
var floor_map: FloorMap = null
var node_id: int = 0
## 已走过的节点（HUD 小地图用；存档不保存，续玩从当前节点重新记录）
var visited_nodes: Array = []
var kills: int = 0
var run_time: float = 0.0
var coins_earned: int = 0
var run_cleared: bool = false
## 专武解锁进度（局内）
var excl_kills: int = 0
var excl_max_coins: int = 0
var floor_clean: bool = true
var excl_clean_floor: bool = false
var exclusive_equipped: bool = false
var training: bool = false

## 额度系统运行状态（仅 GPT / Claude 使用）
var ai_plan: int = 0
var ai_mode: int = 0
var ai_quota: float = 120.0
var ai_reset_t: float = 180.0
var ai_reset_cards: int = 1
var ai_depleted: bool = false

var upgrades: Array = []      # 已持有藏品 id
var combos: Array = []        # 已激活组合名
var synergies: Array = []     # 已激活的跨角色协同
var mods: Dictionary = {}     # 藏品/协同算出的运行时修正（钩子读取）
var stats: Dictionary = {}

# 场景内引用（由 game.gd / player.gd 维护）
var player: Node2D = null
var bullets_root: Node2D = null
var enemies: Array = []
var obstacles: Array = []   # Rect2：挡子弹、挡移动
var crates: Array = []      # 可破坏木箱节点


func _ready() -> void:
	recalc_stats()


func _process(delta: float) -> void:
	if player != null and is_instance_valid(player) and player.alive:
		run_time += delta
		_tick_ai_quota(delta)


func start_run(id: String, seed_text: String = "") -> void:
	char_id = id
	SeedManager.start_run(seed_text)
	ChallengeManager.start_run()
	char_data = load_character(id)
	hp = PLAYER_MAX_HP
	max_hp = PLAYER_MAX_HP
	coins = 0
	floor_index = 1
	room_index = 1
	node_id = 0
	floor_map = FloorMap.generate(1, SeedManager.seed_string)
	visited_nodes = [0]
	kills = 0
	run_time = 0.0
	upgrades = []
	combos = []
	synergies = []
	enemies = []
	obstacles = []
	crates = []
	player = null
	recalc_stats()
	hp = max_hp
	coins_earned = 0
	run_time = 0.0
	run_cleared = false
	excl_kills = 0
	excl_max_coins = 0
	floor_clean = true
	excl_clean_floor = false
	exclusive_equipped = false
	_reset_ai_quota()
	MetaProgress.start_run(id)
	coins_changed.emit(coins)
	hp_changed.emit(hp, max_hp)
	upgrades_changed.emit()


## 从存档恢复（不重新抽种子/挑战）
func restore_run(d: Dictionary) -> void:
	char_id = String(d.get("char", "deepseek"))
	char_data = load_character(char_id)
	SeedManager.difficulty = int(d.get("difficulty", 1))
	SeedManager.seed_string = String(d.get("seed", ""))
	SeedManager.rng.seed = hash(SeedManager.seed_string)
	floor_index = int(d.get("floor", 1))
	room_index = int(d.get("room", 1))
	# 地图由种子确定性重建；room 存档是 1 基显示序号，节点是 0 基
	floor_map = FloorMap.generate(floor_index, SeedManager.seed_string)
	node_id = clampi(room_index - 1, FloorMap.START_ID, FloorMap.BOSS_ID)
	room_index = node_id + 1
	visited_nodes = [node_id]
	coins = int(d.get("coins", 0))
	kills = int(d.get("kills", 0))
	run_time = float(d.get("time", 0.0))
	upgrades = d.get("upgrades", []).duplicate()
	combos = d.get("combos", []).duplicate()
	ai_plan = int(d.get("ai_plan", 0))
	ai_mode = clampi(int(d.get("ai_mode", 0)), 0, max_mode_index())
	ai_quota = float(d.get("ai_quota", -1.0))
	ai_reset_t = float(d.get("ai_reset_t", -1.0))
	if ai_quota < 0.0:
		ai_quota = quota_cap() if has_quota_system() else 0.0
	if ai_reset_t < 0.0:
		ai_reset_t = plan_reset()
	ai_reset_cards = int(d.get("ai_reset_cards", 1))
	ai_depleted = false
	recalc_stats()
	hp = clampi(int(d.get("hp", max_hp)), 1, max_hp)
	run_cleared = false
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
	_recalc_mods()
	max_hp = PLAYER_MAX_HP + int(s["max_hp_bonus"])
	if hp > max_hp:
		hp = max_hp


## 藏品钩子：把"藏品 + 角色"的协同翻译成运行时修正，武器只查表，不写 if 链
func _recalc_mods() -> void:
	var m := {
		"split_inherit_pierce": false,
		"roll_shot_bonus": 0.0,
		"low_hp_damage": 0.0,
		"room_clear_heal": 0,
		"voice_kill_cd": 0.0,
		"shield_counter": false,
		"split_homing": false,
		"beam_burn": false,
		"echo_clone": false,
		"voice_haste": false,
		"shield_break_burst": false,
		"beam_overload": false,
		"focus_crit_at": 0,
		"streak_rate": 0.0,
		"roll_speed": 0.0,
		"first_hit_crit": false,
		"specialty": "",
	}
	if char_id == "deepseek" and upgrades.has("split_prism"):
		m["split_inherit_pierce"] = true
	if char_id == "gpt" and upgrades.has("cool_module"):
		m["voice_kill_cd"] = 1.5
	if char_id == "claude" and upgrades.has("piercing_nail"):
		m["shield_counter"] = true
	if upgrades.has("roll_core"):
		m["roll_shot_bonus"] = 0.6
	if upgrades.has("extra_heart"):
		m["low_hp_damage"] = 0.25
	if upgrades.has("scholar_page"):
		m["room_clear_heal"] = 1
	# 质变型藏品：钩子参数来自 resources/relics/*.tres
	for rs in Stats.relics:
		var r: RelicStats = rs
		if r != null and upgrades.has(r.id) and m.has(r.trigger):
			m[r.trigger] = true if r.value >= 1.0 else r.value
	# 由数值改为条件触发的四件
	if upgrades.has("sharp_round"):
		m["focus_crit_at"] = 3
	if upgrades.has("rapid_cycle"):
		m["streak_rate"] = 0.35
	if upgrades.has("feather_boots"):
		m["roll_speed"] = 0.30
	if upgrades.has("crit_lens"):
		m["first_hit_crit"] = true
	# 专精：同一角色两件专属藏品
	for cid in ["deepseek", "gpt", "claude"]:
		var owned := 0
		for uid in upgrades:
			var up: Upgrade = UpgradeDB.get_upgrade(uid)
			if up != null and up.char_tag == cid:
				owned += 1
		if owned >= 2 and char_id == cid:
			m["specialty"] = cid
	mods = m

	var found: Array = []
	if m["split_inherit_pierce"]:
		found.append("裂开的推理也会穿透")
	if m["voice_kill_cd"] > 0.0:
		found.append("说出口的话会自己找上下一句")
	if m["shield_counter"]:
		found.append("被挡住的东西会原路返回")
	if m["roll_shot_bonus"] > 0.0:
		found.append("翻滚之后的第一枪格外准")
	if m["low_hp_damage"] > 0.0:
		found.append("越接近极限越不肯放手")
	if m["room_clear_heal"] > 0:
		found.append("读完这一页就休息一下")
	for name in found:
		if not synergies.has(name):
			synergies.append(name)
			synergy_activated.emit(name)


func mod_value(key: String, default_value = 0.0):
	return mods.get(key, default_value)


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
	MetaProgress.see_relic(uid)
	RunSave.save_run()
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
	coins_earned += n
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


func on_enemy_killed(tag: String = "") -> void:
	kills += 1
	MetaProgress.note_kill()
	# GPT 协同：语音击杀后短时间射速提升
	if tag == "voice" and upgrades.has("gpt_voice_haste"):
		if player != null and is_instance_valid(player):
			player.add_buff("fire_rate", 0.3, 3.0)
	# GPT 协同：语音冲击波击杀缩短「涌现」冷却
	if tag == "voice" and float(mods.get("voice_kill_cd", 0.0)) > 0.0:
		if player != null and is_instance_valid(player) and player.weapon != null:
			player.weapon.skill_cd_left = maxf(0.0,
				float(player.weapon.skill_cd_left) - float(mods["voice_kill_cd"]))
	var every := int(stat("lifesteal_every", 0))
	if every > 0 and kills % every == 0:
		heal(10)


func enemy_scale() -> float:
	# v0.10：1.2 幂 × 线性项，并封顶 6 倍（无限层不再指数爆炸）
	var f := float(floor_index - 1)
	return minf(6.0, pow(1.2, f) * (1.0 + 0.05 * f))


## 层末存款利息：每 50 金币 +5，单层封顶 15（鼓励留钱）
func floor_interest() -> int:
	return mini(15, (coins / 50) * 5)


## 保证当前层地图存在（续玩/调试/章节跳转都走这里）
func ensure_map() -> FloorMap:
	if floor_map == null or floor_map.floor_index != floor_index:
		floor_map = FloorMap.generate(floor_index, SeedManager.seed_string)
		node_id = FloorMap.START_ID
		room_index = node_id + 1
	return floor_map


## 专武是否已达成解锁条件
func exclusive_ready() -> bool:
	match char_id:
		"deepseek":
			return excl_kills >= 30
		"gpt":
			return excl_max_coins >= 50
		"claude":
			return excl_clean_floor
	return false


## HUD 进度文本
func exclusive_progress() -> String:
	match char_id:
		"deepseek":
			return "击杀 %d/30" % mini(excl_kills, 30)
		"gpt":
			return "金币 %d/50" % mini(excl_max_coins, 50)
		"claude":
			return "无伤过层 %s" % ("达成" if excl_clean_floor else "未达成")
	return ""


func exclusive_ratio() -> float:
	match char_id:
		"deepseek":
			return clampf(float(excl_kills) / 30.0, 0.0, 1.0)
		"gpt":
			return clampf(float(excl_max_coins) / 50.0, 0.0, 1.0)
		"claude":
			return 1.0 if excl_clean_floor else 0.0
	return 0.0


# ---------------- 额度系统（GPT / Claude） ----------------
func has_quota_system() -> bool:
	return char_id == "gpt" or char_id == "claude"


func _plan_table() -> Array:
	return GPT_PLANS if char_id == "gpt" else CLAUDE_PLANS


func _mode_table() -> Array:
	return GPT_MODES if char_id == "gpt" else CLAUDE_MODES


func plan_name() -> String:
	var t := _plan_table()
	return String(t[clampi(ai_plan, 0, t.size() - 1)]["name"])


func mode_name() -> String:
	var t := _mode_table()
	return String(t[clampi(ai_mode, 0, t.size() - 1)]["name"])


func mode_cn() -> String:
	var t := _mode_table()
	return String(t[clampi(ai_mode, 0, t.size() - 1)]["cn"])


## HUD 用：FREE · LUNA / MAX 5X · OPUS
func model_label() -> String:
	return "%s · %s" % [plan_name(), mode_name()]


func quota_cap() -> float:
	var t := _plan_table()
	return float(t[clampi(ai_plan, 0, t.size() - 1)]["cap"])


func plan_reset() -> float:
	var t := _plan_table()
	return float(t[clampi(ai_plan, 0, t.size() - 1)]["reset"])


func reset_left() -> float:
	return maxf(0.0, ai_reset_t)


func next_plan_name() -> String:
	var t := _plan_table()
	if ai_plan >= t.size() - 1:
		return ""
	return String(t[ai_plan + 1]["name"])


func next_plan_price() -> int:
	var t := _plan_table()
	if ai_plan >= t.size() - 1:
		return -1
	return int(t[ai_plan + 1]["price"])


func max_mode_index() -> int:
	var t := _mode_table()
	var m := 0
	for i in t.size():
		if ai_plan >= int(t[i]["plan"]):
			m = i
	return m


func _mode_data() -> Dictionary:
	var t := _mode_table()
	return t[clampi(ai_mode, 0, t.size() - 1)]


func model_damage_mult() -> float:
	if not has_quota_system():
		return 1.0
	var v := float(_mode_data().get("dmg", 1.0))
	return v * (DEPLETED_DMG if ai_depleted else 1.0)


func model_rate_mult() -> float:
	if not has_quota_system():
		return 1.0
	var v := float(_mode_data().get("rate", 1.0))
	return v * (DEPLETED_RATE if ai_depleted else 1.0)


func model_bullet_mult() -> float:
	if not has_quota_system():
		return 1.0
	var v := float(_mode_data().get("bullet", 1.0))
	return v * (DEPLETED_BULLET if ai_depleted else 1.0)


func model_move_mult() -> float:
	if not has_quota_system():
		return 1.0
	var v := float(_mode_data().get("move", 1.0))
	return v * (DEPLETED_MOVE if ai_depleted else 1.0)


func model_quota_cost() -> float:
	if not has_quota_system():
		return 0.0
	return float(_mode_data().get("cost", 0.0))


func _reset_ai_quota() -> void:
	ai_plan = 0
	ai_mode = 0
	ai_reset_cards = 1
	ai_depleted = false
	ai_quota = quota_cap() if has_quota_system() else 0.0
	ai_reset_t = plan_reset()
	ai_state_changed.emit()


func _refill_quota() -> void:
	ai_quota = quota_cap()
	ai_reset_t = plan_reset()
	if ai_depleted:
		ai_depleted = false
		ai_depleted_changed.emit(false)
	ai_state_changed.emit()


func _tick_ai_quota(delta: float) -> void:
	if not has_quota_system() or training:
		return
	ai_reset_t = maxf(0.0, ai_reset_t - delta)
	if ai_reset_t <= 0.0:
		_refill_quota()


## 每发子弹扣额度；耗尽只降级，不阻止开火
func spend_quota(amount: float) -> void:
	drain_quota(amount)


func drain_quota(amount: float) -> void:
	if not has_quota_system() or amount <= 0.0:
		return
	ai_quota = maxf(0.0, ai_quota - amount)
	if ai_quota <= 0.0 and not ai_depleted:
		ai_depleted = true
		ai_depleted_changed.emit(true)
	ai_state_changed.emit()


## R：在已解锁模型间循环；免费档只有 Luna / Sonnet
func cycle_model_mode() -> String:
	if not has_quota_system():
		return "本角色没有模型额度"
	var max_i := max_mode_index()
	if max_i <= 0:
		var need := next_plan_name()
		return "升级到 %s 解锁更多模型" % need if need != "" else "已到最高档"
	ai_mode += 1
	if ai_mode > max_i:
		ai_mode = 0
	ai_state_changed.emit()
	return "模型切换：%s（%s）" % [mode_name(), mode_cn()]


## 商店 P：按顺序升级套餐，补满额度并缩短重置时间
func upgrade_plan() -> bool:
	if not has_quota_system():
		return false
	var price := next_plan_price()
	if price < 0 or coins < price:
		return false
	coins -= price
	coins_changed.emit(coins)
	ai_plan += 1
	ai_mode = mini(ai_mode, max_mode_index())
	ai_quota = quota_cap()
	ai_reset_t = plan_reset()
	if ai_depleted:
		ai_depleted = false
		ai_depleted_changed.emit(false)
	ai_state_changed.emit()
	RunSave.save_run()
	return true


func can_buy_reset_card() -> bool:
	return has_quota_system() and ai_reset_cards < RESET_CARD_MAX \
		and coins >= RESET_CARD_PRICE


## 商店 K：购买额度重置卡（上限 3 张）
func buy_reset_card() -> bool:
	if not can_buy_reset_card():
		return false
	coins -= RESET_CARD_PRICE
	coins_changed.emit(coins)
	ai_reset_cards += 1
	ai_state_changed.emit()
	RunSave.save_run()
	return true


## T：跳过重置等待，立即回满额度
func use_quota_reset_card() -> bool:
	if not has_quota_system():
		return false
	if ai_reset_cards <= 0:
		return false
	if ai_quota >= quota_cap() and not ai_depleted:
		return false
	ai_reset_cards -= 1
	_refill_quota()
	RunSave.save_run()
	return true
