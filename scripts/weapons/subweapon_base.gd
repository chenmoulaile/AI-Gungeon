extends Node2D
## 专属副武器基类：每个角色一把，只能由对应角色使用
## 冷却统一走 cd_left / cd_total，HUD 右下角画环形进度

var player = null
var char_id: String = ""
var display_name: String = "副武器"
var key_label: String = "滚轮"
var cd_total: float = 4.0
var cd_left: float = 0.0
var color: Color = Color("#7fb2ff")
## 是否处于当前手持槽（滚轮切到副武器时为 true）
var active: bool = false
## HUD 图标路径（留空则回退到角色武器图标）
var icon_path: String = ""


func setup(p: Node) -> void:
	player = p
	char_id = String(p.char_id)
	_configure()


## 子类设置数值
func _configure() -> void:
	pass


## 滚轮切换时由玩家调用
func set_active(v: bool) -> void:
	active = v
	queue_redraw()


func _process(delta: float) -> void:
	cd_left = maxf(0.0, cd_left - delta)


func ready() -> bool:
	return cd_left <= 0.0 and player != null and is_instance_valid(player) and player.alive


func ratio() -> float:
	return 1.0 - clampf(cd_left / maxf(cd_total, 0.01), 0.0, 1.0)


## 每帧由玩家调用（副武器槽内：左键按下触发）
func handle_input(_delta: float) -> void:
	if not active:
		return
	if InputBuffer.consume("shoot") or Input.is_action_just_pressed("shoot"):
		try_use()


func try_use() -> bool:
	if not ready():
		return false
	if not _use():
		return false
	ChallengeManager.on_skill()
	return true


func _use() -> bool:
	return false


## 藏品钩子：本角色专属藏品会缩短冷却（每件 -8%，最多 -24%）
func relic_cd_mult() -> float:
	var n := 0
	for uid in GameState.upgrades:
		if String(uid).begins_with(_relic_prefix()):
			n += 1
	return 1.0 - 0.08 * float(mini(n, 3))


func _relic_prefix() -> String:
	match char_id:
		"deepseek":
			return "ds_"
		"gpt":
			return "gpt_"
		_:
			return "cl_"


func start_cd(base: float) -> void:
	cd_total = base
	cd_left = base * relic_cd_mult()


## 最近的敌人（可限定范围）
func nearest_enemy(max_dist: float = 9999.0, exclude: Array = []) -> Node:
	var best = null
	var bd := max_dist
	for e in GameState.enemies:
		if not is_instance_valid(e) or e.dead or exclude.has(e):
			continue
		var d: float = player.global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best
