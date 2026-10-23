extends Node
## 主控：启动画面 -> 主菜单 -> 角色选择 -> 游戏 -> 结算
## 所有场景切换统一走 Transition（淡入淡出 / 圆形遮罩 / 横向滑动），禁止硬切

const SplashScene = preload("res://scenes/ui/splash.tscn")
const MenuScene = preload("res://scenes/ui/main_menu.tscn")
const SelectScene = preload("res://scenes/ui/character_select.tscn")
const GameScene = preload("res://scenes/main/game.tscn")
const ResultScene = preload("res://scenes/ui/result.tscn")
const CollectionScene = preload("res://scenes/ui/collection_menu.tscn")
const TrainingScene = preload("res://scenes/training/training_room.tscn")
const SettingsScene = preload("res://scenes/ui/settings_menu.tscn")

var current: Node = null
var _settings: Node = null


func _ready() -> void:
	show_splash()


func _swap(node: Node) -> void:
	DialogueManager.clear()
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = node
	add_child(node)


# ---------------- 启动 ----------------
func show_splash() -> void:
	var s: Node = SplashScene.instantiate()
	_swap(s)
	s.finished.connect(func() -> void: Transition.play("fade", show_menu))


func show_menu() -> void:
	MusicManager.play("explore")
	GameState.player = null
	GameState.bullets_root = null
	ScreenFx.set_battle(false, true)
	var m: Node = MenuScene.instantiate()
	m.start_game.connect(func() -> void: Transition.play("fade", show_select))
	m.continue_run.connect(func() -> void: Transition.play("fade", resume_run))
	m.open_settings.connect(open_settings)
	m.open_collection.connect(func() -> void: Transition.play("fade", show_collection))
	m.open_training.connect(func() -> void: Transition.play("fade", show_training))
	m.open_about.connect(open_settings)
	_swap(m)


# ---------------- 角色选择 ----------------
func show_select() -> void:
	GameState.player = null
	GameState.bullets_root = null
	ScreenFx.set_battle(false, true)
	var s: Node = SelectScene.instantiate()
	s.character_chosen.connect(_on_character_chosen)
	s.open_collection.connect(func() -> void: Transition.play("fade", show_collection))
	s.open_training.connect(func() -> void: Transition.play("fade", show_training))
	s.resume_requested.connect(func() -> void: Transition.play("fade", resume_run))
	s.abandon_requested.connect(func() -> void:
		RunSave.clear()
		Transition.play("fade", show_select))
	_swap(s)


func _on_character_chosen(id: String, seed_text: String = "", difficulty: int = 1) -> void:
	SeedManager.difficulty = difficulty
	GameState.start_run(id, seed_text)
	Transition.play("circle", _start_game, 0.32)


func _start_game() -> void:
	var g: Node = GameScene.instantiate()
	g.run_over.connect(_on_run_over)
	_swap(g)


func resume_run() -> void:
	var d := RunSave.load_run()
	if d.is_empty():
		show_select()
		return
	GameState.restore_run(d)
	Transition.play("fade", _start_game)


# ---------------- 其它入口 ----------------
func show_training() -> void:
	var t: Node = TrainingScene.instantiate()
	t.exit_requested.connect(func() -> void: Transition.play("fade", show_select))
	_swap(t)


func show_collection() -> void:
	var c: Node = CollectionScene.instantiate()
	c.closed.connect(func() -> void: Transition.play("fade", show_menu))
	_swap(c)


func open_settings() -> void:
	if _settings != null and is_instance_valid(_settings):
		return
	DialogueManager.clear()
	_settings = SettingsScene.instantiate()
	add_child(_settings)
	_settings.closed.connect(func() -> void:
		if is_instance_valid(_settings):
			_settings.queue_free()
		_settings = null)


func _on_run_over() -> void:
	Transition.play("fade", func() -> void:
		var r: Node = ResultScene.instantiate()
		r.restart.connect(func() -> void:
			GameState.start_run(GameState.char_id)
			Transition.play("fade", _start_game))
		r.to_menu.connect(func() -> void: Transition.play("fade", show_menu))
		_swap(r))
