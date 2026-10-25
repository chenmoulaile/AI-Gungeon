extends Node2D
## 手持武器（v0.9）：支持程序化像素武器（长法杖 / 饭盆 / 书 / 铁盆）与原有贴图武器。
## 坐标系：原点 = 握把，+X = 瞄准方向；所有线条落在整数像素上，描边 1px。

var texture: Texture2D = null
var base_rot: float = 0.0
var tint: Color = Color(1, 1, 1, 1)
var draw_size: float = 32.0
var grip_offset: Vector2 = Vector2.ZERO
var glow: Color = Color(0, 0, 0, 0)
var proc: String = ""
var trim: Color = Color("#5F86F0")

var _flash: float = 0.0
var _recoil: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_recoil = move_toward(_recoil, 0.0, delta * 60.0)
	queue_redraw()


## tex_path 为空时使用程序化绘制；rot_deg 是贴图本身的朝向修正
func set_visual(tex_path: String, rot_deg: float = 0.0, col: Color = Color(1, 1, 1, 1),
		proc_name: String = "", size: float = 32.0, grip: Vector2 = Vector2.ZERO) -> void:
	base_rot = deg_to_rad(rot_deg)
	tint = col
	draw_size = size
	grip_offset = grip
	proc = proc_name
	texture = null
	if tex_path != "" and ResourceLoader.exists(tex_path):
		texture = load(tex_path)
	queue_redraw()


func set_glow(col: Color) -> void:
	glow = col
	queue_redraw()


## 袖口颜色：由玩家按角色主色设置
func set_trim(col: Color) -> void:
	trim = col
	queue_redraw()


func set_aim(dir: Vector2) -> void:
	rotation = dir.angle() + base_rot


func muzzle_local() -> Vector2:
	match proc:
		"staff":
			return Vector2(88, 0)
		"rice_bowl":
			return Vector2(20, 0)
		"book":
			return Vector2(18, 0)
		"basin":
			return Vector2(16, 0)
	return Vector2(draw_size * 0.46, 0).round()


func flash() -> void:
	_flash = 0.09
	_recoil = 2.0


func _draw() -> void:
	_draw_sleeve()
	if proc != "":
		match proc:
			"staff":
				_draw_staff()
			"rice_bowl":
				_draw_rice_bowl()
			"book":
				_draw_book()
			"basin":
				_draw_basin()
		if _flash > 0.0:
			_draw_muzzle_flash()
		return
	if texture == null:
		draw_rect(Rect2(-8, -8, 16, 16), Color(0.8, 0.85, 0.95))
		return
	var fw := float(texture.get_height())
	var frames := maxi(1, int(texture.get_width() / fw))
	var frame := 0
	if frames >= 3:
		if _recoil > 0.4:
			frame = 2
		elif _flash > 0.0:
			frame = 1
	var pos := (-Vector2(draw_size, draw_size) * 0.5 + grip_offset
		- Vector2(_recoil, 0.0)).round()
	draw_texture_rect_region(texture, Rect2(pos, Vector2(draw_size, draw_size)),
		Rect2(frame * fw, 0, fw, fw), tint)
	if _flash > 0.0:
		_draw_muzzle_flash()


## 袖口 / 手臂连接：只画手边 13px 的浅色短袖 + 角色色袖箍，
## 避免一大块浅色矩形压在角色胸口造成新的“割裂”
func _draw_sleeve() -> void:
	var edge := trim.darkened(0.62)
	var cloth := trim.lightened(0.62)
	var cloth_hi := trim.lightened(0.82)
	var cuff := trim.darkened(0.18)
	draw_rect(Rect2(-13, -4, 13, 9), edge)
	draw_rect(Rect2(-12, -3, 12, 7), cloth)
	draw_rect(Rect2(-11, -2, 9, 2), cloth_hi)
	draw_rect(Rect2(-6, -3, 3, 7), cuff)
	draw_rect(Rect2(-5, -2, 1, 5), cloth_hi)
	# 握把处的小手块
	draw_rect(Rect2(-3, 0, 5, 5), edge)
	draw_rect(Rect2(-3, 1, 4, 3), Color("#F2E3D2"))
	draw_rect(Rect2(-3, 1, 3, 1), Color("#FFF3E6"))


