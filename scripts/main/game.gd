extends Node2D
## 关卡循环：房间 -> 清场 -> 开门 -> 下一房间 -> 商店 -> Boss -> 下一层

signal run_over

const RoomScene = preload("res://scenes/rooms/room_basic.tscn")
const PlayerScene = preload("res://scenes/player/player.tscn")
const ChaserScene = preload("res://scenes/enemies/enemy_chaser.tscn")
const ShooterScene = preload("res://scenes/enemies/enemy_shooter.tscn")
const SpreaderScene = preload("res://scenes/enemies/enemy_spreader.tscn")
const BossScene = preload("res://scenes/enemies/boss.tscn")
const HudScene = preload("res://scenes/ui/hud.tscn")
const ShopScene = preload("res://scenes/ui/shop.tscn")
const BossIntroScene = preload("res://scenes/ui/boss_intro.tscn")
const PortraitDialogScene = preload("res://scenes/ui/portrait_dialog.tscn")

var room = null
var player = null
var hud = null
var enemy_layer: Node2D
var bullet_layer: Node2D
var ui_layer: CanvasLayer

var wave_index: int = 0
var wave_total: int = 2
var alive_count: int = 0
var room_cleared: bool = false
var is_boss_room: bool = false
var boss = null
var busy: bool = false
var intro_shown: bool = false


func _ready() -> void:
	_build_layers()
	GameState.bullets_root = bullet_layer
	GameState.run_ended.connect(_on_run_ended)
	_spawn_player()
	_start_room(GameState.room_index)
	if not intro_shown and GameState.floor_index == 1 and GameState.room_index == 1:
		intro_shown = true
		_show_intro_dialog()


func _build_layers() -> void:
	enemy_layer = Node2D.new()
	enemy_layer.name = "Enemies"
	add_child(enemy_layer)

	bullet_layer = Node2D.new()
	bullet_layer.name = "Bullets"
	add_child(bullet_layer)

	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)

	hud = HudScene.instantiate()
	ui_layer.add_child(hud)


func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	add_child(player)
	move_child(player, 2)


# ---------------- 房间 ----------------
func _start_room(index: int) -> void:
	GameState.room_index = index
	busy = false
	room_cleared = false
	wave_index = 0
	alive_count = 0
	is_boss_room = (index == 5)
	boss = null
	_clear_layer(enemy_layer)
	_clear_layer(bullet_layer)
	GameState.enemies.clear()

	if room != null and is_instance_valid(room):
		room.queue_free()
	room = RoomScene.instantiate()
	add_child(room)
	move_child(room, 0)

	player.global_position = room.spawn_point(0)
	player.grant_invuln(1.0)

	if is_boss_room:
		_spawn_boss()
	else:
		wave_total = 2 if GameState.floor_index < 2 else 3
		hud.show_toast("B%d · 房间 %d" % [GameState.floor_index, index], 1.4)
		_spawn_wave()


func _spawn_wave() -> void:
	if busy or room == null or not is_instance_valid(room):
		return
	wave_index += 1
	var count: int = 2 + GameState.floor_index + wave_index
	for i in count:
		var scene: PackedScene = _pick_enemy()
		var e = scene.instantiate()
		var pos: Vector2 = room.random_point(80.0)
		var guard := 0
		while pos.distance_to(player.global_position) < 130.0 and guard < 12:
			pos = room.random_point(80.0)
			guard += 1
		e.position = pos
		e.died.connect(_on_enemy_died)
		enemy_layer.add_child(e)
		alive_count += 1


func _pick_enemy() -> PackedScene:
	var roll := randf()
	var floor_bonus := 0.08 * float(GameState.floor_index - 1)
	if roll < 0.5 - floor_bonus:
		return ChaserScene
	elif roll < 0.8:
		return ShooterScene
	return SpreaderScene


func _spawn_boss() -> void:
	boss = BossScene.instantiate()
	boss.position = Vector2(GameConfig.ROOM_W * 0.66, GameConfig.ROOM_H * 0.5)
	boss.died.connect(_on_enemy_died)
	enemy_layer.add_child(boss)
	alive_count = 1
	Sfx.play("boss")
	_show_boss_intro()


## 开局对话：立绘 + 打字机
func _show_intro_dialog() -> void:
	var d = GameState.char_data
	if d == null:
		return
	var dlg = PortraitDialogScene.instantiate()
	dlg.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(dlg)
	dlg.setup("res://assets/portraits/%s_full.png" % GameState.char_id, d.display_name,
		[d.blurb, "武器「%s」：%s" % [d.weapon_name, d.weapon_desc],
		 "技能「%s」：%s" % [d.skill_name, d.skill_desc],
		 "清空 5 个房间，第 5 间是 Boss。走吧。"])
	get_tree().paused = true
	dlg.finished.connect(func() -> void:
		get_tree().paused = false
		if is_instance_valid(dlg):
			dlg.queue_free())


func _show_boss_intro() -> void:
	var intro = BossIntroScene.instantiate()
	intro.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(intro)
	get_tree().paused = true
	intro.finished.connect(func() -> void:
		get_tree().paused = false
		if is_instance_valid(intro):
			intro.queue_free())


# ---------------- 敌人死亡 / 清场 ----------------
func _on_enemy_died(e: Node) -> void:
	alive_count = maxi(0, alive_count - 1)
	if is_boss_room and e == boss:
		_on_boss_dead()
		return
	if alive_count > 0 or busy:
		return
	if wave_index < wave_total:
		await get_tree().create_timer(0.75).timeout
		if not is_inside_tree() or busy:
			return
		_spawn_wave()
	else:
		_on_room_cleared()


func _on_room_cleared() -> void:
	if room_cleared:
		return
	room_cleared = true
	if room != null and is_instance_valid(room):
		room.open_door()
	GameState.add_coins(4)
	hud.show_toast("房间清空 · 向右离开", 2.2)


func _on_boss_dead() -> void:
	boss = null
	# 清掉 Boss 召唤出来的小怪
	for e in enemy_layer.get_children():
		if is_instance_valid(e):
			e.queue_free()
	alive_count = 0
	GameState.add_coins(25)
	room_cleared = true
	if room != null and is_instance_valid(room):
		room.open_door()
	hud.show_toast("回响聚合体已被击破！向右进入下一层", 3.0)
	Sfx.play("skill", -2.0, 0.7)


# ---------------- 房间推进 ----------------
func _process(_delta: float) -> void:
	if busy or not room_cleared or player == null or not is_instance_valid(player):
		return
	if not player.alive:
		return
	if room != null and is_instance_valid(room) and room.door_zone().has_point(player.global_position):
		_advance()


func _advance() -> void:
	busy = true
	var idx := GameState.room_index
	if is_boss_room:
		GameState.floor_index += 1
		GameState.add_coins(10)
		hud.show_toast("进入 B%d 层（敌人强度 +20%%）" % GameState.floor_index, 2.0)
		await get_tree().create_timer(0.9).timeout
		if not is_inside_tree():
			return
		_start_room(1)
	elif idx == 4:
		_open_shop()
	else:
		_start_room(idx + 1)


func _open_shop() -> void:
	busy = true
	var shop = ShopScene.instantiate()
	shop.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(shop)
	get_tree().paused = true
	shop.closed.connect(func() -> void:
		get_tree().paused = false
		_start_room(5))


func _clear_layer(layer: Node) -> void:
	for c in layer.get_children():
		c.queue_free()


func _on_run_ended() -> void:
	if busy:
		return
	busy = true
	await get_tree().create_timer(1.1).timeout
	if not is_inside_tree():
		return
	run_over.emit()
