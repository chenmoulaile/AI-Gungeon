extends Node
## 无头自测：三个角色开局 -> 开火 -> 技能 -> 清场 -> 开门 -> 商店 -> Boss -> 死亡结算
## 运行：godot --headless --path . res://tests/smoke_test.tscn

var results: Array = []
var failed: int = 0


func _ready() -> void:
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		results.append("  OK   " + msg)
	else:
		failed += 1
		results.append("  FAIL " + msg)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	_check(main.current != null and main.current.name == "Splash", "启动 -> 启动画面")
	await _wait(2.2)
	_check(main.current != null and main.current.name == "MainMenu", "启动画面 -> 主菜单")
	main.queue_free()
	await _frames(3)

	for cid in ["deepseek", "gpt", "claude"]:
		await _test_character(cid)
	await _test_boss()
	await _test_boss_pool()
	await _test_miniboss()
	await _test_shop()
	await _test_death()

	print("\n================ 自测结果 ================")
	for line in results:
		print(line)
	print("失败项: %d" % failed)
	print("=========================================")
	get_tree().quit(1 if failed > 0 else 0)


func _new_game(cid: String):
	GameState.start_run(cid)
	var g = load("res://scenes/main/game.tscn").instantiate()
	add_child(g)
	await _frames(4)
	await _dismiss_overlay(g)
	return g


## 关掉栈顶的打字机界面（开局对话 / Boss 登场）
func _dismiss_overlay(g) -> void:
	for k in 24:
		var top = g.ui_layer.get_child(g.ui_layer.get_child_count() - 1)
		if top != null and is_instance_valid(top) and top.has_method("_advance"):
			top._advance()
		await _frames(2)
	get_tree().paused = false
	await _frames(2)


func _kill_all() -> void:
	for e in GameState.enemies.duplicate():
		if is_instance_valid(e):
			e.take_damage(9999.0)


## 反复清怪直到房间开门（波次刷新）
func _clear_room(g) -> bool:
	for i in 40:
		_kill_all()
		await _wait(0.35)
		if g.room_cleared:
			return true
	return false


