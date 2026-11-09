extends Node2D
## 伤害数字（由 GameFeel 对象池管理）

var value: float = 0.0
var text: String = ""
var crit: bool = false
## 文字色覆盖：a=0 表示未指定，_draw 回退到暴击金/普通白
var _text_color: Color = Color(0, 0, 0, 0)
var _tw: Tween = null


## color 为可选透传（M2："+1" 传 GOLD）；不传时保持暴击金/普通白默认
func show_text(pos: Vector2, s: String, color: Color = Color(0, 0, 0, 0)) -> void:
	text = s
	show_number(pos, 0.0, false)
	_text_color = color


func show_number(pos: Vector2, amount: float, is_crit: bool) -> void:
	_text_color = Color(0, 0, 0, 0)   # 池化复用：先回默认，show_text 再按需上色
	global_position = pos
	if text == "":
		value = amount
	else:
		value = 0.0
	crit = is_crit
	visible = true
	set_process(true)
	scale = Vector2.ONE
	modulate = Color(1, 1, 1, 1)
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	# 上浮（回弹缓动）-> 下坠（加速）-> 淡出
	_tw.tween_property(self, "position", position + Vector2(0, -16), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position", position + Vector2(0, -8), 0.28)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.parallel().tween_property(self, "modulate:a", 0.0, 0.42)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.tween_callback(func() -> void: GameFeel.release_number(self))
	queue_redraw()


func _draw() -> void:
	if GameConfig.ui_font == null:
		return
	var txt := text if text != "" else str(int(round(value)))
	var size := 14 if crit else 12
	var col := _text_color if _text_color.a > 0.0 \
		else (Color(1.0, 0.86, 0.35) if crit else Color(0.94, 0.97, 1.0))
	var w: float = GameConfig.ui_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(-w * 0.5, 0)
	draw_string(GameConfig.ui_font, p + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1,
		size, Color(0, 0, 0, 0.75))
	draw_string(GameConfig.ui_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
