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
const BossMirrorScene = preload("res://scenes/enemies/boss_mirror.tscn")
const BossTwinsScene = preload("res://scenes/enemies/boss_twins.tscn")
const ChargerScene = preload("res://scenes/enemies/enemy_charger.tscn")
const RingScene = preload("res://scenes/enemies/enemy_ring_shooter.tscn")
const SummonerScene = preload("res://scenes/enemies/enemy_summoner.tscn")
const ShieldScene = preload("res://scenes/enemies/enemy_shield_bearer.tscn")
const SplitterScene = preload("res://scenes/enemies/enemy_splitter.tscn")
const SniperScene = preload("res://scenes/enemies/enemy_sniper.tscn")
const BulletScript = preload("res://scripts/weapons/bullet.gd")

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
const EventRoomScript = preload("res://scripts/ui/event_room.gd")
const RoomChoiceScript = preload("res://scripts/ui/room_choice.gd")

enum Kind {SMALL, MIXED, ELITE, BREATHER, CLIMAX, BOSS}

var room = null
var player = null
var hud = null
var enemy_layer: Node2D
var bullet_layer: Node2D
var ui_layer: CanvasLayer
var tutorial = null

var wave_index: int = 0
var _debug_safe: bool = false
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
	# 网页验收模式：跳过开场对话框，免得遮住截图
	var dbg := _debug_query()
	_debug_safe = dbg.contains("safe")
	GameState.ensure_map()
	# 如果续玩时停在上一次商店节点，直接进 Boss，避免把商店节点当房间刷怪
	if String(GameState.floor_map.node_at(GameState.node_id).get("kind", "")) == FloorMap.KIND_SHOP:
		GameState.node_id = FloorMap.BOSS_ID
		GameState.room_index = GameState.node_id + 1
	var wants_intro := not intro_shown and dbg == "" \
		and GameState.floor_index == 1 and GameState.node_id == FloorMap.START_ID
	# 开场介绍期间不生成第一波敌人：介绍播完再刷，避免“看着介绍挨打”
	_start_node(GameState.node_id, wants_intro)
	ScreenFx.set_battle(true)
	BaCursor.set_battle(true)
	if wants_intro:
		intro_shown = true
		_show_intro_dialog(wants_intro)
	_check_debug_query(dbg)


func _debug_query() -> String:
	var js = Engine.get_singleton("JavaScriptBridge")
	if js == null:
		return ""
	var raw = js.eval("window.location.search", true)
	return "" if raw == null else str(raw)


## 网页版验收用：URL 带 ?enemies=1 时在首房间摆满 9 种敌人（仅调试，不影响正常流程）
func _check_debug_query(q: String = "") -> void:
	if q == "":
		q = _debug_query()
	if q == "":
		return
	# ?floor=2/3：网页验收时切换楼层主题（仅调试）
	for part in q.trim_prefix("?").split("&"):
		if part.begins_with("floor="):
			var fi := int(part.trim_prefix("floor="))
			if fi >= 1 and fi <= 3:
				call_deferred("_debug_set_floor", fi)
	if q.contains("enemies"):
		call_deferred("_debug_spawn_enemies")
	if q.contains("bullets"):
		call_deferred("_debug_spawn_bullets")
	if q.contains("boss"):
		call_deferred("_debug_go_boss")
	if q.contains("view"):
		call_deferred("_debug_view_actor")


func _debug_set_floor(fi: int) -> void:
	GameState.floor_index = fi
	GameState.floor_map = FloorMap.generate(fi, SeedManager.seed_string)
	GameState.node_id = FloorMap.START_ID
	GameState.room_index = GameState.node_id + 1
	GameState.visited_nodes = []
	_start_node(GameState.node_id)


## 调试/自测直达：按节点类型跳房（boss / elite / event / shop / small ...）
func debug_start(kind: String) -> void:
	var map := GameState.ensure_map()
	if kind == FloorMap.KIND_SHOP:
		_open_shop(map.find_first(FloorMap.KIND_SHOP))
		return
	var id := map.START_ID if kind == "" else map.find_first(kind)
	if id < 0:
		return
	_start_node(id)


