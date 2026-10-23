extends Sprite2D
## 翻滚残影：只做视觉，不参与任何逻辑（由 GameFeel.afterimage 创建并自毁）

func _ready() -> void:
	centered = true
	offset = Vector2(0, -29)
	z_index = -1
