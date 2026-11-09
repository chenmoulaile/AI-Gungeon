class_name UiKit
extends RefCounted
## Data Academy UI 工具层（v0.7 P2 → M4 学园重定向）
## 硬边 / 1px 边框 / 多层 1px 渐淡发光描边 / 分段条 / 键帽 / 抖动装饰。
## 保留旧函数名与签名，屏幕脚本不需要大改 import。
## 设计画布 640x360（窗口 1280x720 整数 2x 缩放），字号只用 12 / 24 / 36。

# ---------------- 调色板（M4 学园重定向：浅底 + 青/品红主色） ----------------
const VOID := Color("#F2F4FA")        # 页面底：冷白
const DEEP := Color("#E9EDF7")        # 面板底：浅蓝白
const PANEL := Color("#FFFFFF")       # 卡片：纯白
const RAISED := Color("#DCE2F0")      # 键帽 / 凸起
const BORDER := Color("#A9B3CE")      # 常规边：冷灰蓝
const BORDER_HI := Color("#7C8AC0")   # 高亮边
const TEXT_DIM := Color("#6A7594")    # 次级文字
const TEXT := Color("#2A3350")        # 主文字：藏青（浅底上可读）
const CYAN := Color("#12AECF")        # 主色：学园青
const GOLD := Color("#D89A1E")        # 强调金（浅底加深一档）
const DANGER := Color("#E4486B")
const SUCCESS := Color("#2FA972")
const ORANGE := Color("#E07A2E")
const PURPLE := Color("#8A5BD6")
const MAGENTA := Color("#F055B8")     # 主色：学园品红
const WHITE := Color("#FFFFFF")
const SHADOW := Color("#3A4468")      # 文字 / 面板硬阴影（浅底加深藏青）

# 兼容旧名
const BG := VOID
const BG_DEEP := DEEP
const PANEL_SOLID := PANEL
const PANEL_SOFT := Color(1, 1, 1, 0.82)
const ACCENT := CYAN
const ACCENT_HOVER := MAGENTA
const ACCENT_DEEP := Color("#0C7A93")
const TEXT_LIGHT := TEXT
const LINE := BORDER
const OK := SUCCESS
const BTN_NORMAL := Color("#FFFFFF")
const BTN_HOVER := Color("#EFF4FF")
const BTN_PRESS := Color("#DCE6F8")
const BTN_OFF := Color("#E7EAF2")

# ---------------- 字体层级：只有 12 / 24 / 36 ----------------
const F_H1 := 36     # 大标题
const F_H2 := 24     # 屏标题
const F_H3 := 12     # 小节标题（用颜色和间距区分层级）
const F_BODY := 12
const F_SMALL := 12
const F_TINY := 12   # 最小字号，不允许再小

static var _cache: Dictionary = {}


static func font() -> Font:
	return GameConfig.ui_font


# ---------------- StyleBox：硬边，无圆角，无柔和阴影 ----------------
static func box(bg: Color, radius: int = 0, border: Color = BORDER,
		border_w: int = 1, shadow: bool = false) -> StyleBoxFlat:
	var key := "b|%s|%s|%d|%s" % [bg.to_html(), border.to_html(), border_w, shadow]
	if _cache.has(key):
		return _cache[key]
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.shadow_size = 0
	sb.set_content_margin_all(4)
	_cache[key] = sb
	return sb


static func soft_box(bg: Color, _radius: int = 0) -> StyleBoxFlat:
	return box(bg, 0, BORDER, 1, false)


