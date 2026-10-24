extends Node
## 武器自动测试：三个角色各自动射击 N 秒，统计命中数与总伤害
## 运行：godot --headless --path . res://tests/weapon_test.tscn

const TargetScript = preload("res://scripts/fx/training_target.gd")
const SECONDS := 10.0

var results: Array = []


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _close_overlay(g) -> void:
	for k in 12:
		var top = g.ui_layer.get_child(g.ui_layer.get_child_count() - 1)
		if top != null and is_instance_valid(top) and top.has_method("_advance"):
			top._advance()
		await _frames(2)
	get_tree().paused = false
	await _frames(3)


func _run() -> void:
	for cid in ["deepseek", "gpt", "claude"]:
		await _test(cid)
	print("\n================ 武器测试 ================")
	for r in results:
		print("%-9s 命中 %4d  总伤害 %8.1f  DPS %6.1f  武器 %s" %
			[r["id"], r["hits"], r["dmg"], r["dmg"] / SECONDS, r["weapon"]])
	print("=========================================")
	get_tree().quit(0)


func _test(cid: String) -> void:
	GameState.start_run(cid)
	var g = load("res://scenes/main/game.tscn").instantiate()
	add_child(g)
	await _frames(5)
	await _close_overlay(g)
	var p = g.player
	p.invuln = 9999.0
	g.busy = true
	for e in GameState.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	GameState.enemies.clear()
	await _frames(2)

	var targets: Array = []
	for off in [Vector2(100, -16), Vector2(100, -40), Vector2(100, 20)]:
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
	results.append({"id": cid, "hits": hits, "dmg": dmg,
		"weapon": String(p.weapon.get_script().resource_path.get_file()) if p.weapon != null else "无"})
	print("[%s] hits=%d dmg=%.1f" % [cid, hits, dmg])
	g.queue_free()
	await _frames(4)
