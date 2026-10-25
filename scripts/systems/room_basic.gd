extends Node2D
class_name RoomBasic
## 固定战斗房间：960x540，四面墙 + 右侧门
## 视觉分层：主题地板 -> 装饰 -> 墙体 -> 门 -> 淡入
## 三层主题由 FloorTheme 提供：色调 / 地面纹理 / 装饰 / 环境光 / 氛围粒子

const DOOR_H := 64.0
const LIGHT_TEX := "res://assets/fx/light_radial.png"
const CrateScript = preload("res://scripts/systems/crate.gd")
const AmbientScript = preload("res://scripts/fx/ambient_particles.gd")

var cleared: bool = false
var door_open: bool = false
var is_boss: bool = false
## -1 = 跟随 GameState.floor_index；>=1 时强制用该层主题（训练场等固定场景用，避免继承上一局的配色）
var floor_override: int = -1

var _gate: StaticBody2D = null
var _t: float = 0.0
var _door_light: PointLight2D = null
var _modulate: CanvasModulate = null
var _obstacles: Array = []

var _theme: Dictionary = {}
var _fade: float = 1.0
## 16×16 地砖：{"rect": Rect2, "tone": 0/1/2}，仅记录与底色不同的块
var _tiles: Array = []
## 2×2 像素细节（铜钉 / 焊盘 / 通风孔）
var _studs: Array = []
var _traces: Array = []
var _pads: Array = []
var _decor: Array = []
var _ambient: Node2D = null
## Y-Sort 层：障碍物视觉挂到这里，才能和角色互相遮挡
var visual_parent: Node2D = null
var _obstacle_nodes: Array = []


func _ready() -> void:
	var fi: int = floor_override if floor_override > 0 else GameState.floor_index
	_theme = FloorTheme.boss_theme(FloorTheme.get_theme(fi)) if is_boss \
		else FloorTheme.get_theme(fi)
	_build_floor_pattern()
	_build_decor()
	_build_lighting()
	_build_walls()
	_build_obstacles()
	_spawn_ambient()
	_fade = 1.0
	var tw := create_tween()
	tw.tween_property(self, "_fade", 0.0, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	queue_redraw()


# ---------------- 主题数据 ----------------
## 地面细节用固定种子生成，重绘不会跳变
## 16×16 像素地砖：底 a，20% 用 b，6% 压暗；再撒 2×2 细节
func _build_floor_pattern() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%d_%d" % [String(_theme.get("id", "x")), GameState.floor_index,
		GameState.room_index])
	var r := GameConfig.room_rect()
	var tile := 16.0
	var cols := int(ceil(r.size.x / tile))
	var rows := int(ceil(r.size.y / tile))
	var kind := String(_theme.get("decor", "shelf"))

	for yy in rows:
		for xx in cols:
			var roll := rng.randf()
			var tone := 0
			if roll < 0.20:
				tone = 1
			elif roll < 0.26:
				tone = 2
			if tone != 0:
				_tiles.append({"rect": Rect2(float(xx) * tile, float(yy) * tile, tile, tile),
					"tone": tone})
			elif rng.randf() < 0.14:
				# 只在底色块上撒 2×2 细节，避免与亮块打架
				var ox := float(xx) * tile + 2.0 + float(rng.randi_range(0, 5)) * 2.0
				var oy := float(yy) * tile + 2.0 + float(rng.randi_range(0, 5)) * 2.0
				_studs.append(Rect2(ox, oy, 2.0, 2.0))

	match kind:
		"rack":
			# 数据中心：沿 16px 网格的低频走线 + 焊盘
			for i in 18:
				var tx := rng.randi_range(1, cols - 3)
				var ty := rng.randi_range(1, rows - 3)
				var pts := PackedVector2Array([Vector2(float(tx) * tile, float(ty) * tile)])
				var horiz := rng.randf() < 0.5
				for s in rng.randi_range(2, 4):
					if horiz:
						tx += rng.randi_range(2, 5)
					else:
						ty += rng.randi_range(2, 5)
					pts.append(Vector2(float(tx) * tile, float(ty) * tile))
					horiz = not horiz
				_traces.append(pts)
				_pads.append(pts[pts.size() - 1])
		"conduit":
			# 核心区：1px 阶梯裂纹
			for i in 12:
				var x2 := float(rng.randi_range(2, cols - 3)) * tile
				var y2 := float(rng.randi_range(2, rows - 3)) * tile
				var pts2 := PackedVector2Array([Vector2(x2, y2)])
				var horiz2 := rng.randf() < 0.5
				for s2 in rng.randi_range(3, 5):
					var step2 := float(rng.randi_range(2, 5)) * tile * 0.5
					if horiz2:
						x2 += step2
					else:
						y2 += step2
					pts2.append(Vector2(x2, y2))
					horiz2 = not horiz2
				_traces.append(pts2)
		_:
			# 档案库：地砖 + 铜钉
			pass


