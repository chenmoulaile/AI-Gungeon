extends Node
## 设置（Autoload）：音量 / 震动强度 / 全屏 / 按键重映射（键盘+手柄）/ 高对比弹幕 / 手柄震动

signal changed

const PATH := "user://settings.cfg"

var master_volume: float = 1.0
var sfx_volume: float = 0.8
var music_volume: float = 0.6
var shake_scale: float = 0.7
var fullscreen: bool = false
var high_contrast: bool = false
var tutorial_done: bool = false
var vibration: bool = true
var difficulty: int = 1

## action -> {"device": "key" | "mouse" | "joy_button" | "joy_axis", "code": int, "dir": int}
var bindings: Dictionary = {}

const DEFAULT_BINDINGS := {
	"move_left": {"device": "key", "code": KEY_A},
	"move_right": {"device": "key", "code": KEY_D},
	"move_up": {"device": "key", "code": KEY_W},
	"move_down": {"device": "key", "code": KEY_S},
	"shoot": {"device": "mouse", "code": MOUSE_BUTTON_LEFT},
	"roll": {"device": "key", "code": KEY_SPACE},
	"skill": {"device": "key", "code": KEY_E},
	"switch_mode": {"device": "key", "code": KEY_R},
}

## 手柄绑定单独一张表，和键盘互不覆盖（var 以便重映射）
var PAD_BINDINGS := {
	"move_left": {"device": "joy_axis", "code": 0, "dir": -1},
	"move_right": {"device": "joy_axis", "code": 0, "dir": 1},
	"move_up": {"device": "joy_axis", "code": 1, "dir": -1},
	"move_down": {"device": "joy_axis", "code": 1, "dir": 1},
	"aim_left": {"device": "joy_axis", "code": 2, "dir": -1},
	"aim_right": {"device": "joy_axis", "code": 2, "dir": 1},
	"aim_up": {"device": "joy_axis", "code": 3, "dir": -1},
	"aim_down": {"device": "joy_axis", "code": 3, "dir": 1},
	"shoot": {"device": "joy_axis", "code": 5, "dir": 1},
	"roll": {"device": "joy_button", "code": 0, "dir": 1},
	"skill": {"device": "joy_button", "code": 2, "dir": 1},
	"switch_mode": {"device": "joy_button", "code": 3, "dir": 1},
	"pause": {"device": "joy_button", "code": 6, "dir": 1},
}

const PAD_ACTIONS := ["move_left", "move_right", "move_up", "move_down",
	"aim_left", "aim_right", "aim_up", "aim_down",
	"shoot", "roll", "skill", "switch_mode", "pause"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bindings = DEFAULT_BINDINGS.duplicate(true)
	load_settings()
	apply_all()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = float(cfg.get_value("audio", "master", master_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	music_volume = float(cfg.get_value("audio", "music", music_volume))
	shake_scale = float(cfg.get_value("video", "shake", shake_scale))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	high_contrast = bool(cfg.get_value("video", "high_contrast", high_contrast))
	vibration = bool(cfg.get_value("video", "vibration", vibration))
	difficulty = int(cfg.get_value("game", "difficulty", difficulty))
	tutorial_done = bool(cfg.get_value("misc", "tutorial_done", tutorial_done))
	var saved = cfg.get_value("input", "bindings", null)
	if saved is Dictionary:
		for k in saved.keys():
			if bindings.has(k):
				bindings[k] = saved[k]


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("video", "shake", shake_scale)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "high_contrast", high_contrast)
	cfg.set_value("video", "vibration", vibration)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("misc", "tutorial_done", tutorial_done)
	cfg.set_value("input", "bindings", bindings)
	cfg.save(PATH)


func apply_all() -> void:
	apply_audio()
	apply_video()
	apply_bindings()
	changed.emit()


func apply_audio() -> void:
	var m := AudioServer.get_bus_index("Master")
	var s := AudioServer.get_bus_index("SFX")
	if m >= 0:
		AudioServer.set_bus_volume_db(m, linear_to_db(maxf(0.0001, master_volume)))
	if s >= 0:
		AudioServer.set_bus_volume_db(s, linear_to_db(maxf(0.0001, sfx_volume)))
	if is_inside_tree() and MusicManager != null:
		MusicManager.refresh_bus()
	changed.emit()


func apply_video() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func apply_bindings() -> void:
	for action in bindings.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		InputMap.action_set_deadzone(action, 0.25)
		var b: Dictionary = bindings[action]
		match String(b.get("device", "key")):
			"mouse":
				var ev := InputEventMouseButton.new()
				ev.button_index = int(b["code"])
				InputMap.action_add_event(action, ev)
			"key":
				var ev2 := InputEventKey.new()
				ev2.physical_keycode = int(b["code"])
				InputMap.action_add_event(action, ev2)
	_add_extra("move_left", KEY_LEFT)
	_add_extra("move_right", KEY_RIGHT)
	_add_extra("move_up", KEY_UP)
	_add_extra("move_down", KEY_DOWN)
	apply_pad_bindings()


## 手柄事件是"附加"的：不覆盖键盘
func apply_pad_bindings() -> void:
	for action in PAD_BINDINGS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_set_deadzone(action, 0.25)
		var b: Dictionary = PAD_BINDINGS[action]
		# 先移除同类手柄事件，避免重复叠加
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				InputMap.action_erase_event(action, ev)
		if String(b.get("device", "")) == "joy_axis":
			var m := InputEventJoypadMotion.new()
			m.axis = int(b["code"])
			m.axis_value = float(b.get("dir", 1))
			InputMap.action_add_event(action, m)
		else:
			var btn := InputEventJoypadButton.new()
			btn.button_index = int(b["code"])
			InputMap.action_add_event(action, btn)


func _add_extra(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == keycode:
			return
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	InputMap.action_add_event(action, e)


func rebind(action: String, device: String, code: int) -> void:
	bindings[action] = {"device": device, "code": code}
	apply_bindings()
	save_settings()


func rebind_pad(action: String, device: String, code: int, dir: int = 1) -> void:
	PAD_BINDINGS[action] = {"device": device, "code": code, "dir": dir}
	apply_pad_bindings()
	save_settings()


func set_shake(value: float) -> void:
	shake_scale = clampf(value, 0.0, 1.0)
	GameFeel.shake_scale = shake_scale
	save_settings()


func key_label(action: String) -> String:
	if not bindings.has(action):
		return "-"
	var b: Dictionary = bindings[action]
	if String(b.get("device", "key")) == "mouse":
		return "鼠标%d" % int(b["code"])
	return OS.get_keycode_string(int(b["code"]))


func pad_label(action: String) -> String:
	if not PAD_BINDINGS.has(action):
		return "-"
	var b: Dictionary = PAD_BINDINGS[action]
	var names := {0: "A", 1: "B", 2: "X", 3: "Y", 4: "LB", 5: "RB",
		6: "Start", 7: "Select", 8: "L3", 9: "R3"}
	var nm: String = String(names.get(int(b["code"]), "键%d" % int(b["code"])))
	if String(b.get("device", "")) == "joy_axis":
		var axis := int(b["code"])
		var axis_names := {0: "左摇杆X", 1: "左摇杆Y", 2: "右摇杆X", 3: "右摇杆Y",
			4: "LT", 5: "RT"}
		var label: String = String(axis_names.get(axis, "轴%d" % axis))
		return "%s%s" % [label, "＋" if int(b.get("dir", 1)) > 0 else "－"]
	return nm
