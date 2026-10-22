extends Node
## 简易音效池（autoload）：音效全部由 tools/make_ui_icons.py 程序化合成

const SOUNDS := {
	"shoot": "res://assets/audio/shoot.wav",
	"hit": "res://assets/audio/hit.wav",
	"hurt": "res://assets/audio/hurt.wav",
	"roll": "res://assets/audio/roll.wav",
	"coin": "res://assets/audio/coin.wav",
	"skill": "res://assets/audio/skill.wav",
	"boss": "res://assets/audio/boss.wav",
	"ui": "res://assets/audio/ui.wav",
	"die": "res://assets/audio/die.wav",
}

const POOL_SIZE := 10
const MIN_GAP := 0.045   # 同名音效最小间隔，避免密集射击时爆音

var streams: Dictionary = {}
var players: Array = []
var next_index: int = 0
var last_time: Dictionary = {}


func _ready() -> void:
	for key in SOUNDS.keys():
		if ResourceLoader.exists(SOUNDS[key]):
			streams[key] = load(SOUNDS[key])
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = -8.0
		add_child(p)
		players.append(p)


func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not streams.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if last_time.has(name) and now - float(last_time[name]) < MIN_GAP:
		return
	last_time[name] = now
	var p: AudioStreamPlayer = players[next_index]
	next_index = (next_index + 1) % players.size()
	p.stream = streams[name]
	p.volume_db = -8.0 + volume_db
	p.pitch_scale = pitch
	p.play()
