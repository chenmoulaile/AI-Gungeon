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

var _gate: StaticBody2D = null
var _t: float = 0.0
var _door_light: PointLight2D = null
var _modulate: CanvasModulate = null
var _obstacles: Array = []

var _theme: Dictionary = {}
var _fade: float = 1.0
var _slabs: Array = []
var _traces: Array = []
var _pads: Array = []
var _decor: Array = []
var _ambient: Node2D = null


func _ready() -> void:
	_theme = FloorTheme.boss_theme(FloorTheme.get_theme(GameState.floor_index)) if is_boss \
		else FloorTheme.get_theme(GameState.floor_index)
	_build_floor_pattern()
	_build_decor()
	_build_lighting()
	_build_walls()
	_build_obstacles()
	_build_floor_wave()
	_spawn_ambient()
	_fade = 1.0
	var tw := create_tween()
	tw.tween_property(self, "_fade", 0.0, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	queue_redraw()


# ---------------- 主题数据 ----------------
## 地面细节（裂纹 / 线路 / 石板）用固定种子生成，重绘不会跳变
func _build_floor_pattern() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%d_%d" % [String(_theme.get("id", "x")), GameState.floor_index,
		GameState.room_index])
	var r := GameConfig.room_rect()
	var inner := Rect2(r.position + Vector2(GameConfig.WALL, GameConfig.WALL),
		r.size - Vector2(GameConfig.WALL * 2.0, GameConfig.WALL * 2.0))

	match String(_theme.get("decor", "shelf")):
		"shelf":
			# 档案库：地板只做规则地砖，细节在 _draw 里按网格画
			pass
		"rack":
			# 数据中心：线路板走线 + 焊盘
			for i in 26:
				var x := inner.position.x + rng.randf() * inner.size.x
				var y := inner.position.y + rng.randf() * inner.size.y
				var horiz := rng.randf() < 0.5
				var ln := rng.randf_range(30.0, 120.0)
				var pts := PackedVector2Array([Vector2(x, y)])
				var cx := x
				var cy := y
				var segs := rng.randi_range(2, 4)
				for s in segs:
					var step := ln / float(segs)
					if horiz:
						cx += step
					else:
						cy += step
					pts.append(Vector2(cx, cy))
					horiz = not horiz
				_traces.append(pts)
				_pads.append(Vector2(x, y))
		_:
			# 核心区：不规则石板 + 裂纹
			var cols := 6
			var rows := 4
			for yy in rows:
				for xx in cols:
					var w := inner.size.x / float(cols)
					var h := inner.size.y / float(rows)
					var jitter := 4.0
					var rect := Rect2(inner.position.x + xx * w + rng.randf_range(-jitter, jitter),
						inner.position.y + yy * h + rng.randf_range(-jitter, jitter),
						w - 2.0, h - 2.0)
					_slabs.append({"rect": rect, "tone": rng.randf_range(-0.045, 0.045)})
			for i in 14:
				var x2 := inner.position.x + rng.randf() * inner.size.x
				var y2 := inner.position.y + rng.randf() * inner.size.y
				var pts2 := PackedVector2Array([Vector2(x2, y2)])
				var ang := rng.randf() * TAU
				for s2 in rng.randi_range(3, 6):
					ang += rng.randf_range(-0.9, 0.9)
					var step2 := rng.randf_range(14.0, 34.0)
					x2 += cos(ang) * step2
					y2 += sin(ang) * step2
					pts2.append(Vector2(x2, y2))
				_traces.append(pts2)


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
					var bw := rng.randf_range(52.0, 74.0)
					_decor.append({"kind": "shelf", "rect": Rect2(x, y, bw, 20.0),
						"seed": rng.randi()})
					x += bw + 6.0
			_side_columns(rng, "vshelf")
		"rack":
			for side2 in [0, 1]:
				var y3 := r.position.y + w + 2.0 if side2 == 0 else r.end.y - w - 26.0
				var x3 := r.position.x + w + 8.0
				while x3 < r.end.x - w - 80.0:
					var bw2 := rng.randf_range(40.0, 54.0)
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
				x4 += rng.randf_range(90.0, 160.0)
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


