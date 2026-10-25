extends Control
## 训练场分步引导（v0.7 P2 像素版）：键帽/文字 + 4 格进度方块
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
	["滚轮切换副武器", "滚一下滚轮，切到角色专属那把武器"],
]


func setup(p: Node, host_node: Node, target: Node = null, enemy: Node = null) -> void:
	player = p
	host = host_node
	# 训练场已经常驻靶和敌人时直接复用，不再额外生成
	_target = target
	_enemy = enemy
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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


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
			if Input.is_action_just_pressed("switch_weapon"):
				MetaProgress.set_tutorial_flag("sub")
				_advance()
	queue_redraw()


func _advance() -> void:
	step += 1
	_done_pop = 0.6
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
			var r := Rect2(220, 150, 200, 44)
			UiKit.frame(self, r, UiKit.DEEP, UiKit.BORDER, UiKit.SUCCESS, true)
			UiKit.text_center(self, r.get_center().x, r.position.y + 20, "训练完成",
				UiKit.F_BODY, UiKit.SUCCESS)
			UiKit.text_center(self, r.get_center().x, r.position.y + 36, "ESC 打开菜单",
				UiKit.F_SMALL, UiKit.TEXT_DIM)
		return
	var hint: Array = HINTS[step]
	var cx := GameConfig.BASE_W * 0.5
	var r := Rect2(cx - 108, 264, 216, 48)
	UiKit.frame(self, r, Color(UiKit.DEEP.r, UiKit.DEEP.g, UiKit.DEEP.b, 0.94),
		UiKit.BORDER, UiKit.BORDER_HI, true)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2), UiKit.CYAN)
	UiKit.text_center(self, cx, r.position.y + 18, String(hint[0]), UiKit.F_BODY, UiKit.TEXT)
	UiKit.text_center(self, cx, r.position.y + 34, String(hint[1]), UiKit.F_SMALL, UiKit.TEXT_DIM)
	# 4 个步骤方块
	for i in 4:
		var c := Rect2(cx - 21 + i * 11, r.position.y + 40, 6, 4)
		var col := UiKit.CYAN if i < step else (UiKit.GOLD if i == step else UiKit.RAISED)
		draw_rect(c, col)
		draw_rect(c, UiKit.SHADOW, false, 1.0)
