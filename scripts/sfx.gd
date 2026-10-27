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


static func creak() -> AudioStreamWAV:
	return _stream("creak")


static func rung() -> AudioStreamWAV:
	return _stream("rung")


static func rain() -> AudioStreamWAV:
	return _stream("rain")


static func tick() -> AudioStreamWAV:
	return _stream("tick")


static func gunshot() -> AudioStreamWAV:
	return _stream("gunshot")


static func hiss() -> AudioStreamWAV:
	return _stream("hiss")


static func gasp() -> AudioStreamWAV:
	return _stream("gasp")


static func engine() -> AudioStreamWAV:
	return _stream("engine")


static func sparks() -> AudioStreamWAV:
	return _stream("sparks")


static func scuttle() -> AudioStreamWAV:
	return _stream("scuttle")


static func pump() -> AudioStreamWAV:
	return _stream("pump")


## Эмбиент: сквозняк в тоннеле, тёмный пэд, тревожный пэд (при сильном страхе), стон металла вдали.
static func wind() -> AudioStreamWAV:
	return _stream("wind")


static func pad() -> AudioStreamWAV:
	return _stream("pad")


static func pad_tense() -> AudioStreamWAV:
	return _stream("pad_tense")


static func groan() -> AudioStreamWAV:
	return _stream("groan")


## Крик для скримера: резкий, рваный, с перегрузом.
static func scream() -> AudioStreamWAV:
	return _stream("scream")


static func radio() -> AudioStreamWAV:
	return _stream("radio")


static func radio_loop() -> AudioStreamWAV:
	return _stream("radio_loop")


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
		"creak": w = _make_creak()
		"rung": w = _make_rung()
		"radio": w = _make_radio(0.5, false)
		"gunshot": w = _make_gunshot()
		"rain": w = _make_rain()
		"tick": w = _make_tick()
		"hiss": w = _make_hiss()
		"radio_loop": w = _make_radio(2.0, true)
		"gasp": w = _make_gasp()
		"engine": w = _make_engine()
		"sparks": w = _make_sparks()
		"scuttle": w = _make_scuttle()
		"pump": w = _make_pump()
		"scream": w = _make_scream()
		"wind": w = _make_wind()
		"pad": w = _make_pad([55.0, 65.5, 82.5, 110.0, 131.0], 0.25)
		"pad_tense": w = _make_pad([58.25, 77.75, 116.5, 155.5, 932.5], 0.5)
		"groan": w = _make_groan()
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


# Скрип тяжёлой крышки люка.
static func _make_creak() -> AudioStreamWAV:
	var dur := 1.3
	var s := _buf(dur)
	var phase := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := 95.0 + 40.0 * sin(t * 7.0) + 25.0 * sin(t * 23.0)
		phase += f / RATE
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		var env := minf(t * 8.0, 1.0) * minf((dur - t) * 4.0, 1.0)
		s[i] = (saw * 0.35 + randf_range(-1.0, 1.0) * 0.08) * env
	return _wav(s)


# Ступенька металлической лестницы.
static func _make_rung() -> AudioStreamWAV:
	var s := _buf(0.18)
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.6 * sin(TAU * 880.0 * t) + 0.35 * sin(TAU * 2310.0 * t)
		s[i] = (v * exp(-t * 28.0) + randf_range(-1.0, 1.0) * exp(-t * 150.0)) * 0.4
	return _wav(s)


# Помехи рации: шипение с треском. Короткий вариант начинается писком.
static func _make_radio(dur: float, loop: bool) -> AudioStreamWAV:
	var s := _buf(dur)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		lp += 0.35 * (n - lp)
		var band := n - lp
		var crackle := randf_range(-1.0, 1.0) if randf() < 0.002 else 0.0
		var v := band * (0.25 + 0.15 * sin(TAU * 3.0 * t)) + crackle * 0.8
		if not loop:
			v *= minf((dur - t) * 6.0, 1.0)
			if t < 0.08:
				v = sin(TAU * 1200.0 * t) * 0.3
		s[i] = v
	return _wav(s, loop)


# Выстрел в тоннеле: резкий хлопок и долгий гул эха.
static func _make_gunshot() -> AudioStreamWAV:
	var s := _buf(1.4)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		lp += 0.08 * (n - lp)
		var crack := n * exp(-t * 60.0)
		var boom := sin(TAU * 55.0 * t) * exp(-t * 9.0)
		var tail := lp * 3.0 * exp(-t * 2.2)
		s[i] = clampf(crack * 0.9 + boom * 0.7 + tail * 0.6, -1.0, 1.0)
	return _wav(s)


