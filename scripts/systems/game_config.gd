extends Node
## 全局配置与通用工具（autoload）
## 约定：常量全大写，函数 snake_case，中文注释

# ---------------- 分辨率与房间 ----------------
const BASE_W := 640
const BASE_H := 360
const ROOM_W := 960.0
const ROOM_H := 540.0
const WALL := 14.0
const SPRITE_FRAME := 64

# ---------------- 玩家手感 ----------------
const PLAYER_SPEED := 120.0
const ROLL_SPEED := 330.0
const ROLL_TIME := 0.25
const ROLL_CD := 0.8
const INVULN_TIME := 1.0
const PLAYER_RADIUS := 7.0

# ---------------- 配色 ----------------
const COL_BG := Color("#0b0d13")
const COL_FLOOR_A := Color("#202839")
const COL_FLOOR_B := Color("#2c3549")
const COL_FLOOR_LINE := Color("#39445c")
const COL_WALL := Color("#2b3244")
const COL_WALL_TOP := Color("#3a4359")
const COL_DOOR := Color("#f2b53c")
const COL_TEXT := Color("#e8ecf6")
const COL_DIM := Color("#8b93a8")
const COL_FRIEND := Color("#8ee6ff")
const COL_ENEMY := Color("#ff6b8b")
const COL_GOLD := Color("#ffd166")
const COL_HP := Color("#ff5d7a")

# 角色主题色（界面与特效使用）
const CHAR_COLORS := {
	"deepseek": Color("#5f86f0"),
	"gpt": Color("#b09cf0"),
	"claude": Color("#f0904a"),
}

var ui_font: Font = null
var ui_theme: Theme = null


func _ready() -> void:
	_setup_input()
	_load_font()
	_build_theme()


# ---------------- 输入映射（代码注册，避免手写 InputEvent 序列化） ----------------
func _setup_input() -> void:
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("move_up", [KEY_W, KEY_UP])
	_add_keys("move_down", [KEY_S, KEY_DOWN])
	_add_keys("roll", [KEY_SPACE])
	_add_keys("skill", [KEY_E])
	_add_keys("sub_weapon", [KEY_Q])
	_add_keys("switch_mode", [KEY_R])
	_add_keys("quota_reset", [KEY_T])
	# 武器切换：鼠标滚轮（上/下都切到另一把）
	_add_wheel("switch_weapon", [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN])
	_add_keys("restart", [KEY_F5])
	_add_keys("pause", [KEY_ESCAPE])
	_add_mouse("shoot", MOUSE_BUTTON_LEFT)
	_add_keys("select_1", [KEY_1])
	_add_keys("select_2", [KEY_2])
	_add_keys("select_3", [KEY_3])


func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _add_mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


## 滚轮事件（WHEEL_UP / WHEEL_DOWN）：同一动作绑两个方向
func _add_wheel(action: String, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for b in buttons:
		var ev := InputEventMouseButton.new()
		ev.button_index = b
		ev.pressed = true
		InputMap.action_add_event(action, ev)


# ---------------- 字体（像素字体优先，中文兜底） ----------------
func _load_font() -> void:
	# P2：优先融合像素 12px（OFL），关闭抗锯齿/次像素/微调，保证 1px 网格
	for bundled in ["res://assets/fonts/pixel_12px.woff2", "res://assets/fonts/pixel_12px.ttf"]:
		if ResourceLoader.exists(bundled):
			var res = load(bundled)
			if res is FontFile:
				var ff := res as FontFile
				ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
				ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
				ff.hinting = TextServer.HINTING_NORMAL
				ff.oversampling = 1.0
				ui_font = ff
				return
			elif res is Font:
				ui_font = res
				return
	# 中文兜底：工程内置 Noto Sans SC（非像素，仅当像素字体缺失时使用）
	for bundled in ["res://assets/fonts/ui.otf", "res://assets/fonts/ui.ttf"]:
		if ResourceLoader.exists(bundled):
			var res2 = load(bundled)
			if res2 is Font:
				ui_font = res2
				return
	# 兜底：桌面系统字体（不复制、不打包）
	var candidates := [
		"C:/Windows/Fonts/msyh.ttc",
		"C:/Windows/Fonts/msyhbd.ttc",
		"C:/Windows/Fonts/simhei.ttf",
		"C:/Windows/Fonts/Deng.ttf",
		"C:/Windows/Fonts/simsun.ttc",
		"res://assets/fonts/ui.ttf",
	]
	for path in candidates:
		if not FileAccess.file_exists(path):
			continue
		var f := FontFile.new()
		if f.load_dynamic_font(path) == OK:
			ui_font = f
			return
	# 最终兜底：系统字体（Web 端由浏览器提供）
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC",
		"Noto Sans SC", "PingFang SC", "Source Han Sans SC", "sans-serif"])
	ui_font = sys


func _build_theme() -> void:
	var t := Theme.new()
	if ui_font != null:
		t.default_font = ui_font
		# 全局兜底字体：容器 UI（Label/Button）也能显示中文，Web 端同样有效
		ThemeDB.fallback_font = ui_font
	t.default_font_size = 12
	ui_theme = t


# ---------------- 像素帧工具 ----------------
## 从 assets/sprites/<char>/<anim>.png 生成 SpriteFrames（横向排列的帧表）
func build_sprite_frames(char_id: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var anims := {"idle": 4.0, "walk": 10.0, "attack": 12.0, "roll": 14.0}
	for anim_name in anims.keys():
		var path := "res://assets/sprites/%s/%s.png" % [char_id, anim_name]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var count := int(tex.get_width() / SPRITE_FRAME)
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, anims[anim_name])
		frames.set_animation_loop(anim_name, anim_name != "attack")
		for i in count:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * SPRITE_FRAME, 0, SPRITE_FRAME, SPRITE_FRAME)
			frames.add_frame(anim_name, at)
	return frames


## 房间可用区域（世界坐标）
func room_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(ROOM_W, ROOM_H))


func char_color(char_id: String) -> Color:
	return CHAR_COLORS.get(char_id, Color.WHITE)


func fmt_time(sec: float) -> String:
	return "%.1fs" % max(0.0, sec)