## ?boss=1：网页验收直接进 Boss 房，看战斗内像素化
func _debug_go_boss() -> void:
	debug_start(FloorMap.KIND_BOSS)
	if get_tree().paused:
		get_tree().paused = false
	for n in ui_layer.get_children():
		if n.has_method("queue_free") and String(n.name).begins_with("BossIntro"):
			n.queue_free()


## ?boss=1&view=1：把玩家挪到 Boss 旁并冻结本体，方便网页截图验收像素化（仅调试）
func _debug_view_actor() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	player.global_position = boss.global_position + Vector2(-160, 40)
	player.grant_invuln(999.0)
	boss.set_physics_process(false)
	boss.set_process(false)


func _debug_spawn_enemies() -> void:
	if player == null or not is_instance_valid(player):
		return
	busy = true
	if tutorial != null and is_instance_valid(tutorial):
		tutorial.visible = false
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
		# 验收时放在箱子上方，避免被场景装饰挡住
		e.z_index = 8
		# 冻结：验收只看得清外形与配色，不让 AI 挤到玩家身上
		e.set_physics_process(false)
		e.set_process(false)
		i += 1


## 网页验收用：?bullets 时在玩家附近摆一排静态弹幕样例（仅调试）
func _debug_spawn_bullets() -> void:
	if player == null or not is_instance_valid(player):
		return
	busy = true
	if tutorial != null and is_instance_valid(tutorial):
		tutorial.visible = false
	for e in GameState.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	GameState.enemies.clear()
	var samples := [
		[Vector2(340, 300), true, Color("#8EE6FF"), 3.0, false, false],
		[Vector2(392, 300), true, Color("#FFD166"), 4.0, true, false],
		[Vector2(444, 300), false, Color("#FF5A63"), 5.0, false, false],
		[Vector2(496, 300), false, Color("#FF5A63"), 3.0, false, true],
		[Vector2(548, 300), false, Color("#E4485F"), 5.0, true, true],
	]
	for s in samples:
		var b = BulletScript.new()
		b.position = s[0]
		bullet_layer.add_child(b)
		b.friendly = bool(s[1])
		b.color = s[2]
		b.radius = float(s[3])
		b.trail = bool(s[4])
		b.destructible = bool(s[5])
		b.homing = 1.0 if bool(s[5]) else 0.0
		b.homing_time = 0.0
		b.dir = Vector2.RIGHT
		b.speed = 0.0
		b.life = 9999.0
		b.prepare()
		b.set_physics_process(false)
	# 地雷单独一个：需要 mine 标记
	var m = BulletScript.new()
	m.position = Vector2(600, 300)
	bullet_layer.add_child(m)
	m.friendly = false
	m.mine = true
	m.color = Color("#FF5A63")
	m.speed = 0.0
	m.prepare()
	m.set_physics_process(false)


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
func _kind_for_node(kind: String) -> int:
	match kind:
		FloorMap.KIND_SMALL:
			return Kind.SMALL
		FloorMap.KIND_MIXED:
			return Kind.MIXED
		FloorMap.KIND_ELITE:
			return Kind.ELITE
		FloorMap.KIND_EVENT:
			return Kind.BREATHER
		FloorMap.KIND_CLIMAX:
			return Kind.CLIMAX
		FloorMap.KIND_BOSS:
			return Kind.BOSS
	return Kind.MIXED


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


func _start_node(node_id: int, defer_wave: bool = false) -> void:
	var map := GameState.ensure_map()
	var node := map.node_at(node_id)
	if node.is_empty():
		return
	var kind_s := String(node["kind"])
	if kind_s == FloorMap.KIND_SHOP:
		_open_shop(node_id)
		return
	GameState.node_id = node_id
	GameState.room_index = node_id + 1
	if not GameState.visited_nodes.has(node_id):
		GameState.visited_nodes.append(node_id)
	busy = false
	room_cleared = false
	wave_index = 0
	alive_count = 0
	room_kind = _kind_for_node(kind_s)
	is_boss_room = room_kind == Kind.BOSS
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
	elif room_kind == Kind.BREATHER:
		# 事件房：没有敌人，进门即开门，三选一由弹出界面处理
		MusicManager.play("explore")
		hud.show_toast("B%d · %s" % [GameState.floor_index, String(node["name"])], 1.4)
		room.open_door()
		room_cleared = true
		busy = true
		call_deferred("_show_event_room")
	else:
		MusicManager.play("combat")
		wave_total = _wave_total_for(room_kind) + int(SeedManager.diff("wave"))
		hud.show_toast("B%d · %s" % [GameState.floor_index, String(node["name"])], 1.4)
		if not defer_wave and not _debug_safe:
			_spawn_wave()
	ChallengeManager.on_room_start(GameState.floor_index)
	RunSave.save_run()
	if tutorial != null and is_instance_valid(tutorial):
		tutorial.on_room_start(GameState.room_index)


