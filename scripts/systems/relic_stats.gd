class_name RelicStats
extends Resource
## 质变藏品的钩子参数（resources/relics/*.tres）：GameState 按 trigger 写入 mods

@export var id: String = ""
@export var trigger: String = ""     # mods 里的键
@export var value: float = 1.0
@export var tag: String = ""         # 展示用标签