# ---------------- 绘制：像素面板 ----------------
## 2px 硬阴影 + 1px 外框 + 1px 顶部/左侧内高光
static func frame(ci: CanvasItem, r: Rect2, bg: Color = DEEP, border: Color = BORDER,
		hi: Color = BORDER_HI, shadow: bool = true) -> void:
	var rr := Rect2(r.position.round(), r.size.round())
	if shadow:
		ci.draw_rect(Rect2(rr.position + Vector2(2, 2), rr.size), SHADOW)
	ci.draw_rect(rr, bg)
	ci.draw_rect(rr, border, false, 1.0)
	if hi.a > 0.0:
		ci.draw_line(rr.position + Vector2(1, 1), Vector2(rr.end.x - 2, rr.position.y + 1), hi)
		ci.draw_line(rr.position + Vector2(1, 1), Vector2(rr.position.x + 1, rr.end.y - 2), hi)


## 内凹槽（血条底/输入框/格子）
static func inset(ci: CanvasItem, r: Rect2, bg: Color = VOID, border: Color = BORDER) -> void:
	var rr := Rect2(r.position.round(), r.size.round())
	ci.draw_rect(rr, bg)
	ci.draw_rect(rr, border, false, 1.0)
	ci.draw_line(rr.position + Vector2(1, 1), Vector2(rr.end.x - 2, rr.position.y + 1), SHADOW)


## M4 学园发光边框：由内向外多层 1px 渐淡描边模拟辉光（不做高斯模糊，保持整数像素）。
## pulse 0~1：共鸣脉冲等场景传入 sin 波，静态传 1。
static func glow_frame(ci: CanvasItem, r: Rect2, col: Color = CYAN, layers: int = 3,
		pulse: float = 1.0) -> void:
	var rr := Rect2(r.position.round(), r.size.round())
	var k := clampf(pulse, 0.0, 1.0)
	for i in layers:
		var a := col.a * (1.0 - float(i) / float(layers)) * k
		if a <= 0.01:
			continue
		ci.draw_rect(rr.grow(float(i + 1)), Color(col.r, col.g, col.b, a), false, 1.0)


## 半透明白面板底色（浅色学园 HUD/卡片通用），alpha 可调
static func panel_soft(alpha: float = 0.86) -> Color:
	return Color(WHITE.r, WHITE.g, WHITE.b, alpha)


static func panel(ci: CanvasItem, r: Rect2, bg: Color = DEEP, _radius: int = 0) -> void:
	frame(ci, r, bg, BORDER, BORDER_HI, true)


static func card(ci: CanvasItem, r: Rect2, bg: Color = PANEL, _radius: int = 0) -> void:
	frame(ci, r, bg, BORDER, BORDER_HI, true)


## 学园背景：冷白大厅 + 32px 地砖网格 + 青/品红数据信标 + 扫描线；t 用于闪烁
static func gradient_backdrop(ci: CanvasItem, r: Rect2, t: float = 0.0) -> void:
	ci.draw_rect(r, VOID)
	# 两条横向色带（无渐变）
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, r.size.y * 0.46), Color("#E9EDF7"))
	# 16px 地砖缝（错行）
	var y := r.position.y
	var row := 0
	while y < r.end.y:
		var off := 0.0 if row % 2 == 0 else 16.0
		var x := r.position.x - off
		while x < r.end.x:
			ci.draw_line(Vector2(x, y), Vector2(x, y + 16), Color("#DCE2F0"), 1.0)
			x += 32.0
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color("#DCE2F0"), 1.0)
		y += 16.0
		row += 1
	# 数据信标：左右各一支，2 帧闪（青 / 品红）
	_beacon(ci, Vector2(r.position.x + 46, r.position.y + 96), t, 0.0, CYAN)
	_beacon(ci, Vector2(r.end.x - 46, r.position.y + 128), t, 0.4, MAGENTA)
	# 扫描线：每 3px 一条 1px 线，透明度 ≤ 6%
	var yy := r.position.y
	while yy < r.end.y:
		ci.draw_line(Vector2(r.position.x, yy), Vector2(r.end.x, yy), Color(0, 0, 0, 0.05), 1.0)
		yy += 3.0


