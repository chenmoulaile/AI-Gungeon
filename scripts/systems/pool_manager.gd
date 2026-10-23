class_name PoolManager
extends RefCounted
## 对象池回收规范：只 hide() 不够，必须停掉 process / 物理 / 碰撞体

static func recycle(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	_disable_shapes(node)
	if node.get_parent() != null:
		node.get_parent().remove_child(node)


static func revive(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.process_mode = Node.PROCESS_MODE_INHERIT
	node.set_process(true)
	node.set_physics_process(true)
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	_enable_shapes(node)


static func _disable_shapes(node: Node) -> void:
	for c in node.get_children():
		if c is CollisionShape2D:
			(c as CollisionShape2D).disabled = true
		elif c is CollisionPolygon2D:
			(c as CollisionPolygon2D).disabled = true
		elif c is Area2D:
			(c as Area2D).monitoring = false
		elif c is CollisionObject2D:
			(c as CollisionObject2D).set_physics_process(false)


static func _enable_shapes(node: Node) -> void:
	for c in node.get_children():
		if c is CollisionShape2D:
			(c as CollisionShape2D).disabled = false
		elif c is CollisionPolygon2D:
			(c as CollisionPolygon2D).disabled = false
		elif c is Area2D:
			(c as Area2D).monitoring = true
