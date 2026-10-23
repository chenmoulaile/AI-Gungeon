extends Control
## 首局地面提示（非模态）：第一间房显示「WASD 移动 / 左键射击」，做出动作后消失
## 只在没完成训练场、且没看过提示时出现；状态写入 meta.cfg 的 tutorial 节

var step: int = 0
var _start_pos: Vector2 = Vector2.ZERO
var _armed: bool = false
var _t: float = 0.0
var _fade: float = 1.0
var _ranged_seen: bool = false
var _mark = null
var _mark_t: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if MetaProgress.tutorial_flag("room_hint_done"):
		step = 3
		set_process(false)
	set_process(true)


func on_room_start(index: int) -> void:
	if index != 1 or GameState.floor_index != 1:
		return
	var p = GameState.player
	if p != null and is_instance_valid(p):
		_start_pos = p.global_position
		_armed = true


func on_room_cleared() -> void:
	if step < 3:
		_finish()


func _finish() -> void:
	step = 3
	MetaProgress.set_tutorial_flag("room_hint_done")
	var tw := create_tween()
	tw.tween_property(self, "_fade", 0.0, 0.25)


func _process(delta: float) -> void:
	_t += delta
	if _mark_t > 0.0:
		_mark_t -= delta
		if _mark_t <= 0.0:
			_mark = null
	var p = GameState.player
	if not _armed or p == null or not is_instance_valid(p):
		return
	if step == 0 and p.global_position.distance_to(_start_pos) > 36.0:
		step = 1
		Sfx.play("ui", -10.0, 1.3)
	elif step == 1 and (p.fire_anim > 0.0 or Input.is_action_pressed("shoot")):
		_finish()
	if not _ranged_seen:
		for e in GameState.enemies:
			if is_instance_valid(e) and ("pattern" in e or "ring_mode" in e):
				_mark = e
				_mark_t = 1.5
				_ranged_seen = true
				break
	queue_redraw()


func _draw() -> void:
	if _fade <= 0.0:
		return
	var a: float = _fade * clampf(_t * 2.0, 0.0, 1.0)
	if step < 3:
		var txt := "WASD 移动" if step == 0 else "左键射击"
		var sub := "先走两步" if step == 0 else "瞄准并开火"
		var cx := GameConfig.BASE_W * 0.5
		var cy := GameConfig.BASE_H - 66.0
		var r := Rect2(cx - 76, cy - 14, 152, 30)
		draw_style_box(UiKit.box(Color(1, 1, 1, 0.86 * a), 10, Color(1, 1, 1, 0.9 * a), 1, true), r)
		UiKit.text_center(self, cx, cy, txt, UiKit.F_H3,
			Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, a))
		UiKit.text_center(self, cx, cy + 11, sub, UiKit.F_TINY,
			Color(UiKit.TEXT_DIM.r, UiKit.TEXT_DIM.g, UiKit.TEXT_DIM.b, a))
	if _mark != null and is_instance_valid(_mark) and _mark_t > 0.0:
		var xf := get_viewport().get_canvas_transform()
		var sp: Vector2 = xf * (_mark.global_position + Vector2(0, -24))
		var ma: float = clampf(_mark_t / 0.4, 0.0, 1.0)
		var bounce: float = sin(_t * 9.0) * 1.5
		draw_circle(sp + Vector2(0, bounce), 8.0, Color(0.95, 0.35, 0.35, 0.85 * ma))
		UiKit.text_center(self, sp.x, sp.y + bounce + 3.5, "!", UiKit.F_SMALL,
			Color(1, 1, 1, ma))
