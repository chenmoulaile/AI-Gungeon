extends Node
## 音频层（Autoload，注册名沿用 Sfx，避免全项目改调用点）
## 总线：Master / SFX / Music；音效全部代码合成；音高随机 ±10%；同类同时发声上限 4

const MAX_VOICES := 4
const PITCH_JITTER := 0.1
const SR := 22050
const PLAYER_POOL := 14

var _streams: Dictionary = {}
var _players: Array = []
var _next := 0
var _ends: Dictionary = {}   # name -> Array[float] 结束时间，用来数"当前还在响的同类音效"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_build_streams()
	for i in PLAYER_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)
	apply_volumes()


# ---------------- 总线 ----------------
func _ensure_buses() -> void:
	var layout_path := "res://resources/audio/bus_layout.tres"
	if ResourceLoader.exists(layout_path):
		var layout = load(layout_path)
		if layout is AudioBusLayout:
			AudioServer.set_bus_layout(layout)
	# 兜底：布局没加载成功时用代码建
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	# SFX 上挂 Limit，防止同时发声爆音
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0 and AudioServer.get_bus_effect_count(sfx_idx) == 0:
		var lim := AudioEffectLimiter.new()
		lim.threshold_db = -6.0
		lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(sfx_idx, lim)


func apply_volumes() -> void:
	var m := AudioServer.get_bus_index("Master")
	var s := AudioServer.get_bus_index("SFX")
	var mu := AudioServer.get_bus_index("Music")
	if m >= 0:
		AudioServer.set_bus_volume_db(m, linear_to_db(maxf(0.0001, Settings.master_volume)))
	if s >= 0:
		AudioServer.set_bus_volume_db(s, linear_to_db(maxf(0.0001, Settings.sfx_volume)))
	if mu >= 0:
		AudioServer.set_bus_volume_db(mu, linear_to_db(maxf(0.0001, Settings.music_volume)))


# ---------------- 合成 ----------------
func _build_streams() -> void:
	_streams["shoot"] = _tone(0.07, 880.0, 620.0, 26.0, "square", 0.22)
	_streams["hit"] = _tone(0.055, 340.0, 180.0, 30.0, "noise", 0.26)
	_streams["hurt"] = _mix([
		_tone(0.22, 200.0, 90.0, 9.0, "square", 0.30),
		_tone(0.22, 96.0, 60.0, 7.0, "sine", 0.18),
	])
	_streams["roll"] = _tone(0.16, 540.0, 240.0, 10.0, "sine", 0.20)
	_streams["coin"] = _mix([
		_tone(0.07, 1180.0, 1180.0, 16.0, "square", 0.14),
		_delay(_tone(0.10, 1580.0, 1580.0, 12.0, "square", 0.13), 0.06),
	])
	_streams["relic"] = _mix([
		_tone(0.09, 660.0, 660.0, 12.0, "square", 0.14),
		_delay(_tone(0.09, 880.0, 880.0, 12.0, "square", 0.14), 0.08),
		_delay(_tone(0.16, 1180.0, 1180.0, 8.0, "square", 0.15), 0.16),
	])
	_streams["boss"] = _mix([
		_tone(0.55, 110.0, 70.0, 3.0, "square", 0.30),
		_tone(0.45, 900.0, 300.0, 6.0, "noise", 0.10),
	])
	_streams["die"] = _mix([
		_tone(0.55, 260.0, 55.0, 4.0, "square", 0.28),
		_tone(0.55, 130.0, 40.0, 3.0, "sine", 0.18),
	])
	_streams["ui"] = _tone(0.05, 700.0, 700.0, 22.0, "square", 0.14)
	_streams["skill"] = _mix([
		_tone(0.30, 420.0, 980.0, 6.0, "sine", 0.22),
		_tone(0.30, 210.0, 480.0, 6.0, "square", 0.10),
	])


func _tone(duration: float, f0: float, f1: float, decay: float, kind: String,
		vol: float) -> AudioStreamWAV:
	var n := int(SR * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 31.0 + duration * 977.0)
	var phase := 0.0
	for i in n:
		var t := float(i) / SR
		var f: float = lerpf(f0, f1, t / maxf(duration, 0.0001))
		phase += TAU * f / SR
		var s := 0.0
		match kind:
			"square":
				s = 1.0 if sin(phase) >= 0.0 else -1.0
			"noise":
				s = rng.randf_range(-1.0, 1.0) * 0.7 + (1.0 if sin(phase) >= 0.0 else -1.0) * 0.3
			_:
				s = sin(phase)
		var env: float = exp(-decay * t) * (1.0 - exp(-220.0 * t))   # 快速起音 + 指数衰减
		data.encode_s16(i * 2, int(clampf(s * env * vol * 32767.0, -32768.0, 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = false
	wav.data = data
	return wav


func _delay(stream: AudioStreamWAV, seconds: float) -> AudioStreamWAV:
	var pad := int(SR * seconds) * 2
	var data := PackedByteArray()
	data.resize(pad)
	data.fill(0)
	data.append_array(stream.data)
	var wav := AudioStreamWAV.new()
	wav.format = stream.format
	wav.mix_rate = stream.mix_rate
	wav.stereo = false
	wav.data = data
	return wav


func _mix(parts: Array) -> AudioStreamWAV:
	var total := 0
	for p in parts:
		total = maxi(total, (p as AudioStreamWAV).data.size())
	var acc := PackedFloat32Array()
	acc.resize(total / 2)
	for p in parts:
		var d: PackedByteArray = (p as AudioStreamWAV).data
		var n := d.size() / 2
		for i in n:
			acc[i] += float(d.decode_s16(i * 2)) / 32768.0
	var out := PackedByteArray()
	out.resize(total)
	for i in acc.size():
		out.encode_s16(i * 2, int(clampf(acc[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = false
	wav.data = out
	return wav


# ---------------- 播放 ----------------
func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	# 清理已结束的记录，并统计同类正在发声的数量
	var arr: Array = _ends.get(name, [])
	var alive: Array = []
	for e in arr:
		if float(e) > now:
			alive.append(e)
	if alive.size() >= MAX_VOICES:
		_ends[name] = alive
		return   # 超过上限就跳过，而不是继续叠加
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.volume_db = -6.0 + volume_db
	var jitter := randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	p.pitch_scale = maxf(0.05, pitch * jitter)
	p.play()
	alive.append(now + float(_streams[name].get_length()) / maxf(p.pitch_scale, 0.05))
	_ends[name] = alive


## 与 hit-stop 对齐的命中音：由 GameFeel 在冻结开始时调用
func play_hit(crit: bool = false) -> void:
	play("hit", 0.0 if crit else -3.0, 1.08 if crit else 1.0)
