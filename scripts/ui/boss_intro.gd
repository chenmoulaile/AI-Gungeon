extends Control
## Boss 登场（v0.7 P2）：像素菱形剪影 + 8 段像素环 + 打字机台词
## 说明：Boss 没有参考立绘，这里用与战斗内一致的几何风格放大渲染，不引入外部素材

signal finished

const DEFAULT_LINES := [
	"三个助手的推理回响，在这个房间里聚成了一个实体。",
	"它没有名字，只有你刚才打出的每一发子弹的记忆。",
	"清空它，才能进入下一层。",
]

var boss_name: String = "回响聚合体"
var subtitle: String = "ECHO AGGREGATE"
var lines: Array = DEFAULT_LINES
var accent: Color = Color("#8E6AC8")

var line_index: int = 0
var typed: float = 0.0
var speed: float = 30.0
var _t: float = 0.0
var _done: bool = false


## 由 game.gd 在加入场景前传入：名称 / 副标题 / 台词 / 主色
func setup(cfg: Dictionary) -> void:
	if cfg.is_empty():
		return
	boss_name = String(cfg.get("name", boss_name))
	subtitle = String(cfg.get("subtitle", subtitle))
	var cfg_lines = cfg.get("lines", null)
	if cfg_lines is Array and not (cfg_lines as Array).is_empty():
		lines = cfg_lines
	accent = cfg.get("color", accent)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Sfx.play("boss")


func _process(delta: float) -> void:
	_t += delta
	if not _done and line_index < lines.size():
		var full: String = lines[line_index]
		if typed < float(full.length()):
			typed = minf(float(full.length()), typed + speed * delta)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
			_advance()
			get_viewport().set_input_as_handled()


func _advance() -> void:
	if _done:
		return
	var full: String = lines[line_index] if line_index < lines.size() else ""
	if typed < float(full.length()):
		typed = float(full.length())
		return
	line_index += 1
	typed = 0.0
	if line_index >= lines.size():
		_done = true
		finished.emit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), Color(0.02, 0.01, 0.04, 0.96))
	UiKit.dither_rect(self, Rect2(0, 0, GameConfig.BASE_W, 36), Color(0.10, 0.02, 0.16, 0.8), 2)
	UiKit.dither_rect(self, Rect2(0, GameConfig.BASE_H - 36, GameConfig.BASE_W, 36),
		Color(0.10, 0.02, 0.16, 0.8), 2)
	UiKit.scanlines(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), 0.06)

	var center := Vector2(GameConfig.BASE_W * 0.5, 150)
	# 8 段像素环（两层，反向旋转）
	for k in 2:
		var radius := 62.0 + k * 14.0
		var dir := 1.0 if k == 0 else -0.6
		for i in 8:
			var a := TAU * float(i) / 8.0 + _t * 0.5 * dir
			var p := center + Vector2(cos(a), sin(a)) * radius
			var s := 4 if k == 0 else 3
			draw_rect(Rect2((p - Vector2(s, s) * 0.5).round(), Vector2(s, s)),
				Color(accent.r, accent.g, accent.b, 0.42 - k * 0.14))
	# 核心剪影：硬边像素菱形（颜色跟随当前 Boss）
	_pixel_diamond(center, 46, 38, UiKit.SHADOW)
	_pixel_diamond(center, 44, 36, accent.darkened(0.66))
	_pixel_diamond(center, 32, 26, accent.darkened(0.38))
	_pixel_diamond(center, 20, 16, accent.lightened(0.26))
	# 眼
	draw_rect(Rect2(center.x - 9, center.y - 4, 18, 8), UiKit.WHITE)
	draw_rect(Rect2(center.x - 3, center.y - 4, 6, 8), Color("#160A22"))
	draw_rect(Rect2(center.x - 2, center.y - 3, 2, 2), Color(1, 1, 1, 0.9))

	UiKit.text_center(self, center.x, 40, boss_name, UiKit.F_H2, UiKit.GOLD)
	UiKit.text_center(self, center.x, 56, subtitle, UiKit.F_SMALL, accent.lightened(0.18))

	var box := Rect2(80, GameConfig.BASE_H - 92, GameConfig.BASE_W - 160, 76)
	UiKit.frame(self, box, Color(0.05, 0.04, 0.07, 0.96), accent.darkened(0.45),
		accent, true)
	var full: String = lines[line_index] if line_index < lines.size() else ""
	var shown: String = full.substr(0, int(typed))
	UiKit.text_block(self, box.position + Vector2(14, 24), shown, box.size.x - 28,
		UiKit.F_BODY, UiKit.TEXT, 4)
	if fmod(_t, 0.9) < 0.55:
		UiKit.text_right(self, box.end.x - 14, box.end.y - 8, "空格 / 点击 继续",
			UiKit.F_SMALL, UiKit.TEXT_DIM)


func _pixel_diamond(c: Vector2, rx: int, ry: int, col: Color) -> void:
	for dy in range(-ry, ry + 1):
		var w := int(round(float(rx) * (1.0 - float(absf(float(dy))) / float(ry))))
		if w <= 0:
			continue
		draw_line(Vector2(c.x - w, c.y + dy), Vector2(c.x + w + 1, c.y + dy), col, 1.0)
