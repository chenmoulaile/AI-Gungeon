extends Control
## 训练场分步引导（非模态，不暂停）：移动 -> 射击 -> 翻滚 -> 副武器
## 每一步只显示一条提示，完成当前步骤才显示下一步；状态写入 meta.cfg 的 tutorial 节

const TargetScript = preload("res://scripts/fx/training_target.gd")
const ShooterScene = preload("res://scenes/enemies/enemy_shooter.tscn")

var player = null
var host = null
var step: int = 0
var _start_pos: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _target = null
var _enemy = null
var _done_pop: float = 0.0

const HINTS := [
	["WASD 移动", "先走两步，熟悉手感"],
	["鼠标瞄准 · 左键射击", "打爆前面的靶子"],
	["空格翻滚", "翻滚期间可以穿过子弹"],
	["Q 专属副武器", "试试角色专属的那把武器"],
]


func setup(p: Node, host_node: Node) -> void:
	player = p
	host = host_node
	_start_pos = p.global_position if p != null else Vector2.ZERO
	if MetaProgress.tutorial_flag("moved"):
		step = 1
	if MetaProgress.tutorial_flag("shot"):
		step = 2
	if MetaProgress.tutorial_flag("rolled"):
		step = 3
	if MetaProgress.tutorial_flag("sub"):
		step = 4
	_enter_step()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	_done_pop = maxf(0.0, _done_pop - delta)
	if player == null or not is_instance_valid(player):
		return
	match step:
		0:
			if player.global_position.distance_to(_start_pos) > 40.0:
				MetaProgress.set_tutorial_flag("moved")
				_advance()
		1:
			if player.fire_anim > 0.0 or Input.is_action_pressed("shoot"):
				MetaProgress.set_tutorial_flag("shot")
				_advance()
		2:
			if Input.is_action_just_pressed("roll"):
				MetaProgress.set_tutorial_flag("rolled")
				_advance()
		3:
			if Input.is_action_just_pressed("sub_weapon"):
				MetaProgress.set_tutorial_flag("sub")
				_advance()
	queue_redraw()


func _advance() -> void:
	step += 1
	_done_pop = 0.5
	Sfx.play("relic", -6.0, 1.4)
	if step >= 4:
		MetaProgress.mark_training_done()
	_enter_step()


func _enter_step() -> void:
	if step == 1 and _target == null and host != null and is_instance_valid(host):
		_target = TargetScript.new()
		_target.position = Vector2(GameConfig.ROOM_W * 0.62, GameConfig.ROOM_H * 0.42)
		host.add_child(_target)
	elif step == 3 and _enemy == null and host != null and is_instance_valid(host):
		_enemy = ShooterScene.instantiate()
		_enemy.position = Vector2(GameConfig.ROOM_W * 0.78, GameConfig.ROOM_H * 0.62)
		host.add_child(_enemy)


func _draw() -> void:
	if step >= HINTS.size():
		if _done_pop > 0.0:
			UiKit.text_center(self, GameConfig.BASE_W * 0.5, GameConfig.BASE_H * 0.5,
				"训练完成 · 按 ESC 返回", UiKit.F_H3,
				Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, _done_pop * 2.0))
		return
	var hint: Array = HINTS[step]
	var cx := GameConfig.BASE_W * 0.5
	var cy := GameConfig.BASE_H - 78.0
	var w := 190.0
	var r := Rect2(cx - w * 0.5, cy - 22, w, 34)
	draw_style_box(UiKit.box(Color(1, 1, 1, 0.90), 10, Color(1, 1, 1, 0.9), 1, true), r)
	UiKit.text_center(self, cx, cy - 6, String(hint[0]), UiKit.F_H3, UiKit.TEXT)
	UiKit.text_center(self, cx, cy + 6, String(hint[1]), UiKit.F_TINY, UiKit.TEXT_DIM)
	# 步骤点
	for i in 4:
		var c := Vector2(cx - 21 + i * 14, cy + 20)
		draw_circle(c, 2.6, UiKit.ACCENT if i <= step else Color(1, 1, 1, 0.5))