## 两侧装饰：书架 / 机柜 / 能量导管，全部贴墙，不阻挡通行
func _build_decor() -> void:
	var r := GameConfig.room_rect()
	var w := GameConfig.WALL
	var kind := String(_theme.get("decor", "shelf"))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("decor_%s_%d" % [kind, GameState.floor_index])

	match kind:
		"shelf":
			for side in [0, 1]:
				var y := r.position.y + w + 2.0 if side == 0 else r.end.y - w - 22.0
				var x := r.position.x + w + 8.0
				while x < r.end.x - w - 70.0:
					var bw := float(rng.randi_range(52, 74))
					_decor.append({"kind": "shelf", "rect": Rect2(x, y, bw, 20.0),
						"seed": rng.randi()})
					x += bw + 6.0
			_side_columns(rng, "vshelf")
		"rack":
			for side2 in [0, 1]:
				var y3 := r.position.y + w + 2.0 if side2 == 0 else r.end.y - w - 26.0
				var x3 := r.position.x + w + 8.0
				while x3 < r.end.x - w - 80.0:
					var bw2 := float(rng.randi_range(40, 54))
					_decor.append({"kind": "rack", "rect": Rect2(x3, y3, bw2, 24.0),
						"seed": rng.randi()})
					x3 += bw2 + 8.0
			_side_columns(rng, "vrack")
		_:
			_decor.append({"kind": "pipe", "rect": Rect2(r.position.x + w, r.position.y + w + 4.0,
				r.size.x - w * 2.0, 3.0), "seed": 0})
			_decor.append({"kind": "pipe", "rect": Rect2(r.position.x + w, r.end.y - w - 7.0,
				r.size.x - w * 2.0, 3.0), "seed": 0})
			var x4 := r.position.x + w + 40.0
			while x4 < r.end.x - w - 40.0:
				_decor.append({"kind": "node", "rect": Rect2(x4, r.position.y + w + 1.0, 8.0, 9.0),
					"seed": rng.randi()})
				_decor.append({"kind": "node", "rect": Rect2(x4 + 12.0, r.end.y - w - 10.0, 8.0, 9.0),
					"seed": rng.randi()})
				x4 += float(rng.randi_range(90, 160))
			_side_columns(rng, "vpipe")


## 左右两侧的竖向装饰：出生点视野里就能看到，强化该层辨识度
func _side_columns(rng: RandomNumberGenerator, kind: String) -> void:
	var r := GameConfig.room_rect()
	var w := GameConfig.WALL
	var hgt := 18.0 if kind != "vrack" else 22.0
	for side in [0, 1]:
		var x := r.position.x + w + 3.0 if side == 0 else r.end.x - w - 21.0
		var y := r.position.y + w + 16.0
		while y < r.end.y - w - 26.0:
			_decor.append({"kind": kind, "rect": Rect2(x, y, 18.0, hgt), "seed": rng.randi()})
			y += hgt + 4.0


