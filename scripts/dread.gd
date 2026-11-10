class_name Dread
extends Node
## Страх между событиями. Работает поверх «режиссёра»:
##  • кривая напряжения: затишье → нарастание (признаки всё ближе, в конце — тишина) → пик (событие «режиссёра»)
##    или ничего (ложное нарастание — и это хуже) → отпускает;
##  • признаки жизни тоннеля на длинных пустых участках: не события, а намёки — звуки сквозь землю,
##    звякнувший вдали рельс, осыпь с потолка, погасшая впереди лампа, мокрые следы поперёк тоннеля;
##  • эхо шагов в трубе — и иногда лишний шаг, когда ты уже остановился;
##  • мир врёт: пикеты повторяются, на схеме — штольня, которой нет, а штольня, которой не было, появляется.

const EARTH_BUS := "Earth"   # звук сквозь грунт: глухо, без верхов, с гулким хвостом

var main  # Main
var player: Player
var level: Level
var director: Director

var tension := 0.0           # 0..1 — для отладки и других систем
var phase := "calm"          # calm / build / relief
var _phase_t := 30.0
var _phase_len := 30.0
var _false := false          # это нарастание ничем не кончится
var _hushed := false
var _sign_t := 0.0
var _walked := 0.0
var _next_life := 40.0
var _last_pos := Vector3.ZERO
var _step_wait := -1.0
var _extra_step := false
var _wall_steps := 0
var _wall_side := 1.0
var _lie_t := 1.0
var _flags := {}
var _pk_lie: Label3D          # пикет, который повторил номер
var _pk_lie_num := 0
var _fake := {}               # ложная штольня на схеме
var _hidden_t := 0.0


func _ready() -> void:
	if AudioServer.get_bus_index(EARTH_BUS) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, EARTH_BUS)
		if AudioServer.get_bus_index("Ambience") >= 0:
			AudioServer.set_bus_send(i, "Ambience")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 420.0
		lp.resonance = 0.7
		AudioServer.add_bus_effect(i, lp)
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.85
		rv.damping = 0.75
		rv.wet = 0.35
		rv.dry = 0.85
		AudioServer.add_bus_effect(i, rv)
	player.footstep.connect(_on_step)


func start_day(d: int) -> void:
	phase = "calm"
	_set_phase("calm", randf_range(30.0, 55.0))
	tension = 0.0
	_walked = 0.0
	_next_life = randf_range(25.0, 45.0)
	_extra_step = false
	_wall_steps = 0
	_flags = {}
	_pk_lie = null
	_fake = {}
	_hidden_t = randf_range(60.0, 140.0)
	if main.hud:
		main.hud.set_map_fake({})
	_last_pos = player.global_position if player else Vector3.ZERO


func _set_phase(p: String, t: float) -> void:
	phase = p
	_phase_t = t
	_phase_len = maxf(t, 0.1)
	_hushed = false


func _process(delta: float) -> void:
	if main == null or main.busy or main.state != "playing" or main.collapsing:
		return
	var p := player.global_position
	var below := p.y < Level.FLOOR_Y + 5.0 and not player.climbing
	if not below or p.z > Level.TUN_Z0 - 2.0:
		_last_pos = p
		return
	var in_old: bool = level.lower.contains(p)
	var moved := Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length()
	_last_pos = p
	if moved < 2.0:
		_walked += moved
	_update_steps(delta)
	if Game.day != Game.LAST_DAY - 1:
		_update_lies(delta, in_old)
	# Длинный пустой участок — тоннель подаёт признаки жизни. Не события: намёки.
	if _walked >= _next_life and phase != "build":
		_walked = 0.0
		_next_life = randf_range(35.0, 70.0)
		_sign(0, in_old)
	_update_curve(delta, in_old)


# --- Кривая напряжения -----------------------------------------------------------

