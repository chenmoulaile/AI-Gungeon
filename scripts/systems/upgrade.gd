class_name Upgrade
extends Resource
## 藏品数据（resources/upgrades/*.tres）
## effects 支持的键见 GameState.recalc_stats()

@export var id: String = ""
@export var title: String = ""
@export var desc: String = ""
@export var price: int = 25
@export var icon_path: String = ""
@export var effects: Dictionary = {}
@export var char_tag: String = ""      # 专属角色（deepseek / gpt / claude / 空）
@export var mutation: bool = false     # 是否为质变型藏品
