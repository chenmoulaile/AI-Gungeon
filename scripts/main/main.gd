extends Node
## 主控：角色选择 -> 游戏 -> 结算 -> 重新开始

const SelectScene = preload("res://scenes/ui/character_select.tscn")
const GameScene = preload("res://scenes/main/game.tscn")
const ResultScene = preload("res://scenes/ui/result.tscn")
const CollectionScene = preload("res://scenes/ui/collection_menu.tscn")
const TrainingScene = preload("res://scenes/training/training_room.tscn")

var current: Node = null


func _ready() -> void:
	show_select()


func _swap(node: Node) -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = node
	add_child(node)


func show_select() -> void:
	MusicManager.play("explore")
	GameState.player = null
	GameState.bullets_root = null
	var s: Node = SelectScene.instantiate()
	s.character_chosen.connect(_on_character_chosen)
	s.open_collection.connect(show_collection)
	s.open_training.connect(show_training)
	_swap(s)


func _on_character_chosen(id: String, seed_text: String = "", difficulty: int = 1) -> void:
	print("[pick] ", id, " seed=", seed_text, " diff=", difficulty)
	SeedManager.difficulty = difficulty
	GameState.start_run(id, seed_text)
	var g: Node = GameScene.instantiate()
	g.run_over.connect(_on_run_over)
	_swap(g)


func show_training() -> void:
	var t: Node = TrainingScene.instantiate()
	t.exit_requested.connect(show_select)
	_swap(t)


func show_collection() -> void:
	var c: Node = CollectionScene.instantiate()
	c.closed.connect(show_select)
	_swap(c)


func _on_run_over() -> void:
	var r: Node = ResultScene.instantiate()
	r.restart.connect(func() -> void: _on_character_chosen(GameState.char_id))
	r.to_menu.connect(show_select)
	_swap(r)