## 事件房三选一：无敌人、可跳过；关掉界面后开门
func _show_event_room() -> void:
	if not is_inside_tree():
		return
	var node := GameState.ensure_map().node_at(GameState.node_id)
	if String(node.get("kind", "")) != FloorMap.KIND_EVENT:
		busy = false
		return
	var ev = EventRoomScript.new()
	ev.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(ev)
	DialogueManager.clear()
	get_tree().paused = true
	ev.closed.connect(func() -> void:
		if is_instance_valid(ev):
			ev.queue_free()
		get_tree().paused = false
		if player != null and is_instance_valid(player):
			player.lock_input(0.3)
		busy = false
		hud.show_toast("事件结束 · 向右离开", 1.8))


func _spawn_wave() -> void:
	if busy or room == null or not is_instance_valid(room):
		return
	wave_index += 1
	# 同屏数量封顶 10：超出部分转成精英化，而不是继续堆数量
	var want: int = _count_for(room_kind)
	var count: int = mini(want, 10)
	var overflow: int = maxi(0, want - count)
	var types := _wave_types()
	var miniboss_spawned := false
	for i in count:
		var scene: PackedScene = _scene_for(String(types[i % types.size()]))
		var e = scene.instantiate()
		# 混合/高潮房首波 15% 概率升一只迷你首领
		if i == 0 and not miniboss_spawned and wave_index == 1 \
				and (room_kind == Kind.MIXED or room_kind == Kind.CLIMAX) \
				and SeedManager.randf() < 0.15:
			e.miniboss = true
			miniboss_spawned = true
		if room_kind == Kind.ELITE and SeedManager.randf() < 0.45:
			e.elite = true
		if overflow > 0 and i < overflow:
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
	if miniboss_spawned:
		hud.show_toast("迷你首领出现 · 优先击杀", 2.0)
		Sfx.play("warn_high", -2.0, 0.85)


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
		"spreader":
			return SpreaderScene
		_:
			return ChaserScene


func _spawn_boss() -> void:
	boss = _boss_scene_for_floor().instantiate()
	boss.position = Vector2(GameConfig.ROOM_W * 0.66, GameConfig.ROOM_H * 0.5)
	boss.died.connect(_on_enemy_died)
	enemy_layer.add_child(boss)
	alive_count = 1
	Sfx.play("boss")
	_show_boss_intro(boss.intro_config())


## 三层 Boss 循环：1 回响聚合体 / 2 镜像回声 / 3 双生回响
func _boss_scene_for_floor() -> PackedScene:
	match (GameState.floor_index - 1) % 3:
		1:
			return BossMirrorScene
		2:
			return BossTwinsScene
	return BossScene


## 开局对话：立绘 + 打字机
func _show_intro_dialog(deferred_wave: bool = false) -> void:
	var d = GameState.char_data
	if d == null:
		if deferred_wave:
			_spawn_wave()
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
			"天赋「%s」：%s" % [d.passive_name, d.passive_desc],
			"清空 5 个房间，第 5 间是 Boss。走吧。"])
	get_tree().paused = true
	dlg.finished.connect(func() -> void:
		get_tree().paused = false
		if is_instance_valid(dlg):
			dlg.queue_free()
		# 关对白那一下点击不能变成攻击：清缓冲 + 锁 0.4s
		if player != null and is_instance_valid(player):
			player.lock_input(0.4)
		if deferred_wave:
			_spawn_wave())