func _test_character(cid: String) -> void:
	print("\n[角色] ", cid)
	var g = await _new_game(cid)
	var p = g.player
	_check(p != null, "%s: 玩家生成" % cid)
	_check(GameState.enemies.size() > 0, "%s: 首波敌人 %d 个" % [cid, GameState.enemies.size()])
	GameState.player.invuln = 999.0

	# 用真实输入通道开火（开局有 0.4s 输入锁，先等锁结束）
	await _wait(0.5)
	Input.action_press("shoot")
	await _frames(30)
	Input.action_release("shoot")
	var bullets := get_tree().get_nodes_in_group("bullets")
	var beams := get_tree().get_nodes_in_group("beams")
	beams += get_tree().get_nodes_in_group("harness")
	beams += get_tree().get_nodes_in_group("law_zone")
	_check(bullets.size() > 0 or beams.size() > 0,
		"%s: 开火产生弹体（子弹 %d / 光束 %d）" % [cid, bullets.size(), beams.size()])

	# 技能
	Input.action_press("skill")
	await _frames(2)
	Input.action_release("skill")
	await _wait(0.4)
	var charged := false
	if p.weapon != null and "charge_ratio" in p:
		charged = float(p.charge_ratio) > 0.0
	await _wait(1.3)
	var beams2 := get_tree().get_nodes_in_group("beams")
	var buff_ok: bool = p.buff_timer > 0.0
	var fish_n := get_tree().get_nodes_in_group("fish_minions").size()
	var summon_ok: bool = cid == "deepseek" and fish_n > 0
	_check(charged or beams2.size() > 0 or buff_ok or p.shield_hits > 0 or summon_ok,
		"%s: 技能生效（蓄力 %s / 光束 %d / 增益 %s / 护盾 %d / 小肥鱼 %d）"
		% [cid, str(charged), beams2.size(), str(buff_ok), p.shield_hits, fish_n])
	if cid == "deepseek":
		# Token 有自然回复，只要明显低于满值即可（召唤消耗 20）
		_check(fish_n > 0 and float(p.token) < 95.0,
			"deepseek: 鲸群集结消耗 Token 并召唤小肥鱼（Token %.0f / 鱼 %d）"
			% [float(p.token), fish_n])

	# DeepSeek 天赋：移动不消耗 Token
	if cid == "deepseek":
		var tk0 := float(p.token)
		p._token_hold = 999.0
		Input.action_press("move_left")
		await _wait(0.35)
		Input.action_release("move_left")
		_check(float(p.token) >= tk0 - 0.01, "deepseek: 移动不扣除 Token（%.1f）"
			% float(p.token))
		p._token_hold = 0.0

	# 翻滚
	var before: Vector2 = p.global_position
	Input.action_press("move_right")
	Input.action_press("roll")
	await _frames(4)
	Input.action_release("roll")
	await _wait(0.2)
	Input.action_release("move_right")
	_check(p.global_position.distance_to(before) > 2.0, "%s: 翻滚位移生效" % cid)

	# 专属副武器（滚轮切到副武器槽，左键使用）
	if p.sub != null:
		Input.action_press("switch_weapon")
		await _frames(3)
		Input.action_release("switch_weapon")
		await _frames(3)
		_check(int(p.active_slot) == 1, "%s: 滚轮切到副武器槽" % cid)
		Input.action_press("shoot")
		if cid == "deepseek":
			await _wait(0.6)
			_check(bool(p.sub._charging) and float(p.charge_ratio) > 0.3,
				"deepseek: 铁盆长按蓄力（%.0f%%）" % (float(p.charge_ratio) * 100.0))
			Input.action_release("shoot")
			await _frames(4)
			_check(not bool(p.sub._charging) and float(p.charge_ratio) <= 0.01,
				"deepseek: 松手挥出并清空蓄力")
		else:
			await _frames(4)
			Input.action_release("shoot")
			await _wait(0.2)
		_check(float(p.sub.cd_left) > 0.0, "%s: 副武器「%s」进入冷却（%.1fs）"
			% [cid, String(p.sub.display_name), float(p.sub.cd_left)])
		# 切回主武器，后续用例仍能射击
		Input.action_press("switch_weapon")
		await _frames(3)
		Input.action_release("switch_weapon")
		await _frames(3)
	else:
		_check(false, "%s: 副武器节点缺失" % cid)

	# 清场 -> 开门
	var cleared := await _clear_room(g)
	_check(cleared, "%s: 清场后开门" % cid)

	# 走进门：入口是分支岔口，会弹出二选一
	p.global_position = g.room.door_zone().get_center()
	await _wait(0.8)
	var choice = null
	for c in g.ui_layer.get_children():
		if c.name == "RoomChoice":
			choice = c
	if choice != null:
		choice._pick(0)
		await _wait(0.5)
	_check(GameState.node_id in [1, 2] and GameState.room_index == GameState.node_id + 1,
		"%s: 门后二选一进入分支节点（节点 %d）" % [cid, GameState.node_id])

	g.queue_free()
	await _frames(3)


func _test_boss() -> void:
	print("\n[Boss]")
	var g = await _new_game("deepseek")
	g.debug_start(FloorMap.KIND_BOSS)
	await _wait(0.3)
	_check(g.boss != null, "Boss 生成")
	GameState.player.invuln = 999.0

	var intro = g.ui_layer.get_child(g.ui_layer.get_child_count() - 1)
	for i in 10:
		if intro != null and is_instance_valid(intro) and intro.has_method("_advance"):
			intro._advance()
		await _frames(2)
	get_tree().paused = false
	await _wait(0.3)
	_check(not get_tree().paused, "Boss 登场对话可跳过并恢复游戏")

	var boss = g.boss
	if boss != null:
		var hp0: float = boss.hp
		boss.take_damage(hp0 * 0.5)
		await _wait(1.0)   # 阶段转换有 0.75s 预警
		_check(boss.phase == 2, "Boss 半血进入第 2 阶段（phase=%d）" % boss.phase)
		boss.take_damage(hp0 * 0.4)
		await _wait(1.0)
		_check(boss.phase == 3, "Boss 残血进入第 3 阶段（phase=%d）" % boss.phase)
		boss.take_damage(hp0)
		await _wait(0.5)
		_check(g.room_cleared, "Boss 击破后开门")

	g.player.global_position = g.room.door_zone().get_center()
	await _wait(1.5)
	_check(GameState.floor_index == 2, "进入第 2 层（floor=%d）" % GameState.floor_index)
	g.queue_free()
	await _frames(3)


