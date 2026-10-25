class_name FloorMap
extends RefCounted
## 每层分支地图（v0.10 MVP）：7 节点菱形网
## 入口 -> [战斗 / 精英] -> 事件 -> [战斗 / 商店] -> Boss
## 用 seed 文本 + 层数做确定性哈希，不消耗主随机数流，续玩可原样重建。

const KIND_SMALL := "small"
const KIND_MIXED := "mixed"
const KIND_ELITE := "elite"
const KIND_EVENT := "event"
const KIND_CLIMAX := "climax"
const KIND_SHOP := "shop"
const KIND_BOSS := "boss"

const START_ID := 0
const BOSS_ID := 6
const NODE_COUNT := 7
const LAYERS := 5

var floor_index: int = 1
var seed_text: String = ""
var nodes: Dictionary = {}   # id:int -> {id, kind, layer, lane, next, name, desc}


static func generate(fi: int, seed_in: String = "") -> FloorMap:
	var m := FloorMap.new()
	m.floor_index = fi
	m.seed_text = seed_in
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("floormap|%d|%s" % [fi, seed_in])
	var swap_a := rng.randi() % 2 == 1
	var swap_b := rng.randi() % 2 == 1
	var a_left := KIND_MIXED
	var a_right := KIND_ELITE
	if swap_a:
		a_left = KIND_ELITE
		a_right = KIND_MIXED
	var b_left := KIND_CLIMAX
	var b_right := KIND_SHOP
	if swap_b:
		b_left = KIND_SHOP
		b_right = KIND_CLIMAX

	m._add(0, KIND_SMALL, 0, 1, [1, 2])
	m._add(1, a_left, 1, 0, [3])
	m._add(2, a_right, 1, 2, [3])
	m._add(3, KIND_EVENT, 2, 1, [4, 5])
	m._add(4, b_left, 3, 0, [6])
	m._add(5, b_right, 3, 2, [6])
	m._add(6, KIND_BOSS, 4, 1, [])
	return m


func _add(id: int, kind: String, layer: int, lane: int, next: Array) -> void:
	nodes[id] = {
		"id": id,
		"kind": kind,
		"layer": layer,
		"lane": lane,
		"next": next,
		"name": kind_name(kind),
		"desc": kind_desc(kind),
	}


func node_at(id: int) -> Dictionary:
	return nodes.get(id, {})


func has_id(id: int) -> bool:
	return nodes.has(id)


func next_of(id: int) -> Array:
	var n: Dictionary = node_at(id)
	return [] if n.is_empty() else (n["next"] as Array).duplicate()


## 当前节点是否有两个分支可选
func is_choice(id: int) -> bool:
	return next_of(id).size() >= 2


func find_first(kind: String) -> int:
	for i in NODE_COUNT:
		var n: Dictionary = node_at(i)
		if not n.is_empty() and String(n["kind"]) == kind:
			return i
	return -1


## 该层是否有某种节点（例如商店）
func has_kind(kind: String) -> bool:
	return find_first(kind) >= 0


static func kind_name(kind: String) -> String:
	match kind:
		KIND_SMALL, KIND_MIXED, KIND_CLIMAX:
			return "战斗房"
		KIND_ELITE:
			return "精英房"
		KIND_EVENT:
			return "事件房"
		KIND_SHOP:
			return "商店"
		KIND_BOSS:
			return "Boss 房"
	return "未知"


static func kind_desc(kind: String) -> String:
	match kind:
		KIND_SMALL:
			return "普通敌人 · 清场得金币"
		KIND_MIXED:
			return "普通敌人 · 两波清场"
		KIND_ELITE:
			return "强化敌人 · 必掉稀有藏品"
		KIND_EVENT:
			return "三选一 · 生命 / 藏品 / 金币"
		KIND_CLIMAX:
			return "三波强敌 · 金币更多"
		KIND_SHOP:
			return "花金币换战力 · 可刷新 / 治疗"
		KIND_BOSS:
			return "本层终点"
	return ""


static func kind_short(kind: String) -> String:
	match kind:
		KIND_SMALL, KIND_MIXED, KIND_CLIMAX:
			return "战"
		KIND_ELITE:
			return "精"
		KIND_EVENT:
			return "事"
		KIND_SHOP:
			return "商"
		KIND_BOSS:
			return "B"
	return "?"


static func kind_color(kind: String) -> String:
	match kind:
		KIND_ELITE:
			return "#B06BFF"
		KIND_EVENT:
			return "#FFD166"
		KIND_SHOP:
			return "#63E6BE"
		KIND_BOSS:
			return "#FF5A63"
	return "#8EE6FF"