static func _beacon(ci: CanvasItem, c: Vector2, t: float, phase: float, col: Color) -> void:
	var flick := int(fmod(t * 8.0 + phase * 10.0, 2.0))
	var base := Color("#C8D0E6")
	ci.draw_rect(Rect2(c + Vector2(-1, 6), Vector2(3, 14)), base)
	ci.draw_rect(Rect2(c + Vector2(-3, 4), Vector2(7, 3)), Color("#A9B3CE"))
	var h := 6 + flick
	ci.draw_rect(Rect2(c + Vector2(-2, -h + 4), Vector2(5, h)), col)
	ci.draw_rect(Rect2(c + Vector2(-1, -h + 2), Vector2(3, h - 3)),
		Color(1, 1, 1, 0.85) if flick == 0 else col.lightened(0.4))
	ci.draw_rect(Rect2(c + Vector2(-1, -3), Vector2(2, 2)), WHITE)


## 装饰：斜向像素虚线（低频，避免抢视线；浅底用深色虚线）
static func stripes(ci: CanvasItem, r: Rect2, t: float = 0.0) -> void:
	var step := 32
	var off := int(fmod(t * 6.0, float(step)))
	var x := r.position.x - off
	while x < r.end.x:
		var y := r.position.y
		while y < r.end.y:
			if int((y - r.position.y) / 4.0) % 4 == 0:
				ci.draw_rect(Rect2(x, y, 1, 2), Color(0.2, 0.25, 0.4, 0.05))
			y += 16.0
		x += step


static func scanlines(ci: CanvasItem, r: Rect2, alpha: float = 0.08) -> void:
	var y := r.position.y
	while y < r.end.y:
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0, 0, 0, alpha), 1.0)
		y += 3.0


## 2×2 抖动块（用于过渡/选中底，替代渐变）
static func dither_rect(ci: CanvasItem, r: Rect2, col: Color, step: int = 2) -> void:
	var y := int(r.position.y)
	var ry := int(r.end.y)
	var rx := int(r.end.x)
	while y < ry:
		var x := int(r.position.x) + (0 if (y / step) % 2 == 0 else step)
		while x < rx:
			ci.draw_rect(Rect2(x, y, step, step), col)
			x += step * 2
		y += step


## 金色选择角括号（2px）
static func corner_brackets(ci: CanvasItem, r: Rect2, col: Color = GOLD, arm: int = 5) -> void:
	var p := r.position
	var e := r.end
	for c in [p, Vector2(e.x, p.y), Vector2(p.x, e.y), e]:
		var sx := 1.0 if c.x == p.x else -1.0
		var sy := 1.0 if c.y == p.y else -1.0
		ci.draw_rect(Rect2(c.x if sx > 0 else c.x - arm, c.y, arm, 2), col)
		ci.draw_rect(Rect2(c.x, c.y if sy > 0 else c.y - arm, 2, arm), col)


