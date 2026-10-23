extends Node
## 输入缓冲（Autoload）：按键按下后 0.10s 内仍然有效
## 翻滚与射击共用同一套窗口，避免各角色脚本各写计时器

const WINDOW := 0.10

var _expire: Dictionary = {}   # action -> 过期时间（秒）


func _process(_delta: float) -> void:
	if _expire.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for k in _expire.keys():
		if float(_expire[k]) <= now:
			_expire.erase(k)


func press(action: String) -> void:
	_expire[action] = Time.get_ticks_msec() / 1000.0 + WINDOW


func peek(action: String) -> bool:
	if not _expire.has(action):
		return false
	return float(_expire[action]) > Time.get_ticks_msec() / 1000.0


func consume(action: String) -> bool:
	if not peek(action):
		_expire.erase(action)
		return false
	_expire.erase(action)
	return true


func clear(action: String) -> void:
	_expire.erase(action)


func clear_all() -> void:
	_expire.clear()
