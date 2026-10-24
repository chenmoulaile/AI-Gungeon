extends SceneTree
## 把输入动作写进 project.godot（保证 Web 端在运行时脚本执行前就存在）
## 运行：godot --headless --path . --script tools/setup_input.gd

func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _mouse(btn: int) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	return e


func _init() -> void:
	var acts := {
		"move_left": [_key(KEY_A), _key(KEY_LEFT)],
		"move_right": [_key(KEY_D), _key(KEY_RIGHT)],
		"move_up": [_key(KEY_W), _key(KEY_UP)],
		"move_down": [_key(KEY_S), _key(KEY_DOWN)],
		"aim_left": [_key(KEY_J)],
		"aim_right": [_key(KEY_L)],
		"aim_up": [_key(KEY_I)],
		"aim_down": [_key(KEY_K)],
		"roll": [_key(KEY_SPACE), _mouse(MOUSE_BUTTON_RIGHT)],
		"skill": [_key(KEY_E)],
		"sub_weapon": [_key(KEY_Q)],
		"switch_mode": [_key(KEY_R)],
		"restart": [_key(KEY_F5)],
		"pause": [_key(KEY_ESCAPE)],
		"shoot": [_mouse(MOUSE_BUTTON_LEFT)],
		"select_1": [_key(KEY_1)],
		"select_2": [_key(KEY_2)],
		"select_3": [_key(KEY_3)],
	}
	for a in acts.keys():
		var evs: Array = []
		for e in acts[a]:
			evs.append(e)
		ProjectSettings.set_setting("input/" + String(a), {"deadzone": 0.5, "events": evs})
	var err := ProjectSettings.save()
	print("input actions saved: ", err)
	quit()
