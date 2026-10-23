extends Node2D
class_name RoomBasic
## 固定战斗房间：960x540，四面墙 + 右侧门
## 视觉分层：背景地板 -> 中景装饰/墙内阴影 -> 角色 -> 前景暗角（HUD 层）
## 2D 光照：CanvasModulate 压暗环境 + PointLight2D 点亮角色与门

const DOOR_H := 64.0
const LIGHT_TEX := "res://assets/fx/light_radial.png"

var cleared: bool = false
var door_open: bool = false

var _gate: StaticBody2D = null
var _t: float = 0.0
var _door_light: PointLight2D = null
var _modulate: CanvasModulate = null


func _ready() -> void:
	_build_lighting()
	_build_walls()
	queue_redraw()


## 光照采样吸附到像素网格，消除平滑插值造成的糊边
func _apply_pixel_light() -> void:
	var path := "res://shaders/pixel_light.gdshader"
	if not ResourceLoader.exists(path):
		return
	var mat := ShaderMaterial.new()
	mat.shader = load(path)
	mat.set_shader_parameter("pixel_size", 2.0)
	material = mat


func _process(delta: float) -> void:
	_t += delta
	if door_open:
		queue_redraw()
	if _door_light != null and is_instance_valid(_door_light):
		var target := 0.95 if door_open else 0.0
		_door_light.energy = lerpf(_door_light.energy, target, clampf(delta * 4.0, 0.0, 1.0))


# ---------------- 光照 ----------------
func _build_lighting() -> void:
	# 环境压暗：偏冷的深蓝灰，让角色和子弹从背景里跳出来
	_modulate = CanvasModulate.new()
	_modulate.color = Color(0.80, 0.84, 0.94)
	add_child(_modulate)

	var tex: Texture2D = load(LIGHT_TEX) if ResourceLoader.exists(LIGHT_TEX) else null
	# 房间中心的大范围补光，避免四角全黑影响弹幕可读性
	var fill := PointLight2D.new()
	fill.texture = tex
	fill.energy = 0.28
	fill.texture_scale = 5.0
	fill.color = Color(0.62, 0.72, 1.0)
	fill.position = Vector2(GameConfig.ROOM_W * 0.5, GameConfig.ROOM_H * 0.5)
	fill.shadow_enabled = false
	add_child(fill)

	# 门口暖光：清场后点亮，形成"可以走了"的视觉引导
	_door_light = PointLight2D.new()
	_door_light.texture = tex
	_door_light.energy = 0.0
	_door_light.texture_scale = 1.9
	_door_light.color = Color(1.0, 0.82, 0.42)
	_door_light.position = Vector2(GameConfig.ROOM_W - 40.0, GameConfig.ROOM_H * 0.5)
	_door_light.shadow_enabled = false
	add_child(_door_light)


func _build_walls() -> void:
	var r := GameConfig.room_rect()
	var w := GameConfig.WALL
	_wall(Rect2(r.position.x, r.position.y, r.size.x, w))
	_wall(Rect2(r.position.x, r.end.y - w, r.size.x, w))
	_wall(Rect2(r.position.x, r.position.y, w, r.size.y))
	var gap_top: float = r.position.y + r.size.y * 0.5 - DOOR_H * 0.5
	_wall(Rect2(r.end.x - w, r.position.y, w, gap_top - r.position.y))
	_wall(Rect2(r.end.x - w, gap_top + DOOR_H, w, r.end.y - (gap_top + DOOR_H)))
	_gate = _wall(Rect2(r.end.x - w, gap_top, w, DOOR_H))


func _wall(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	add_child(body)

	# 遮挡体：让灯光在墙后投下硬边阴影
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	var hw := rect.size.x * 0.5
	var hh := rect.size.y * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	occ.occluder = poly
	occ.position = rect.get_center()
	add_child(occ)
	return body


func open_door() -> void:
	cleared = true
	door_open = true
	if _gate != null and is_instance_valid(_gate):
		_gate.queue_free()
		_gate = null
	Sfx.play("ui", -4.0, 0.8)
	queue_redraw()


## 玩家走进这个矩形就进入下一房间
func door_zone() -> Rect2:
	var r := GameConfig.room_rect()
	return Rect2(r.end.x - 34.0, r.position.y + r.size.y * 0.5 - DOOR_H * 0.5,
		34.0, DOOR_H)


func spawn_point(index: int) -> Vector2:
	var r := GameConfig.room_rect()
	match index:
		0:
			return Vector2(r.position.x + 90.0, r.position.y + r.size.y * 0.5)
		1:
			return Vector2(r.position.x + r.size.x * 0.5, r.position.y + 80.0)
		2:
			return Vector2(r.end.x - 150.0, r.position.y + r.size.y * 0.5)
		_:
			return Vector2(r.position.x + r.size.x * 0.5, r.end.y - 80.0)


func random_point(pad: float = 60.0) -> Vector2:
	var r := GameConfig.room_rect().grow(-pad)
	return Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))


