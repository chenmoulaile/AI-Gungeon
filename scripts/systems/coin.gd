extends Node2D
## 金币掉落物：靠近自动吸附

var value: int = 1
var _player: Node2D = null
var _t: float = 0.0
var _picked: bool = false


func _ready() -> void:
	add_to_group("coins")
	_player = GameState.player
	_t = randf() * TAU


func _physics_process(delta: float) -> void:
	_t += delta * 6.0
	if _picked:
		return
	if _player == null or not is_instance_valid(_player):
		_player = GameState.player
	if _player != null and is_instance_valid(_player):
		var d := global_position.distance_to(_player.global_position)
		var magnet := float(GameState.stat("magnet", 34.0))
		if d < magnet:
			global_position = global_position.move_toward(_player.global_position, 260.0 * delta)
		if d < 13.0:
			_collect()
	queue_redraw()


func _collect() -> void:
	_picked = true
	GameState.add_coins(value)
	Sfx.play("coin", -10.0, randf_range(0.95, 1.2))
	queue_free()


func _draw() -> void:
	var bob := sin(_t) * 1.2
	var c := GameConfig.COL_GOLD
	draw_circle(Vector2(0, bob), 4.6, Color(0, 0, 0, 0.35))
	var pts := PackedVector2Array([
		Vector2(0, -3.4 + bob), Vector2(3.0, bob), Vector2(0, 3.4 + bob), Vector2(-3.0, bob),
	])
	draw_colored_polygon(pts, c)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
		Color(0.45, 0.3, 0.05, 0.9), 1.0)
	draw_circle(Vector2(-0.8, -1.0 + bob), 0.9, Color(1, 1, 1, 0.85))