## 地面微波动：一层极淡的正弦亮带（GPU 绘制，不额外消耗 CPU）
func _build_floor_wave() -> void:
	if not ResourceLoader.exists("res://shaders/floor_wave.gdshader"):
		return
	var rect := ColorRect.new()
	rect.name = "FloorWave"
	rect.position = Vector2.ZERO
	rect.size = Vector2(GameConfig.ROOM_W, GameConfig.ROOM_H)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/floor_wave.gdshader")
	mat.set_shader_parameter("tint", _theme.get("accent", Color(0.66, 0.80, 1.0)))
	mat.set_shader_parameter("strength", 0.035 if is_boss else 0.05)
	rect.material = mat
	add_child(rect)
	move_child(rect, 0)


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
	_draw_obstacles()
	_draw_walls(r)
	_draw_door(r)
	if is_boss:
		_draw_boss_glow(r)
	_draw_fade(r)


func _draw_floor(r: Rect2) -> void:
	var a: Color = _theme.get("floor_a", Color(0.72, 0.78, 0.86))
	var b: Color = _theme.get("floor_b", Color(0.68, 0.74, 0.83))
	var line: Color = _theme.get("floor_line", Color(0.55, 0.62, 0.72))
	draw_rect(r, a)

	match String(_theme.get("decor", "shelf")):
		"shelf":
			var tile := 32.0
			var cols := int(r.size.x / tile)
			var rows := int(r.size.y / tile)
			for y in rows:
				for x in cols:
					if (x + y) % 2 == 0:
						draw_rect(Rect2(x * tile, y * tile, tile, tile), b)
			for x2 in cols + 1:
				draw_line(Vector2(x2 * tile, 0), Vector2(x2 * tile, r.size.y), line, 1.0)
			for y2 in rows + 1:
				draw_line(Vector2(0, y2 * tile), Vector2(r.size.x, y2 * tile), line, 1.0)
		"rack":
			# 线路板：48px 网格 + 少量走线
			var step := 48.0
			var gx := r.position.x
			while gx < r.end.x:
				draw_line(Vector2(gx, r.position.y), Vector2(gx, r.end.y),
					Color(line.r, line.g, line.b, 0.35), 1.0)
				gx += step
			var gy := r.position.y
			while gy < r.end.y:
				draw_line(Vector2(r.position.x, gy), Vector2(r.end.x, gy),
					Color(line.r, line.g, line.b, 0.35), 1.0)
				gy += step
		_:
			# 裂纹石板：石板明度抖动
			for s in _slabs:
				var rect: Rect2 = s["rect"]
				var tone: float = s["tone"]
				var c := a.lightened(tone) if tone > 0.0 else a.darkened(-tone)
				draw_rect(rect, c)


func _draw_floor_details() -> void:
	var line: Color = _theme.get("floor_line", Color(0.55, 0.62, 0.72))
	match String(_theme.get("decor", "shelf")):
		"rack":
			var glow: Color = _theme.get("accent", Color(0.30, 0.85, 0.72))
			for pts in _traces:
				var p: PackedVector2Array = pts
				draw_polyline(p, Color(line.r, line.g, line.b, 0.55), 1.0)
				draw_polyline(p, Color(glow.r, glow.g, glow.b, 0.10), 3.0)
			for pad in _pads:
				var pp: Vector2 = pad
				draw_rect(Rect2(pp - Vector2(2, 2), Vector2(4, 4)),
					Color(glow.r, glow.g, glow.b, 0.35))
		"conduit":
			for pts2 in _traces:
				var p2: PackedVector2Array = pts2
				draw_polyline(p2, Color(line.r * 0.7, line.g * 0.6, line.b * 0.65, 0.75), 1.0)


