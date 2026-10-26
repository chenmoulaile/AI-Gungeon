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
const AboutScene = preload("res://scenes/ui/about_menu.tscn")

const PauseScript = preload("res://scripts/ui/pause_menu.gd")

var current: Node = null
var _settings: Node = null
var _pause_menu: Node = null
var _pause_layer: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Web：浏览器里点一下画面就把焦点交给 canvas，键鼠才会立刻响应
	get_window().grab_focus()
	# 网页验收：?enemies / ?bullets / ?floor=N 直接开局，跳过启动画面与菜单
	var q := _web_debug_query()
	if q.contains("enemies") or q.contains("bullets") or q.contains("floor="):
		GameState.start_run("deepseek")
		call_deferred("_start_game")
		return
	show_splash()


func _web_debug_query() -> String:
	var js = Engine.get_singleton("JavaScriptBridge")
	if js == null:
		return ""
	var raw = js.eval("window.location.search", true)
	return "" if raw == null else str(raw)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		get_window().grab_focus()


## ESC：游戏中暂停 / 暂停中继续；菜单里不响应
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_close_pause()
		get_viewport().set_input_as_handled()
		return
	# 对话 / Boss 登场会主动暂停游戏，此时 ESC 归对话框推进，不能再抢暂停
	if get_tree().paused:
		return
	if current != null and is_instance_valid(current) and current.get("is_gameplay") == true:
		_open_pause()
		get_viewport().set_input_as_handled()


func _open_pause() -> void:
	if _pause_menu != null and is_instance_valid(_pause_menu):
		return
	_pause_menu = PauseScript.new()
	_pause_menu.name = "PauseMenu"
	# 训练场里 ESC 只打开暂停菜单，退出训练场必须走菜单里的按钮
	_pause_menu.in_training = current != null and current.get("is_training_room") == true
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 100
	add_child(_pause_layer)
	_pause_layer.add_child(_pause_menu)
	_pause_menu.resume_pressed.connect(_close_pause)
	_pause_menu.menu_pressed.connect(func() -> void:
		_close_pause()
		Transition.play("fade", show_menu))
	_pause_menu.training_exit_pressed.connect(_exit_training)
	_pause_menu.quit_pressed.connect(func() -> void: get_tree().quit())
	DialogueManager.clear()
	get_tree().paused = true
	BaCursor.set_battle(false)


## 暂停菜单 -> 退出训练场：先关菜单再让训练场自己发 exit_requested
func _exit_training() -> void:
	var t := current
	_close_pause()
	if t != null and is_instance_valid(t) and t.has_method("exit_training"):
		t.exit_training()


func _close_pause() -> void:
	get_tree().paused = false
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
	_pause_menu = null
	if _pause_layer != null and is_instance_valid(_pause_layer):
		_pause_layer.queue_free()
	_pause_layer = null
	InputBuffer.clear_all()


func _swap(node: Node) -> void:
	# 任何场景切换都必须先解除暂停并销毁暂停菜单，否则菜单会残留在新场景上
	_close_pause()
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
	m.open_about.connect(func() -> void: Transition.play("fade", show_about))
	m.quit_game.connect(func() -> void: get_tree().quit())
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


func show_about() -> void:
	var a: Node = AboutScene.instantiate()
	a.closed.connect(func() -> void: Transition.play("fade", show_menu))
	_swap(a)


func open_settings() -> void:
	if _settings != null and is_instance_valid(_settings):
		return
	DialogueManager.clear()
	_settings = SettingsScene.instantiate()
	var layer := CanvasLayer.new()
	layer.layer = 110
	add_child(layer)
	layer.add_child(_settings)
	_settings.closed.connect(func() -> void:
		if is_instance_valid(_settings):
			_settings.queue_free()
		_settings = null
		if is_instance_valid(layer):
			layer.queue_free())


func _on_run_over() -> void:
	Transition.play("fade", func() -> void:
		var r: Node = ResultScene.instantiate()
		r.restart.connect(func() -> void:
			GameState.start_run(GameState.char_id)
			Transition.play("fade", _start_game))
		r.to_menu.connect(func() -> void: Transition.play("fade", show_menu))
		_swap(r))
