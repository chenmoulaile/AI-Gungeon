extends Node2D
## 关卡循环：房间 -> 清场 -> 开门 -> 下一房间 -> 商店 -> Boss -> 下一层
## 房间节奏：小怪 -> 混合/精英 -> 喘息 -> Boss 前小高潮；波次之间留 1.5~2s 走位窗口

signal run_over

const RoomScene = preload("res://scenes/rooms/room_basic.tscn")
const PlayerScene = preload("res://scenes/player/player.tscn")
const ChaserScene = preload("res://scenes/enemies/enemy_chaser.tscn")
const ShooterScene = preload("res://scenes/enemies/enemy_shooter.tscn")
const SpreaderScene = preload("res://scenes/enemies/enemy_spreader.tscn")
const BossScene = preload("res://scenes/enemies/boss.tscn")
const ChargerScene = preload("res://scenes/enemies/enemy_charger.tscn")
const RingScene = preload("res://scenes/enemies/enemy_ring_shooter.tscn")
const SummonerScene = preload("res://scenes/enemies/enemy_summoner.tscn")
const ShieldScene = preload("res://scenes/enemies/enemy_shield_bearer.tscn")
const SplitterScene = preload("res://scenes/enemies/enemy_splitter.tscn")
const SniperScene = preload("res://scenes/enemies/enemy_sniper.tscn")

## 分层敌人池：第 1 层三种，第 2 层加环形射手/分裂体，第 3 层加召唤者/盾卫/狙击手
const POOL_F1 := ["chaser", "charger", "shooter"]
const POOL_F2 := ["chaser", "charger", "shooter", "ring", "splitter"]
const POOL_F3 := ["chaser", "charger", "shooter", "ring", "splitter",
	"summoner", "shield", "sniper"]

## 需要走位的 / 需要优先击杀的
const KITE_TYPES := ["charger", "ring", "sniper", "shooter"]
const PRIORITY_TYPES := ["summoner", "shield", "splitter"]
const HudScene = preload("res://scenes/ui/hud.tscn")
const ShopScene = preload("res://scenes/ui/shop.tscn")
const BossIntroScene = preload("res://scenes/ui/boss_intro.tscn")
const PortraitDialogScene = preload("res://scenes/ui/portrait_dialog.tscn")
const SettingsScene = preload("res://scenes/ui/settings_menu.tscn")
const TutorialScript = preload("res://scripts/ui/tutorial_hint.gd")
const FloorCardScript = preload("res://scripts/ui/floor_card.gd")

enum Kind {SMALL, MIXED, ELITE, BREATHER, CLIMAX, BOSS}

var room = null
var player = null
var hud = null
var enemy_layer: Node2D
var bullet_layer: Node2D
var ui_layer: CanvasLayer
var tutorial = null

var wave_index: int = 0
var wave_total: int = 2
var alive_count: int = 0
var room_cleared: bool = false
var is_boss_room: bool = false
var boss = null
var busy: bool = false
var intro_shown: bool = false
var room_kind: int = Kind.SMALL
var _dense_tick: int = 0
## 标记：允许主控在这里触发暂停菜单
var is_gameplay: bool = true


func _ready() -> void:
	_build_layers()
	GameState.bullets_root = bullet_layer
	GameState.run_ended.connect(_on_run_ended)
	_spawn_player()
	_start_room(GameState.room_index)
	ScreenFx.set_battle(true)
	BaCursor.set_battle(true)
	if not intro_shown and GameState.floor_index == 1 and GameState.room_index == 1:
		intro_shown = true
		_show_intro_dialog()
	_check_debug_query()


## 网页版验收用：URL 带 ?enemies=1 时在首房间摆满 9 种敌人（仅调试，不影响正常流程）
func _check_debug_query() -> void:
	var js = Engine.get_singleton("JavaScriptBridge")
	if js == null:
		return
	var raw = js.eval("window.location.search", true)
	if raw == null:
		return
	var q := str(raw)
	if q.contains("enemies"):
		call_deferred("_debug_spawn_enemies")