func _update_curve(delta: float, in_old: bool) -> void:
	var d := Game.day
	if d == Game.LAST_DAY - 1:
		tension = move_toward(tension, 0.0, delta * 0.05)
		return  # шестая — тихая: только признаки жизни
	_phase_t -= delta
	match phase:
		"calm":
			tension = move_toward(tension, 0.1, delta * 0.02)
			if _phase_t <= 0.0:
				if director.hunt_soon() or main.stalker.visible:
					_phase_t = 8.0
					return
				# Чем глубже в смены, тем чаще и тем реже обманывает.
				_set_phase("build", randf_range(24.0, 40.0) - d * 1.5)
				_false = director.budget_left() == 0 or in_old or randf() < (0.55 if d <= 2 else 0.35)
				_sign_t = randf_range(3.0, 5.0)
		"build":
			var k := clampf(1.0 - _phase_t / _phase_len, 0.0, 1.0)
			tension = lerpf(0.2, 0.9, k)
			if main.stalker.visible:
				_set_phase("relief", randf_range(25.0, 40.0))
				return
			_sign_t -= delta
			if _sign_t <= 0.0 and _phase_t > 3.5:
				_sign_t = lerpf(8.0, 3.5, k)
				_sign(1 if k < 0.6 else 2, in_old)
			# Перед вершиной — всё замолкает.
			if _phase_t <= 3.0 and not _hushed:
				_hushed = true
				main.ambience.silence(3.5 + (3.0 if _false else 0.0))
			if _phase_t <= 0.0:
				if _false or not director.peak():
					_set_phase("relief", randf_range(12.0, 20.0))
					get_tree().create_timer(6.0).timeout.connect(func():
						if Game.day == d and not main.busy:
							Game.say_once("false_build", "Ничего. Я ждал — и ничего. Это хуже, чем если бы вышло.", Game.THOUGHT, 4.0))
				else:
					_set_phase("relief", randf_range(25.0, 40.0))
		"relief":
			tension = move_toward(tension, 0.0, delta * 0.05)
			if _phase_t <= 0.0:
				_set_phase("calm", maxf(25.0, randf_range(50.0, 85.0) - d * 5.0))


# --- Признаки -----------------------------------------------------------------------

## lv: 0 — далёкое (жизнь тоннеля), 1 — ближе, 2 — совсем рядом.
func _sign(lv: int, in_old: bool) -> void:
	var p := player.global_position
	var axis: Vector3 = level.axis_at(p)
	var ahead := axis * (1.0 if player.forward_flat().dot(axis) >= 0.0 else -1.0)
	var right := Vector3(-ahead.z, 0.0, ahead.x)
	var side := 1.0 if randf() < 0.5 else -1.0
	var opts: Array
	match lv:
		0:
			opts = ["earth_far", "earth_far", "steps_far", "rail", "pebbles", "drip", "far_lamp"]
		1:
			opts = ["earth_knock", "wall_steps", "drag", "lamp_behind", "prints", "pebbles"]
		_:
			opts = ["wall_scratch", "extra_step", "lamp_near", "breath_earth", "earth_knock"]
	if in_old:
		opts = opts.filter(func(o): return not ["rail", "far_lamp", "lamp_behind", "lamp_near", "prints"].has(o))
	if opts.is_empty():
		return
	Game.add_fear([1.0, 3.0, 5.0][clampi(lv, 0, 2)])
	match opts.pick_random():
		"earth_far":
			var sounds := [Sfx.moan(), Sfx.knock(), Sfx.rumble(), Sfx.scrape(), Sfx.groan()]
			play_earth(sounds.pick_random(), p + Vector3(randf_range(-12.0, 12.0), -7.0, randf_range(-12.0, 12.0)), -2.0)
		"steps_far":
			# Шаги где-то под тобой — проходят мимо.
			var from := p - ahead * 10.0 + right * side * 6.0 + Vector3(0, -5.0, 0)
			for i in 6:
				var at := from + ahead * (i * 3.0)
				get_tree().create_timer(0.55 * i).timeout.connect(func(): play_earth(Sfx.step(), at, 2.0))
		"rail":
			Game.play_at(Sfx.clank(), p + ahead * randf_range(30.0, 45.0) + Vector3(0, 0.3, 0), -8.0)
			Game.say_once("rail", "Рельс звякнул — далеко впереди. Будто по нему ударили. Один раз.", Game.THOUGHT, 3.5)
		"pebbles":
			var at := p + ahead * randf_range(6.0, 12.0)
			if level.is_walkable(at):
				main._drop_rock(at)
				Game.play_at(Sfx.clank(), at + Vector3(0, 0.3, 0), -14.0)
		"drip":
			for i in 4:
				var at := p + ahead * 3.0 + right * side * 1.4 + Vector3(0, 2.6, 0)
				get_tree().create_timer(0.3 * i + randf() * 0.2).timeout.connect(func(): Game.play_at(Sfx.drip(), at, -4.0))
		"far_lamp":
			level.flicker_lamp_near(p + ahead * randf_range(25.0, 45.0), randf_range(1.5, 3.0), 14.0)
		"earth_knock":
			# Три удара — каждый ближе. Снизу.
			for i in 3:
				var at := p + right * side * lerpf(10.0, 2.0, i / 2.0) + Vector3(0, lerpf(-8.0, -3.0, i / 2.0), 0)
				get_tree().create_timer(0.9 * i).timeout.connect(func(): play_earth(Sfx.knock(), at, 4.0))
			Game.say_once("earth_knock", "Стучат снизу. Из-под шпал. Каждый удар — ближе.", Game.THOUGHT, 4.0)
		"wall_steps":
			# Кто-то идёт за стенкой трубы — в ногу с тобой.
			_wall_steps = randi_range(6, 9)
			_wall_side = side
		"drag":
			play_earth(Sfx.scrape(), p - ahead * 25.0 + Vector3(0, -2.0, 0), 2.0)
			Game.say_once("drag", "Сзади, далеко, по железу что-то тащат. Медленно.", Game.WHISPER, 3.5)
		"lamp_behind":
			if level.flicker_lamp_near(p - ahead * 14.0, randf_range(18.0, 30.0), 12.0):
				Game.say_once("lamp_behind", "Лампа за спиной погасла. Та, под которой я только что прошёл.", Game.THOUGHT, 3.5)
		"prints":
			_prints(p + ahead * randf_range(7.0, 11.0), ahead, right * side)
		"wall_scratch":
			play_earth(Sfx.scrape(), p + right * side * 2.4 + Vector3(0, 1.2, 0), 4.0)
			Game.say_once("wall_scratch", "Скребут. Прямо за тюбингом, у самого плеча.", Game.WHISPER, 3.5)
		"extra_step":
			_extra_step = true
		"lamp_near":
			for i in 3:
				get_tree().create_timer(0.7 * i).timeout.connect(func(): level.flicker_lamp_near(player.global_position, 0.35, 10.0))
		"breath_earth":
			play_earth(Sfx.breath(), p + Vector3(0, -2.5, 0) - player.forward_flat() * 0.6, 4.0)


