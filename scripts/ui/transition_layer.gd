extends CanvasLayer
## 统一转场层（Autoload: Transition）
## 淡入淡出 / 圆形遮罩收缩（Boss 房）/ 横向滑动（商店），时长 0.25~0.35s，ease in out
## 转场期间用全屏 ColorRect 拦住输入，结束后恢复

signal covered

const DUR := 0.18
const MODES := {"fade": 0, "circle": 1, "slide": 2}

var busy: bool = false

var _rect: ColorRect = null
var _mat: ShaderMaterial = null
var _token: int = 0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.name = "Cover"
	_rect.color = Color(1, 1, 1, 1)
	_rect.position = Vector2.ZERO
	_rect.size = Vector2(GameConfig.BASE_W, GameConfig.BASE_H)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	_mat = ShaderMaterial.new()
	if ResourceLoader.exists("res://shaders/ba_transition.gdshader"):
		_mat.shader = load("res://shaders/ba_transition.gdshader")
	_rect.material = _mat
	add_child(_rect)


## 切场景：先盖住 -> 执行 mid -> 再揭开
func play(kind: String, mid: Callable, dur: float = DUR) -> void:
	_token += 1
	var token := _token
	busy = true
	_rect.visible = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var mode := int(MODES.get(kind, 0))
	_mat.set_shader_parameter("mode", mode)
	_mat.set_shader_parameter("progress", 0.0)
	await _tween_progress(0.0, 1.0, dur)
	if token != _token:
		return
	if mid.is_valid():
		mid.call()
	covered.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	await _tween_progress(1.0, 0.0, dur)
	if token != _token:
		return
	_rect.visible = false
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false


## 只盖住（用于加载），需要手动 reveal
func cover(kind: String = "fade", dur: float = DUR) -> void:
	_rect.visible = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_mat.set_shader_parameter("mode", int(MODES.get(kind, 0)))
	_mat.set_shader_parameter("progress", 0.0)
	await _tween_progress(0.0, 1.0, dur)


func reveal(dur: float = DUR) -> void:
	await _tween_progress(1.0, 0.0, dur)
	_rect.visible = false
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false


func _tween_progress(from: float, to: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_progress, from, to, maxf(0.01, dur))\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _set_progress(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("progress", v)