func _spawn_ambient() -> void:
	_ambient = AmbientScript.new()
	_ambient.name = "Ambient"
	add_child(_ambient)
	var col: Color = _theme.get("accent", Color(1, 1, 1))
	col.a = 0.55
	_ambient.setup(String(_theme.get("particle", "mote")), col)


## 0~3 个不可通行障碍（柱子/石台）+ 10% 概率一个可破坏木箱
func _build_obstacles() -> void:
	GameState.obstacles.clear()
	GameState.crates.clear()
	var r := GameConfig.room_rect()
	var door_pt := Vector2(r.end.x - 30.0, r.size.y * 0.5)
	var spawn_pt := Vector2(r.position.x + 90.0, r.size.y * 0.5)
	var count := SeedManager.randi() % 4
	var tries := 0
	while _obstacles.size() < count and tries < 60:
		tries += 1
		var sz := Vector2(SeedManager.randf_range(44.0, 60.0), SeedManager.randf_range(44.0, 60.0))
		var px := SeedManager.randf_range(r.position.x + 80.0, r.end.x - 80.0 - sz.x)
		var py := SeedManager.randf_range(r.position.y + 80.0, r.end.y - 80.0 - sz.y)
		var rect := Rect2(px, py, sz.x, sz.y)
		# 不堵门、不压出生点、彼此留出通道
		if rect.grow(80.0).has_point(door_pt):
			continue
		if rect.grow(70.0).has_point(spawn_pt):
			continue
		var ok := true
		for o in _obstacles:
			if (o as Rect2).grow(80.0).intersects(rect):
				ok = false
		if not ok:
			continue
		_obstacles.append(rect)
		_add_obstacle(rect)
		_add_obstacle_visual(rect)
	GameState.obstacles = _obstacles.duplicate()

	if SeedManager.randf() < 0.1:
		for i in 20:
			var p := Vector2(SeedManager.randf_range(r.position.x + 120.0, r.end.x - 120.0),
				SeedManager.randf_range(r.position.y + 120.0, r.end.y - 120.0))
			if p.distance_to(door_pt) < 140.0 or p.distance_to(spawn_pt) < 140.0:
				continue
			var clear := true
			for o in _obstacles:
				if (o as Rect2).grow(40.0).has_point(p):
					clear = false
			if clear:
				var crate := CrateScript.new()
				crate.position = p
				add_child(crate)
				GameState.crates.append(crate)
				break


## 障碍物视觉：节点原点放在底边中点，配合 Y-Sort 实现遮挡
func _add_obstacle_visual(rect: Rect2) -> void:
	if visual_parent == null or not is_instance_valid(visual_parent):
		return
	var n := Node2D.new()
	n.name = "Obstacle"
	n.position = Vector2(rect.get_center().x, rect.end.y)
	n.set_script(load("res://scripts/systems/obstacle_visual.gd"))
	n.set("size", rect.size)
	n.set("theme", _theme)
	visual_parent.add_child(n)
	_obstacle_nodes.append(n)


func _add_obstacle(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	# 障碍也挡光，但只有墙级别的遮挡体，不额外加光源
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	var hw := rect.size.x * 0.5
	var hh := rect.size.y * 0.5
	poly.polygon = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh),
		Vector2(hw, hh), Vector2(-hw, hh)])
	occ.occluder = poly
	occ.position = rect.get_center()
	add_child(occ)


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
	if door_open or is_boss or _fade > 0.0:
		queue_redraw()
	if _door_light != null and is_instance_valid(_door_light):
		var target := 0.95 if door_open else 0.0
		_door_light.energy = lerpf(_door_light.energy, target, clampf(delta * 4.0, 0.0, 1.0))


