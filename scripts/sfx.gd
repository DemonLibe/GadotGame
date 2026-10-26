class_name Sfx
extends RefCounted
## Процедурные звуки: гул тоннеля, шаги, капли, шёпот, удары. Генерируются один раз и кешируются.

const RATE := 22050

static var _cache := {}


static func drone() -> AudioStreamWAV:
	return _stream("drone")


static func step() -> AudioStreamWAV:
	return _stream("step")


static func drip() -> AudioStreamWAV:
	return _stream("drip")


static func sting() -> AudioStreamWAV:
	return _stream("sting")


static func whisper() -> AudioStreamWAV:
	return _stream("whisper")


static func hum() -> AudioStreamWAV:
	return _stream("hum")


static func clank() -> AudioStreamWAV:
	return _stream("clank")


static func click() -> AudioStreamWAV:
	return _stream("click")


static func rumble() -> AudioStreamWAV:
	return _stream("rumble")


static func heartbeat() -> AudioStreamWAV:
	return _stream("heartbeat")


static func flame() -> AudioStreamWAV:
	return _stream("flame")


static func pickup() -> AudioStreamWAV:
	return _stream("pickup")


static func _stream(key: String) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var w: AudioStreamWAV
	match key:
		"drone": w = _make_drone()
		"step": w = _make_step()
		"drip": w = _make_drip()
		"sting": w = _make_sting()
		"whisper": w = _make_whisper()
		"hum": w = _make_hum()
		"clank": w = _make_clank()
		"click": w = _make_click()
		"rumble": w = _make_rumble()
		"heartbeat": w = _make_heartbeat()
		"flame": w = _make_flame()
		_: w = _make_pickup()
	_cache[key] = w
	return w


static func _buf(seconds: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(RATE * seconds))
	return s


static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


# Низкий гул с «дыханием» — бесшовная петля 8 секунд.
static func _make_drone() -> AudioStreamWAV:
	var s := _buf(8.0)
	var lp := 0.0
	var lp2 := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += 0.02 * (randf_range(-1.0, 1.0) - lp)
		lp2 += 0.05 * (lp - lp2)
		var v := 0.18 * sin(TAU * 41.0 * t) + 0.12 * sin(TAU * 55.0 * t + 0.5 * sin(TAU * 0.25 * t)) + lp2 * 2.5
		v *= 0.75 + 0.25 * sin(TAU * 0.125 * t)
		s[i] = v * 0.6
	return _wav(s, true)


static func _make_step() -> AudioStreamWAV:
	var s := _buf(0.22)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += 0.25 * (randf_range(-1.0, 1.0) - lp)
		s[i] = (lp * 1.6 + 0.6 * sin(TAU * 65.0 * t) * exp(-t * 40.0)) * exp(-t * 28.0) * 0.8
	return _wav(s)


static func _make_drip() -> AudioStreamWAV:
	var s := _buf(0.35)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		phase += TAU * (1400.0 - 800.0 * minf(t * 8.0, 1.0)) / RATE
		s[i] = sin(phase) * exp(-t * 20.0) * 0.5
	return _wav(s)


# Резкий диссонанс для испуга.
static func _make_sting() -> AudioStreamWAV:
	var s := _buf(2.6)
	for i in s.size():
		var t := float(i) / RATE
		var env := minf(t * 60.0, 1.0) * exp(-t * 1.3)
		var v := sin(TAU * 110.0 * t) + sin(TAU * 116.5 * t) + 0.8 * sin(TAU * 155.6 * t) + 0.6 * sin(TAU * 233.1 * t)
		v += 0.25 * (sin(TAU * 1830.0 * t) + sin(TAU * 1897.0 * t)) * exp(-t * 2.5)
		v += randf_range(-1.0, 1.0) * exp(-t * 12.0) * 0.8
		s[i] = v * env * 0.22
	return _wav(s)


static func _make_whisper() -> AudioStreamWAV:
	var dur := 1.8
	var s := _buf(dur)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		lp += 0.15 * (n - lp)
		var band := n - lp
		var env := (0.5 + 0.5 * sin(TAU * 3.3 * t + 2.0 * sin(TAU * 1.1 * t))) * sin(PI * t / dur)
		s[i] = band * env * 0.45
	return _wav(s)


static func _make_hum() -> AudioStreamWAV:
	var s := _buf(1.0)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = 0.2 * sin(TAU * 50.0 * t) + 0.1 * sin(TAU * 100.0 * t) + 0.05 * sin(TAU * 150.0 * t)
	return _wav(s, true)


static func _make_clank() -> AudioStreamWAV:
	var s := _buf(0.6)
	for i in s.size():
		var t := float(i) / RATE
		var v := sin(TAU * 420.0 * t) + 0.7 * sin(TAU * 1130.0 * t) + 0.4 * sin(TAU * 2370.0 * t)
		s[i] = (v * exp(-t * 9.0) * 0.3 + randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.5)
	return _wav(s)


static func _make_click() -> AudioStreamWAV:
	var s := _buf(0.05)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = randf_range(-1.0, 1.0) * exp(-t * 200.0) * 0.6
	return _wav(s)


static func _make_rumble() -> AudioStreamWAV:
	var dur := 3.5
	var s := _buf(dur)
	var lp := 0.0
	var lp2 := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += 0.02 * (randf_range(-1.0, 1.0) - lp)
		lp2 += 0.05 * (lp - lp2)
		var env := minf(t * 4.0, 1.0) * exp(-t * 1.1)
		var knock := 0.0
		if randf() < 0.0004:
			knock = randf_range(-1.0, 1.0)
		s[i] = clampf(lp2 * 9.0 * env + knock * env, -1.0, 1.0)
	return _wav(s)


static func _make_heartbeat() -> AudioStreamWAV:
	var s := _buf(0.6)
	for i in s.size():
		var t := float(i) / RATE
		var a := sin(TAU * 52.0 * t) * exp(-t * 22.0)
		var t2 := t - 0.26
		var b := 0.0
		if t2 > 0.0:
			b = 0.7 * sin(TAU * 48.0 * t2) * exp(-t2 * 22.0)
		s[i] = (a + b) * 0.9
	return _wav(s)


static func _make_flame() -> AudioStreamWAV:
	var s := _buf(1.0)
	var lp := 0.0
	var lp2 := 0.0
	for i in s.size():
		var n := randf_range(-1.0, 1.0)
		lp += 0.3 * (n - lp)
		lp2 += 0.02 * (n - lp2)
		s[i] = (lp - lp2) * 0.5
	return _wav(s, true)


static func _make_pickup() -> AudioStreamWAV:
	var s := _buf(0.25)
	for i in s.size():
		var t := float(i) / RATE
		var f := 600.0 if t < 0.1 else 900.0
		s[i] = sin(TAU * f * t) * exp(-fmod(t, 0.1) * 30.0) * 0.25
	return _wav(s)
