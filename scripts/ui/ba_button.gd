class_name BaButton
extends Control
## 蔚蓝档案风格按钮：圆角浅蓝底 + 悬停放大 1.03 + 按下回弹 0.97，全部走 Tween
## 变体：primary（强调色实心）/ secondary（浅蓝）/ ghost（透明描边）/ danger（红）

signal pressed

var label: String = ""
var sub_label: String = ""
var icon_path: String = ""
var variant: String = "secondary"
var font_size: int = UiKit.F_BODY
var disabled: bool = false:
	set(v):
		disabled = v
		queue_redraw()

var _hover: bool = false
var _hover_k: float = 0.0
var _down: bool = false
var _scale_tw: Tween = null
var _hover_tw: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	add_to_group("ui_hotspot")
	pivot_offset = size * 0.5
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func setup(text: String, r: Rect2, kind: String = "secondary", icon: String = "",
		fs: int = UiKit.F_BODY) -> BaButton:
	label = text
	position = r.position
	size = r.size
	variant = kind
	icon_path = icon
	font_size = fs
	return self


func _process(_delta: float) -> void:
	if _hover:
		queue_redraw()


func _on_enter() -> void:
	if disabled:
		return
	_hover = true
	_tween_hover(1.0)
	_tween_scale(1.03, 0.10, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	Sfx.play("ui_hover", -14.0)


func _on_exit() -> void:
	_hover = false
	_down = false
	_tween_hover(0.0)
	_tween_scale(1.0, 0.10, Tween.TRANS_CUBIC, Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_down = true
			_tween_scale(0.97, 0.06, Tween.TRANS_CUBIC, Tween.EASE_OUT)
			Sfx.play("ui", -6.0)
		else:
			_down = false
			_tween_scale(1.03 if _hover else 1.0, 0.12, Tween.TRANS_BACK, Tween.EASE_OUT)
			if _hover:
				pressed.emit()
		accept_event()


func _tween_scale(target: float, dur: float, trans: int, ease: int) -> void:
	if _scale_tw != null and _scale_tw.is_valid():
		_scale_tw.kill()
	_scale_tw = create_tween()
	_scale_tw.tween_property(self, "scale", Vector2(target, target), dur)\
		.set_trans(trans).set_ease(ease)


func _tween_hover(target: float) -> void:
	if _hover_tw != null and _hover_tw.is_valid():
		_hover_tw.kill()
	_hover_tw = create_tween()
	_hover_tw.tween_property(self, "_hover_k", target, 0.10)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := UiKit.BTN_NORMAL
	var fg := UiKit.TEXT
	var border := Color(1, 1, 1, 0.85)
	var radius := 8
	match variant:
		"primary":
			bg = UiKit.ACCENT
			fg = UiKit.TEXT_LIGHT
			border = Color(1, 1, 1, 0.35)
		"ghost":
			bg = Color(1, 1, 1, 0.42)
			fg = UiKit.TEXT
			border = Color(1, 1, 1, 0.9)
		"danger":
			bg = UiKit.DANGER
			fg = UiKit.TEXT_LIGHT
			border = Color(1, 1, 1, 0.35)
		_:
			pass
	if disabled:
		bg = UiKit.BTN_OFF
		fg = Color(1, 1, 1, 0.75)
		border = Color(1, 1, 1, 0.4)
	elif variant != "primary" and variant != "danger":
		bg = bg.lerp(UiKit.BTN_HOVER, _hover_k * 0.85)
	elif _hover_k > 0.0:
		bg = bg.lerp(UiKit.ACCENT_HOVER, _hover_k * 0.55)
	if _down and not disabled:
		bg = bg.lerp(UiKit.ACCENT_DEEP, 0.35)
	draw_style_box(UiKit.box(bg, radius, border, 1, not disabled), r)

	var tx := r.size.x * 0.5
	var has_icon := icon_path != "" and UiKit.icon(icon_path) != null
	if has_icon:
		var isz := minf(r.size.y - 8.0, 16.0)
		var iy := (r.size.y - isz) * 0.5
		draw_texture_rect(UiKit.icon(icon_path), Rect2(Vector2(8, iy), Vector2(isz, isz)), false)
		tx = 8.0 + isz + (r.size.x - isz - 8.0) * 0.5

	var ty := r.size.y * 0.5 + font_size * 0.36
	if sub_label != "":
		ty -= 2.0
	UiKit.text_center(self, tx, ty, label, font_size, fg)
	if sub_label != "":
		UiKit.text_center(self, r.size.x * 0.5, ty + font_size + 1.0, sub_label,
			UiKit.F_TINY, Color(fg.r, fg.g, fg.b, 0.75))
