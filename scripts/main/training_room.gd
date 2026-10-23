extends Node2D
## 训练场：无死亡、无统计；中央弹幕发生器可切换 6 种弹幕

signal exit_requested

const RoomScene = preload("res://scenes/rooms/room_basic.tscn")
const PlayerScene = preload("res://scenes/player/player.tscn")
const LaserScene = preload("res://scripts/weapons/laser_sweep.gd")
const BulletScript = preload("res://scripts/weapons/bullet.gd")

const PATTERN_NAMES := ["环形", "扇形", "追踪", "激光", "地雷", "反弹"]

var room = null
var player = null
var ui: Control = null
var pattern: int = 0
var timer: float = 1.2
var t: float = 0.0
var gen_pos := Vector2(GameConfig.ROOM_W * 0.5, GameConfig.ROOM_H * 0.5)
var _beeps: float = 0.0


func _ready() -> void:
	GameState.training = true
	GameState.obstacles = []
	GameState.crates = []
	if GameState.char_data == null:
		GameState.char_data = GameState.load_character(GameState.char_id)
	GameState.hp = GameState.max_hp
	GameState.enemies.clear()

	room = RoomScene.instantiate()
	add_child(room)
	move_child(room, 0)

	player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = Vector2(GameConfig.ROOM_W * 0.28, GameConfig.ROOM_H * 0.5)
	GameState.player = player
	GameState.bullets_root = self

	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.add_child(ui)
	add_child(layer)
	ui.draw.connect(_draw_ui)
	MusicManager.play("combat")


func _process(delta: float) -> void:
	t += delta
	if player != null and is_instance_valid(player):
		player.invuln = 999.0
		player.hp = GameState.max_hp
	timer -= delta
	if timer <= 0.0:
		timer = 1.8
		_emit_pattern()
	if ui != null:
		ui.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				_exit()
			KEY_Q, KEY_LEFT:
				pattern = (pattern + PATTERN_NAMES.size() - 1) % PATTERN_NAMES.size()
				Sfx.play("ui")
			KEY_E, KEY_RIGHT:
				pattern = (pattern + 1) % PATTERN_NAMES.size()
				Sfx.play("ui")
			KEY_R:
				_reset()
			KEY_1, KEY_2, KEY_3:
				_switch_char(["deepseek", "gpt", "claude"][event.physical_keycode - KEY_1])
	elif event is InputEventJoypadButton and event.pressed:
		var b := (event as InputEventJoypadButton).button_index
		if b == 1:
			_exit()
		elif b == 2:
			_reset()
		elif b == 4:
			pattern = (pattern + PATTERN_NAMES.size() - 1) % PATTERN_NAMES.size()
		elif b == 5:
			pattern = (pattern + 1) % PATTERN_NAMES.size()


## 训练场内切换角色：直接重建玩家节点
func _switch_char(id: String) -> void:
	if player != null and is_instance_valid(player):
		player.queue_free()
	GameState.char_id = id
	GameState.char_data = GameState.load_character(id)
	GameState.hp = GameState.max_hp
	player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = Vector2(GameConfig.ROOM_W * 0.28, GameConfig.ROOM_H * 0.5)
	GameState.player = player
	Sfx.play("ui")


func _exit() -> void:
	GameState.training = false
	exit_requested.emit()


func _reset() -> void:
	for b in get_tree().get_nodes_in_group("bullets"):
		if is_instance_valid(b):
			b.queue_free()
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		if is_instance_valid(b):
			b.queue_free()
	for b in get_tree().get_nodes_in_group("beams"):
		if is_instance_valid(b):
			b.queue_free()
	timer = 0.6
	Sfx.play("ui")


func _emit_pattern() -> void:
	match pattern:
		0:
			for i in 12:
				var a := TAU * float(i) / 12.0 + t
				_spawn(Vector2(cos(a), sin(a)), 130.0, 4.0)
		1:
			for i in 5:
				var a2 := -PI / 2.0 + (float(i) - 2.0) * 0.24
				_spawn(Vector2(cos(a2), sin(a2)), 190.0, 4.0)
		2:
			for i in 2:
				var b = GameFeel.get_bullet()
				if b == null:
					return
				b.friendly = false
				b.dir = Vector2(-1.0, 0.2 * float(i * 2 - 1)).normalized()
				b.speed = 100.0
				b.damage = 1.0
				b.radius = 4.6
				b.color = Color("#ff8a4d")
				b.life = 8.0
				b.homing = 2.0
				b.homing_time = 4.0
				b.destructible = true
				b.trail = true
				b.global_position = gen_pos + Vector2(0, -20 + i * 40)
				b.prepare()
		3:
			var l = LaserScene.new()
			l.origin = gen_pos
			l.base_angle = PI
			add_child(l)
		4:
			for i in 3:
				var ang := TAU * float(i) / 3.0 + t
				var b2 = GameFeel.get_bullet()
				if b2 == null:
					return
				b2.friendly = false
				b2.dir = Vector2.ZERO
				b2.speed = 0.0
				b2.damage = 1.0
				b2.radius = 5.0
				b2.color = Color("#ff6b3d")
				b2.life = 4.0
				b2.mine = true
				b2.mine_fuse = 1.5
				b2.global_position = gen_pos + Vector2(cos(ang), sin(ang)) * 120.0
				b2.prepare()
		5:
			for i in 2:
				var b3 = GameFeel.get_bullet()
				if b3 == null:
					return
				b3.friendly = false
				b3.dir = Vector2(-1.0, 0.35 * float(i * 2 - 1)).normalized()
				b3.speed = 240.0
				b3.damage = 1.0
				b3.radius = 4.0
				b3.color = Color("#b06bff")
				b3.bounce = 2
				b3.life = 6.0
				b3.global_position = gen_pos + Vector2(0, -20 + i * 40)
				b3.prepare()


func _spawn(dir: Vector2, speed: float, radius: float) -> void:
	var b = GameFeel.get_bullet()
	if b == null:
		return
	b.friendly = false
	b.dir = dir.normalized()
	b.speed = speed
	b.damage = 1.0
	b.radius = radius
	b.color = Color("#ff5d7a")
	b.life = 6.0
	b.global_position = gen_pos
	b.prepare()


func _draw_ui() -> void:
	if ui == null or GameConfig.ui_font == null:
		return
	var f: Font = GameConfig.ui_font
	# 发生器
	var pulse: float = 0.5 + 0.5 * sin(t * 3.0)
	ui.draw_circle(gen_pos, 26.0, Color(0.16, 0.18, 0.24))
	ui.draw_arc(gen_pos, 26.0, 0.0, TAU, 24, Color(0.55, 0.7, 1.0, 0.5 + 0.4 * pulse), 2.0, true)
	ui.draw_string(f, gen_pos + Vector2(-12, 4), "靶", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.9, 0.95, 1.0))

	ui.draw_rect(Rect2(10, 10, 150, 22), Color(0.05, 0.07, 0.11, 0.85))
	ui.draw_string(f, Vector2(18, 25), "弹幕：%s" % PATTERN_NAMES[pattern],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.95, 1.0))
	ui.draw_string(f, Vector2(10, GameConfig.BASE_H - 12),
		"← → / Q E 切换弹幕    R 重置    1/2/3 换角色    ESC 退出（不计统计）",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.62, 0.68, 0.8))
