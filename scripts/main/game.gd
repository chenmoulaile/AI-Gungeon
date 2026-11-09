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
const RunIntroScript = preload("res://scripts/ui/run_intro.gd")
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
## M3 调试：>0 时到点定格世界（真实时间 ms），供网页验收连拍精英击杀帧
var _debug_freeze_at_ms: int = -1
## 网页验收末波页（?lastwave）专用：末波加密度、前 3 槽精英、聚怪给连锁割草演示
var _debug_last_wave_mode: bool = false


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
	# 开局介绍期间不生成第一波敌人：介绍播完再刷，避免“看着介绍挨打”
	_start_node(GameState.node_id, wants_intro)
	ScreenFx.set_battle(true)
	BaCursor.set_battle(true)
	if wants_intro:
		intro_shown = true
		_show_run_intro()
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
	# M2 验收钩子：末波精英 / 金币雨自带战斗画面，命中时 ?enemies 的静态摆怪让位
	if q.contains("lastwave"):
		call_deferred("_debug_last_wave")
	if q.contains("coinrain"):
		call_deferred("_debug_coin_rain")
	if q.contains("enemies") and not q.contains("lastwave") and not q.contains("coinrain"):
		call_deferred("_debug_spawn_enemies")
	if q.contains("shop"):
		call_deferred("_debug_go_shop")
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
	player.grant_invuln(999.0)
	if tutorial != null and is_instance_valid(tutorial):
		tutorial.visible = false
	for e in GameState.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	GameState.enemies.clear()
	# 9 种敌人各一只 + 5 只补充杂兵 = 14 只，三排铺满可视区（相机初始视野 x 0~640 / y 90~450）
	var slots: Array = []
	var row1 := ["chaser", "shooter", "spreader", "charger", "ring"]
	var row2 := ["summoner", "shield", "splitter", "sniper"]
	var row3 := ["chaser", "charger", "shooter", "splitter", "chaser"]
	for i in row1.size():
		slots.append([String(row1[i]), Vector2(180.0 + 82.5 * float(i), 150.0)])
	for i in row2.size():
		slots.append([String(row2[i]), Vector2(220.0 + 80.0 * float(i), 250.0)])
	for i in row3.size():
		slots.append([String(row3[i]), Vector2(180.0 + 82.5 * float(i), 360.0)])
	for s in slots:
		var e = _scene_for(String(s[0])).instantiate()
		e.position = s[1]
		e.died.connect(_on_enemy_died)
		enemy_layer.add_child(e)
		# 验收时放在箱子上方，避免被场景装饰挡住
		e.z_index = 8
		# 冻结：验收只看得清外形与配色，不让 AI 挤到玩家身上
		e.set_physics_process(false)
		e.set_process(false)
	_debug_bullet_showcase()


## ?enemies 验收页静态弹幕样例阵（仅调试）：围玩家一圈 + 右侧三臂螺旋 + 顶部扇弧，
## 全部 speed 0 / 不处理物理，专供截图看「弹幕压迫感」的图案与密度
func _debug_bullet_showcase() -> void:
	if bullet_layer == null or player == null or not is_instance_valid(player):
		return
	var samples: Array = []
	# 环 1：围玩家 20 发（r=105，中心 (150,270)，红）
	var c1 := Vector2(150.0, 270.0)
	for i in 20:
		var a := TAU * float(i) / 20.0
		samples.append([c1 + Vector2(cos(a), sin(a)) * 105.0, Color("#FF5A63"), 3.4])
	# 环 2：右中 28 发双圈补密度（中心 (390,255)，深红）
	var c2 := Vector2(390.0, 255.0)
	for i in 28:
		var a2 := TAU * float(i) / 28.0 + 0.11
		samples.append([c2 + Vector2(cos(a2), sin(a2)) * 150.0, Color("#E4485F"), 2.8])
	# 三臂螺旋：从 (565,250) 向外旋开 27 点（品红/红相间）
	var c3 := Vector2(565.0, 250.0)
	for arm in 3:
		for k in 9:
			var a3 := TAU * float(arm) / 3.0 + float(k) * 0.55
			var rr := 22.0 + 10.0 * float(k)
			samples.append([c3 + Vector2(cos(a3), sin(a3)) * rr,
				Color("#F055B8") if k % 2 == 0 else Color("#ff5d7a"), 3.0])
	# 顶部扇弧：9 发向下张开（中心 (350,120)）
	for i in 9:
		var a4 := deg_to_rad(90.0 - 50.0 + 12.5 * float(i))
		samples.append([Vector2(350.0, 120.0) + Vector2(cos(a4), sin(a4)) * 70.0,
			Color("#ff5d7a"), 3.0])
	for s in samples:
		var b = BulletScript.new()
		b.position = s[0]
		bullet_layer.add_child(b)
		b.friendly = false
		b.color = s[1]
		b.radius = float(s[2])
		b.dir = Vector2.RIGHT
		b.speed = 0.0
		b.life = 9999.0
		b.prepare()
		b.set_physics_process(false)


