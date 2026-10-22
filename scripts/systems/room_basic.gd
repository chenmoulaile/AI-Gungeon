extends Node2D
class_name RoomBasic
## 固定战斗房间：960x540，四面墙 + 右侧门
## 地板与墙全部用 _draw 程序化绘制，不产生任何占位图片

const DOOR_H := 64.0

var cleared: bool = false
var door_open: bool = false

var _gate: StaticBody2D = null
var _t: float = 0.0


func _ready() -> void:
	_build_walls()
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if door_open:
		queue_redraw()


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
	# 地板：32px 棋盘格 + 细网格
	var tile := 32.0
	var cols := int(r.size.x / tile)
	var rows := int(r.size.y / tile)
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

	# 墙体
	var w := GameConfig.WALL
	var walls := [
		Rect2(r.position.x, r.position.y, r.size.x, w),
		Rect2(r.position.x, r.end.y - w, r.size.x, w),
		Rect2(r.position.x, r.position.y, w, r.size.y),
	]
	var gap_top: float = r.position.y + r.size.y * 0.5 - DOOR_H * 0.5
	walls.append(Rect2(r.end.x - w, r.position.y, w, gap_top - r.position.y))
	walls.append(Rect2(r.end.x - w, gap_top + DOOR_H, w, r.end.y - (gap_top + DOOR_H)))
	for rect in walls:
		draw_rect(rect, GameConfig.COL_WALL)
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y),
			GameConfig.COL_WALL_TOP, 2.0)

	# 门
	var dz := door_zone()
	if door_open:
		var a: float = 0.35 + 0.25 * sin(_t * 4.0)
		draw_rect(dz, Color(0.95, 0.72, 0.24, 0.22))
		draw_rect(dz, Color(0.98, 0.78, 0.32, a), false, 2.0)
		for i in 3:
			var yy := dz.position.y + 14.0 + i * 18.0
			draw_line(Vector2(dz.position.x + 6, yy), Vector2(dz.end.x - 6, yy),
				Color(1.0, 0.85, 0.4, 0.55), 2.0)
	else:
		draw_rect(Rect2(dz.position.x, gap_top, w, DOOR_H), Color("#3b2f1a"))
		draw_rect(Rect2(dz.position.x + 3, gap_top + 4, w - 6, DOOR_H - 8),
			Color(0.55, 0.42, 0.2, 0.8))