# Шипение существа.
static func _make_hiss() -> AudioStreamWAV:
	var dur := 1.1
	var s := _buf(dur)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		lp += 0.5 * (n - lp)
		var env := minf(t * 10.0, 1.0) * minf((dur - t) * 3.0, 1.0) * (0.7 + 0.3 * sin(TAU * 17.0 * t))
		s[i] = (n - lp) * env * 0.6
	return _wav(s)


# Дождь за окном: мягкий шум с редкими каплями по стеклу (петля 4 с).
static func _make_rain() -> AudioStreamWAV:
	var s := _buf(4.0)
	var lp := 0.0
	var lp2 := 0.0
	var drop := 0.0
	for i in s.size():
		var n := randf_range(-1.0, 1.0)
		lp += 0.25 * (n - lp)
		lp2 += 0.03 * (lp - lp2)
		if randf() < 0.0006:
			drop = randf_range(0.3, 0.7)
		drop *= 0.992
		s[i] = (lp - lp2) * 0.35 + drop * randf_range(-1.0, 1.0) * 0.4
	return _wav(s, true)


# Ход настенных часов (петля 2 с: тик и так).
static func _make_tick() -> AudioStreamWAV:
	var s := _buf(2.0)
	for i in s.size():
		var t := float(i) / RATE
		var a := fmod(t, 1.0)
		var f := 3200.0 if t < 1.0 else 2700.0
		s[i] = sin(TAU * f * a) * exp(-a * 160.0) * 0.35 + randf_range(-1.0, 1.0) * exp(-a * 400.0) * 0.2
	return _wav(s, true)


# Судорожный вдох после задержки дыхания.
static func _make_gasp() -> AudioStreamWAV:
	var dur := 0.9
	var s := _buf(dur)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		lp += 0.3 * (n - lp)
		var env := minf(t * 12.0, 1.0) * exp(-t * 3.0)
		s[i] = (n - lp * 0.6) * env * 0.7 * (0.8 + 0.2 * sin(TAU * 9.0 * t))
	return _wav(s)


# Дизель-генератор: тарахтящий низкий цикл (петля 1 с).
static func _make_engine() -> AudioStreamWAV:
	var s := _buf(1.0)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var cyc := fmod(t * 25.0, 1.0)
		lp += 0.1 * (randf_range(-1.0, 1.0) - lp)
		var pulse := exp(-cyc * 9.0)
		s[i] = clampf((sin(TAU * 50.0 * t) * 0.3 + lp * 2.0) * (0.3 + pulse) * 0.6, -1.0, 1.0)
	return _wav(s, true)


# Искрящий кабель: треск разрядов (петля 1 с).
static func _make_sparks() -> AudioStreamWAV:
	var s := _buf(1.0)
	var burst := 0.0
	for i in s.size():
		if randf() < 0.0015:
			burst = 1.0
		burst *= 0.995
		s[i] = randf_range(-1.0, 1.0) * burst * 0.6 + 0.05 * sin(TAU * 100.0 * float(i) / RATE)
	return _wav(s, true)


# Топот сотни лапок.
static func _make_scuttle() -> AudioStreamWAV:
	var dur := 1.6
	var s := _buf(dur)
	var tick := 0.0
	for i in s.size():
		var t := float(i) / RATE
		if randf() < 0.012:
			tick = randf_range(0.3, 1.0)
		tick *= 0.9
		s[i] = randf_range(-1.0, 1.0) * tick * 0.5 * sin(PI * t / dur)
	return _wav(s)


# Насос: хлюпающее чавканье (петля 2 с).
static func _make_pump() -> AudioStreamWAV:
	var s := _buf(2.0)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp += 0.05 * (randf_range(-1.0, 1.0) - lp)
		var cyc := fmod(t, 1.0)
		var stroke := sin(PI * cyc) * (0.6 + 0.4 * sin(TAU * 3.0 * t))
		s[i] = clampf(lp * 4.0 * stroke + 0.15 * sin(TAU * 70.0 * t) * stroke, -1.0, 1.0)
	return _wav(s, true)