## ?lastwave=1：网页验收直接看末波（保底精英括号标记）——清掉首波后把波次推进到最后一波（仅调试）
func _debug_last_wave() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.grant_invuln(999.0)
	if tutorial != null and is_instance_valid(tutorial):
		tutorial.visible = false
	for e in GameState.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	GameState.enemies.clear()
	alive_count = 0
	_debug_last_wave_mode = true
	wave_index = maxi(wave_total - 1, 1)
	_spawn_wave()
	var elite_n := 0
	for e2 in GameState.enemies:
		if is_instance_valid(e2) and (e2 as EnemyBase).elite:
			elite_n += 1
	print("[lastwave] wave=%d/%d count=%d elites=%d" % [wave_index, wave_total,
		GameState.enemies.size(), elite_n])
	hud.show_toast("末波 %d/%d · 精英 %d 只" % [wave_index, wave_total, elite_n], 8.0)
	# 注意：busy 必须在 _spawn_wave 之后置位（它开头会因 busy 直接 return），
	# 用来压掉 intro 回调与死亡驱动的后续自动刷波
	busy = true
	# 定格末波画面便于截图：精英括号标记保持可见（与 ?enemies 静态摆怪同款处理）
	# 注意玩家也挂在 enemy_layer 下，必须跳过，否则玩家被冻结无法开火
	var elite_slot2 := 0
	var elite_pos := Vector2.ZERO
	for e in enemy_layer.get_children():
		if not is_instance_valid(e) or e == player:
			continue
		e.set_physics_process(false)
		e.set_process(false)
		e.z_index = 8
		# 保底精英挪到玩家近旁，括号标记在截图里一目了然（挪位仅为验收，仿 _debug_view_actor）
		if e is EnemyBase and (e as EnemyBase).elite:
			var rr := GameConfig.room_rect().grow(-44.0)
			e.global_position = (player.global_position
				+ Vector2(150.0 + 46.0 * elite_slot2, 56.0)).clamp(rr.position, rr.end)
			elite_pos = e.global_position
			elite_slot2 += 1
			# M3 击杀帧验收：精英死亡后 1.6s 再定格整棵树，爆散/连锁/入账都拍得到
			(e as EnemyBase).died.connect(_debug_freeze_on_elite_death)
	# 把精英世界坐标暴露给网页脚本（web_verify 读取后瞄准连拍击杀帧）
	if elite_slot2 > 0:
		var js = Engine.get_singleton("JavaScriptBridge")
		if js != null:
			js.eval("window.__elite_pos = \"%d,%d\"" % [int(elite_pos.x), int(elite_pos.y)], true)
	# 连锁割草演示：非精英全部聚到精英锚点周围 62~104px 的两圈上，
	# 精英一死触发爆散冲击（64px）+ 持续火力，画面上成一串连锁击杀。
	# 只挪 EnemyBase：enemy_layer 下还挂着房间的障碍物视觉节点（Obstacle），不能动
	var anchor: Vector2 = player.global_position + Vector2(180.0, 10.0)
	var rr2 := GameConfig.room_rect().grow(-44.0)
	var fi := 0
	for e in enemy_layer.get_children():
		if not is_instance_valid(e) or e == player:
			continue
		if not (e is EnemyBase):
			continue
		if (e as EnemyBase).elite:
			continue
		var ang := TAU * float(fi) / 11.0 + 0.4
		var rad := 62.0 + 21.0 * float(fi % 3)
		e.global_position = (anchor + Vector2(cos(ang), sin(ang)) * rad)\
			.clamp(rr2.position, rr2.end)
		fi += 1