func _debug_spawn_enemies() -> void:
	await get_tree().create_timer(1.2).timeout
	if player == null or not is_instance_valid(player):
		return
	player.invuln = 99999.0
	busy = true
	for e in GameState.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	GameState.enemies.clear()
	var keys := ["chaser", "shooter", "spreader", "charger", "ring",
		"summoner", "shield", "splitter", "sniper"]
	var i := 0
	for k in keys:
		var e = _scene_for(String(k)).instantiate()
		e.position = Vector2(300 + (i % 3) * 120, 130 + int(i / 3) * 105)
		e.died.connect(_on_enemy_died)
		enemy_layer.add_child(e)
		i += 1


func _build_layers() -> void:
	enemy_layer = Node2D.new()
	enemy_layer.name = "Actors"
	# Y-Sort：脚底作为排序点，走到箱子下方会被遮挡
	enemy_layer.y_sort_enabled = true
	add_child(enemy_layer)

	bullet_layer = Node2D.new()
	bullet_layer.name = "Bullets"
	add_child(bullet_layer)

	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	ui_layer.layer = 10
	add_child(ui_layer)

	hud = HudScene.instantiate()
	ui_layer.add_child(hud)

	if not MetaProgress.training_done():
		tutorial = TutorialScript.new()
		tutorial.name = "Tutorial"
		ui_layer.add_child(tutorial)


func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	enemy_layer.add_child(player)


# ---------------- 房间节奏 ----------------
func _kind_for(index: int) -> int:
	if index >= 5:
		return Kind.BOSS
	match index:
		1:
			return Kind.SMALL
		2:
			return Kind.ELITE if GameState.floor_index >= 2 else Kind.MIXED
		3:
			return Kind.BREATHER
		_:
			return Kind.CLIMAX


func _wave_total_for(kind: int) -> int:
	match kind:
		Kind.BREATHER:
			return 1
		Kind.CLIMAX:
			return 3
		Kind.ELITE:
			return 2
		_:
			return 2


func _count_for(kind: int) -> int:
	var f: int = GameState.floor_index
	match kind:
		Kind.SMALL:
			return 2 + f
		Kind.MIXED:
			return 3 + f
		Kind.ELITE:
			return 2 + f
		Kind.BREATHER:
			return 1 + int(f / 2.0)
		Kind.CLIMAX:
			return 4 + f
		_:
			return 3


func _start_room(index: int) -> void:
	GameState.room_index = index
	busy = false
	room_cleared = false
	wave_index = 0
	alive_count = 0
	is_boss_room = (index == 5)
	room_kind = _kind_for(index)
	boss = null
	_clear_layer(enemy_layer)
	_clear_layer(bullet_layer)
	GameState.enemies.clear()

	if room != null and is_instance_valid(room):
		room.queue_free()
	room = RoomScene.instantiate()
	room.is_boss = is_boss_room
	room.visual_parent = enemy_layer
	add_child(room)
	move_child(room, 0)

	player.global_position = room.spawn_point(0)
	player.grant_invuln(1.0)
	# 角色手电亮度跟随层主题（浅色地面不需要那么亮的光池）
	if player.key_light != null and is_instance_valid(player.key_light):
		var th: Dictionary = FloorTheme.get_theme(GameState.floor_index)
		player.key_light.energy = float(th.get("light_energy", 0.6))
		var lum := float(th.get("sprite_lum", 1.2))
		player.anim.self_modulate = Color(lum, lum, lum * 1.04)

	Sfx.play_ambience("f%d" % clampi(GameState.floor_index, 1, 3))
	if is_boss_room:
		MusicManager.play("boss")
		_spawn_boss()
	else:
		MusicManager.play("combat")
		wave_total = _wave_total_for(room_kind) + int(SeedManager.diff("wave"))
		hud.show_toast("B%d · 房间 %d" % [GameState.floor_index, index], 1.4)
		_spawn_wave()
	ChallengeManager.on_room_start(GameState.floor_index)
	RunSave.save_run()
	if tutorial != null and is_instance_valid(tutorial):
		tutorial.on_room_start(index)


