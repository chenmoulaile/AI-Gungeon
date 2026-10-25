extends Control
## 首局地面提示（v0.7 P2 像素版）：键帽 + 像素提示条 + 1px 指示线
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
	tw.tween_property(self, "_fade", 0.0, 0.18)


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
		var cx := GameConfig.BASE_W * 0.5
		var r := Rect2(cx - 100, 262, 200, 48)
		UiKit.frame(self, r, Color(UiKit.DEEP.r, UiKit.DEEP.g, UiKit.DEEP.b, 0.94 * a),
			Color(UiKit.BORDER.r, UiKit.BORDER.g, UiKit.BORDER.b, a),
			Color(UiKit.BORDER_HI.r, UiKit.BORDER_HI.g, UiKit.BORDER_HI.b, a), true)
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2),
			Color(UiKit.CYAN.r, UiKit.CYAN.g, UiKit.CYAN.b, a))
		if step == 0:
			_caps(cx, r.position.y + 6, ["W", "A", "S", "D"], a)
			UiKit.text_center(self, cx, r.position.y + 33, "移动", UiKit.F_SMALL,
				Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, a))
			UiKit.text_center(self, cx, r.position.y + 45, "先走两步", UiKit.F_SMALL,
				Color(UiKit.TEXT_DIM.r, UiKit.TEXT_DIM.g, UiKit.TEXT_DIM.b, a))
		else:
			_caps(cx, r.position.y + 6, ["L"], a)
			UiKit.text_center(self, cx, r.position.y + 33, "左键射击", UiKit.F_SMALL,
				Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, a))
			UiKit.text_center(self, cx, r.position.y + 45, "瞄准并开火", UiKit.F_SMALL,
				Color(UiKit.TEXT_DIM.r, UiKit.TEXT_DIM.g, UiKit.TEXT_DIM.b, a))
	if _mark != null and is_instance_valid(_mark) and _mark_t > 0.0:
		var xf := get_viewport().get_canvas_transform()
		var sp: Vector2 = xf * (_mark.global_position + Vector2(0, -24))
		sp = sp.round()
		var ma: float = clampf(_mark_t / 0.4, 0.0, 1.0)
		# 像素菱形指示
		var col := Color(UiKit.GOLD.r, UiKit.GOLD.g, UiKit.GOLD.b, ma)
		draw_rect(Rect2(sp.x - 2, sp.y - 5, 4, 10), col)
		draw_rect(Rect2(sp.x - 5, sp.y - 2, 10, 4), col)
		draw_rect(Rect2(sp.x - 3, sp.y - 3, 6, 6), Color(UiKit.SHADOW.r, UiKit.SHADOW.g,
			UiKit.SHADOW.b, ma))
		draw_rect(Rect2(sp.x - 1, sp.y - 1, 2, 2), col)
		# 1px 指示线
		var line_y := sp.y + 7
		while line_y < sp.y + 40:
			draw_line(Vector2(sp.x, line_y), Vector2(sp.x, line_y + 3),
				Color(col.r, col.g, col.b, ma * 0.8), 1.0)
			line_y += 6


func _caps(cx: float, y: float, labels: Array, a: float) -> void:
	var total: float = labels.size() * 16.0 + maxf(0.0, labels.size() - 1) * 3.0
	var x := roundf(cx - total * 0.5)
	for l in labels:
		var r := Rect2(x, y, 16, 16)
		draw_rect(Rect2(r.position + Vector2(0, 1), r.size), Color(0, 0, 0, 0.5 * a))
		draw_rect(r, Color(UiKit.RAISED.r, UiKit.RAISED.g, UiKit.RAISED.b, a))
		draw_rect(r, Color(UiKit.BORDER_HI.r, UiKit.BORDER_HI.g, UiKit.BORDER_HI.b, a),
			false, 1.0)
		UiKit.text_center(self, r.get_center().x, r.position.y + 12, String(l), UiKit.F_SMALL,
			Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, a))
		x += 19.0
