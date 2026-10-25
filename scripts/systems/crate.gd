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
	if SeedManager.randf() < 0.5:
		GameState.heal(1)
	else:
		var coin_scene = load("res://scripts/systems/coin.gd")
		for i in SeedManager.randi_range(3, 5):
			var c: Node2D = coin_scene.new()
			c.value = 1
			c.global_position = global_position + Vector2(SeedManager.randf_range(-8, 8), SeedManager.randf_range(-8, 8))
			GameState.bullets_root.add_child(c)
	queue_free()


func _draw() -> void:
	# 26×26 木箱：1px 深描边 + 2px 亮边 + 整数像素木纹
	var r := Rect2(-13.0, -26.0, 26.0, 26.0)
	draw_rect(r, Color("#5C4128"))
	draw_rect(r, Color("#1A0F06"), false, 1.0)
	draw_rect(Rect2(-12.0, -25.0, 24.0, 2.0), Color("#7A5836"))
	draw_rect(Rect2(-12.0, -8.0, 24.0, 2.0), Color("#3A2614"))
	draw_rect(Rect2(-4.0, -25.0, 2.0, 24.0), Color("#3A2614"))
	draw_rect(Rect2(2.0, -25.0, 2.0, 24.0), Color("#7A5836"))