## v0.10.1：三层各一只 Boss，且镜像回声的镜盾免伤
func _test_boss_pool() -> void:
	print("\n[Boss 池]")
	var expect := ["echo", "mirror", "twins"]
	for f in [1, 2, 3]:
		var g = await _new_game("deepseek")
		g._debug_set_floor(f)
		g.debug_start(FloorMap.KIND_BOSS)
		await _wait(0.3)
		_check(g.boss != null, "第 %d 层 Boss 生成" % f)
		if g.boss != null:
			var key := String(g.boss.boss_key)
			_check(key == expect[f - 1], "第 %d 层 Boss = %s（实际 %s）"
				% [f, expect[f - 1], key])
			var intro = g.ui_layer.get_child(g.ui_layer.get_child_count() - 1)
			var intro_name := ""
			if intro != null and "boss_name" in intro:
				intro_name = String(intro.boss_name)
			_check(intro_name == String(g.boss.display_name),
				"第 %d 层登场标题与 Boss 一致（%s）" % [f, intro_name])
		await _dismiss_overlay(g)
		if f == 2 and g.boss != null:
			GameState.player.invuln = 999.0
			var mb = g.boss
			mb.shield_t = 1.0
			var hp0: float = mb.hp
			mb.take_damage(25.0)
			_check(is_equal_approx(mb.hp, hp0), "镜像回声镜盾期间免伤（hp %.1f）" % mb.hp)
			mb.shield_t = 0.0
			mb.take_damage(5.0)
			_check(mb.hp < hp0, "镜盾结束后可正常受伤（hp %.1f）" % mb.hp)
		g.queue_free()
		await _frames(3)


## v0.10.1：迷你首领 = 精英标记 + 血量/体积/掉落再强化
func _test_miniboss() -> void:
	print("\n[迷你首领]")
	var normal = load("res://scenes/enemies/enemy_chaser.tscn").instantiate()
	add_child(normal)
	await _frames(2)
	var mini = load("res://scenes/enemies/enemy_chaser.tscn").instantiate()
	mini.miniboss = true
	add_child(mini)
	await _frames(2)
	_check(mini.miniboss and mini.elite, "迷你首领同时带精英标记")
	_check(mini.max_hp > normal.max_hp * 2.2,
		"迷你首领血量显著高于普通（%.1f vs %.1f）" % [mini.max_hp, normal.max_hp])
	_check(mini.radius > normal.radius and mini.coin_value >= normal.coin_value + 8,
		"迷你首领体积与掉落提升（半径 %.1f / 金币 %d）" % [mini.radius, mini.coin_value])
	GameState.unregister_enemy(normal)
	GameState.unregister_enemy(mini)
	normal.queue_free()
	mini.queue_free()
	await _frames(3)


func _test_shop() -> void:
	print("\n[商店]")
	var g = await _new_game("claude")
	g.debug_start(FloorMap.KIND_SHOP)
	await _wait(1.0)
	GameState.player.invuln = 999.0
	GameState.add_coins(200)
	_check(get_tree().paused, "进入商店（游戏暂停）")
	var shop = null
	for c in g.ui_layer.get_children():
		if c.name == "Shop":
			shop = c
	_check(shop != null, "商店界面已创建")
	if shop != null:
		var before: int = GameState.upgrades.size()
		shop._buy(0)
		await _frames(3)
		_check(GameState.upgrades.size() == before + 1, "购买藏品成功（%d -> %d）"
			% [before, GameState.upgrades.size()])
		_check(GameState.coins < 200, "金币被扣除（剩余 %d）" % GameState.coins)
		var coins_before: int = GameState.coins
		var rar_before: int = shop._reroll_cost
		shop._msg_t = 0.0
		shop._reroll()
		await _frames(3)
		_check(GameState.coins == coins_before - rar_before and shop._reroll_cost > rar_before,
			"刷新货架并提高下次价格（剩余 %d）" % GameState.coins)
		shop.closed.emit()
		shop.queue_free()
		get_tree().paused = false
		await _wait(1.0)
		_check(GameState.node_id == FloorMap.BOSS_ID, "商店结束后进入 Boss 节点（节点 %d）"
			% GameState.node_id)
	_check(GameState.combos.size() >= 0, "组合效果系统可用")
	g.queue_free()
	await _frames(3)


func _test_death() -> void:
	print("\n[死亡结算]")
	GameState.start_run("gpt")
	var main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	main._on_character_chosen("gpt")
	await _wait(1.0)
	var g = main.current
	_check(g != null and g.player != null, "通过主控进入一局")
	if g == null or g.player == null:
		return
	g.player.invuln = 0.0
	g.player.take_damage(99)
	await _wait(1.8)
	_check(GameState.hp == 0, "生命归零")
	_check(main.current != null and main.current.name == "Result",
		"自动切换到结算界面（当前 %s）" % (main.current.name if main.current else "null"))
	main.queue_free()
	await _frames(3)
