extends Node
## 音频层（Autoload，注册名沿用 Sfx）
## 总线：Master / SFX / Music；音效全部代码合成并归一化到 -12 dBFS
## 非空间音效（玩家/Boss）走 AudioStreamPlayer；敌人音效走 AudioStreamPlayer2D（600px 衰减）

const MAX_VOICES := 4
const PITCH_JITTER := 0.1
const SR := 22050
const PLAYER_POOL := 14
const SPATIAL_POOL := 12
const TARGET_PEAK_DB := -12.0
const MERGE_WINDOW := 0.1

var _streams: Dictionary = {}
var _players: Array = []
var _spatial: Array = []
var _next := 0
var _next_s := 0
var _ends: Dictionary = {}
var _merge: Dictionary = {}
var _amb: AudioStreamPlayer = null
var _amb_kind: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_amb = AudioStreamPlayer.new()
	_amb.bus = "Music"
	_amb.volume_db = -26.0
	_amb.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_amb)
	_ensure_buses()
	_build_streams()
	for i in PLAYER_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)
	for i in SPATIAL_POOL:
		var s := AudioStreamPlayer2D.new()
		s.bus = "SFX"
		s.max_distance = 600.0
		s.attenuation = 1.5
		s.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(s)
		_spatial.append(s)
	apply_volumes()


# ---------------- 总线 ----------------
func _ensure_buses() -> void:
	var layout_path := "res://resources/audio/bus_layout.tres"
	if ResourceLoader.exists(layout_path):
		var layout = load(layout_path)
		if layout is AudioBusLayout:
			AudioServer.set_bus_layout(layout)
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0 and AudioServer.get_bus_effect_count(sfx_idx) == 0:
		var lim := AudioEffectLimiter.new()
		lim.threshold_db = -6.0
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(sfx_idx, lim)


func apply_volumes() -> void:
	var m := AudioServer.get_bus_index("Master")
	var s := AudioServer.get_bus_index("SFX")
	if m >= 0:
		AudioServer.set_bus_volume_db(m, linear_to_db(maxf(0.0001, Settings.master_volume)))
	if s >= 0:
		AudioServer.set_bus_volume_db(s, linear_to_db(maxf(0.0001, Settings.sfx_volume)))
	MusicManager.refresh_bus()


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
	# 光标悬停 / 确认：比 ui 更轻，避免菜单里高频点击时刺耳
	_streams["ui_hover"] = _tone(0.03, 1250.0, 1250.0, 46.0, "sine", 0.09)
	# 层间转场：上升的和弦 + 低频落点
	_streams["floor_shift"] = _mix([
		_tone(0.40, 220.0, 440.0, 2.6, "sine", 0.15),
		_delay(_tone(0.34, 330.0, 660.0, 2.2, "sine", 0.11), 0.10),
		_delay(_tone(0.45, 120.0, 70.0, 3.0, "square", 0.16), 0.22),
	])
	_streams["ui_confirm"] = _mix([
		_tone(0.04, 980.0, 1320.0, 34.0, "sine", 0.16),
		_delay(_tone(0.05, 1320.0, 1560.0, 30.0, "sine", 0.12), 0.04),
	])
	_streams["skill"] = _mix([
		_tone(0.30, 420.0, 980.0, 6.0, "sine", 0.22),
		_tone(0.30, 210.0, 480.0, 6.0, "square", 0.10),
	])
	# ---- 新增弹幕 / 敌人行为 ----
	_streams["warn_high"] = _tone(0.20, 900.0, 1700.0, 6.0, "sine", 0.20)
	_streams["spiral_fire"] = _mix([
		_tone(0.80, 300.0, 240.0, 2.2, "tri", 0.20),
		_tone(0.80, 452.0, 360.0, 2.4, "sine", 0.10),
	])
	_streams["lock_beep"] = _tone(0.08, 1400.0, 1400.0, 20.0, "square", 0.20)
	_streams["whoosh"] = _tone(0.22, 300.0, 90.0, 8.0, "noise", 0.22)
	_streams["laser_charge"] = _tone(0.50, 260.0, 1200.0, 1.2, "sine", 0.20)
	_streams["laser_fire"] = _mix([
		_tone(0.80, 1200.0, 900.0, 1.0, "noise", 0.18),
		_tone(0.80, 220.0, 220.0, 1.4, "saw", 0.12),
	])
	_streams["mine_drop"] = _tone(0.05, 420.0, 300.0, 30.0, "tri", 0.20)
	_streams["mine_beep"] = _tone(0.06, 1800.0, 1800.0, 26.0, "square", 0.18)
	_streams["boom"] = _mix([
		_tone(0.40, 120.0, 40.0, 5.0, "sine", 0.34),
		_tone(0.35, 600.0, 200.0, 8.0, "noise", 0.18),
	])
	_streams["bounce"] = _tone(0.09, 520.0, 380.0, 14.0, "tri", 0.22)
	_streams["charge_windup"] = _tone(0.60, 90.0, 150.0, 1.6, "saw", 0.20)
	_streams["dash"] = _tone(0.30, 700.0, 160.0, 5.0, "noise", 0.22)
	_streams["ring_warn"] = _tone(0.50, 420.0, 620.0, 2.0, "tri", 0.18)
	_streams["summon_cast"] = _mix([
		_tone(0.30, 500.0, 900.0, 4.0, "square", 0.14),
		_tone(0.30, 250.0, 450.0, 4.0, "sine", 0.12),
	])
	_streams["summon_pop"] = _tone(0.12, 900.0, 1400.0, 12.0, "tri", 0.18)
	_streams["clang"] = _mix([
		_tone(0.14, 2400.0, 1800.0, 14.0, "square", 0.16),
		_tone(0.10, 3200.0, 2600.0, 18.0, "sine", 0.10),
	])
	_streams["crack"] = _tone(0.26, 900.0, 220.0, 9.0, "noise", 0.24)


