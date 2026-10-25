extends Node

func _ready() -> void:
	GameState.start_run("deepseek")
	var g = load("res://scenes/main/game.tscn").instantiate()
	add_child(g)
	await get_tree().process_frame
	await get_tree().process_frame
	# 关掉开场对话
	for k in 12:
		var top = g.ui_layer.get_child(g.ui_layer.get_child_count() - 1)
		if top != null and is_instance_valid(top) and top.has_method("_advance"):
			top._advance()
		await get_tree().process_frame
	get_tree().paused = false
	await get_tree().process_frame
	print("start room=", GameState.room_index, " paused=", get_tree().paused)
	g.debug_start(FloorMap.KIND_BOSS)
	await get_tree().create_timer(0.5).timeout
	# 关 Boss 登场
	for k in 14:
		var top2 = g.ui_layer.get_child(g.ui_layer.get_child_count() - 1)
		if top2 != null and is_instance_valid(top2) and top2.has_method("_advance"):
			top2._advance()
		await get_tree().process_frame
	get_tree().paused = false
	await get_tree().create_timer(0.5).timeout
	print("boss room alive=", g.alive_count, " boss=", g.boss)
	if g.boss != null and is_instance_valid(g.boss):
		g.boss.take_damage(99999.0, Vector2.ZERO, "heavy", false, "test")
	await get_tree().create_timer(1.2).timeout
	print("after kill alive=", g.alive_count, " cleared=", g.room_cleared,
		" door=", g.room.door_open if g.room != null else "no room",
		" paused=", get_tree().paused, " busy=", g.busy)
	# 走到门口
	if g.player != null and is_instance_valid(g.player):
		g.player.global_position = g.room.door_zone().get_center()
	await get_tree().create_timer(3.0).timeout
	print("after door floor=", GameState.floor_index, " room=", GameState.room_index,
		" paused=", get_tree().paused, " busy=", g.busy,
		" player_visible=", g.player.visible if g.player != null else "no player")
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://tests/_shot_boss_after.png"))
	get_tree().quit()
