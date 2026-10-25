extends Node
## 敌人视觉验收截图：一屏摆 9 种敌人，第 2/3 层各一张
## 运行：godot --path . res://tests/enemy_shot.tscn

const SCENES := {
	"chaser": "res://scenes/enemies/enemy_chaser.tscn",
	"shooter": "res://scenes/enemies/enemy_shooter.tscn",
	"spreader": "res://scenes/enemies/enemy_spreader.tscn",
	"charger": "res://scenes/enemies/enemy_charger.tscn",
	"ring": "res://scenes/enemies/enemy_ring_shooter.tscn",
	"summoner": "res://scenes/enemies/enemy_summoner.tscn",
	"shield": "res://scenes/enemies/enemy_shield_bearer.tscn",
	"splitter": "res://scenes/enemies/enemy_splitter.tscn",
	"sniper": "res://scenes/enemies/enemy_sniper.tscn",
}


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
	img.save_png(ProjectSettings.globalize_path("res://tests/_shot_%s.png" % name))
	print("saved ", name)


func _run() -> void:
	GameState.start_run("deepseek")
	var g = load("res://scenes/main/game.tscn").instantiate()
	add_child(g)
	await _frames(5)
	for k in 12:
		var top = g.ui_layer.get_child(g.ui_layer.get_child_count() - 1)
		if top != null and is_instance_valid(top) and top.has_method("_advance"):
			top._advance()
		await _frames(2)
	get_tree().paused = false
	await _frames(3)
	g.player.invuln = 9999.0
	g.busy = true
	for e in GameState.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	GameState.enemies.clear()
	await _frames(2)

	for floor_i in [2, 3]:
		GameState.floor_index = floor_i
		g.debug_start("")
		g.busy = true
		await _frames(2)
		for e in GameState.enemies.duplicate():
			if is_instance_valid(e):
				e.queue_free()
		GameState.enemies.clear()
		g.player.global_position = Vector2(140, 270)
		var i := 0
		for key in SCENES.keys():
			var e = load(String(SCENES[key])).instantiate()
			var col := i % 3
			var row := int(i / 3)
			e.position = Vector2(300 + col * 120, 130 + row * 105)
			g.add_child(e)
			e.set_physics_process(false)
			e.set_process(false)
			i += 1
		await _wait(0.8)
		await _shot("enemies_f%d" % floor_i)

	get_tree().quit()
