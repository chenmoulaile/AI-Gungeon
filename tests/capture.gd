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
	await _shot("battle")
	Input.action_release("shoot")

	# 副武器
	Input.action_press("sub_weapon")
	await _frames(6)
	Input.action_release("sub_weapon")
	await _frames(8)
	await _shot("subweapon")

	# 技能：蓄力到释放的瞬间
	Input.action_press("skill")
	await _frames(2)
	Input.action_release("skill")
	await _frames(92)
	await _shot("skill_beam")

	# 三层主题
	GameState.floor_index = 1
	g._start_room(1)
	await _wait(1.6)
	await _shot("floor1")
	GameState.floor_index = 2
	g._start_room(1)
	await _wait(1.6)
	await _shot("floor2")
	GameState.floor_index = 3
	g._start_room(1)
	await _wait(1.6)
	await _shot("floor3")
	# 层间转场卡片
	var card = load("res://scripts/ui/floor_card.gd").new()
	card.setup(2)
	g.ui_layer.add_child(card)
	await _wait(0.55)
	await _shot("floor_card")
	card.queue_free()

	# Boss 房（沿用第 3 层主题的强化版）
	g._start_room(5)
	await _frames(20)
	await _shot("boss_intro")
	await _close_overlay(g)
	await _frames(30)
	await _shot("boss_fight")

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

	# 训练场引导
	main.show_training()
	await _wait(0.8)
	await _shot("training")

	get_tree().quit()