func _tone(duration: float, f0: float, f1: float, decay: float, kind: String,
		vol: float) -> AudioStreamWAV:
	var n := int(SR * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 31.0 + duration * 977.0)
	var phase := 0.0
	var peak := 0.0001
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / SR
		var f: float = lerpf(f0, f1, t / maxf(duration, 0.0001))
		phase += TAU * f / SR
		var s := 0.0
		match kind:
			"square":
				s = 1.0 if sin(phase) >= 0.0 else -1.0
			"tri":
				s = 2.0 / PI * asin(sin(phase))
			"saw":
				s = 2.0 * fmod(phase / TAU, 1.0) - 1.0
			"noise":
				s = rng.randf_range(-1.0, 1.0) * 0.7 + (1.0 if sin(phase) >= 0.0 else -1.0) * 0.3
			_:
				s = sin(phase)
		var env: float = exp(-decay * t) * (1.0 - exp(-220.0 * t))
		buf[i] = s * env * vol
		peak = maxf(peak, absf(buf[i]))
	# 统一归一化到 -12 dBFS
	var gain: float = pow(10.0, TARGET_PEAK_DB / 20.0) / peak
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i] * gain * 32767.0, -32768.0, 32767.0)))
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
	var peak := 0.0001
	for i in acc.size():
		peak = maxf(peak, absf(acc[i]))
	var gain: float = pow(10.0, TARGET_PEAK_DB / 20.0) / peak
	var out := PackedByteArray()
	out.resize(total)
	for i in acc.size():
		out.encode_s16(i * 2, int(clampf(acc[i] * gain, -1.0, 1.0) * 32767.0))
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
	var arr: Array = _ends.get(name, [])
	var alive: Array = []
	for e in arr:
		if float(e) > now:
			alive.append(e)
	if alive.size() >= MAX_VOICES:
		_ends[name] = alive
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.volume_db = -6.0 + volume_db
	var jitter := randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	p.pitch_scale = maxf(0.05, pitch * jitter)
	p.play()
	alive.append(now + float(_streams[name].get_length()) / maxf(p.pitch_scale, 0.05))
	_ends[name] = alive
	# 密集音效时侧链压低音乐
	if alive.size() >= 2:
		MusicManager.duck()


## 空间音效：敌人弹幕/行为，600px 内可听
func play_at(name: String, pos: Vector2, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var key := "%s@%d_%d" % [name, int(pos.x / 32.0), int(pos.y / 32.0)]
	if _merge.has(key) and now - float(_merge[key]) < MERGE_WINDOW:
		return
	_merge[key] = now
	var s: AudioStreamPlayer2D = _spatial[_next_s]
	_next_s = (_next_s + 1) % _spatial.size()
	s.stream = _streams[name]
	s.volume_db = -4.0 + volume_db
	s.pitch_scale = maxf(0.05, pitch * randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER))
	s.global_position = pos
	s.play()
	if _merge.size() > 64:
		_merge.clear()


func play_hit(crit: bool = false) -> void:
	play("hit", 0.0 if crit else -3.0, 1.08 if crit else 1.0)


func stop_all() -> void:
	for p in _players:
		p.stop()
	for s in _spatial:
		s.stop()


# ---------------- 环境底噪（按楼层） ----------------
## 生成可无缝循环的底噪：整数周期正弦 + 低通噪声
func _loop_noise(dur: float, hz: float, noise_amt: float, tone_amt: float) -> AudioStreamWAV:
	var n := int(dur * SR)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var cycles := maxf(1.0, round(hz * dur))
	for i in n:
		var t := float(i) / float(SR)
		var s1 := sin(TAU * cycles * float(i) / float(n))
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.05)
		var v := s1 * tone_amt + lp * noise_amt
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = SR
	st.stereo = false
	st.data = data
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	return st


func play_ambience(kind: String) -> void:
	if _amb == null:
		return
	if _amb_kind == kind and _amb.playing:
		return
	_amb_kind = kind
	var key := "amb_" + kind
	if not _streams.has(key):
		match kind:
			"f1":
				_streams[key] = _loop_noise(2.0, 60.0, 0.05, 0.05)
			"f2":
				_streams[key] = _loop_noise(2.0, 90.0, 0.10, 0.06)
			"f3":
				_streams[key] = _loop_noise(2.0, 45.0, 0.13, 0.07)
			_:
				_streams[key] = _loop_noise(2.0, 70.0, 0.04, 0.04)
	_amb.stream = _streams[key]
	_amb.play()


func stop_ambience() -> void:
	if _amb != null:
		_amb.stop()
	_amb_kind = ""
