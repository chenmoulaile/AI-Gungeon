class_name UiKit
extends RefCounted
## 蔚蓝档案风格 UI 工具：配色 / 字体层级 / 圆角面板 / 按钮样式 / 文本绘制
## 设计画布为 640x360（窗口 1280x720 整数倍缩放），因此这里的字号是"屏幕像素的一半"。

# ---------------- 配色 ----------------
const BG := Color(0.96, 0.97, 1.00)
const BG_DEEP := Color(0.90, 0.93, 0.99)
const PANEL := Color(1, 1, 1, 0.88)
const PANEL_SOLID := Color(1, 1, 1, 0.97)
const PANEL_SOFT := Color(1, 1, 1, 0.62)
const ACCENT := Color(0.35, 0.62, 0.95)
const ACCENT_HOVER := Color(0.45, 0.72, 1.00)
const ACCENT_DEEP := Color(0.24, 0.45, 0.78)
const TEXT := Color(0.15, 0.22, 0.35)
const TEXT_DIM := Color(0.45, 0.52, 0.65)
const TEXT_LIGHT := Color(1, 1, 1, 0.96)
const DANGER := Color(0.95, 0.35, 0.35)
const GOLD := Color(0.94, 0.70, 0.24)
const OK := Color(0.30, 0.72, 0.52)

const BTN_NORMAL := Color(0.88, 0.93, 1.00)
const BTN_HOVER := Color(0.75, 0.86, 1.00)
const BTN_PRESS := Color(0.62, 0.78, 0.98)
const BTN_OFF := Color(0.85, 0.85, 0.85)
const LINE := Color(0.80, 0.85, 0.94)
const SHADOW := Color(0.20, 0.30, 0.52, 0.13)

# ---------------- 字体层级（跳跃率 1.3~1.6） ----------------
const F_H1 := 24     # 大标题 48px
const F_H2 := 16     # 标题 32px
const F_H3 := 12     # 中标题 24px
const F_BODY := 8    # 正文 16px
const F_SMALL := 6   # 小字 12px
const F_TINY := 5    # 最小字 10px

static var _cache: Dictionary = {}


static func font() -> Font:
	return GameConfig.ui_font


# ---------------- StyleBox ----------------
static func box(bg: Color, radius: int = 10, border: Color = Color(1, 1, 1, 0.6),
		border_w: int = 1, shadow: bool = true) -> StyleBoxFlat:
	var key := "b|%s|%d|%s|%d|%s" % [bg.to_html(), radius, border.to_html(), border_w, shadow]
	if _cache.has(key):
		return _cache[key]
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = SHADOW
		sb.shadow_size = 3
		sb.shadow_offset = Vector2(0, 2)
	sb.set_content_margin_all(6)
	_cache[key] = sb
	return sb


static func soft_box(bg: Color, radius: int = 8) -> StyleBoxFlat:
	return box(bg, radius, Color(1, 1, 1, 0.35), 1, false)


# ---------------- 绘制：面板 ----------------
static func panel(ci: CanvasItem, r: Rect2, bg: Color = PANEL, radius: int = 10) -> void:
	ci.draw_style_box(box(bg, radius), r)


static func card(ci: CanvasItem, r: Rect2, bg: Color = PANEL_SOLID, radius: int = 10) -> void:
	ci.draw_style_box(box(bg, radius), r)


## 顶部渐变底（浅蓝白 -> 透明），用于菜单背景
static func gradient_backdrop(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, BG)
	var steps := 12
	for i in steps:
		var t := float(i) / float(steps)
		var a := 0.10 * (1.0 - t)
		ci.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * t,
			r.size.x, r.size.y / float(steps) + 1.0), Color(0.55, 0.72, 1.0, a))


## 斜向装饰条纹（很淡，避免纯色背景）
static func stripes(ci: CanvasItem, r: Rect2, t: float) -> void:
	var step := 26.0
	var off := fmod(t * 6.0, step)
	var x := r.position.x - r.size.y + off
	while x < r.end.x:
		ci.draw_line(Vector2(x, r.end.y), Vector2(x + r.size.y, r.position.y),
			Color(1, 1, 1, 0.22), 6.0)
		x += step