# ---------------- 光照 ----------------
func _build_lighting() -> void:
	_modulate = CanvasModulate.new()
	_modulate.color = _theme.get("ambient", Color(0.85, 0.90, 1.0))
	add_child(_modulate)

	var tex: Texture2D = load(LIGHT_TEX) if ResourceLoader.exists(LIGHT_TEX) else null
	var accent: Color = _theme.get("accent", Color(0.62, 0.72, 1.0))
	# 房间中心的大范围补光，避免四角全黑影响弹幕可读性
	var fill := PointLight2D.new()
	fill.texture = tex
	fill.energy = float(_theme.get("fill_energy", 0.06))
	fill.texture_scale = 5.0
	fill.color = accent
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
	return Vector2(SeedManager.randf_range(r.position.x, r.end.x), SeedManager.randf_range(r.position.y, r.end.y))


# ---------------- 绘制 ----------------
func _draw() -> void:
	var r := GameConfig.room_rect()
	_draw_floor(r)
	_draw_floor_details()
	_draw_decor()
	_draw_walls(r)
	_draw_door(r)
	if is_boss:
		_draw_boss_glow(r)
	_draw_fade(r)


## 16×16 像素地砖：底色 + 亮/暗块 + 1px 砖缝 + 2×2 细节
func _draw_floor(r: Rect2) -> void:
	var a: Color = _theme.get("floor_a", Color("#1B2A2E"))
	var b: Color = _theme.get("floor_b", Color("#24383C"))
	var line: Color = _theme.get("floor_line", Color("#0E1618"))
	var accent: Color = _theme.get("accent", Color("#8A6A3A"))
	var kind := String(_theme.get("decor", "shelf"))
	draw_rect(r, a)

	var dark := a.darkened(0.10)
	for t in _tiles:
		var tr: Rect2 = t["rect"]
		draw_rect(tr, b if int(t["tone"]) == 1 else dark)

	# 1px 砖缝，全部落在 16px 网格上
	var tile := 16.0
	var cols := int(ceil(r.size.x / tile))
	var rows := int(ceil(r.size.y / tile))
	for x in cols + 1:
		draw_rect(Rect2(float(x) * tile, r.position.y, 1.0, r.size.y), line)
	for y in rows + 1:
		draw_rect(Rect2(r.position.x, float(y) * tile, r.size.x, 1.0), line)

	# 2×2 像素细节：档案库铜钉 / 数据中心焊盘 / 核心区通风孔
	var stud := accent.darkened(0.25)
	if kind == "rack":
		stud = accent.darkened(0.35)
	elif kind == "conduit":
		stud = accent.darkened(0.15)
	for s in _studs:
		var sr: Rect2 = s
		draw_rect(sr, stud)
		draw_rect(Rect2(sr.position, Vector2.ONE), stud.lightened(0.30))


func _draw_floor_details() -> void:
	var line: Color = _theme.get("floor_line", Color("#0E1618"))
	var accent: Color = _theme.get("accent", Color("#8A6A3A"))
	match String(_theme.get("decor", "shelf")):
		"rack":
			# 线路：1px 折线，不加 3px 光晕
			for pts in _traces:
				var p: PackedVector2Array = pts
				draw_polyline(p, accent.darkened(0.30), 1.0)
			for pad in _pads:
				var pp: Vector2 = pad
				draw_rect(Rect2(pp - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), accent)
		"conduit":
			# 裂纹：1px 阶梯暗线
			for pts2 in _traces:
				var p2: PackedVector2Array = pts2
				draw_polyline(p2, line.darkened(0.30), 1.0)


