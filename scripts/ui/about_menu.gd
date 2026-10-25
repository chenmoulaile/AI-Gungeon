extends Control
## 关于页（v0.9）：项目说明 / 操作 / 授权 / 原作链接。
## Enter、空格、ESC 均可返回；按钮可鼠标点击。

signal closed

const URL := "https://www.bilibili.com/video/BV1gVHA6mEbS/"
const PANEL := Rect2(48, 34, 544, 292)

var _t: float = 0.0
var _closed: bool = false
var _link_btn: BaButton = null
var _back_btn: BaButton = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modulate.a = 0.0
	_build_buttons()
	BaCursor.set_battle(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.14)


func _build_buttons() -> void:
	_link_btn = BaButton.new()
	add_child(_link_btn)
	_link_btn.setup("B站原作", Rect2(PANEL.end.x - 208, PANEL.end.y - 32, 96, 22),
		"ghost", "", UiKit.F_BODY)
	_link_btn.pressed.connect(_open_link)

	_back_btn = BaButton.new()
	add_child(_back_btn)
	_back_btn.setup("返回", Rect2(PANEL.end.x - 104, PANEL.end.y - 32, 88, 22),
		"primary", "", UiKit.F_BODY)
	_back_btn.pressed.connect(_close)


func _open_link() -> void:
	OS.shell_open(URL)
	Sfx.play("ui", -10.0)


func _close() -> void:
	if _closed:
		return
	_closed = true
	Sfx.play("ui", -8.0)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE]:
			_close()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		# 点在面板外也返回，避免“关于页卡住”
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_close()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	UiKit.gradient_backdrop(self, Rect2(0, 0, GameConfig.BASE_W, GameConfig.BASE_H), _t)
	UiKit.panel(self, PANEL, UiKit.DEEP)

	# 标题
	UiKit.text(self, PANEL.position + Vector2(20, 34), "关于", 36, UiKit.CYAN)
	UiKit.text_right(self, PANEL.end.x - 20, PANEL.position.y + 24,
		"AI GUNGEON · v%s" % str(ProjectSettings.get_setting(
			"application/config/version", "0.9.0")), 12, UiKit.TEXT_DIM)
	draw_rect(Rect2(PANEL.position + Vector2(20, 44), Vector2(PANEL.size.x - 40, 1)),
		UiKit.BORDER)
	draw_rect(Rect2(PANEL.position + Vector2(20, 44), Vector2(64, 1)), UiKit.CYAN)

	var x := PANEL.position.x + 20
	var y := PANEL.position.y + 70
	var w := PANEL.size.x - 40

	UiKit.text(self, Vector2(x, y), "非官方同人 · 像素地牢 Roguelike", 12, UiKit.TEXT)
	UiKit.text(self, Vector2(x, y + 20),
		"三个 AI 模型化身地牢角色：DeepSeek / GPT / Claude。", 12, UiKit.TEXT_DIM)
	UiKit.text(self, Vector2(x, y + 34),
		"清空 5 个房间，击破回响聚合体，向下深入三层。", 12, UiKit.TEXT_DIM)

	# 分栏：左右各 248px，避免长句压到另一列
	var mid_y := y + 58
	draw_rect(Rect2(x, mid_y, w, 1), UiKit.BORDER)
	var col1 := x
	var col2 := x + 272.0

	UiKit.text(self, Vector2(col1, mid_y + 20), "素材与授权", 12, UiKit.GOLD)
	UiKit.text(self, Vector2(col1, mid_y + 38),
		"角色形象：B站 UP 主 ZipZipPipe 二创", 12, UiKit.TEXT_DIM)
	UiKit.text(self, Vector2(col1, mid_y + 52),
		"协议：CC BY-NC-SA 4.0 · 非商用", 12, UiKit.TEXT_DIM)
	UiKit.text(self, Vector2(col1, mid_y + 66),
		"大肥鱼设定：BV1gVHA6mEbS", 12, UiKit.TEXT_DIM)
	UiKit.text(self, Vector2(col1, mid_y + 80),
		"角色设计 @苏沐沐_Official", 12, UiKit.TEXT_DIM)
	UiKit.text(self, Vector2(col1, mid_y + 94),
		"铁盆 @锦上川__", 12, UiKit.TEXT_DIM)

	UiKit.text(self, Vector2(col2, mid_y + 20), "操作", 12, UiKit.GOLD)
	UiKit.text(self, Vector2(col2, mid_y + 38),
		"WASD 移动 · 鼠标瞄准 · 左键射击", 12, UiKit.TEXT_DIM)
	UiKit.text(self, Vector2(col2, mid_y + 52),
		"Q 副武器 · E 技能 · 空格翻滚", 12, UiKit.TEXT_DIM)
	UiKit.text(self, Vector2(col2, mid_y + 66),
		"ESC 暂停 · Enter 确认 / 下一步", 12, UiKit.TEXT_DIM)
	UiKit.text(self, Vector2(col2, mid_y + 80),
		"DeepSeek：Q 铁盆长按蓄力", 12, UiKit.TEXT_DIM)
	UiKit.text(self, Vector2(col2, mid_y + 94),
		"菜单 F 开始 · W/S 选择", 12, UiKit.TEXT_DIM)

	# 底部状态条：感谢语与返回提示分居两侧，按钮在下一行
	var foot_y := PANEL.end.y - 64
	draw_rect(Rect2(x, foot_y, w, 1), UiKit.BORDER)
	var blink := UiKit.CYAN if fmod(_t, 1.4) < 0.9 else UiKit.BORDER_HI
	UiKit.text(self, Vector2(x, foot_y + 18), "> 感谢游玩，愿你每次深入都能活着回来。", 12, blink)
	UiKit.text_right(self, PANEL.end.x - 20, foot_y + 18, "Enter / ESC 返回", 12,
		UiKit.TEXT_DIM)