# Скример: визг из нескольких расстроенных «пил», тон рывками ползёт вверх и дрожит,
# поверх — хрип (шум) и удар в начале. Перегруз мягким ограничителем — чтобы било по ушам.
static func _make_scream() -> AudioStreamWAV:
	var dur := 2.8
	var s := _buf(dur)
	var phases := [0.0, 0.0, 0.0, 0.0]
	var detune := [1.0, 1.013, 0.987, 2.01]
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var base := 520.0 + 380.0 * minf(t / 0.35, 1.0) + 90.0 * sin(TAU * 6.5 * t) + 60.0 * sin(TAU * 13.0 * t + 1.3)
		var v := 0.0
		for k in phases.size():
			phases[k] = fmod(phases[k] + base * detune[k] / RATE, 1.0)
			v += (2.0 * phases[k] - 1.0) * (0.5 if k == 3 else 1.0)
		var n := randf_range(-1.0, 1.0)
		lp += 0.35 * (n - lp)
		v += lp * 2.2
		v += sin(TAU * 55.0 * t) * 3.0 * exp(-t * 6.0)  # удар
		var env := minf(t * 80.0, 1.0) * minf((dur - t) * 2.5, 1.0)
		s[i] = tanh(v * 0.9) * env * 0.95
	return _wav(s)


# Сквозняк в тоннеле: шум через два фильтра, медленные порывы. Петля 8 с; конец плавно
# перетекает в начало, чтобы не было щелчка на стыке.
static func _make_wind() -> AudioStreamWAV:
	var loop := 8.0
	var fade := 1.0
	var raw := _buf(loop + fade)
	var lp := 0.0
	var lp2 := 0.0
	var hp := 0.0
	for i in raw.size():
		var t := float(i) / RATE
		var n := randf_range(-1.0, 1.0)
		lp += 0.06 * (n - lp)
		lp2 += 0.06 * (lp - lp2)
		hp += 0.004 * (lp2 - hp)
		var gust := 0.55 + 0.3 * sin(TAU * t / 8.0) + 0.15 * sin(TAU * t / 2.0 + 1.0)
		raw[i] = (lp2 - hp) * 6.0 * gust
	var s := _buf(loop)
	var nf := int(fade * RATE)
	for i in s.size():
		var v := raw[i]
		if i < nf:
			var k := float(i) / nf
			v = raw[i] * k + raw[i + s.size()] * (1.0 - k)
		s[i] = clampf(v, -1.0, 1.0) * 0.5
	return _wav(s, true)


# Тёмный пэд: частоты подобраны так, чтобы за 12 с укладывалось целое число периодов, —
# петля без стыка. Пары тонов чуть расстроены (beat — разница в Гц) и медленно «дышат».
static func _make_pad(freqs: Array, beat: float) -> AudioStreamWAV:
	var loop := 12.0
	var s := _buf(loop)
	var amps := []
	for k in freqs.size():
		amps.append(1.0 / (1.0 + k * 0.6))
	amps[freqs.size() - 1] *= 0.25 if freqs[freqs.size() - 1] > 500.0 else 1.0
	for i in s.size():
		var t := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			var f: float = freqs[k]
			var a: float = amps[k] * (0.6 + 0.4 * sin(TAU * t * (k + 1) / loop + k))
			v += a * (sin(TAU * f * t) + 0.8 * sin(TAU * (f + beat) * t) + 0.15 * sin(TAU * 2.0 * f * t))
		s[i] = v * 0.09
	return _wav(s, true)


# Стон металла где-то далеко: низкий тон медленно сползает вниз, неровные обертоны и скрежет.
static func _make_groan() -> AudioStreamWAV:
	var dur := 3.6
	var s := _buf(dur)
	var ph := 0.0
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var f := 62.0 - 14.0 * (t / dur) + 3.0 * sin(TAU * 4.5 * t) * (t / dur)
		ph += f / RATE
		var v := sin(TAU * ph) + 0.5 * sin(TAU * ph * 2.03) + 0.3 * sin(TAU * ph * 3.1) + 0.2 * sin(TAU * ph * 5.37)
		lp += 0.1 * (randf_range(-1.0, 1.0) - lp)
		v += lp * 1.5 * (0.5 + 0.5 * sin(TAU * 9.0 * t))
		var env := minf(t * 1.5, 1.0) * minf((dur - t) * 1.2, 1.0)
		s[i] = tanh(v * 0.6) * env * 0.5
	return _wav(s)