func _draw_decor() -> void:
	var wall: Color = _theme.get("wall", Color("#162326"))
	var top: Color = _theme.get("wall_top", Color("#2B3F44"))
	var edge: Color = _theme.get("wall_edge", Color("#05090A"))
	var accent: Color = _theme.get("accent", Color("#8A6A3A"))
	var book_cols := [accent.darkened(0.15), Color("#6B5C8A"), Color("#4E7A78"),
		accent.lightened(0.05)]
	for d in _decor:
		var rect: Rect2 = d["rect"]
		var seed_v: int = d["seed"]
		var kind := String(d["kind"])
		match kind:
			"shelf":
				draw_rect(rect, top.darkened(0.18))
				draw_rect(rect, edge, false, 1.0)
				draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), top.lightened(0.10))
				var rng := RandomNumberGenerator.new()
				rng.seed = seed_v
				var x := rect.position.x + 3.0
				while x < rect.end.x - 3.0:
					var bw := float(rng.randi_range(3, 6))
					var h := float(rng.randi_range(9, 14))
					draw_rect(Rect2(x, rect.end.y - 3.0 - h, bw, h),
						book_cols[rng.randi() % book_cols.size()])
					x += bw + 1.0
				draw_rect(Rect2(rect.position.x, rect.end.y - 3.0, rect.size.x, 3.0),
					wall.darkened(0.10))
			"rack", "vrack":
				draw_rect(rect, wall.darkened(0.12))
				draw_rect(rect, edge, false, 1.0)
				var rng2 := RandomNumberGenerator.new()
				rng2.seed = seed_v
				for row in 3:
					var ry := rect.position.y + 4.0 + float(row) * 6.0
					draw_rect(Rect2(rect.position.x + 3.0, ry, rect.size.x - 6.0, 2.0),
						top.darkened(0.10))
					var blink := fmod(_t * 1.6 + float(rng2.randi() % 10) * 0.3, 3.0) < 1.5
					if blink:
						draw_rect(Rect2(rect.end.x - 6.0, ry, 2.0, 2.0), accent)
			"pipe", "vpipe":
				draw_rect(rect, wall)
				draw_rect(rect, edge, false, 1.0)
				draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)),
					top.lightened(0.08))
				# 2 帧能量闪，不做平滑脉冲
				if fmod(_t * 2.2 + float(seed_v % 5) * 0.5, 1.6) < 0.9:
					draw_rect(rect.grow(-3.0), accent.darkened(0.20))
			"node":
				draw_rect(rect, wall)
				draw_rect(rect, edge, false, 1.0)
				if fmod(_t * 2.6 + float(seed_v % 7) * 0.4, 1.8) < 0.9:
					draw_rect(rect.grow(-2.0), accent.darkened(0.10))
			"vshelf":
				draw_rect(rect, top.darkened(0.18))
				draw_rect(rect, edge, false, 1.0)
				var rng3 := RandomNumberGenerator.new()
				rng3.seed = seed_v
				for i in 3:
					draw_rect(Rect2(rect.position.x + 2.0, rect.position.y + 2.0 + float(i) * 5.0,
						rect.size.x - 4.0, 4.0), book_cols[rng3.randi() % book_cols.size()].darkened(0.15))


## 2×2 像素抖动填充：用方格代替半透明渐变
func _dither_fill(rect: Rect2, col: Color, step: float = 4.0) -> void:
	var x := rect.position.x
	while x + 2.0 <= rect.end.x:
		var y := rect.position.y
		while y + 2.0 <= rect.end.y:
			draw_rect(Rect2(x, y, 2.0, 2.0), col)
			y += step
		x += step