## M3 击杀帧截图辅助（仅 ?lastwave 调试路径）：精英死亡后 1.6s 真实时间定格世界。
## 原来 0.30s 就定格，网页脚本 150ms/帧的连拍窗口里第 2 帧起全是静止画面，
## 死亡爆散/连锁击杀/计数器变化全被掐掉；放宽到 1.6s 让整个连拍窗口（约 1.4s）
## 都是活画面，之后才定格收尾。
## 不用 await：死亡敌人 fade 后 queue_free，挂在其信号回调里的协程会被一起丢弃；
## 这里只登记真实时间截止点，由 _process 每帧到点执行（Time.get_ticks_msec 不受
## time_scale 影响，顿帧期间也走真实时钟）。
func _debug_freeze_on_elite_death(_e: Node = null) -> void:
	print("[freeze] elite died, pause in 1.60s (real time)")
	_debug_freeze_at_ms = Time.get_ticks_msec() + 1600


## ?coinrain=1：网页验收直接演示清场金币雨与 "+1" 拾取飘字（走 _on_room_cleared 同一函数，仅调试）
## 流程：撒币后等网页脚本置 window.__coinrain_go=1，再自动走位穿过币堆，
## 停步点旁补 3 枚近距金币，磁吸飞入 -> "+1" 飘字 -> 回池，全程走真实拾取链路
func _debug_coin_rain() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.grant_invuln(999.0)
	if tutorial != null and is_instance_valid(tutorial):
		tutorial.visible = false
	for e in GameState.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	GameState.enemies.clear()
	alive_count = 0
	busy = true
	_coin_rain(52, 64)
	# 等网页脚本发令（headless 下键盘注入持续走位不稳，改由钩子演示走位）
	var js = Engine.get_singleton("JavaScriptBridge")
	if js != null:
		var waited := 0.0
		var flag := str(js.eval("String(window.__coinrain_go)", true))
		while flag != "1" and waited < 60.0:
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
			flag = str(js.eval("String(window.__coinrain_go)", true))
		print("[coinrain] go flag=", flag, " waited=", waited)
	var p0: Vector2 = player.global_position
	print("[coinrain] walk from ", p0)
	var tw := create_tween()
	tw.tween_property(player, "global_position", p0 + Vector2(110, 40), 1.0)
	tw.tween_property(player, "global_position", p0 + Vector2(70, 130), 0.9)
	tw.tween_property(player, "global_position", p0 + Vector2(-20, 60), 0.9)
	tw.tween_callback(_drop_pickup_demo_coins)


## 演示收尾：停步点旁补 3 枚近距金币，下一帧即被磁吸飞入拾取
func _drop_pickup_demo_coins() -> void:
	if player == null or not is_instance_valid(player):
		return
	print("[coinrain] sprinkle at ", player.global_position)
	for i in 3:
		var c: Node2D = GameFeel.get_coin(1)
		if c == null:
			continue
		c.global_position = player.global_position + Vector2(18.0 + 10.0 * i, -4.0 + 6.0 * i)


## ?shop=1：网页验收直达商店看学园白卡与共鸣脉冲（仅调试）
func _debug_go_shop() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.grant_invuln(999.0)
	if tutorial != null and is_instance_valid(tutorial):
		tutorial.visible = false
	GameState.add_coins(300)   # 摆拍：可购买状态展示白卡与价签
	debug_start(FloorMap.KIND_SHOP)


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
	# M2：战斗房拉长到 3~4 波（精英/高潮房固定 4 波，小型/混合房 3~4 随机）；
	# 事件房保持 1 波（无战斗）
	match kind:
		Kind.BREATHER:
			return 1
		Kind.ELITE, Kind.CLIMAX:
			return 4
		_:
			return 3 if SeedManager.randf() < 0.5 else 4


