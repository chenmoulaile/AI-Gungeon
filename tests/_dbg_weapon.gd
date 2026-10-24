extends Node
func _ready() -> void:
	GameState.start_run("gpt")
	var g = load("res://scenes/main/game.tscn").instantiate()
	add_child(g)
	await get_tree().process_frame
	await get_tree().process_frame
	for k in 12:
		var top = g.ui_layer.get_child(g.ui_layer.get_child_count() - 1)
		if top != null and is_instance_valid(top) and top.has_method("_advance"):
			top._advance()
		await get_tree().process_frame
	get_tree().paused = false
	var p = g.player
	print("weapon=", p.weapon, " script=", p.weapon.get_script() if p.weapon else null)
	print("mode=", p.weapon.mode if p.weapon else -1)
	p.invuln = 9999.0
	Input.action_press("aim_right")
	Input.action_press("shoot")
	for i in 8:
		await get_tree().create_timer(0.25).timeout
		var live := 0
		for b in get_tree().get_nodes_in_group("bullets"):
			if b.visible:
				live += 1
		print("t=%.2f live_bullets=%d cooldown=%.3f" % [i * 0.25, live, p.weapon.cooldown])
	get_tree().quit()
