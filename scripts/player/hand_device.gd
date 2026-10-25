extends Node2D
## 手持武器（v0.7 P3）：32×32 像素贴图，3 帧（待机/开火/后坐）+ 2 帧枪口像素星
## 贴图文件可以是 32×32 单帧，也可以是 96×32 三帧横排。

var texture: Texture2D = null
var base_rot: float = 0.0
var tint: Color = Color(1, 1, 1, 1)
var draw_size: float = 32.0
var grip_offset: Vector2 = Vector2.ZERO
var glow: Color = Color(0, 0, 0, 0)

var _flash: float = 0.0
var _recoil: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	_recoil = move_toward(_recoil, 0.0, delta * 60.0)
	queue_redraw()


## tex_path 为空时用调试方块；rot_deg 是贴图本身的朝向修正
func set_visual(tex_path: String, rot_deg: float = 0.0, col: Color = Color(1, 1, 1, 1),
		_proc: String = "", size: float = 32.0, grip: Vector2 = Vector2.ZERO) -> void:
	base_rot = deg_to_rad(rot_deg)
	tint = col
	draw_size = size
	grip_offset = grip
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
	return Vector2(draw_size * 0.46, 0).round()


func flash() -> void:
	_flash = 0.09
	_recoil = 2.0


func _draw() -> void:
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