## Мокрые следы поперёк тоннеля: из стены — в стену.
func _prints(at: Vector3, ahead: Vector3, across: Vector3) -> void:
	if not level.is_walkable(at):
		return
	var wet := ProcTex.flat(Color(0.04, 0.045, 0.05), 0.08, 0.2)
	var yaw := atan2(across.x, across.z)
	for i in 7:
		var foot := at + across * (1.5 - i * 0.5) + ahead * (0.12 if i % 2 == 0 else -0.12)
		foot.y = Level.FLOOR_Y + 0.006
		var m := Geo.box(main, foot, Vector3(0.11, 0.004, 0.27), wet, false, Basis(Vector3.UP, yaw))
		m.add_to_group("day_objects")
	get_tree().create_timer(3.0).timeout.connect(func():
		if player.global_position.distance_to(at) < 12.0:
			Game.say_once("prints", "Мокрые следы. Босые. Поперёк тоннеля — из стены в стену.", Game.THOUGHT, 4.0))


## Звук сквозь грунт: глухой, без верхов.
func play_earth(stream: AudioStream, pos: Vector3, volume_db := 0.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.unit_size = 10.0
	p.bus = EARTH_BUS
	main.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


# --- Шаги ---------------------------------------------------------------------------

## Свои шаги отражаются от трубы — тихо, с задержкой, откуда-то спереди или сзади.
func _on_step() -> void:
	var p := player.global_position
	if p.y > Level.FLOOR_Y + 5.0 or player.climbing:
		return
	_step_wait = 0.8
	var axis: Vector3 = level.axis_at(p)
	var e := p + axis * randf_range(5.0, 9.0) * (1.0 if randf() < 0.5 else -1.0)
	var db := -24.0 if player.crouching else -16.0
	get_tree().create_timer(randf_range(0.18, 0.3)).timeout.connect(func(): Game.play_at(Sfx.step(), e, db))
	if _wall_steps > 0:
		_wall_steps -= 1
		var right := Vector3(-axis.z, 0.0, axis.x)
		var w := p + right * _wall_side * 3.2 + Vector3(0, 0.2, 0)
		get_tree().create_timer(0.12).timeout.connect(func(): play_earth(Sfx.step(), w, 3.0))
		if _wall_steps == 0:
			Game.say_once("wall_steps", "За стенкой трубы кто-то шёл. В ногу со мной. Там нет прохода.", Game.THOUGHT, 4.0)


## Остановился — а шаги ещё один раз.
func _update_steps(delta: float) -> void:
	if _step_wait <= 0.0:
		return
	_step_wait -= delta
	if _step_wait > 0.0 or not _extra_step:
		return
	_extra_step = false
	var pos := player.global_position - player.forward_flat() * 5.0
	Game.play_at(Sfx.step(), pos, 0.0)
	Game.add_fear(8.0)
	Game.say_once("extra_step", "Я остановился. Шаги — нет. Ещё один. За спиной.", Game.THOUGHT, 4.0)


# --- Мир врёт ------------------------------------------------------------------------

func _update_lies(delta: float, in_old: bool) -> void:
	_lie_t -= delta
	if _lie_t > 0.0:
		return
	_lie_t = 1.0
	var d := Game.day
	if d < 2 or in_old:
		return
	_picket_lie(d)
	_map_lie(d)
	_hidden_branch(d)


## Пикет впереди повторяет номер того, что позади. Пока не смотришь — меняется.
func _picket_lie(d: int) -> void:
	var p := player.global_position
	if _pk_lie != null and is_instance_valid(_pk_lie):
		if p.distance_to(_pk_lie.global_position) < 6.0 and player.is_looking_at(_pk_lie.global_position, 0.6):
			Game.say_once("pk_lie", "ПК %d. Предыдущий тоже был ПК %d. Я его уже проходил." % [_pk_lie_num, _pk_lie_num], Game.THOUGHT, 4.5)
			Game.add_fear(6.0)
			_pk_lie = null
		return
	if _flags.has("pk") or d < 3 or randf() > 0.02:
		return
	var fwd := player.forward_flat()
	var behind: Label3D = null
	var ahead: Label3D = null
	for pk in level.pickets:
		var to := pk.global_position - p
		var dist := to.length()
		if dist < 30.0 and to.dot(fwd) < 0.0 and (behind == null or dist < behind.global_position.distance_to(p)):
			behind = pk
		if dist > 35.0 and dist < 80.0 and to.dot(fwd) > 0.0 and not player.is_looking_at(pk.global_position, 0.3):
			ahead = pk
	if behind == null or ahead == null:
		return
	_flags["pk"] = true
	_pk_lie = ahead
	_pk_lie_num = int(behind.get_meta("number"))
	ahead.text = "ПК %d" % _pk_lie_num


## На схеме — штольня, которой нет: дойдёшь — там сплошной тюбинг.
func _map_lie(d: int) -> void:
	var p := player.global_position
	if not _fake.is_empty():
		if absf(p.z - float(_fake["z"])) < 4.0 and absf(p.x - Level.TUN_CX) < 3.0:
			Game.say_once("map_lie", "По схеме здесь штольня. Здесь — тюбинг. Сплошной. Я трогал.", Game.THOUGHT, 4.5)
			Game.add_fear(5.0)
			var gone := _fake
			get_tree().create_timer(15.0).timeout.connect(func():
				if _fake == gone:
					_fake = {}
					main.hud.set_map_fake({}))
		return
	if _flags.has("map") or d < 3 or randf() > 0.02 or absf(level.axis_at(p).dot(Vector3.FORWARD)) < 0.99:
		return
	var sgn := -1.0 if player.forward_flat().z < 0.0 else 1.0
	var side := 1 if randf() < 0.5 else -1
	var z := p.z + sgn * randf_range(70.0, 130.0)
	if z > Level.TUN_Z0 - 20.0 or z < maxf(main.day_limit(), Level.GRATE_Z) + 10.0:
		return
	if not level.is_plain(-1, z, side, 12.0):
		return
	_flags["map"] = true
	var n := 1
	for b in Level.BRANCHES:
		if int(b["parent"]) < 0 and not b.get("hidden", false):
			n += 1
	_fake = {"z": z, "side": side, "name": "ШТОЛЬНЯ %d" % n}
	main.hud.set_map_fake(_fake)


## Потайная штольня: только что была сплошная стена — а теперь проход. Потом — снова стена.
func _hidden_branch(d: int) -> void:
	var i := level.hidden_branch
	if i < 0 or d < 3:
		return
	var o := Level.branch_origin(i)
	var p := player.global_position
	var dist := Vector2(p.x - o.x, p.z - o.z).length()
	var unseen := not player.is_looking_at(o + Vector3(0, 1.2, 0), 0.2)
	if not level.hidden_open:
		if _flags.has("hidden_was") and dist < 14.0 and not unseen:
			_flags.erase("hidden_was")
			Game.say_once("hidden_gone", "Здесь была штольня. Я в неё заходил. Теперь — стена. Холодная.", Game.THOUGHT, 4.5)
			Game.add_fear(8.0)
		if not main._reachable_root(i) or _flags.has("hidden_was"):
			return
		_hidden_t -= 1.0
		if _hidden_t <= 0.0 and dist > 25.0 and dist < 80.0 and unseen:
			level.set_hidden_open(true)
			main.refresh_map()
			_flags["hidden_open"] = true
		return
	# Открыта. Увидел вблизи — запомнил.
	if dist < 14.0 and not unseen and not _flags.has("hidden_seen"):
		_flags["hidden_seen"] = true
		Game.say_once("hidden_branch", "Штольня. Её здесь не было — я проходил тут, и тут был тюбинг. Сплошной.", Game.THOUGHT, 5.0)
		Game.add_fear(10.0)
	# Ушёл далеко и не смотришь — её снова нет (но не пока ты внутри).
	if _flags.has("hidden_seen") and dist > 40.0 and unseen and randf() < 0.05:
		var seg := level._segment_index(p)
		if seg == i + 1:
			return
		level.set_hidden_open(false)
		main.refresh_map()
		_flags.erase("hidden_seen")
		_flags["hidden_was"] = true
		_hidden_t = randf_range(120.0, 240.0)