## 长法杖（v0.9.1）：握把到杖头 88px，冠部 30px，双层像素光环。
## 描边用角色主色压暗的深紫，不用纯黑，避免“贴图黑边”观感。
func _draw_staff() -> void:
	var edge := Color("#2C1B47")
	var shaft := Color("#CBBEF0")
	var shaft_hi := Color("#F1EAFF")
	var shaft_lo := Color("#8A76B7")
	var head := Color("#DCCBFF")
	var head_hi := Color("#F6F0FF")
	var core := Color("#8EE6FF")
	var white := Color("#F6F1FF")
	var gold := Color("#FFD166")
	var violet := Color("#B06BFF")
	var x0 := -roundf(_recoil)
	var flash := _flash > 0.0
	var hx := x0 + 86.0

	# 悬浮光环（画在杖头后面）：两层 2×2 块，反向慢转，每层留一个断口
	for ring in [[15.0, 14, 0.0], [21.0, 18, 2.4]]:
		var rr: float = float(ring[0])
		var count: int = int(ring[1])
		var spin: float = _t * 0.85 + float(ring[2])
		for i in count:
			if i == count / 2:
				continue
			var a := spin + TAU * float(i) / float(count)
			var off := Vector2(roundf(cos(a) * rr / 2.0) * 2.0,
				roundf(sin(a) * rr * 0.78 / 2.0) * 2.0)
			var lit: bool = (i + int(_t * 7.0)) % 4 != 0
			draw_rect(Rect2(Vector2(hx, 0) + off - Vector2(1, 1), Vector2(2, 2)),
				violet if lit else violet.darkened(0.45))

	# 尾端配重 + 握把
	draw_rect(Rect2(x0 - 10, -4, 6, 8), edge)
	draw_rect(Rect2(x0 - 9, -3, 4, 6), gold.darkened(0.4))
	draw_rect(Rect2(x0 - 8, -2, 2, 2), gold)
	draw_rect(Rect2(x0 - 4, -5, 16, 10), edge)
	draw_rect(Rect2(x0 - 3, -4, 14, 8), shaft_lo)
	draw_rect(Rect2(x0 - 3, -4, 14, 2), shaft)
	for i in 4:
		draw_rect(Rect2(x0 - 1 + i * 3, -4, 2, 8), Color("#4A3568"))
	draw_rect(Rect2(x0 + 11, -5, 3, 10), edge)
	draw_rect(Rect2(x0 + 12, -4, 1, 8), gold)

	# 杖身：6px 芯 + 上下 1px 描边
	draw_rect(Rect2(x0 + 13, -4, 74, 8), edge)
	draw_rect(Rect2(x0 + 13, -3, 74, 6), shaft)
	draw_rect(Rect2(x0 + 13, -3, 74, 2), shaft_hi)
	draw_rect(Rect2(x0 + 13, 2, 74, 1), shaft_lo)
	# 三道金色符环：只留 1px 暗边，避免看起来像黑色隔断
	for bx in [31.0, 51.0, 71.0]:
		draw_rect(Rect2(x0 + bx, -5, 3, 1), edge)
		draw_rect(Rect2(x0 + bx, 4, 3, 1), edge)
		draw_rect(Rect2(x0 + bx, -4, 3, 8), gold.darkened(0.15))
		draw_rect(Rect2(x0 + bx + 1, -3, 1, 6), gold)
		draw_rect(Rect2(x0 + bx + 1, -1, 1, 2), Color("#FFF3C4"))

	# 冠部：菱形晶框（阶梯 4px 行）+ 上下冠刺
	var frames := [8.0, 16.0, 24.0, 24.0, 16.0, 8.0]
	for i in frames.size():
		draw_rect(Rect2(hx - float(frames[i]) * 0.5, -12.0 + float(i) * 4.0,
			float(frames[i]), 4.0), edge)
	var inner := [8.0, 16.0, 20.0, 16.0, 8.0]
	for i in inner.size():
		draw_rect(Rect2(hx - float(inner[i]) * 0.5, -10.0 + float(i) * 4.0,
			float(inner[i]), 4.0), head)
	# 晶面高光 / 暗面
	draw_rect(Rect2(hx - 6, -10, 4, 2), head_hi)
	draw_rect(Rect2(hx - 9, -6, 3, 2), head_hi)
	draw_rect(Rect2(hx + 4, 6, 5, 2), head.darkened(0.18))
	# 冠刺 + 冠顶宝石
	draw_rect(Rect2(hx - 3, -20, 6, 8), edge)
	draw_rect(Rect2(hx - 2, -19, 4, 6), head)
	draw_rect(Rect2(hx - 1, -18, 2, 2), gold)
	draw_rect(Rect2(hx - 3, 12, 6, 6), edge)
	draw_rect(Rect2(hx - 2, 12, 4, 4), head)
	# 中央云晶：竖瞳状能量
	draw_rect(Rect2(hx - 5, -8, 10, 16), Color("#10204A"))
	draw_rect(Rect2(hx - 3, -7, 6, 14), Color("#B9F1FF"))
	draw_rect(Rect2(hx - 2, -5, 4, 10), core if not flash else white)
	draw_rect(Rect2(hx - 1, -3, 2, 6), white if flash else Color("#E8FDFF"))
	draw_rect(Rect2(hx - 2, -1, 4, 2), white)

	# 浮动符文：杖头上下各 2 块，呼吸位移
	for i in 2:
		var ph := _t * 1.6 + float(i) * 3.1
		var fy := -24.0 - roundf(sin(ph) * 3.0) - float(i) * 6.0
		draw_rect(Rect2(hx - 1, fy, 2, 2), violet)
		draw_rect(Rect2(hx - 1, -fy - 4, 2, 2), violet.darkened(0.2))
	# 施法时杖头白闪
	if flash:
		draw_rect(Rect2(hx - 12, -14, 24, 1), Color(1, 1, 1, 0.85))
		draw_rect(Rect2(hx - 12, 13, 24, 1), Color(1, 1, 1, 0.55))