func _draw_decor() -> void:
	for d in _decor:
		var rect: Rect2 = d["rect"]
		var seed_v: int = d["seed"]
		match String(d["kind"]):
			"shelf":
				draw_rect(rect, Color(0.26, 0.30, 0.40))
				draw_rect(rect, Color(0.14, 0.17, 0.24), false, 1.0)
				var rng := RandomNumberGenerator.new()
				rng.seed = seed_v
				var x := rect.position.x + 3.0
				var cols2 := [Color(0.55, 0.68, 0.92), Color(0.72, 0.58, 0.45),
					Color(0.52, 0.76, 0.70), Color(0.80, 0.72, 0.45)]
				while x < rect.end.x - 3.0:
					var bw := rng.randf_range(3.0, 6.0)
					var h := rng.randf_range(9.0, 14.0)
					draw_rect(Rect2(x, rect.end.y - 3.0 - h, bw, h),
						cols2[rng.randi() % cols2.size()])
					x += bw + 1.5
				draw_rect(Rect2(rect.position.x, rect.end.y - 3.0, rect.size.x, 3.0),
					Color(0.20, 0.24, 0.32))
			"rack":
				draw_rect(rect, Color(0.13, 0.20, 0.24))
				draw_rect(rect, Color(0.06, 0.10, 0.13), false, 1.0)
				var rng2 := RandomNumberGenerator.new()
				rng2.seed = seed_v
				var accent: Color = _theme.get("accent", Color(0.30, 0.85, 0.72))
				for row in 3:
					draw_rect(Rect2(rect.position.x + 3.0, rect.position.y + 4.0 + row * 6.0,
						rect.size.x - 6.0, 2.0), Color(0.18, 0.28, 0.32))
					var on: bool = fmod(_t * 1.6 + float(rng2.randi() % 10) * 0.3, 3.0) < 1.5
					if on:
						draw_rect(Rect2(rect.end.x - 6.0, rect.position.y + 4.0 + row * 6.0,
							2.0, 2.0), accent)
			"pipe":
				draw_rect(rect, Color(0.20, 0.12, 0.17))
				draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)),
					Color(0.34, 0.20, 0.27))
				var pulse: float = 0.35 + 0.35 * sin(_t * 2.2)
				draw_rect(rect, Color(0.95, 0.42, 0.45, 0.10 + pulse * 0.10))
			"node":
				var glow2: Color = _theme.get("accent", Color(0.95, 0.42, 0.45))
				var p3: float = 0.4 + 0.6 * absf(sin(_t * 2.6 + float(seed_v % 7)))
				draw_rect(rect, Color(0.24, 0.14, 0.19))
				draw_rect(rect.grow(-2.0), Color(glow2.r, glow2.g, glow2.b, 0.35 + 0.4 * p3))
			"vshelf":
				draw_rect(rect, Color(0.26, 0.30, 0.40))
				draw_rect(rect, Color(0.14, 0.17, 0.24), false, 1.0)
				var rng3 := RandomNumberGenerator.new()
				rng3.seed = seed_v
				var cols3 := [Color(0.55, 0.68, 0.92), Color(0.72, 0.58, 0.45),
					Color(0.52, 0.76, 0.70), Color(0.80, 0.72, 0.45)]
				for i in 3:
					draw_rect(Rect2(rect.position.x + 2.0, rect.position.y + 2.0 + i * 5.5,
						rect.size.x - 4.0, 4.0), cols3[rng3.randi() % cols3.size()].darkened(0.15))
			"vrack":
				draw_rect(rect, Color(0.13, 0.20, 0.24))
				draw_rect(rect, Color(0.06, 0.10, 0.13), false, 1.0)
				var accent2: Color = _theme.get("accent", Color(0.30, 0.85, 0.72))
				for i2 in 3:
					draw_rect(Rect2(rect.position.x + 3.0, rect.position.y + 4.0 + i2 * 6.0,
						rect.size.x - 6.0, 2.0), Color(0.18, 0.28, 0.32))
					if fmod(_t * 2.0 + float((seed_v + i2 * 3) % 9) * 0.4, 2.4) < 1.2:
						draw_rect(Rect2(rect.end.x - 5.0, rect.position.y + 4.0 + i2 * 6.0,
							2.0, 2.0), accent2)
			"vpipe":
				draw_rect(rect, Color(0.20, 0.12, 0.17))
				var pulse2: float = 0.3 + 0.5 * absf(sin(_t * 2.0 + float(seed_v % 5)))
				draw_rect(rect.grow(-3.0), Color(0.95, 0.42, 0.45, 0.25 + 0.35 * pulse2))


