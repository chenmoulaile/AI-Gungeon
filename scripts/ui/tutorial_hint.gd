extends Control
## 首局引导（非模态，不暂停游戏）
## 1) 第一个房间：地面半透明提示"WASD 移动"→"左键射击"，做出动作后自动消失
## 2) 第一次遇到远程敌人：在它头顶显示 1.5s 的"！"

var step: int = 0          # 0 移动 / 1 射击 / 2 完成
var _move_from: Vector2 = Vector2.ZERO
var _has_move: bool = false
var _ranged_seen: bool = false
var _mark = null
var _mark_t: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func on_room_start(index: int) -> void:
	if index != 1 or GameState.floor_index != 1:
		return
	var p = GameState.player
	if p != null and is_instance_valid(p):
		_move_from = p.global_position
		_has_move = true


func on_room_cleared() -> void:
	if step < 2:
		step = 2
		Settings.tutorial_done = true
		Settings.save_settings()


func _process(delta: float) -> void:
	_t += delta
	if _mark_t > 0.0:
		_mark_t -= delta
		if _mark_t <= 0.0:
			_mark = null

	var p = GameState.player
	if step == 0 and _has_move and p != null and is_instance_valid(p):
		if p.global_position.distance_to(_move_from) > 44.0:
			step = 1
	elif step == 1:
		if get_tree().get_nodes_in_group("bullets").size() > 0:
			step = 2
			Settings.tutorial_done = true
			Settings.save_settings()

	if not _ranged_seen:
		for e in GameState.enemies:
			if not is_instance_valid(e):
				continue
			if "pattern" in e or "ring_mode" in e:
				_mark = e
				_mark_t = 1.5
				_ranged_seen = true
				break

	if step < 2 or _mark != null:
		queue_redraw()


func _draw() -> void:
	if step == 0:
		_hint_box(Vector2(GameConfig.BASE_W * 0.5, GameConfig.BASE_H - 74), "WASD 移动")
	elif step == 1:
		_hint_box(Vector2(GameConfig.BASE_W * 0.5, GameConfig.BASE_H - 74), "鼠标左键射击")
	if _mark != null and is_instance_valid(_mark) and _mark_t > 0.0:
		var xf := get_viewport().get_canvas_transform()
		var sp: Vector2 = xf * (_mark.global_position + Vector2(0, -22))
		var a: float = clampf(_mark_t / 0.4, 0.0, 1.0)
		var bounce: float = sin(_t * 9.0) * 1.5
		draw_circle(sp + Vector2(0, bounce), 8.0, Color(1.0, 0.35, 0.4, 0.85 * a))
		if GameConfig.ui_font != null:
			draw_string(GameConfig.ui_font, sp + Vector2(-2.5, 3.5 + bounce), "!",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, a))


func _hint_box(center: Vector2, text: String) -> void:
	var w := 116.0
	var h := 20.0
	var r := Rect2(center - Vector2(w * 0.5, h), Vector2(w, h))
	draw_rect(r, Color(0.05, 0.07, 0.11, 0.72))
	draw_rect(r, Color(0.55, 0.72, 1.0, 0.35), false, 1.0)
	if GameConfig.ui_font == null:
		return
	var tw: float = GameConfig.ui_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(GameConfig.ui_font, center + Vector2(-tw * 0.5, -4), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.95, 1.0, 0.92))
