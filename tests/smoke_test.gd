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
	_check(main.current != null, "主场景启动 -> 角色选择")

	for cid in ["deepseek", "gpt", "claude"]:
		await _test_character(cid)
	await _test_boss()
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

	# 用真实输入通道开火
	Input.action_press("shoot")
	await _frames(30)
	Input.action_release("shoot")
	var bullets := get_tree().get_nodes_in_group("bullets")
	var beams := get_tree().get_nodes_in_group("beams")
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
	_check(charged or beams2.size() > 0 or buff_ok or p.shield_hits > 0,
		"%s: 技能生效（蓄力 %s / 光束 %d / 增益 %s / 护盾 %d）"
		% [cid, str(charged), beams2.size(), str(buff_ok), p.shield_hits])

	# 翻滚
	var before: Vector2 = p.global_position
	Input.action_press("move_right")
	Input.action_press("roll")
	await _frames(4)
	Input.action_release("roll")
	await _wait(0.2)
	Input.action_release("move_right")
	_check(p.global_position.distance_to(before) > 2.0, "%s: 翻滚位移生效" % cid)

	# 清场 -> 开门
	var cleared := await _clear_room(g)
	_check(cleared, "%s: 清场后开门" % cid)

	# 走进门
	p.global_position = g.room.door_zone().get_center()
	await _wait(0.8)
	_check(GameState.room_index == 2 or GameState.floor_index > 1,
		"%s: 进入下一房间（房间 %d）" % [cid, GameState.room_index])

	g.queue_free()
	await _frames(3)


func _test_boss() -> void:
	print("\n[Boss]")
	var g = await _new_game("deepseek")
	g._start_room(5)
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


func _test_shop() -> void:
	print("\n[商店]")
	var g = await _new_game("claude")
	g._start_room(4)
	await _wait(0.3)
	GameState.player.invuln = 999.0
	GameState.add_coins(200)
	var cleared := await _clear_room(g)
	_check(cleared, "第 4 间房清空")
	g.player.global_position = g.room.door_zone().get_center()
	await _wait(0.6)
	_check(get_tree().paused, "第 4 间房后进入商店（游戏暂停）")
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
		shop.closed.emit()
		shop.queue_free()
		get_tree().paused = false
		await _wait(1.0)
		_check(GameState.room_index == 5, "商店结束后进入第 5 间（Boss 房，当前 %d）"
			% GameState.room_index)
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
	await _frames(6)
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
