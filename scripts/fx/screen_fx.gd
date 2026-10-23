extends CanvasLayer
## 全屏后处理（Autoload: ScreenFx）：暗角 / 色差 / 全屏闪色 / 弹幕密集警示
## 位于世界层之上、UI 之下（layer 5），不污染 HUD 文字

var _rect: ColorRect = null
var _mat: ShaderMaterial = null
var _vignette: float = 0.0
var _aberration: float = 0.0
var _flash: float = 0.0
var _dense: float = 0.0
var _tint: Color = Color(1, 1, 1)
var _tween: Tween = null


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.name = "ScreenFx"
	_rect.position = Vector2.ZERO
	_rect.size = Vector2(GameConfig.BASE_W, GameConfig.BASE_H)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(1, 1, 1, 1)
	_mat = ShaderMaterial.new()
	if ResourceLoader.exists("res://shaders/ba_screen.gdshader"):
		_mat.shader = load("res://shaders/ba_screen.gdshader")
	_rect.material = _mat
	add_child(_rect)
	_mat.set_shader_parameter("screen_size", Vector2(GameConfig.BASE_W, GameConfig.BASE_H))
	get_viewport().size_changed.connect(_on_resize)
	set_battle(false, true)


func _on_resize() -> void:
	_rect.size = get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("screen_size", _rect.size)


func set_battle(on: bool, instant: bool = false) -> void:
	var target := 0.85 if on else 0.0
	if instant:
		_vignette = target
		_mat.set_shader_parameter("vignette", target)
		return
	_tween_to("vignette", target, 0.35)


## 全屏闪色：玩家死亡闪红 0.2s / Boss 转换闪白 0.15s
func flash(color: Color = Color(1, 1, 1), dur: float = 0.15, peak: float = 0.6) -> void:
	_tint = color
	_mat.set_shader_parameter("flash_color", color)
	_flash = peak
	_mat.set_shader_parameter("flash", peak)
	var tw := create_tween()
	tw.tween_method(_apply_flash, peak, 0.0, dur)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _apply_flash(v: float) -> void:
	_flash = v
	_mat.set_shader_parameter("flash", v)


## 重击 / Boss 阶段转换的短促色差（RGB 分离 2~3px，0.15s 后恢复）
func aberrate(strength: float = 2.6, dur: float = 0.15) -> void:
	_aberration = strength
	_mat.set_shader_parameter("aberration", strength)
	var tw := create_tween()
	tw.tween_method(_apply_aberration, strength, 0.0, dur)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _apply_aberration(v: float) -> void:
	_aberration = v
	_mat.set_shader_parameter("aberration", v)


## 弹幕密集度 0~1：由 game.gd 每 6 帧统计一次敌弹数量
func set_dense(v: float) -> void:
	var nv := clampf(v, 0.0, 1.0)
	if absf(nv - _dense) < 0.02:
		return
	_dense = nv
	_mat.set_shader_parameter("dense", nv)


func _tween_to(_param: String, target: float, dur: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_apply_vignette, _vignette, target, dur)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _apply_vignette(v: float) -> void:
	_vignette = v
	_mat.set_shader_parameter("vignette", v)
