extends Node
## 设置（Autoload）：音量 / 震动强度 / 全屏 / 按键重映射 / 高对比弹幕 / 引导标记
## 保存到 user://settings.cfg，启动时读取并应用

const PATH := "user://settings.cfg"

var master_volume: float = 1.0
var sfx_volume: float = 0.8
var music_volume: float = 0.6
var shake_scale: float = 0.7
var fullscreen: bool = false
var high_contrast: bool = false
var tutorial_done: bool = false

## action -> {"device": "key" | "mouse", "code": int}
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
	cfg.set_value("misc", "tutorial_done", tutorial_done)
	cfg.set_value("input", "bindings", bindings)
	cfg.save(PATH)


func apply_all() -> void:
	apply_audio()
	apply_video()
	apply_bindings()


func apply_audio() -> void:
	if Engine.has_singleton("AudioServer") or true:
		var m := AudioServer.get_bus_index("Master")
		var s := AudioServer.get_bus_index("SFX")
		var mu := AudioServer.get_bus_index("Music")
		if m >= 0:
			AudioServer.set_bus_volume_db(m, linear_to_db(maxf(0.0001, master_volume)))
		if s >= 0:
			AudioServer.set_bus_volume_db(s, linear_to_db(maxf(0.0001, sfx_volume)))
		if mu >= 0:
			AudioServer.set_bus_volume_db(mu, linear_to_db(maxf(0.0001, music_volume)))


func apply_video() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func apply_bindings() -> void:
	for action in bindings.keys():
		var b: Dictionary = bindings[action]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		if String(b.get("device", "key")) == "mouse":
			var ev := InputEventMouseButton.new()
			ev.button_index = int(b["code"])
			InputMap.action_add_event(action, ev)
		else:
			var ev2 := InputEventKey.new()
			ev2.physical_keycode = int(b["code"])
			InputMap.action_add_event(action, ev2)
	# 移动键同时保留方向键
	_add_extra("move_left", KEY_LEFT)
	_add_extra("move_right", KEY_RIGHT)
	_add_extra("move_up", KEY_UP)
	_add_extra("move_down", KEY_DOWN)


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
