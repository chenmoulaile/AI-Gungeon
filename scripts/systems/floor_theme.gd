class_name FloorTheme
extends RefCounted
## 三层视觉主题：地面配色 / 纹理类型 / 墙壁 / 环境光 / 装饰 / 氛围粒子
## 房间与层间转场都从这里取色，改一处即可全层统一

const THEMES := [
	{
		"id": "archive",
		"name": "档案库",
		"subtitle": "ARCHIVE STACK",
		"floor_a": Color(0.72, 0.78, 0.86),
		"floor_b": Color(0.68, 0.74, 0.83),
		"floor_line": Color(0.55, 0.62, 0.72),
		"wall": Color(0.35, 0.42, 0.55),
		"wall_top": Color(0.47, 0.55, 0.68),
		"wall_edge": Color(0.16, 0.20, 0.28),
		"ambient": Color(0.85, 0.90, 1.00),
		"accent": Color(0.42, 0.62, 0.95),
		"decor": "shelf",
		"particle": "mote",
		"light_energy": 0.18,
		"sprite_lum": 1.04,
		"fill_energy": 0.0,
	},
	{
		"id": "datacenter",
		"name": "数据中心",
		"subtitle": "DATA CENTER",
		"floor_a": Color(0.55, 0.72, 0.68),
		"floor_b": Color(0.50, 0.66, 0.63),
		"floor_line": Color(0.36, 0.54, 0.51),
		"wall": Color(0.22, 0.35, 0.42),
		"wall_top": Color(0.31, 0.47, 0.53),
		"wall_edge": Color(0.10, 0.17, 0.22),
		"ambient": Color(0.80, 0.95, 0.92),
		"accent": Color(0.30, 0.85, 0.72),
		"decor": "rack",
		"particle": "data",
		"light_energy": 0.24,
		"sprite_lum": 1.16,
		"fill_energy": 0.02,
	},
	{
		"id": "core",
		"name": "核心区",
		"subtitle": "THE CORE",
		"floor_a": Color(0.55, 0.40, 0.48),
		"floor_b": Color(0.49, 0.35, 0.43),
		"floor_line": Color(0.36, 0.23, 0.30),
		"wall": Color(0.28, 0.18, 0.25),
		"wall_top": Color(0.40, 0.26, 0.34),
		"wall_edge": Color(0.12, 0.07, 0.10),
		"ambient": Color(1.00, 0.88, 0.90),
		"accent": Color(0.95, 0.42, 0.45),
		"decor": "conduit",
		"particle": "ember",
		"light_energy": 0.50,
		"sprite_lum": 1.32,
		"fill_energy": 0.08,
	},
]


## 第 4 层及以后循环使用最后一套主题（本轮只有三层）
static func get_theme(floor_index: int) -> Dictionary:
	var i: int = clampi(floor_index - 1, 0, THEMES.size() - 1)
	return THEMES[i]


static func theme_name(floor_index: int) -> String:
	return String(get_theme(floor_index)["name"])


static func boss_theme(base: Dictionary) -> Dictionary:
	## Boss 房：地面更暗、环境光更红、边缘加动态光晕
	var t: Dictionary = base.duplicate(true)
	t["floor_a"] = (base["floor_a"] as Color).darkened(0.30)
	t["floor_b"] = (base["floor_b"] as Color).darkened(0.34)
	t["floor_line"] = (base["floor_line"] as Color).darkened(0.25)
	t["ambient"] = Color((base["ambient"] as Color).r,
		(base["ambient"] as Color).g * 0.86, (base["ambient"] as Color).b * 0.88)
	t["boss"] = true
	return t
