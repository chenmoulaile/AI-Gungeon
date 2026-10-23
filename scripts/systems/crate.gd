extends StaticBody2D
## 可破坏木箱：被玩家子弹打碎后掉 3~5 金币或 1 点小回复

var hp: int = 3
var size: Vector2 = Vector2(26, 26)
var dead: bool = false


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	add_to_group("crates")


func hit(dmg: float, _dir: Vector2) -> void:
	if dead:
		return
	hp -= int(maxf(1.0, dmg * 0.4))
	GameFeel.burst(global_position, Color(0.85, 0.65, 0.4), 4, 80.0, 0.2)
	Sfx.play("hit", -4.0, 1.3)
	if hp <= 0:
		_break()


func _break() -> void:
	dead = true
	GameFeel.burst(global_position, Color(0.9, 0.7, 0.45), 12, 140.0, 0.35)
	GameFeel.screen_shake(0.12)
	Sfx.play("hit", 0.0, 0.6)
	if randf() < 0.5:
		GameState.heal(1)
	else:
		var coin_scene = load("res://scripts/systems/coin.gd")
		for i in randi_range(3, 5):
			var c: Node2D = coin_scene.new()
			c.value = 1
			c.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
			GameState.bullets_root.add_child(c)
	queue_free()


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, Color(0.45, 0.32, 0.2))
	draw_rect(r, Color(0.62, 0.45, 0.28), false, 2.0)
	draw_line(Vector2(-size.x * 0.5, -size.y * 0.1), Vector2(size.x * 0.5, -size.y * 0.1),
		Color(0.3, 0.2, 0.12), 1.5)
	draw_line(Vector2(-size.x * 0.1, -size.y * 0.5), Vector2(-size.x * 0.1, size.y * 0.5),
		Color(0.3, 0.2, 0.12), 1.5)