func _show_boss_intro(cfg: Dictionary = {}) -> void:
	var intro = BossIntroScene.instantiate()
	intro.setup(cfg)
	intro.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(intro)
	get_tree().paused = true
	intro.finished.connect(func() -> void:
		get_tree().paused = false
		if is_instance_valid(intro):
			intro.queue_free()
		if player != null and is_instance_valid(player):
			player.lock_input(0.4)
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
	if room_kind == Kind.ELITE:
		_grant_elite_reward()
	ChallengeManager.on_room_cleared()
	if tutorial != null and is_instance_valid(tutorial):
		tutorial.on_room_cleared()


## 精英房必掉：至少蓝档藏品；藏品集齐时改发金币
func _grant_elite_reward() -> void:
	var up := UpgradeDB.roll_rare(GameState.upgrades, 1)
	if up == null:
		GameState.add_coins(30)
		hud.show_toast("精英战利品 · 藏品已集齐，改发 30 金币", 2.8)
		return
	GameState.add_upgrade(up.id)
	hud.show_toast("精英战利品 · %s（%s档）" % [up.title,
		String(UpgradeDB.RARITY_NAMES[UpgradeDB.rarity_of(up)])], 3.0)
	Sfx.play("relic", -2.0, 1.1)


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
	if busy:
		return
	busy = true
	var map := GameState.ensure_map()
	if is_boss_room:
		if GameState.floor_clean:
			GameState.excl_clean_floor = true
		GameState.floor_clean = true
		var interest := GameState.floor_interest()
		GameState.floor_index += 1
		GameState.add_coins(10 + interest)
		if interest > 0:
			hud.show_toast("层末结算 · 清场 +10 · 存款利息 +%d" % interest, 2.6)
		await get_tree().create_timer(0.9).timeout
		if not is_inside_tree():
			return
		await _floor_interlude()
		if not is_inside_tree():
			return
		GameState.floor_map = FloorMap.generate(GameState.floor_index, SeedManager.seed_string)
		GameState.visited_nodes = []
		_start_node(FloorMap.START_ID)
	elif map.is_choice(GameState.node_id):
		_show_choice()
	else:
		var nx := map.next_of(GameState.node_id)
		if nx.is_empty():
			busy = false
			return
		_goto_node(int(nx[0]))


## 门后二选一：暂停游戏，弹出两条路线，选完直接进入对应节点
func _show_choice() -> void:
	var map := GameState.ensure_map()
	var ids := map.next_of(GameState.node_id)
	if ids.size() < 2:
		busy = false
		return
	var ui = RoomChoiceScript.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(ui)
	ui.setup(ids, GameState.floor_index)
	DialogueManager.clear()
	get_tree().paused = true
	ui.chosen.connect(func(id: int) -> void:
		if is_instance_valid(ui):
			ui.queue_free()
		get_tree().paused = false
		if player != null and is_instance_valid(player):
			player.lock_input(0.3)
		_goto_node(id))


func _goto_node(id: int) -> void:
	var node := GameState.ensure_map().node_at(id)
	if node.is_empty():
		busy = false
		return
	if String(node["kind"]) == FloorMap.KIND_SHOP:
		_open_shop(id)
	else:
		_start_node(id)


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


func _open_shop(shop_node_id: int = -1) -> void:
	busy = true
	MusicManager.play("explore")
	DialogueManager.clear()
	var map := GameState.ensure_map()
	var sid := shop_node_id
	if sid < 0:
		sid = map.find_first(FloorMap.KIND_SHOP)
	if sid >= 0:
		GameState.node_id = sid
		GameState.room_index = sid + 1
		if not GameState.visited_nodes.has(sid):
			GameState.visited_nodes.append(sid)
	await Transition.cover("slide", 0.28)
	if not is_inside_tree():
		return
	var shop = ShopScene.instantiate()
	shop.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(shop)
	get_tree().paused = true
	shop.closed.connect(func() -> void:
		get_tree().paused = false
		var boss_id := GameState.ensure_map().BOSS_ID
		Transition.play("circle", func() -> void: _goto_node(boss_id), 0.3))
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
			menu.queue_free()
		if player != null and is_instance_valid(player):
			player.lock_input(0.3))


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