func _draw_obstacles() -> void:
	for o in _obstacles:
		var rr: Rect2 = o
		draw_rect(Rect2(rr.position + Vector2(4, 4), rr.size), Color(0, 0, 0, 0.22))
		var base: Color = _theme.get("wall", Color(0.2, 0.22, 0.3))
		draw_rect(rr, base.lightened(0.04))
		draw_rect(rr, base.lightened(0.22), false, 2.0)
		draw_rect(Rect2(rr.position, Vector2(rr.size.x, 6)), base.lightened(0.30))
		draw_rect(Rect2(rr.position + Vector2(0, rr.size.y - 8), Vector2(rr.size.x, 8)),
			base.darkened(0.28))


func _draw_walls(r: Rect2) -> void:
	var w := GameConfig.WALL
	var wall: Color = _theme.get("wall", Color(0.35, 0.42, 0.55))
	var top: Color = _theme.get("wall_top", Color(0.47, 0.55, 0.68))
	var edge: Color = _theme.get("wall_edge", Color(0.16, 0.20, 0.28))
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
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), top, 2.0)
	# 墙体内缘 1px 暗色描边，强化空间感
	var inner := Rect2(w, w, r.size.x - w * 2.0, r.size.y - w * 2.0)
	draw_rect(inner, Color(edge.r, edge.g, edge.b, 0.75), false, 1.0)


func _draw_door(r: Rect2) -> void:
	var w := GameConfig.WALL
	var gap_top: float = r.position.y + r.size.y * 0.5 - DOOR_H * 0.5
	var dz := door_zone()
	var accent: Color = _theme.get("accent", Color(0.95, 0.72, 0.24))
	if door_open:
		var a2: float = 0.35 + 0.25 * sin(_t * 4.0)
		draw_rect(dz, Color(accent.r, accent.g, accent.b, 0.20))
		draw_rect(dz, Color(accent.r, accent.g, accent.b, a2), false, 2.0)
		for i in 3:
			var yy := dz.position.y + 14.0 + i * 18.0
			draw_line(Vector2(dz.position.x + 6, yy), Vector2(dz.end.x - 6, yy),
				Color(accent.r, accent.g, accent.b, 0.55), 2.0)
	else:
		draw_rect(Rect2(dz.position.x, gap_top, w, DOOR_H),
			(_theme.get("wall", Color(0.35, 0.42, 0.55)) as Color).darkened(0.35))
		draw_rect(Rect2(dz.position.x + 3, gap_top + 4, w - 6, DOOR_H - 8),
			Color(accent.r, accent.g, accent.b, 0.55))


## Boss 房强化：边缘呼吸光晕
func _draw_boss_glow(r: Rect2) -> void:
	var accent: Color = _theme.get("accent", Color(0.95, 0.42, 0.45))
	var pulse: float = 0.5 + 0.5 * sin(_t * 1.8)
	for i in 5:
		var d: float = 6.0 + i * 7.0
		var a: float = (0.16 - i * 0.026) * (0.6 + 0.4 * pulse)
		draw_rect(Rect2(d, d, r.size.x - d * 2.0, r.size.y - d * 2.0),
			Color(accent.r, accent.g, accent.b, a), false, 2.0)


## 进房间的 0.3s 淡入（用主题墙色，避免硬切）
func _draw_fade(r: Rect2) -> void:
	if _fade <= 0.001:
		return
	var c: Color = _theme.get("wall", Color(0.2, 0.25, 0.35))
	draw_rect(r, Color(c.r * 0.8, c.g * 0.8, c.b * 0.85, clampf(_fade, 0.0, 1.0)))