## 大白饭碗：蓝碗白饭，1px 深蓝描边
func _draw_rice_bowl() -> void:
	var edge := Color("#10204A")
	var blue := Color("#2E5BD0")
	var blue_hi := Color("#5F86F0")
	var rice := Color("#F4F6FF")
	var rice_lo := Color("#C9D4EE")
	var x0 := 2.0 - roundf(_recoil)
	var flash := _flash > 0.0
	# 碗体（上宽下窄，阶梯）
	draw_rect(Rect2(x0, -4, 22, 3), edge)
	draw_rect(Rect2(x0 + 1, -2, 20, 7), edge)
	draw_rect(Rect2(x0 + 3, 5, 16, 2), edge)
	draw_rect(Rect2(x0 + 1, -3, 20, 5), blue)
	draw_rect(Rect2(x0 + 3, 4, 16, 2), blue)
	draw_rect(Rect2(x0 + 2, -2, 18, 1), blue_hi)
	draw_rect(Rect2(x0 + 6, 2, 12, 2), Color("#1B3A8F"))
	# 白饭堆
	draw_rect(Rect2(x0 + 1, -7, 20, 4), edge)
	draw_rect(Rect2(x0 + 3, -9, 16, 4), edge)
	draw_rect(Rect2(x0 + 2, -6, 18, 3), rice)
	draw_rect(Rect2(x0 + 4, -8, 14, 3), rice)
	draw_rect(Rect2(x0 + 6, -9, 10, 2), rice)
	draw_rect(Rect2(x0 + 4, -6, 14, 1), rice_lo)
	draw_rect(Rect2(x0 + 7, -8, 4, 1), Color("#FFFFFF"))
	if flash:
		draw_rect(Rect2(x0 + 3, -10, 16, 1), Color("#8EE6FF"))