func _spawn_wave() -> void:
	if busy or room == null or not is_instance_valid(room):
		return
	wave_index += 1
	var count: int = _count_for(room_kind)
	var types := _wave_types()
	for i in count:
		var scene: PackedScene = _scene_for(String(types[i % types.size()]))
		var e = scene.instantiate()
		if room_kind == Kind.ELITE and SeedManager.randf() < 0.45:
			e.elite = true
		if room_kind == Kind.CLIMAX:
			e.hp_scale = 0.85
		var pos: Vector2 = room.random_point(80.0)
		var guard := 0
		while pos.distance_to(player.global_position) < 130.0 and guard < 12:
			pos = room.random_point(80.0)
			guard += 1
		e.position = pos
		e.died.connect(_on_enemy_died)
		enemy_layer.add_child(e)
		alive_count += 1


func _pool() -> Array:
	var f: int = GameState.floor_index
	if f <= 1:
		return POOL_F1
	if f == 2:
		return POOL_F2
	return POOL_F3


## 每波 2~4 种，尽量保证「一个要躲的 + 一个要先杀的」
func _wave_types() -> Array:
	var pool := _pool().duplicate()
	SeedManager.shuffle(pool)
	var out: Array = []
	var want := mini(pool.size(), SeedManager.randi_range(2, 4))
	# 先塞一个需要走位的
	for t in KITE_TYPES:
		if pool.has(t) and out.size() < want:
			out.append(t)
			break
	# 再塞一个需要优先击杀的
	for t in PRIORITY_TYPES:
		if pool.has(t) and not out.has(t) and out.size() < want:
			out.append(t)
			break
	for t in pool:
		if out.size() >= want:
			break
		if not out.has(t):
			out.append(t)
	if out.is_empty():
		out = ["chaser"]
	return out


func _scene_for(key: String) -> PackedScene:
	match key:
		"charger":
			return ChargerScene
		"ring":
			return RingScene
		"summoner":
			return SummonerScene
		"shield":
			return ShieldScene
		"splitter":
			return SplitterScene
		"sniper":
			return SniperScene
		"shooter":
			return ShooterScene
		_:
			return ChaserScene


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
	var portrait := "res://assets/portraits/%s_pixel.png" % GameState.char_id
	if not ResourceLoader.exists(portrait):
		portrait = "res://assets/portraits/%s_full.png" % GameState.char_id
	dlg.setup(portrait, d.display_name,
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
			intro.queue_free()
		DialogueManager.say(GameState.char_id, "boss", 2.8))


# ---------------- 敌人死亡 / 清场 ----------------
func _on_enemy_died(e: Node) -> void:
	alive_count = maxi(0, alive_count - 1)
	if is_boss_room and e == boss:
		_on_boss_dead()
		return
	if alive_count > 0 or busy:
		return
	if wave_index < wave_total:
		# 波间隔 1.5~2s，给玩家走位空间
		await get_tree().create_timer(SeedManager.randf_range(1.5, 2.0)).timeout
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
	var bonus := 4
	if Stats.economy != null:
		bonus = Stats.economy.room_clear_coins
	if room_kind == Kind.BREATHER:
		bonus = 12
	GameState.add_coins(bonus)
	var heal: int = int(GameState.mods.get("room_clear_heal", 0))
	if heal > 0:
		GameState.heal(heal)
		hud.show_toast("房间清空 · 回复 %d 点生命 · 向右离开" % heal, 2.4)
	else:
		hud.show_toast("房间清空 · 向右离开", 2.2)
	ChallengeManager.on_room_cleared()
	if tutorial != null and is_instance_valid(tutorial):
		tutorial.on_room_cleared()


