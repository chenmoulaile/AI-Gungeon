class_name FloorTheme
extends RefCounted
## 三层视觉主题：地面配色 / 纹理类型 / 墙壁 / 环境光 / 装饰 / 氛围粒子
## 房间与层间转场都从这里取色，改一处即可全层统一

const THEMES := [
	{
		"id": "archive",
		"name": "档案库",
		"subtitle": "ARCHIVE STACK",
		# B1 深青石：三阶 #1B2A2E / #24383C / 铜 #8A6A3A
		"floor_a": Color("#1B2A2E"),
		"floor_b": Color("#24383C"),
		"floor_line": Color("#0E1618"),
		"wall": Color("#162326"),
		"wall_top": Color("#2B3F44"),
		"wall_edge": Color("#05090A"),
		"ambient": Color(0.94, 0.98, 0.99),
		"accent": Color("#8A6A3A"),
		"decor": "shelf",
		"particle": "mote",
		"light_energy": 0.45,
		"sprite_lum": 1.06,
		"fill_energy": 0.05,
	},
	{
		"id": "datacenter",
		"name": "数据中心",
		"subtitle": "DATA CENTER",
		# B2 深蓝：三阶 #141A2B / #1E2740 / 青 #7FE3FF
		"floor_a": Color("#141A2B"),
		"floor_b": Color("#1E2740"),
		"floor_line": Color("#0A0E19"),
		"wall": Color("#111827"),
		"wall_top": Color("#263252"),
		"wall_edge": Color("#03050B"),
		"ambient": Color(0.90, 0.95, 1.00),
		"accent": Color("#7FE3FF"),
		"decor": "rack",
		"particle": "data",
		"light_energy": 0.55,
		"sprite_lum": 1.10,
		"fill_energy": 0.06,
	},
	{
		"id": "core",
		"name": "核心区",
		"subtitle": "THE CORE",
		# B3 炭黑：三阶 #141018 / #241A2A / 品红 #FF5D7A
		"floor_a": Color("#141018"),
		"floor_b": Color("#241A2A"),
		"floor_line": Color("#09060A"),
		"wall": Color("#140E17"),
		"wall_top": Color("#2E2136"),
		"wall_edge": Color("#030105"),
		"ambient": Color(0.98, 0.93, 0.96),
		"accent": Color("#FF5D7A"),
		"decor": "conduit",
		"particle": "ember",
		"light_energy": 0.62,
		"sprite_lum": 1.12,
		"fill_energy": 0.07,
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
	t["floor_a"] = (base["floor_a"] as Color).darkened(0.16)
	t["floor_b"] = (base["floor_b"] as Color).darkened(0.20)
	t["floor_line"] = (base["floor_line"] as Color).darkened(0.12)
	t["ambient"] = Color((base["ambient"] as Color).r,
		(base["ambient"] as Color).g * 0.86, (base["ambient"] as Color).b * 0.88)
	t["boss"] = true
	return t