func _draw_walls(r: Rect2) -> void:
	var w := GameConfig.WALL
	var wall: Color = _theme.get("wall", Color("#162326"))
	var top: Color = _theme.get("wall_top", Color("#2B3F44"))
	var edge: Color = _theme.get("wall_edge", Color("#05090A"))
	var band := 8.0
	var gap_top: float = r.position.y + r.size.y * 0.5 - DOOR_H * 0.5
	var walls := [
		Rect2(r.position.x, r.position.y, r.size.x, w),
		Rect2(r.position.x, r.end.y - w, r.size.x, w),
		Rect2(r.position.x, r.position.y, w, r.size.y),
	]
	walls.append(Rect2(r.end.x - w, r.position.y, w, gap_top - r.position.y))
	walls.append(Rect2(r.end.x - w, gap_top + DOOR_H, w, r.end.y - (gap_top + DOOR_H)))
	for rect in walls:
		draw_rect(rect, wall)
		# 上沿 8px 顶面 + 1px 亮边
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, band)), top)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), top.lightened(0.14))
		# 每 48px 一道 1px 接缝，破除大面积纯色
		var sx: float = rect.position.x + 48.0
		while sx < rect.end.x:
			draw_rect(Rect2(sx, rect.position.y, 1.0, band), top.darkened(0.16))
			sx += 48.0
		# 内侧 1px 深底
		draw_rect(Rect2(rect.position.x, rect.end.y - 1.0, rect.size.x, 1.0), edge)

	# 地面内缘 1px 暗边 + 四角 2×2 缺口
	var inner := Rect2(w, w, r.size.x - w * 2.0, r.size.y - w * 2.0)
	draw_rect(inner, edge, false, 1.0)
	for corner in [Vector2(w, w), Vector2(r.end.x - w - 2.0, w),
			Vector2(w, r.end.y - w - 2.0), Vector2(r.end.x - w - 2.0, r.end.y - w - 2.0)]:
		draw_rect(Rect2(corner, Vector2(2.0, 2.0)), edge)


func _draw_door(r: Rect2) -> void:
	var w := GameConfig.WALL
	var gap_top: float = r.position.y + r.size.y * 0.5 - DOOR_H * 0.5
	var dz := door_zone()
	var accent: Color = _theme.get("accent", Color("#8A6A3A"))
	var line: Color = _theme.get("floor_line", Color("#0E1618"))
	var wall: Color = _theme.get("wall", Color("#162326"))
	if door_open:
		# 2 帧闪烁的门框；地面光斑用 2×2 抖动
		var glow := accent if fmod(_t * 4.0, 1.0) < 0.5 else accent.darkened(0.30)
		draw_rect(dz, line)
		draw_rect(dz, glow, false, 1.0)
		for i in 3:
			var yy := dz.position.y + 14.0 + float(i) * 18.0
			draw_rect(Rect2(dz.position.x + 6.0, yy, dz.size.x - 12.0, 2.0),
				glow.darkened(0.15))
		for i2 in 3:
			_dither_fill(Rect2(dz.position.x - 26.0 + float(i2) * 6.0,
				dz.position.y + 10.0 + float(i2) * 16.0, 22.0 - float(i2) * 6.0, 6.0),
				accent.darkened(0.35), 4.0)
	else:
		var panel := wall.darkened(0.30)
		draw_rect(Rect2(dz.position.x, gap_top, w, DOOR_H), panel)
		var frame := Rect2(dz.position.x + 3.0, gap_top + 4.0, w - 6.0, DOOR_H - 8.0)
		draw_rect(frame, accent.darkened(0.35))
		draw_rect(frame, accent.darkened(0.10), false, 1.0)
		# 门闩：2×2 金色块
		draw_rect(Rect2(dz.position.x + 6.0, gap_top + DOOR_H * 0.5 - 3.0, 2.0, 6.0),
			accent)


## Boss 房强化：3 圈 1px 方框，2 帧闪烁
func _draw_boss_glow(r: Rect2) -> void:
	var accent: Color = _theme.get("accent", Color("#FF5D7A"))
	var c := accent.darkened(0.20) if fmod(_t * 1.6, 1.0) < 0.5 else accent.darkened(0.45)
	for i in 3:
		var d := 6.0 + float(i) * 8.0
		draw_rect(Rect2(d, d, r.size.x - d * 2.0, r.size.y - d * 2.0), c, false, 1.0)


## 进房间的 0.3s 淡入（用主题墙色，避免硬切）
func _draw_fade(r: Rect2) -> void:
	if _fade <= 0.001:
		return
	var c: Color = _theme.get("wall", Color(0.2, 0.25, 0.35))
	draw_rect(r, Color(c.r * 0.8, c.g * 0.8, c.b * 0.85, clampf(_fade, 0.0, 1.0)))