## 书：厚书脊 + 打开的书页，暖棕 1px 描边
func _draw_book() -> void:
	var edge := Color("#4A2A1A")
	var cover := Color("#E07A3F")
	var cover_hi := Color("#FFB066")
	var page := Color("#FFF3E6")
	var page_lo := Color("#E8C9A8")
	var x0 := 1.0 - roundf(_recoil)
	var flash := _flash > 0.0
	# 封面
	draw_rect(Rect2(x0, -7, 20, 16), edge)
	draw_rect(Rect2(x0 + 1, -6, 18, 14), cover)
	draw_rect(Rect2(x0 + 1, -6, 18, 2), cover_hi)
	# 书页（两页中间留 1px 书脊）
	draw_rect(Rect2(x0 + 3, -4, 6, 10), page)
	draw_rect(Rect2(x0 + 10, -4, 6, 10), page)
	draw_rect(Rect2(x0 + 3, 4, 13, 1), page_lo)
	draw_rect(Rect2(x0 + 9, -5, 1, 11), edge)
	# 字行
	for i in 3:
		draw_rect(Rect2(x0 + 4, -2 + i * 2, 4, 1), Color("#C08A63"))
		draw_rect(Rect2(x0 + 11, -2 + i * 2, 4, 1), Color("#C08A63"))
	# 书签 / 魔法书页边光
	draw_rect(Rect2(x0 + 15, 3, 4, 2), UiKit.GOLD)
	if flash:
		draw_rect(Rect2(x0 + 2, -5, 16, 12), Color(1.0, 0.86, 0.62, 0.35))


## 铁盆：宽口浅盆，深蓝描边 + 蓝搪瓷
func _draw_basin() -> void:
	var edge := Color("#15224A")
	var blue := Color("#2E5BD0")
	var hi := Color("#86E3FF")
	var rice := Color("#F4F6FF")
	var x0 := -roundf(_recoil)
	draw_rect(Rect2(x0 - 4, -8, 30, 3), edge)
	draw_rect(Rect2(x0 - 6, -5, 34, 12), edge)
	draw_rect(Rect2(x0 - 3, 7, 28, 2), edge)
	draw_rect(Rect2(x0 - 5, -6, 32, 10), blue)
	draw_rect(Rect2(x0 - 3, 4, 28, 2), Color("#1B3A8F"))
	draw_rect(Rect2(x0 - 5, -6, 32, 1), hi)
	draw_rect(Rect2(x0 - 2, -4, 8, 1), Color("#A9D8FF"))
	draw_rect(Rect2(x0 - 4, -8, 30, 2), rice)
	draw_rect(Rect2(x0 + 1, -9, 20, 2), rice)
	draw_rect(Rect2(x0 + 4, -9, 3, 1), Color("#FFFFFF"))
	# 手柄
	draw_rect(Rect2(x0 - 8, -3, 4, 6), edge)
	draw_rect(Rect2(x0 - 7, -2, 2, 4), Color("#5A4630"))


## 2 帧枪口像素星：十字 + 四角点，硬边，不画光晕
func _draw_muzzle_flash() -> void:
	var m := muzzle_local()
	var second := _flash < 0.045
	var arm := 3 if second else 4
	var col := UiKit.GOLD if second else UiKit.WHITE
	draw_rect(Rect2(m.x, m.y - 1, arm, 2), col)
	draw_rect(Rect2(m.x + 1, m.y - 2, 2, 4), col)
	draw_rect(Rect2(m.x + 2, m.y - 3, 1, 1), UiKit.CYAN)
	draw_rect(Rect2(m.x + 2, m.y + 2, 1, 1), UiKit.CYAN)
