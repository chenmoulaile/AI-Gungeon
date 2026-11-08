extends "res://scripts/weapons/weapon_base.gd"
## Claude 初始武器「法典之书」
## 按住左键：从书本前方射出持续光束，1s 内宽度 3→13、伤害同步提升；松开进入短冷却

const BeamScript = preload("res://scripts/weapons/beam.gd")
## 参考图导出的像素法典（棕革封面 + 橙色向日葵 + 金流苏），32×32 三帧
const TEX := "res://assets/weapons/claude_starter.png"
const GROW := 1.0
const MIN_DPS := 26.0
const MAX_DPS := 78.0

var beam: Node = null
var grow: float = 0.0
var _page_t: float = 0.0
var _release_cd: float = 0.0


func setup(p: Node) -> void:
	super.setup(p)
	mode_name = "法典之书"
	# 直接用参考图的像素法典贴图，和角色/其它武器保持同一像素风
	p.set_held(TEX, 0.0, Color.WHITE, "", Color("#FFB066"), 34.0)


func fire(_dir: Vector2) -> void:
	# 光束在 _process 里持续更新，这里只占位，避免基类兜底弹
	cooldown = 0.05


func _process(delta: float) -> void:
	super._process(delta)
	if player == null or not is_instance_valid(player) or not player.alive:
		_stop()
		return
	_release_cd = maxf(0.0, _release_cd - delta)
	# 必须尊重开局输入锁与武器槽：否则选完角色那一下点击会直接喷光束
	var holding: bool = Input.is_action_pressed("shoot") and not get_tree().paused \
		and player.input_lock <= 0.0 and player.active_slot == 0
	if holding and _release_cd <= 0.0:
		if beam == null or not is_instance_valid(beam):
			beam = BeamScript.new()
			beam.instant = false
			beam.color = Color("#ffb066")
			beam.tick_interval = 0.1
			_bullet_root().add_child(beam)
		grow = minf(GROW, grow + delta)
		var ratio: float = grow / GROW
		beam.length = 520.0
		beam.width = lerpf(3.0, 13.0, ratio)
		beam.dps = lerpf(MIN_DPS, MAX_DPS, ratio) * damage_mult()
		var origin: Vector2 = player.global_position + Vector2(0, -16) + player.aim * 10.0
		if player.gun != null and is_instance_valid(player.gun):
			origin = player.gun.to_global(player.gun.muzzle_local())
		beam.set_beam(origin, player.aim)
		GameState.drain_quota(GameState.model_quota_cost() * delta)
		player.fire_anim = 0.1
		# 角色周围漂浮的发光书页
		_page_t -= delta
		if _page_t <= 0.0:
			_page_t = 0.18
			var ang := randf() * TAU
			var pos: Vector2 = origin + Vector2(cos(ang), sin(ang)) * randf_range(14.0, 26.0)
			GameFeel.burst(pos, Color(1.0, 0.92, 0.72), 2, 20.0, 0.4)
	elif beam != null:
		_stop()
		_release_cd = 0.45


func _stop() -> void:
	if beam != null and is_instance_valid(beam):
		beam.queue_free()
	beam = null
	grow = 0.0


# ---------------- 技能「宪法规避」：护盾 ----------------
func use_skill() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	player.shield_hits = 6
	player.shield_t = 3.0
	for i in 6:
		var ang := TAU * float(i) / 6.0 - PI / 2.0
		GameFeel.burst(player.global_position + Vector2(0, -14)
			+ Vector2(cos(ang), sin(ang)) * 26.0, Color(1.0, 0.88, 0.55), 2, 34.0, 0.28)
	Sfx.play("skill")
	return true
