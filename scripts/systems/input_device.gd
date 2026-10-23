extends Node
## 最后使用的输入设备（Autoload）：键鼠 / 手柄，只在检测到对应输入时切换

signal device_changed(using_pad: bool)

var using_pad: bool = false


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_apply_device(true)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.25:
			_apply_device(true)
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		_apply_device(false)


func _apply_device(v: bool) -> void:
	if v == using_pad:
		return
	using_pad = v
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if v else Input.MOUSE_MODE_VISIBLE
	device_changed.emit(v)


func label(key_hint: String, pad_hint: String) -> String:
	return pad_hint if using_pad else key_hint
