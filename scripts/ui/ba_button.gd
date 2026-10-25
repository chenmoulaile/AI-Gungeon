class_name BaButton
extends Control
## 像素按钮（v0.7 P2）：硬边 1px 边框 + 2px 硬阴影 + 金色角括号。
## 变体：primary（青框深底）/ secondary / ghost / danger。
## 按下只下沉 1px，不做缩放/圆角/柔和阴影。

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
var _down: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("ui_hotspot")
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)


func setup(text: String, r: Rect2, kind: String = "secondary", icon: String = "",
		fs: int = UiKit.F_BODY) -> BaButton:
	label = text
	position = r.position.round()
	size = r.size.round()
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
	queue_redraw()
	Sfx.play("ui_hover", -14.0)


func _on_exit() -> void:
	_hover = false
	_down = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_down = true
			queue_redraw()
			Sfx.play("ui", -6.0)
		else:
			if _down and _hover:
				pressed.emit()
			_down = false
			queue_redraw()
		accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := UiKit.BTN_NORMAL
	var fg := UiKit.TEXT
	var border := UiKit.BORDER
	match variant:
		"primary":
			bg = Color("#1D3A4A")
			fg = UiKit.CYAN
			border = UiKit.CYAN
		"ghost":
			bg = Color(0.10, 0.14, 0.24, 0.72)
			fg = UiKit.TEXT
			border = UiKit.BORDER
		"danger":
			bg = Color("#3A1B26")
			fg = UiKit.DANGER
			border = UiKit.DANGER
	if disabled:
		bg = UiKit.BTN_OFF
		fg = Color("#4A5468")
		border = Color("#242B3C")
	elif _hover:
		bg = UiKit.BTN_HOVER
		fg = UiKit.GOLD if variant != "danger" else UiKit.DANGER
		border = UiKit.GOLD if variant != "danger" else UiKit.DANGER
	var off := Vector2(0, 1) if (_down and not disabled) else Vector2.ZERO
	var rr := Rect2(off, size - off)
	draw_rect(Rect2(rr.position + Vector2(2, 2), rr.size), UiKit.SHADOW)
	draw_rect(rr, bg)
	draw_rect(rr, border, false, 1.0)
	draw_line(rr.position + Vector2(1, 1), Vector2(rr.end.x - 2, rr.position.y + 1),
		Color(1, 1, 1, 0.10 if not disabled else 0.03))
	if _hover and not disabled:
		UiKit.corner_brackets(self, rr.grow(-1), UiKit.GOLD, 4)

	var tx := rr.size.x * 0.5
	var has_icon := icon_path != "" and UiKit.icon(icon_path) != null
	if has_icon:
		var isz := minf(rr.size.y - 10.0, 16.0)
		var iy := (rr.size.y - isz) * 0.5
		draw_texture_rect(UiKit.icon(icon_path), Rect2(Vector2(8, iy).round(), Vector2(isz, isz)), false)
		tx = 8.0 + isz + (rr.size.x - isz - 8.0) * 0.5

	var ty := rr.size.y * 0.5 + font_size * 0.36
	if sub_label != "":
		ty -= 3.0
	UiKit.text_center(self, tx, ty, label, font_size, fg)
	if sub_label != "":
		UiKit.text_center(self, rr.size.x * 0.5, ty + font_size, sub_label,
			UiKit.F_TINY, Color(fg.r, fg.g, fg.b, 0.6))
