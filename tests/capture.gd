extends Node
## 截图工具（仅用于开发自检，不参与游戏流程）
## 运行：godot --path . res://tests/capture.tscn

func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://tests/_shot_%s.png" % name)
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


## 关掉栈顶的打字机界面
func _close_overlay(g) -> void:
	for k in 14:
		var top = g.ui_layer.get_child(g.ui_layer.get_child_count() - 1)
		if top != null and is_instance_valid(top) and top.has_method("_advance"):
			top._advance()
		await _frames(2)
	get_tree().paused = false
	await _frames(3)


func _run() -> void:
	var main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	await _frames(6)
	await _shot("splash")
	await _wait(2.0)
	await _shot("menu")

	main.show_select()
	await _frames(24)
	await _shot("select")

	main._on_character_chosen("deepseek")
	await _wait(1.1)
	var g = main.current
	await _shot("intro_dialog")
	await _close_overlay(g)

	GameState.player.invuln = 999.0
	Input.action_press("move_right")
	Input.action_press("shoot")
	await _frames(30)
	Input.action_release("move_right")
	await _frames(16)
	# 无敌闪烁会把角色压到 alpha 0.35，截图里看起来像"褪色"，截图前先关掉
	GameState.player.invuln = 0.0
	await _frames(2)
	await _shot("battle")
	GameState.player.invuln = 999.0
	Input.action_release("shoot")

	# 副武器：滚轮切到铁盆，左键蓄力
	Input.action_press("switch_weapon")
	await _frames(4)
	Input.action_release("switch_weapon")
	await _frames(4)
	Input.action_press("shoot")
	await _frames(24)
	await _shot("subweapon")
	Input.action_release("shoot")
	await _frames(6)
	Input.action_press("switch_weapon")
	await _frames(4)
	Input.action_release("switch_weapon")
	await _frames(4)

	# 技能：蓄力到释放的瞬间
	Input.action_press("skill")
	await _frames(2)
	Input.action_release("skill")
	await _frames(92)
	await _shot("skill_beam")

	# 三层主题
	GameState.floor_index = 1
	g._debug_set_floor(1)
	await _wait(1.6)
	await _shot("floor1")
	GameState.floor_index = 2
	g._debug_set_floor(2)
	await _wait(1.6)
	await _shot("floor2")
	GameState.floor_index = 3
	g._debug_set_floor(3)
	await _wait(1.6)
	await _shot("floor3")
	# 层间转场卡片
	var card = load("res://scripts/ui/floor_card.gd").new()
	card.setup(2)
	g.ui_layer.add_child(card)
	await _wait(0.55)
	await _shot("floor_card")
	card.queue_free()

	# Boss 房：第 1 层回响聚合体
	GameState.floor_index = 1
	g._debug_set_floor(1)
	g.debug_start(FloorMap.KIND_BOSS)
	await _frames(20)
	await _shot("boss_intro")
	await _close_overlay(g)
	await _frames(30)
	await _shot("boss_fight")
	DialogueManager.clear()

	# B2 镜像回声：等镜盾展开再截
	GameState.floor_index = 2
	g._debug_set_floor(2)
	g.debug_start(FloorMap.KIND_BOSS)
	await _frames(20)
	await _shot("boss_mirror_intro")
	await _close_overlay(g)
	await _wait(3.2)
	await _shot("boss_mirror_fight")
	DialogueManager.clear()

	# B3 双生回响
	GameState.floor_index = 3
	g._debug_set_floor(3)
	g.debug_start(FloorMap.KIND_BOSS)
	await _frames(20)
	await _shot("boss_twins_intro")
	await _close_overlay(g)
	await _wait(2.2)
	await _shot("boss_twins_fight")
	DialogueManager.clear()

	# 事件房三选一
	g.debug_start(FloorMap.KIND_EVENT)
	await _wait(0.7)
	await _shot("event_room")
	for c in g.ui_layer.get_children():
		if c.name == "EventRoom":
			c._skip()
	await _wait(0.5)

	# 门后二选一
	GameState.node_id = FloorMap.START_ID
	GameState.room_index = FloorMap.START_ID + 1
	g.busy = false
	g._show_choice()
	await _wait(0.5)
	await _shot("room_choice")
	for c in g.ui_layer.get_children():
		if c.name == "RoomChoice":
			c._pick(0)
	await _wait(0.6)

	# 暂停菜单
	var pm = load("res://scripts/ui/pause_menu.gd").new()
	pm.process_mode = Node.PROCESS_MODE_ALWAYS
	g.ui_layer.add_child(pm)
	get_tree().paused = true
	await _wait(0.3)
	await _shot("pause")
	get_tree().paused = false
	pm.queue_free()

	# 商店
	GameState.add_coins(300)
	g._open_shop()
	await _wait(0.6)
	await _shot("shop")
	get_tree().paused = false

	# 结算
	GameState.kills = 37
	GameState.add_upgrade("sharp_round")
	GameState.add_upgrade("crit_lens")
	main._on_run_over()
	await _wait(0.9)
	await _shot("result")

	# 图鉴 / 设置
	main.show_collection()
	await _frames(20)
	await _shot("collection")
	main.open_settings()
	await _frames(20)
	await _shot("settings")
	# 设置是 110 层的覆盖层，不关掉会挡住后面的训练场截图
	if main._settings != null and is_instance_valid(main._settings):
		main._settings.closed.emit()
	await _frames(4)

	# 训练场引导
	main.show_training()
	await _wait(0.8)
	await _shot("training")

	# 三个角色的配饰近景（鲸尾 / 龙翼 / 向日葵）
	for cid in ["deepseek", "gpt", "claude"]:
		main._on_character_chosen(cid)
		await _wait(1.2)
		await _close_overlay(main.current)
		GameState.player.invuln = 0.0
		await _frames(8)
		await _shot("accent_" + cid)

	# 先回主菜单把训练场释放掉，再退出：带着满场景直接 quit 会触发渲染资源泄漏崩溃
	main.show_menu()
	await _wait(1.2)
	get_tree().quit()