func _on_boss_dead() -> void:
	boss = null
	for e in enemy_layer.get_children():
		if e == player:
			continue
		if is_instance_valid(e):
			e.queue_free()
	alive_count = 0
	GameState.add_coins(Stats.economy.boss_clear_coins if Stats.economy != null else 25)
	room_cleared = true
	if room != null and is_instance_valid(room):
		room.open_door()
	hud.show_toast("回响聚合体已被击破！向右进入下一层", 3.0)
	Sfx.play("skill", -2.0, 0.7)
	GameState.run_cleared = true
	ChallengeManager.on_boss_killed(GameState.hp)
	DialogueManager.say(GameState.char_id, "victory", 2.6)


# ---------------- 房间推进 ----------------
func _process(_delta: float) -> void:
	_update_dense_warning()
	if busy or not room_cleared or player == null or not is_instance_valid(player):
		return
	if not player.alive:
		return
	if room != null and is_instance_valid(room) and room.door_zone().has_point(player.global_position):
		_advance()


## 弹幕密集度：每 6 帧统计一次敌弹数量，超过 45 开始出现四角红色光晕
func _update_dense_warning() -> void:
	_dense_tick += 1
	if _dense_tick % 6 != 0:
		return
	var n := get_tree().get_nodes_in_group("enemy_bullets").size()
	ScreenFx.set_dense(clampf((float(n) - 45.0) / 40.0, 0.0, 1.0))


func _advance() -> void:
	busy = true
	var idx := GameState.room_index
	if is_boss_room:
		if GameState.floor_clean:
			GameState.excl_clean_floor = true
		GameState.floor_clean = true
		GameState.floor_index += 1
		GameState.add_coins(10)
		await get_tree().create_timer(0.9).timeout
		if not is_inside_tree():
			return
		await _floor_interlude()
		if not is_inside_tree():
			return
		_start_room(1)
	elif idx == 4:
		_open_shop()
	else:
		_start_room(idx + 1)


## 层间转场：层名 + 序号，1.2s 仪式感，结束后进该层第一间房
func _floor_interlude() -> void:
	ScreenFx.set_dense(0.0)
	var card = FloorCardScript.new()
	card.name = "FloorCard"
	ui_layer.add_child(card)
	card.setup(GameState.floor_index)
	Sfx.play("floor_shift", -4.0, 1.0)
	await card.finished
	if is_instance_valid(card):
		card.queue_free()
	await get_tree().create_timer(0.15).timeout


func _open_shop() -> void:
	busy = true
	MusicManager.play("explore")
	DialogueManager.clear()
	await Transition.cover("slide", 0.28)
	if not is_inside_tree():
		return
	var shop = ShopScene.instantiate()
	shop.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(shop)
	get_tree().paused = true
	shop.closed.connect(func() -> void:
		get_tree().paused = false
		Transition.play("circle", func() -> void: _start_room(5), 0.3))
	Transition.reveal(0.24)


# ---------------- 设置 ----------------



func open_settings() -> void:
	var menu = SettingsScene.instantiate()
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(menu)
	get_tree().paused = true
	menu.closed.connect(func() -> void:
		get_tree().paused = false
		if is_instance_valid(menu):
			menu.queue_free())


func _clear_layer(layer: Node) -> void:
	for c in layer.get_children():
		if c == player:
			continue
		c.queue_free()


func _on_run_ended() -> void:
	if busy:
		return
	busy = true
	ScreenFx.set_battle(false)
	BaCursor.set_battle(false)
	# 保留战场最后一帧给结算界面做背景（headless 下没有渲染，跳过）
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img != null and img.get_width() > 0:
			img.save_png("user://last_frame.png")
	MetaProgress.finish_run(GameState.char_id, GameState.floor_index,
		GameState.run_cleared, GameState.run_time, SeedManager.difficulty)
	RunSave.clear()
	await get_tree().create_timer(1.1).timeout
	if not is_inside_tree():
		return
	run_over.emit()
