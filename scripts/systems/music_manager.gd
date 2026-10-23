extends Node
## 音乐层（Autoload）：双播放器交叉淡化 + 暂停降 12dB + 音效密集时侧链压低 3dB

const TRACKS := {
	"explore": "res://assets/audio/bgm_explore.wav",
	"combat": "res://assets/audio/bgm_combat.wav",
	"boss": "res://assets/audio/bgm_boss.wav",
}

const FADE := 1.0
const PAUSE_DB := -12.0
const DUCK_DB := -3.0
const DUCK_TIME := 0.15

var _players: Array = []
var _active: int = 0
var _current: String = ""
var _duck_t: float = 0.0
var _was_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.volume_db = -60.0
		add_child(p)
		_players.append(p)
	Settings.changed.connect(refresh_bus)
	refresh_bus()


func _process(delta: float) -> void:
	if _duck_t > 0.0:
		_duck_t -= delta
		if _duck_t <= 0.0:
			refresh_bus()
	var paused := get_tree().paused
	if paused != _was_paused:
		_was_paused = paused
		refresh_bus()


## 切换曲目：0.8~1.2s 交叉淡化
func play(track: String, fade: float = FADE) -> void:
	if not TRACKS.has(track):
		return
	if track == _current:
		return
	_current = track
	if not ResourceLoader.exists(TRACKS[track]):
		return
	var stream: AudioStream = load(TRACKS[track])
	var next: AudioStreamPlayer = _players[1 - _active]
	var prev: AudioStreamPlayer = _players[_active]
	next.stream = stream
	next.volume_db = -60.0
	next.play()
	_active = 1 - _active
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(next, "volume_db", 0.0, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(prev, "volume_db", -60.0, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(prev.stop)
	refresh_bus()


## 音效密集时压一下音乐，0.15s 后恢复
func duck(_amount: float = DUCK_DB) -> void:
	_duck_t = DUCK_TIME
	refresh_bus()


func refresh_bus() -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	var db := linear_to_db(maxf(0.0001, Settings.music_volume))
	if get_tree().paused:
		db += PAUSE_DB
	if _duck_t > 0.0:
		db += DUCK_DB
	AudioServer.set_bus_volume_db(idx, db)


func stop() -> void:
	_current = ""
	for p in _players:
		p.stop()