# ---------------- 绘制 ----------------
func _draw() -> void:
	var r := GameConfig.room_rect()
	var tile := 32.0
	var cols := int(r.size.x / tile)
	var rows := int(r.size.y / tile)

	# 第 1 层：地板棋盘
	for y in rows:
		for x in cols:
			var c := GameConfig.COL_FLOOR_A if (x + y) % 2 == 0 else GameConfig.COL_FLOOR_B
			draw_rect(Rect2(x * tile, y * tile, tile, tile), c)
	for x in cols + 1:
		draw_line(Vector2(x * tile, 0), Vector2(x * tile, r.size.y),
			GameConfig.COL_FLOOR_LINE, 1.0)
	for y in rows + 1:
		draw_line(Vector2(0, y * tile), Vector2(r.size.x, y * tile),
			GameConfig.COL_FLOOR_LINE, 1.0)

	# 第 2 层：中景装饰（中央竞技圈 + 四角标记）
	draw_arc(Vector2(r.size.x * 0.5, r.size.y * 0.5), 150.0, 0.0, TAU, 48,
		Color(0.55, 0.68, 0.95, 0.07), 2.0, true)
	draw_arc(Vector2(r.size.x * 0.5, r.size.y * 0.5), 88.0, 0.0, TAU, 40,
		Color(0.55, 0.68, 0.95, 0.07), 1.0, true)
	for i in 4:
		var ang := TAU * i / 4.0 + PI / 4.0
		var p := Vector2(r.size.x * 0.5, r.size.y * 0.5) + Vector2(cos(ang), sin(ang)) * 120.0
		draw_circle(p, 2.0, Color(0.6, 0.72, 1.0, 0.18))

	# 第 2.5 层：墙内阴影（3 段渐变，制造下沉的房间感）
	var w := GameConfig.WALL
	for i in 3:
		var a := 0.16 - i * 0.05
		draw_rect(Rect2(w + i * 6, w + i * 6, r.size.x - (w + i * 6) * 2, 6),
			Color(0, 0, 0, a))
		draw_rect(Rect2(w + i * 6, r.end.y - w - i * 6 - 6, r.size.x - (w + i * 6) * 2, 6),
			Color(0, 0, 0, a))

	# 墙体
	var gap_top: float = r.position.y + r.size.y * 0.5 - DOOR_H * 0.5
	var walls := [
		Rect2(r.position.x, r.position.y, r.size.x, w),
		Rect2(r.position.x, r.end.y - w, r.size.x, w),
		Rect2(r.position.x, r.position.y, w, r.size.y),
	]
	walls.append(Rect2(r.end.x - w, r.position.y, w, gap_top - r.position.y))
	walls.append(Rect2(r.end.x - w, gap_top + DOOR_H, w, r.end.y - (gap_top + DOOR_H)))
	for rect in walls:
		draw_rect(rect, GameConfig.COL_WALL)
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y),
			GameConfig.COL_WALL_TOP, 2.0)

	# 门
	var dz := door_zone()
	if door_open:
		var a2: float = 0.35 + 0.25 * sin(_t * 4.0)
		draw_rect(dz, Color(0.95, 0.72, 0.24, 0.22))
		draw_rect(dz, Color(0.98, 0.78, 0.32, a2), false, 2.0)
		for i in 3:
			var yy := dz.position.y + 14.0 + i * 18.0
			draw_line(Vector2(dz.position.x + 6, yy), Vector2(dz.end.x - 6, yy),
				Color(1.0, 0.85, 0.4, 0.55), 2.0)
	else:
		draw_rect(Rect2(dz.position.x, gap_top, w, DOOR_H), Color("#3b2f1a"))
		draw_rect(Rect2(dz.position.x + 3, gap_top + 4, w - 6, DOOR_H - 8),
			Color(0.55, 0.42, 0.2, 0.8))
