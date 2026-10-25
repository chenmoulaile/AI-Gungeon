extends Node
## 台词调度（Autoload）：只读 resources/dialogue/*.tres，代码里不存台词
## 阻塞对白交给调用方暂停；低血量/Boss 入场用非阻塞小条

const DIR := "res://resources/dialogue"
const IDS := ["deepseek", "gpt", "claude"]
const PortraitScene = preload("res://scenes/ui/portrait_dialog.tscn")

var _data: Dictionary = {}
var _layer: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in IDS:
		var path := "%s/%s.tres" % [DIR, id]
		# 导出包里 .tres 会被重映射成 .res，直接 load，不做 exists 判断
		var res = load(path)
		if res == null:
			continue
		var raw = res.get("intro_text")
		if raw != null and String(raw) != "":
			_data[id] = res


func get_dialogue(char_id: String):
	return _data.get(char_id, null)


func lines(char_id: String, key: String) -> PackedStringArray:
	var d = get_dialogue(char_id)
	if d == null:
		return PackedStringArray()
	const FIELDS := {
		"intro": "intro_text",
		"boss": "boss_enter_text",
		"low_hp": "low_health_text",
		"death": "death_text",
		"victory": "victory_text",
	}
	var field: String = FIELDS.get(key, "")
	if field == "":
		return PackedStringArray()
	var v = d.get(field)
	if v == null:
		return PackedStringArray()
	var raw := String(v)
	var out := PackedStringArray()
	for line in raw.split("\n", false):
		var t := line.strip_edges()
		if t != "":
			out.append(t)
	return out


## 随机取一条；空表返回空串
func pick(char_id: String, key: String) -> String:
	var arr := lines(char_id, key)
	if arr.is_empty():
		return ""
	return arr[randi() % arr.size()]


func display_name(char_id: String) -> String:
	if GameState.char_data != null and GameState.char_id == char_id:
		return GameState.char_data.display_name
	var d := GameState.load_character(char_id)
	return d.display_name if d != null else char_id


## 非阻塞台词条：不暂停游戏，播完自动淡出
func say(char_id: String, key: String, hold: float = 2.2) -> void:
	var text := pick(char_id, key)
	if text == "":
		return
	say_text(char_id, text, hold)


func say_text(char_id: String, text: String, hold: float = 2.2) -> void:
	var layer := _ui()
	if layer == null:
		return
	var dlg = PortraitScene.instantiate()
	dlg.non_blocking = true
	dlg.auto_delay = hold
	layer.add_child(dlg)
	var portrait := "res://assets/portraits/%s_pixel.png" % char_id
	if not ResourceLoader.exists(portrait):
		portrait = "res://assets/portraits/%s_full.png" % char_id
	var avatar := "res://assets/portraits/%s_pixel_avatar.png" % char_id
	dlg.setup(portrait, display_name(char_id), [text], avatar)


## 清掉所有非阻塞台词条（切场景 / 打开商店时调用，避免盖住面板）
func clear() -> void:
	if _layer == null or not is_instance_valid(_layer):
		return
	for c in _layer.get_children():
		c.queue_free()


func _ui() -> CanvasLayer:
	if _layer != null and is_instance_valid(_layer) and _layer.is_inside_tree():
		return _layer
	var scene := get_tree().current_scene
	if scene == null:
		return null
	_layer = CanvasLayer.new()
	_layer.layer = 60
	scene.add_child(_layer)
	return _layer
