extends Node
## 专武测试：强制装备专武后射击 8 秒，统计伤害

const TargetScript = preload("res://scripts/fx/training_target.gd")
const SECONDS := 8.0
var results: Array = []


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _run() -> void:
	for cid in ["deepseek", "gpt", "claude"]:
		GameState.start_run(cid)
		var g = load("res://scenes/main/game.tscn").instantiate()
		add_child(g)
		await _frames(5)
		for k in 10:
			var top = g.ui_layer.get_child(g.ui_layer.get_child_count() - 1)
			if top != null and is_instance_valid(top) and top.has_method("_advance"):
				top._advance()
			await _frames(2)
		get_tree().paused = false
		var p = g.player
		p.invuln = 9999.0
		g.busy = true
		for e in GameState.enemies.duplicate():
			if is_instance_valid(e):
				e.queue_free()
		GameState.enemies.clear()
		await _frames(2)
		var ok: bool = p.equip_weapon(GameState.char_data.exclusive_path)
		await _frames(2)
		var targets: Array = []
		for off in [Vector2(90, -16), Vector2(90, -40), Vector2(90, 20)]:
			var t = TargetScript.new()
			t.position = p.global_position + off
			g.add_child(t)
			targets.append(t)
		Input.action_press("aim_right")
		Input.action_press("shoot")
		await _wait(SECONDS)
		Input.action_release("shoot")
		Input.action_release("aim_right")
		await _frames(4)
		var hits := 0
		var dmg := 0.0
		for t in targets:
			if is_instance_valid(t):
				hits += int(t.hits)
				dmg += float(t.damage_taken)
		print("[%s] 专武 equip=%s 命中=%d 伤害=%.1f DPS=%.1f" %
			[cid, str(ok), hits, dmg, dmg / SECONDS])
		g.queue_free()
		await _frames(4)
	get_tree().quit()