func _count_for(kind: int) -> int:
	# 爽快度调整：波内同屏数量整体上抬（1 层小房 8 只起，高潮房 11 只起），
	# 配合精英爆散冲击形成「满屏割草」的密度感
	var f: int = GameState.floor_index
	match kind:
		Kind.SMALL:
			return 6 + 2 * f
		Kind.MIXED:
			return 8 + 2 * f
		Kind.ELITE:
			return 6 + 2 * f
		Kind.BREATHER:
			return 1 + int(f / 2.0)
		Kind.CLIMAX:
			return 9 + 2 * f
		_:
			return 6


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
	# 同屏数量封顶 18（原 10 拧到 18 配合密度验收）；超出部分转成精英化，而不是继续堆数量
	var want: int = _count_for(room_kind)
	# 网页验收末波页：末波保底 14 只、前 3 槽全精英，保证「满屏 + 多精英」的割草画面
	if _debug_last_wave_mode:
		want = maxi(want, 14)
	var count: int = mini(want, 18)
	var overflow: int = maxi(0, want - count)
	var types := _wave_types()
	var miniboss_spawned := false
	# M2：末波保底至少 1 只精英（复用 e.elite 机制与精英掉落）
	var force_elite := wave_index >= wave_total
	var elite_slot := SeedManager.randi_range(0, count - 1)
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
		if force_elite and (i == elite_slot or (_debug_last_wave_mode and i < 3)):
			e.elite = true
		if room_kind == Kind.CLIMAX:
			e.hp_scale = 0.85
		# 末波验收页：血量 ×0.6，保证连拍窗口（约 1.4s）内打得出一串连锁击杀
		if _debug_last_wave_mode:
			e.hp_scale = 0.6
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


## 开局全屏登场：与 Boss 登场一致，先暂停并拦截点击/空格，关闭后才刷第一波
func _show_run_intro() -> void:
	var intro = RunIntroScript.new()
	intro.setup(GameState.char_data, GameState.floor_index)
	intro.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(intro)
	get_tree().paused = true
	intro.finished.connect(func() -> void:
		get_tree().paused = false
		if is_instance_valid(intro):
			intro.queue_free()
		if player != null and is_instance_valid(player):
			player.lock_input(0.4)
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
		# 波间隔 2~3s：波数变多后给玩家更完整的喘息与走位空间
		await get_tree().create_timer(SeedManager.randf_range(2.0, 3.0)).timeout
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
	# M2：清场金币雨——末波清场额外撒 12~20 枚池化金币
	_coin_rain()
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


## M2：清场金币雨——以玩家为中心撒 24~32 枚池化金币，带初速度散开再磁吸；
## ?coinrain 验收页传 (52, 64) 铺出「金币雨」应有的密度
func _coin_rain(n_lo: int = 24, n_hi: int = 32) -> void:
	if GameState.bullets_root == null:
		return
	if player == null or not is_instance_valid(player):
		return
	var n := SeedManager.randi_range(n_lo, n_hi)
	for i in n:
		# 走 M1 的金币池：get_coin 取币，拾取侧 coin._collect 里 release_coin 回池
		var c: Node2D = GameFeel.get_coin(1)
		if c == null:
			continue
		var ang := SeedManager.randf() * TAU
		var dist := SeedManager.randf_range(30.0, 170.0)
		c.global_position = player.global_position + Vector2(cos(ang), sin(ang)) * dist
		c.launch(Vector2(cos(ang), sin(ang)) * SeedManager.randf_range(140.0, 280.0))


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
	# M3：强力藏品入包的 medium 档顿帧（新增触发点，此前无 hit-stop）
	GameFeel.hit_stop(0.08)


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
	# M3 调试：精英击杀帧定格。main 根节点是 PROCESS_MODE_ALWAYS（其子树全部继承），
	# get_tree().paused 对本游戏无效；直接 DISABLED 整棵 game 子树
	if _debug_freeze_at_ms > 0 and Time.get_ticks_msec() >= _debug_freeze_at_ms:
		_debug_freeze_at_ms = -1
		print("[freeze] disabled game subtree now")
		process_mode = Node.PROCESS_MODE_DISABLED
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