# ---------------- 绘制：文本 ----------------
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int = F_BODY,
		color: Color = TEXT) -> void:
	if font() == null:
		return
	ci.draw_string(font(), pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func text_center(ci: CanvasItem, center_x: float, y: float, s: String,
		size: int = F_BODY, color: Color = TEXT) -> void:
	if font() == null:
		return
	var w := font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font(), Vector2(center_x - w * 0.5, y), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func text_right(ci: CanvasItem, right_x: float, y: float, s: String,
		size: int = F_BODY, color: Color = TEXT) -> void:
	if font() == null:
		return
	var w := font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font(), Vector2(right_x - w, y), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func text_block(ci: CanvasItem, pos: Vector2, s: String, width: float,
		size: int = F_SMALL, color: Color = TEXT_DIM, max_lines: int = 3) -> void:
	if font() == null:
		return
	ci.draw_multiline_string(font(), pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, size,
		max_lines, color)


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
		bg: Color = Color(1, 1, 1, 0.72), fg: Color = TEXT_DIM) -> void:
	var w := measure(s, size) + 10.0
	var r := Rect2(center.x - w * 0.5, center.y - 7.0, w, 14.0)
	ci.draw_style_box(box(bg, 7, Color(1, 1, 1, 0.5), 1, false), r)
	text_center(ci, center.x, center.y + size * 0.36, s, size, fg)


static func bar(ci: CanvasItem, r: Rect2, ratio: float, fg: Color, bg: Color = Color(0.82, 0.87, 0.95)) -> void:
	ci.draw_style_box(box(bg, int(r.size.y * 0.5), bg, 0, false), r)
	var w: float = maxf(0.0, r.size.x * clampf(ratio, 0.0, 1.0))
	if w <= 1.0:
		return
	ci.draw_style_box(box(fg, int(r.size.y * 0.5), fg, 0, false),
		Rect2(r.position, Vector2(w, r.size.y)))


static func ring(ci: CanvasItem, center: Vector2, radius: float, ratio: float,
		col: Color, width: float = 2.0, bg: Color = Color(0.80, 0.85, 0.93, 0.9)) -> void:
	ci.draw_circle(center, radius, Color(1, 1, 1, 0.85))
	ci.draw_arc(center, radius - width * 0.5, 0.0, TAU, 28, bg, width, true)
	if ratio > 0.001:
		ci.draw_arc(center, radius - width * 0.5, -PI * 0.5, -PI * 0.5 + TAU * clampf(ratio, 0.0, 1.0),
			28, col, width, true)


static func shadow_ellipse(ci: CanvasItem, center: Vector2, radius: float, alpha: float = 0.28) -> void:
	ci.draw_set_transform(center, 0.0, Vector2(1.0, 0.38))
	ci.draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	ci.draw_texture_rect(tex, r, false)
	return true


## 保持宽高比铺满目标矩形（cover），超出部分裁掉 —— 立绘卡片用
static func draw_tex_cover(ci: CanvasItem, tex: Texture2D, r: Rect2) -> void:
	if tex == null:
		return
	var ts := tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0 or r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var k: float = maxf(r.size.x / ts.x, r.size.y / ts.y)
	var src := Vector2(r.size.x / k, r.size.y / k)
	ci.draw_texture_rect_region(tex, r, Rect2((ts - src) * 0.5, src))


## 保持宽高比完整放入目标矩形（contain），四周留白 —— 全身立绘用
static func draw_tex_contain(ci: CanvasItem, tex: Texture2D, r: Rect2) -> void:
	if tex == null:
		return
	var ts := tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return
	var k: float = minf(r.size.x / ts.x, r.size.y / ts.y)
	var dst := Vector2(ts.x * k, ts.y * k)
	ci.draw_texture_rect(tex, Rect2(r.get_center() - dst * 0.5, dst), false)
