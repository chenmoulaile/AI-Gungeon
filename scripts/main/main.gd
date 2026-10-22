extends Node
## 主控：角色选择 -> 游戏 -> 结算 -> 重新开始

const SelectScene = preload("res://scenes/ui/character_select.tscn")
const GameScene = preload("res://scenes/main/game.tscn")
const ResultScene = preload("res://scenes/ui/result.tscn")

var current: Node = null


func _ready() -> void:
	show_select()


func _swap(node: Node) -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = node
	add_child(node)


func show_select() -> void:
	GameState.player = null
	GameState.bullets_root = null
	var s: Node = SelectScene.instantiate()
	s.character_chosen.connect(_on_character_chosen)
	_swap(s)


func _on_character_chosen(id: String) -> void:
	GameState.start_run(id)
	var g: Node = GameScene.instantiate()
	g.run_over.connect(_on_run_over)
	_swap(g)


func _on_run_over() -> void:
	var r: Node = ResultScene.instantiate()
	r.restart.connect(show_select)
	_swap(r)
