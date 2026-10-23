extends Node
## 截图工具（仅用于开发自检，不参与游戏流程）
## 运行：godot --path . res://tests/capture.tscn

func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


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
	await _frames(20)
	await _shot("select")

	main._on_character_chosen("deepseek")
	await _frames(12)
	var g = main.current
	await _shot("intro_dialog")
	await _close_overlay(g)

	GameState.player.invuln = 999.0
	Input.action_press("move_right")
	Input.action_press("shoot")
	await _frames(40)
	Input.action_release("move_right")
	await _frames(20)
	await _shot("battle")
	Input.action_release("shoot")

	# 技能：蓄力到释放的瞬间
	Input.action_press("skill")
	await _frames(2)
	Input.action_release("skill")
	await _wait_frames(92)
	await _shot("skill_beam")

	# Boss 房
	g._start_room(5)
	await _frames(20)
	await _shot("boss_intro")
	await _close_overlay(g)
	await _frames(30)
	await _shot("boss_fight")

	# 商店
	GameState.add_coins(300)
	g._open_shop()
	await _frames(10)
	await _shot("shop")
	get_tree().paused = false

	# 结算
	GameState.kills = 37
	GameState.add_upgrade("sharp_round")
	GameState.add_upgrade("crit_lens")
	main._on_run_over()
	await _frames(10)
	await _shot("result")

	get_tree().quit()


func _wait_frames(n: int) -> void:
	await _frames(n)