# ---------------- 绘制：文本 ----------------
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int = F_BODY,
		color: Color = TEXT, shadow: bool = true) -> void:
	if font() == null:
		return
	var p := pos.round()
	if shadow:
		ci.draw_string(font(), p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(SHADOW.r, SHADOW.g, SHADOW.b, color.a * 0.85))
	ci.draw_string(font(), p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func text_center(ci: CanvasItem, center_x: float, y: float, s: String,
		size: int = F_BODY, color: Color = TEXT) -> void:
	if font() == null:
		return
	var w := font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(ci, Vector2(center_x - w * 0.5, y), s, size, color)


static func text_right(ci: CanvasItem, right_x: float, y: float, s: String,
		size: int = F_BODY, color: Color = TEXT) -> void:
	if font() == null:
		return
	var w := font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(ci, Vector2(right_x - w, y), s, size, color)


static func text_block(ci: CanvasItem, pos: Vector2, s: String, width: float,
		size: int = F_BODY, color: Color = TEXT, max_lines: int = 3) -> void:
	if font() == null:
		return
	var p := pos.round()
	ci.draw_multiline_string(font(), p + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT,
		width, size, max_lines, Color(SHADOW.r, SHADOW.g, SHADOW.b, color.a * 0.85))
	ci.draw_multiline_string(font(), p, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, max_lines, color)


static func measure(s: String, size: int) -> float:
	if font() == null:
		return 0.0
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## 超宽截断，补省略号
static func fit(s: String, max_w: float, size: int) -> String:
	if font() == null:
		return s
	if measure(s, size) <= max_w:
		return s
	var out := s
	while out.length() > 1:
		out = out.substr(0, out.length() - 1)
		if measure(out + "…", size) <= max_w:
			return out + "…"
	return out


# ---------------- 绘制：小部件 ----------------
static func chip(ci: CanvasItem, center: Vector2, s: String, size: int = F_TINY,
		bg: Color = PANEL, fg: Color = TEXT_DIM) -> void:
	var w := measure(s, size) + 10.0
	var r := Rect2((center - Vector2(w * 0.5, 9.0)).round(), Vector2(w, 18))
	frame(ci, r, bg, BORDER, Color(0, 0, 0, 0), false)
	text_center(ci, r.get_center().x, r.get_center().y + 4.0, s, size, fg)


## 分段条：每段 4px + 1px 间隔，底凹槽
static func bar(ci: CanvasItem, r: Rect2, ratio: float, fg: Color,
		bg: Color = VOID) -> void:
	var rr := Rect2(r.position.round(), r.size.round())
	inset(ci, rr, bg, BORDER)
	var inner := rr.grow(-1)
	var seg_w := 4
	var gap := 1
	var count: int = maxi(1, int((inner.size.x + gap) / float(seg_w + gap)))
	var lit: int = int(round(clampf(ratio, 0.0, 1.0) * float(count)))
	for i in count:
		var x := inner.position.x + i * (seg_w + gap)
		if x + seg_w > inner.end.x + 1:
			break
		var c := fg if i < lit else Color(fg.r, fg.g, fg.b, 0.13)
		ci.draw_rect(Rect2(x, inner.position.y, seg_w, inner.size.y), c)


## 8 段像素冷却环（不用平滑圆弧）
static func ring(ci: CanvasItem, center: Vector2, radius: float, ratio: float,
		col: Color, width: float = 4.0, bg: Color = BORDER) -> void:
	var c := center.round()
	var seg := 8
	var lit: int = int(round(clampf(ratio, 0.0, 1.0) * float(seg)))
	for i in seg:
		var a := -PI * 0.5 + TAU * float(i) / float(seg)
		var p := Vector2(cos(a), sin(a)) * radius + c
		var rect := Rect2((p - Vector2(width, width) * 0.5).round(), Vector2(width, width))
		ci.draw_rect(rect, col if i < lit else bg)
	# 外框四角
	corner_brackets(ci, Rect2(c - Vector2(radius, radius) * 1.22,
		Vector2(radius, radius) * 2.44), Color(col.r, col.g, col.b, 0.5), 4)


static func keycap(ci: CanvasItem, pos: Vector2, key: String, px: int = 16) -> void:
	var r := Rect2(pos.round(), Vector2(px, px))
	ci.draw_rect(Rect2(r.position + Vector2(0, 1), r.size), SHADOW)
	ci.draw_rect(r, RAISED)
	ci.draw_rect(r, BORDER_HI, false, 1.0)
	ci.draw_line(r.position + Vector2(1, 1), Vector2(r.end.x - 2, r.position.y + 1), BORDER_HI)
	var w := measure(key, 12)
	text(ci, Vector2(r.get_center().x - w * 0.5, r.get_center().y + 4.0).round(), key, 12,
		TEXT, false)


static func shadow_ellipse(ci: CanvasItem, center: Vector2, radius: float, alpha: float = 0.28) -> void:
	var w := int(radius * 2.0)
	var rows := maxi(1, int(radius * 0.7))
	for i in rows:
		var k := float(i) / float(rows)
		var ww := int(w * (1.0 - absf(k - 0.5) * 0.9))
		ci.draw_rect(Rect2(center.x - ww * 0.5, center.y - rows * 0.5 + i, ww, 1),
			Color(0, 0, 0, alpha))


## 图标：优先走缓存，缺失返回 null
static func icon(path: String) -> Texture2D:
	var key := "i|" + path
	if _cache.has(key):
		return _cache[key]
	if not ResourceLoader.exists(path):
		_cache[key] = null
		return null
	var tex: Texture2D = load(path)
	_cache[key] = tex
	return tex


static func draw_icon(ci: CanvasItem, path: String, r: Rect2) -> bool:
	var tex := icon(path)
	if tex == null:
		return false
	ci.draw_texture_rect(tex, Rect2(r.position.round(), r.size.round()), false)
	return true


## 保持宽高比铺满目标矩形（cover）
static func draw_tex_cover(ci: CanvasItem, tex: Texture2D, r: Rect2) -> void:
	if tex == null:
		return
	var ts := tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0 or r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var k: float = maxf(r.size.x / ts.x, r.size.y / ts.y)
	var src := (Vector2(r.size.x / k, r.size.y / k)).round()
	ci.draw_texture_rect_region(tex, Rect2(r.position.round(), r.size.round()),
		Rect2(((ts - src) * 0.5).round(), src))


## 保持宽高比完整放入目标矩形（contain）；放大只允许整数倍，保证像素不糊
static func draw_tex_contain(ci: CanvasItem, tex: Texture2D, r: Rect2) -> void:
	if tex == null:
		return
	var ts := tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return
	var k: float = minf(r.size.x / ts.x, r.size.y / ts.y)
	if k >= 1.0:
		k = floorf(k)
		if k < 1.0:
			k = 1.0
	var dst := (ts * k).round()
	var pos := ((r.get_center() - dst * 0.5)).floor()
	ci.draw_texture_rect(tex, Rect2(pos, dst), false)


# ---------------- 容器版样式 ----------------
static func panel_style(alpha: float = 0.96) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(DEEP.r, DEEP.g, DEEP.b, alpha)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.set_border_width_all(1)
	sb.border_color = BORDER
	sb.shadow_size = 0
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## 容器按钮：像素硬边；hover 亮底 + 品红角，press 下沉 1px（改边框而不是缩放）
static func style_button(b: Button, kind: String = "ghost") -> void:
	var base := BTN_NORMAL
	var hover := BTN_HOVER
	var border := BORDER
	if kind == "primary":
		base = Color("#D8F3FA")
		hover = Color("#BEEAF6")
		border = CYAN
	elif kind == "danger":
		base = Color("#FBE1EA")
		hover = Color("#F6C9D9")
		border = DANGER
	b.add_theme_stylebox_override("normal", _btn_style(base, border))
	b.add_theme_stylebox_override("hover", _btn_style(hover, MAGENTA))
	b.add_theme_stylebox_override("pressed", _btn_style(BTN_PRESS, CYAN))
	b.add_theme_stylebox_override("focus", _btn_style(hover, MAGENTA))
	b.add_theme_stylebox_override("disabled", _btn_style(BTN_OFF, Color("#B9C2D8")))
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", MAGENTA)
	b.add_theme_color_override("font_pressed_color", CYAN)
	b.add_theme_color_override("font_focus_color", MAGENTA)
	b.add_theme_color_override("font_disabled_color", Color("#8A93AC"))


static func hud_panel(_radius: int = 0, alpha: float = 0.88) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(DEEP.r, DEEP.g, DEEP.b, alpha)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.set_border_width_all(1)
	sb.border_color = BORDER
	sb.shadow_size = 0
	return sb
