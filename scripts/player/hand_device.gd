extends Node2D
## 手持武器：只跟随鼠标旋转，不随角色翻转（角色本体只做 flip_h）
## 支持贴图武器（饭盆/法杖/法典）与程序化武器（Harness 虎鲸虚影）

var texture: Texture2D = null
var base_rot: float = 0.0
var tint: Color = Color(1, 1, 1, 1)
var draw_size: float = 32.0
var procedural: String = ""
var glow: Color = Color(0, 0, 0, 0)
var _t: float = 0.0
var _flash: float = 0.0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()


## tex_path 为空时用程序化外观；rot_deg 是贴图本身的朝向修正
func set_visual(tex_path: String, rot_deg: float = 0.0, col: Color = Color(1, 1, 1, 1),
		proc: String = "") -> void:
	procedural = proc
	base_rot = deg_to_rad(rot_deg)
	tint = col
	texture = null
	if tex_path != "" and ResourceLoader.exists(tex_path):
		texture = load(tex_path)
	queue_redraw()


func set_glow(col: Color) -> void:
	glow = col


## 只在瞄准方向旋转，不做垂直翻转
func set_aim(dir: Vector2) -> void:
	rotation = dir.angle() + base_rot


func muzzle_local() -> Vector2:
	return Vector2(draw_size * 0.42, 0)


func flash() -> void:
	_flash = 0.09


func _draw() -> void:
	var half := draw_size * 0.5
	if glow.a > 0.0:
		draw_circle(Vector2.ZERO, half * 0.78, Color(glow.r, glow.g, glow.b, 0.18))
	if procedural == "orca":
		_draw_orca(half)
	elif procedural == "hammer":
		_draw_hammer(half)
	elif texture != null:
		var c := tint
		if _flash > 0.0:
			c = c.lerp(Color(2.2, 2.2, 2.2, 1.0), 0.7)
		draw_texture_rect(texture, Rect2(-half, -half, draw_size, draw_size), false, c)
	else:
		draw_rect(Rect2(-half * 0.5, -half * 0.5, draw_size * 0.5, draw_size * 0.5),
			Color(0.8, 0.85, 0.95))


## Harness 专武：手里的小虎鲸虚影
func _draw_orca(half: float) -> void:
	var s := half / 16.0
	var body := Color(0.10, 0.14, 0.26, 0.92)
	draw_circle(Vector2(2, 0) * s, 8.0 * s, body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1, -8) * s, Vector2(-15, 0) * s, Vector2(-1, 8) * s]), body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, 0) * s, Vector2(-20, -7) * s, Vector2(-18, 0) * s,
		Vector2(-20, 7) * s]), Color(0.10, 0.14, 0.26, 0.8))
	draw_circle(Vector2(5, -3) * s, 2.6 * s, Color(0.92, 0.96, 1.0, 0.9))
	draw_circle(Vector2(5.6, -3) * s, 1.1 * s, Color(0.04, 0.06, 0.12, 0.95))
	if _flash > 0.0:
		draw_arc(Vector2.ZERO, half * 0.9, 0.0, TAU, 18, Color(1, 0.85, 0.4, 0.8), 1.4)


## 法槌专武：木柄 + 陶土槌头
func _draw_hammer(half: float) -> void:
	var wood := Color("#8a5a34")
	var clay := Color("#c98b62")
	draw_rect(Rect2(-half * 0.9, -1.5, half * 1.1, 3.0), wood)
	draw_rect(Rect2(-half * 0.9, -1.5, half * 1.1, 1.0), Color("#a06a40"))
	draw_rect(Rect2(half * 0.2, -half * 0.42, half * 0.6, half * 0.84), clay)
	draw_rect(Rect2(half * 0.2, -half * 0.42, half * 0.6, 2.0), Color("#e0a97f"))
	draw_rect(Rect2(half * 0.2, -half * 0.42, half * 0.6, half * 0.84),
		Color(0.35, 0.20, 0.12), false, 1.0)
	draw_rect(Rect2(half * 0.38, -half * 0.42, 1.6, half * 0.84), Color("#e6c07a"))
	if _flash > 0.0:
		draw_arc(Vector2(half * 0.5, 0), half * 0.8, -0.9, 0.9, 10,
			Color(0.98, 0.85, 0.6, 0.8), 1.6)
