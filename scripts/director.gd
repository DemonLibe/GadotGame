class_name Director
extends Node
## Режиссёр хоррора: по дням дозирует события (шаги за спиной, силуэт в луче,
## шёпот, отключение света), ведёт счётчик страха и сюжетные точки.

const WHISPERS := [
	"…ещё одна смена…",
	"…не свети на меня…",
	"…ты тоже считаешь шаги?…",
	"…он ушёл наверх. Ты — нет…",
	"…тише. Пауки слушают…",
]

var main  # Main
var player: Player
var stalker: Stalker
var level: Level

var _budget := {}
var _cooldown := 30.0
var _echo_left := 0
var _hb := 0.0
var _flags := {}
var _hunt_pending := false
## Охоты «Другого» идут по своему таймеру, а не из общего списка событий: [от, до] секунд между охотами
## (считаются только в тоннелях и пока его нет). Первая — раньше.
const HUNT_EVERY := {3: [75.0, 105.0], 4: [60.0, 90.0], 5: [45.0, 70.0], 7: [35.0, 55.0]}
var _hunt_t := 0.0
var _threat: AudioStreamPlayer  # тревожная петля: он идёт
var _masha_pos := Vector3.ZERO  # откуда звала «Маша»
var _picket: Label3D             # табличка, у которой сменился номер
var _chalk: Label3D              # «ВОСЬМОЙ» и время
const MASHA := Color(0.95, 0.76, 0.8)


func _ready() -> void:
	_threat = AudioStreamPlayer.new()
	_threat.stream = Sfx.threat()
	_threat.bus = "Ambience"
	_threat.volume_db = -60.0
	add_child(_threat)
	player.footstep.connect(_on_step)
	stalker.vanished.connect(_on_vanished)
	stalker.caught.connect(_on_caught)


func start_day(d: int) -> void:
	_flags = {}
	_masha_pos = Vector3.ZERO
	_picket = null
	_chalk = null
	_hunt_pending = false
	_echo_left = 0
	_cooldown = randf_range(20.0, 35.0)
	_hunt_t = _next_hunt(d) * 0.6
	match d:
		1: _budget = {}
		2: _budget = {"footsteps": 1, "sighting": 1, "radio": 1}
		3: _budget = {"footsteps": 1, "sighting": 2, "lamps": 1, "whisper": 1, "radio": 1, "crawler": 1, "interfere": 1,
			"masha": 1, "silence": 1}
		4: _budget = {"footsteps": 1, "sighting": 2, "behind": 2, "lamps": 1, "whisper": 2, "regrow": 1, "radio": 1, "crawler": 2, "interfere": 2,
			"masha": 1, "double": 1, "silence": 1, "picket": 1, "name": 1}
		5: _budget = {"behind": 1, "whisper": 2, "lamps": 1, "footsteps": 1, "radio": 1, "crawler": 3, "interfere": 1,
			"masha": 1, "double": 1, "silence": 1, "picket": 1, "name": 1}
		6: _budget = {}  # тихая смена: ничего
		_: _budget = {"behind": 1, "whisper": 2, "crawler": 2, "swarm": 6, "double": 2, "silence": 2}


func _next_hunt(d: int) -> float:
	var r: Array = HUNT_EVERY.get(d, [0.0, 0.0])
	return randf_range(float(r[0]), float(r[1]))


func _process(delta: float) -> void:
	_update_threat(delta)
	if main.busy:
		return
	main.hud.set_fear(Game.fear / Achievements.fear_max())
	_update_fear(delta)
	_heartbeat(delta)
	_story()
	if main.busy:
		return
	if main.collapsing:
		return  # во время обвала — только бегство
	if Game.fear >= Achievements.fear_max():
		main.panic()
		return
	if player.global_position.z > Level.TUN_Z0 - 4.0 or player.global_position.y > Level.FLOOR_Y + 5.0:
		return  # события только в тоннелях
	if HUNT_EVERY.has(Game.day) and not stalker.visible and not _hunt_pending:
		# Фонарь начинает подмигивать за несколько секунд до того, как он придёт.
		if _hunt_t < 4.0 and randf() < delta * 1.5:
			player.flicker(randf_range(0.1, 0.3))
		_hunt_t -= delta
		if _hunt_t <= 0.0:
			_hunt_t = _next_hunt(Game.day) if _hunt() else 5.0
			return
	_cooldown -= delta
	if _cooldown > 0.0 or stalker.visible:
		return
	var options: Array = []
	for k in _budget:
		if _budget[k] > 0:
			options.append(k)
	if options.is_empty():
		return
	var ev: String = options.pick_random()
	if _run(ev):
		_budget[ev] -= 1
		_cooldown = randf_range(35.0, 60.0) - Game.day * 4.0
	else:
		_cooldown = 4.0


## Тревожная петля: тихо, когда пауки только побежали, громче, чем ближе он, во весь голос — когда гонится.
func _update_threat(delta: float) -> void:
	var target := -60.0
	if stalker.visible and stalker.mode == "hunt":
		var d := stalker.global_position.distance_to(player.global_position)
		target = lerpf(-4.0, -22.0, clampf((d - 4.0) / 36.0, 0.0, 1.0))
		# Чем он ближе, тем чаще дрожит фонарь.
		if d < 18.0 and randf() < delta * (18.0 - d) / 6.0:
			player.flicker(randf_range(0.05, 0.2))
		if stalker.is_chasing():
			target = 0.0
	elif _hunt_pending:
		target = -18.0
	if main.busy and not stalker.visible:
		target = -60.0
	if target > -55.0 and not _threat.playing:
		_threat.play()
	_threat.volume_db = move_toward(_threat.volume_db, target, delta * (20.0 if target > _threat.volume_db else 8.0))
	if _threat.playing and _threat.volume_db <= -59.0:
		_threat.stop()


# --- Страх -------------------------------------------------------------------

func _update_fear(delta: float) -> void:
	var pos := player.global_position
	# На лестнице страх не копится: спуск и подъём — передышка, а не испытание.
	if player.climbing:
		Game.add_fear(-delta * 2.0)
		return
	var lit := player.has_light() or level.is_lit_near(pos) or pos.y > Level.ROOM_Y - 1.0
	if lit:
		Game.add_fear(-delta * (6.0 if pos.z > Level.TUN_Z0 or pos.y > Level.ROOM_Y - 1.0 else 2.5))
	else:
		# Шестая смена — тихая, страх копится как в первую.
		var d := 1 if Game.day == Game.LAST_DAY - 1 else Game.day
		Game.add_fear(delta * (3.5 + d * 1.2))
		Game.say_once("dark", "Темно... Слишком темно. Нужен свет.")
	if stalker.visible and stalker.global_position.distance_to(pos) < 12.0:
		Game.add_fear(delta * 4.0)


func _heartbeat(delta: float) -> void:
	var fmax := Achievements.fear_max()
	if Game.fear < fmax * 0.45:
		return
	_hb -= delta
	if _hb <= 0.0:
		var k := (Game.fear - fmax * 0.45) / (fmax * 0.55)
		_hb = lerpf(1.1, 0.45, k)
		Game.play_ui(Sfx.heartbeat(), lerpf(-20.0, -3.0, k))


# --- Сюжетные точки ----------------------------------------------------------

func _story() -> void:
	var z := player.global_position.z
	var y := player.global_position.y
	var d := Game.day
	var at_station := y < Level.FLOOR_Y + 5.0 and z < -30.0 and z > -50.0
	# В шахте: кто-то ещё на лестнице.
	if player.climbing and d >= 2 and y > 20.0 and y < 60.0 and _once("shaft"):
		Game.play_at(Sfx.rung(), player.global_position + Vector3(0, 9.0, 0), 4.0)
		get_tree().create_timer(0.6).timeout.connect(func(): Game.play_at(Sfx.rung(), player.global_position + Vector3(0, 8.7, 0), 4.0))
		Game.say("Сверху... ступеньки звенят. Кто-то спускается следом?", Game.THOUGHT, 5.0)
	if player.climbing and d >= 4 and y > -5.0 and y < 15.0 and _once("shaft_dark"):
		player.flicker(1.5)
		Game.play_at(Sfx.whisper(), player.global_position + Vector3(0, -6.0, 0), 0.0)
		Game.say_once("shaft_whisper", "…ниже… ещё ниже…", Game.WHISPER)
	if d == 1 and Game.all_done() and at_station and _once("rumble"):
		Game.play_ui(Sfx.rumble(), -6.0)
		Game.say("Что-то обрушилось в глубине тоннеля... Завтра проверю.", Game.THOUGHT, 5.0)
	if d == 3 and at_station and z < -34.0 and _once("cart"):
		Game.say("Где вагонетка?.. Она всегда стоит здесь. Всегда.", Game.THOUGHT, 5.0)
	if d == 4 and Game.all_done() and at_station and z < -36.0 and _once("watch"):
		var pos := Vector3(Level.TUN_CX, Level.FLOOR_Y, -64.0)
		stalker.appear(pos, "watch", 15.0)
		Game.play_at(Sfx.step(), pos, 2.0)
	if y < Level.FLOOR_Y + 5.0 and Game.has_open_task("inspect:end") and z < main.day_limit() + 4.0:
		Game.report("inspect:end")
		Game.say("Ограждение. За ним завал... и в завале что-то шевелится. Хватит, назад.", Game.THOUGHT, 5.0)
	if y < Level.FLOOR_Y + 5.0 and z < Level.GRATE_Z + 4.0 and Game.has_open_task("inspect:grate"):
		Game.report("inspect:grate")
		if d == Game.FINAL_DAY:
			Game.say("Решётка открыта. Замок сорван... изнутри.", Game.THOUGHT, 5.0)
			Game.add_task("inspect:nest", "Узнать, что за решёткой", 1)
		else:
			Game.say("Решётка заперта. За ней... каски? Чьи это каски?", Game.THOUGHT, 5.0)
	if d == Game.FINAL_DAY and y < Level.FLOOR_Y + 5.0 and z < Level.GRATE_Z - 25.0:
		main.ending()
	# Дошёл туда, откуда звала «Маша»: пусто — а за спиной хлопает дверь.
	if _masha_pos != Vector3.ZERO and player.global_position.distance_to(_masha_pos) < 5.0 and _once("masha_found"):
		var slammed := false
		for door in main.doors:
			if door.is_open and door.global_position.distance_to(player.global_position) < 45.0:
				door.slam()
				slammed = true
				break
		if not slammed:
			Game.play_at(Sfx.clank(), player.global_position - player.forward_flat() * 6.0 + Vector3(0, 1.0, 0), 4.0)
		Game.add_fear(15.0)
		Game.say("Пусто. Только на стене мелом — фонарик. Такой, как она нарисовала мне в письме.", Game.THOUGHT, 5.0)
	# Пикет за спиной сменил номер — заметил, когда оглянулся.
	if _picket and player.is_looking_at(_picket.global_position, 0.9) and player.global_position.distance_to(_picket.global_position) < 18.0:
		Game.add_fear(10.0)
		Game.say("ПК 8?.. Я только что прошёл мимо. Там был ПК %d." % int(_picket.get_meta("number")), Game.THOUGHT, 4.5)
		_picket = null
	if _chalk and player.is_lighting(_chalk.global_position):
		Game.add_fear(12.0)
		Game.say("«ВОСЬМОЙ». И время. Сейчас — ровно столько. Мел ещё сыпется.", Game.THOUGHT, 4.5)
		_chalk = null


func _once(key: String) -> bool:
	if _flags.has(key):
		return false
	_flags[key] = true
	return true


# --- События -----------------------------------------------------------------

func _run(ev: String) -> bool:
	match ev:
		"footsteps":
			_echo_left = randi_range(6, 9)
			return true
		"sighting":
			return _sighting()
		"behind":
			return _behind()
		"lamps":
			_lamps_out()
			return true
		"whisper":
			_whisper()
			return true
		"regrow":
			return main.regrow_web_behind(player.global_position.z)
		"radio":
			return player.has_radio and main.dispatcher.random_call(Game.day)
		"crawler":
			return _crawler()
		"interfere":
			return _interfere()
		"hunt":
			return _hunt()
		"swarm":
			return _swarm()
		"masha":
			return _masha()
		"double":
			return _double()
		"silence":
			return _silence()
		"picket":
			return _change_picket()
		"name":
			return _write_name()
	return false


## Охота «Другого» (3–5 смены). Сначала оттуда, где он появится, бегут пауки — и пропадают.
## Через несколько секунд выходит он сам. С каждой сменой — быстрее, дольше ищет, меньше боится света.
func _hunt() -> bool:
	if _hunt_pending:
		return false
	var p := player.global_position
	# Он выходит в основном тоннеле: впереди по взгляду, если обходчик в нём, или у развилки его штольни.
	var pos := Vector3.ZERO
	var axis := level.axis_at(p)
	var in_main := absf(axis.dot(Vector3.FORWARD)) > 0.99
	if in_main:
		var sgn := -1.0 if player.forward_flat().z < 0.0 else 1.0
		pos = Vector3(Level.TUN_CX, Level.FLOOR_Y, p.z + sgn * randf_range(30.0, 40.0))
	else:
		var jz := 0.0
		for i in Level.BRANCHES.size():
			if absf(Level.branch_dir(i).dot(axis)) > 0.99:
				jz = float(Level.BRANCHES[i]["z"])
		pos = Vector3(Level.TUN_CX, Level.FLOOR_Y, jz - randf_range(12.0, 20.0))
	pos.z = clampf(pos.z, maxf(main.day_limit() + 2.0, Level.GRATE_Z + 2.0), Level.TUN_Z0 - 6.0)
	if pos.distance_to(p) < 18.0:
		# Впереди тупик или ограждение — тогда он выходит с другой стороны.
		pos.z = clampf(p.z - (pos.z - p.z), maxf(main.day_limit() + 2.0, Level.GRATE_Z + 2.0), Level.TUN_Z0 - 6.0)
		if pos.distance_to(p) < 18.0:
			return false
	_hunt_pending = true
	# Пауки бегут оттуда: те, что рядом с ним, и стайка с самого места — прямо на обходчика и дальше.
	var dir_z := signf(p.z - pos.z)
	if dir_z == 0.0:
		dir_z = 1.0
	for n in get_tree().get_nodes_in_group("spiders"):
		var sp := n as Spider
		if sp and absf(sp.global_position.z - pos.z) < 25.0:
			sp.flee_and_vanish(pos - Vector3(0, 0, dir_z * 3.0), randf_range(5.0, 8.0))
	for i in 4 + Game.day:
		var sp: Spider = main.add_runner_spider(pos.z + randf_range(-2.0, 2.0), i % 2 == 0)
		sp.flee_and_vanish(pos - Vector3(0, 0, dir_z * 3.0), randf_range(6.0, 9.0), randf_range(3.0, 4.2))
	Game.play_at(Sfx.scuttle(), pos + Vector3(0, 2.0, 0), 4.0)
	get_tree().create_timer(1.2).timeout.connect(func(): Game.play_at(Sfx.scuttle(), p.lerp(pos, 0.5) + Vector3(0, 2.0, 0), 2.0))
	Game.say("Пауки... бегут. Все разом — оттуда. Он идёт. Нужен шкаф. Быстро.", Game.THOUGHT, 4.0)
	var delay: float = [0.0, 0.0, 0.0, 7.0, 5.5, 4.0, 4.0, 3.0][clampi(Game.day, 0, Game.LAST_DAY)]
	get_tree().create_timer(delay).timeout.connect(func(): _hunt_arrive(pos))
	return true


func _hunt_arrive(pos: Vector3) -> void:
	_hunt_pending = false
	if main.busy or main.collapsing or stalker.visible:
		return
	stalker.hunt(pos, Game.day)
	Game.play_at(Sfx.whisper(), pos + Vector3(0, 1.7, 0), 4.0)


func _on_caught() -> void:
	if main.busy or main._smoke:
		get_tree().create_timer(1.0).timeout.connect(stalker.hide_now)
		return
	player.input_locked = true
	player.flicker(1.0)
	get_tree().create_timer(0.8).timeout.connect(func(): main.fail_day("Он нашёл тебя."))


## Силуэт далеко впереди — на краю луча.
func _sighting() -> bool:
	# Работает в основном тоннеле и в штольнях — силуэт всегда по взгляду вдоль прохода.
	var f := player.forward_flat()
	var p := player.global_position
	var axis := level.axis_at(p)
	var along := f.dot(axis)
	if absf(along) < 0.6:
		return false
	var pos := p + axis * signf(along) * randf_range(18.0, 26.0)
	pos.y = Level.FLOOR_Y
	if pos.z > Level.TUN_Z0 - 2.0 or pos.z < Level.GRATE_Z + 1.0:
		return false
	if not level.is_walkable(pos):
		return false
	stalker.appear(pos, "sighting", 7.0)
	return true


## Из темноты выползает ещё одно существо — впереди по проходу, вне света.
func _crawler() -> bool:
	var p := player.global_position
	var axis := level.axis_at(p)
	var f := player.forward_flat()
	var sgn := 1.0 if f.dot(axis) >= 0.0 else -1.0
	var pos := p + axis * sgn * randf_range(16.0, 24.0)
	pos.y = Level.FLOOR_Y
	if not level.is_walkable(pos) or level.is_lit_near(pos) or pos.z > Level.TUN_Z0 - 10.0 or pos.z < main.day_limit() + 2.0:
		return false
	# Сначала разбегаются пауки — предупреждение. Через три секунды из темноты выползает оно.
	var near_spider := false
	for n in get_tree().get_nodes_in_group("spiders"):
		var sp := n as Spider
		if sp and sp.global_position.distance_to(p) < 18.0:
			sp.alarm(pos)
			near_spider = true
	Game.play_at(Sfx.scuttle(), p + (pos - p).normalized() * 5.0 + Vector3(0, 2.0, 0), -2.0)
	if near_spider:
		Game.say_once("spiders_run", "Пауки... разбегаются. Все разом. Что-то идёт.", Game.THOUGHT, 3.5)
	get_tree().create_timer(3.0).timeout.connect(func(): _crawler_arrive(pos))
	return true


func _crawler_arrive(pos: Vector3) -> void:
	if main.busy or main.collapsing:
		return
	var c: Crawler = main.spawn_crawler(pos)
	c.state = "investigate"
	c._goal = player.global_position
	Game.play_at(Sfx.hiss(), pos + Vector3(0, 0.5, 0), 2.0)


## Голос Маши из штольни, где обходчика нет: «Папа?.. Папа, ты где?»
func _masha() -> bool:
	var p := player.global_position
	var cand: Array = []
	for i in Level.BRANCHES.size():
		var length := float(Level.BRANCHES[i]["length"])
		if main._reachable(i, length):
			var end := Level.branch_origin(i) + Level.branch_dir(i) * (length - 6.0)
			if end.distance_to(p) > 25.0:
				cand.append(end)
	if cand.is_empty():
		return false
	_masha_pos = cand.pick_random()
	var path := "res://voice/m_call.ogg"
	var voice: AudioStream = load(path) if ResourceLoader.exists(path) else Sfx.whisper()
	var a := AudioStreamPlayer3D.new()
	a.stream = voice
	a.unit_size = 14.0
	a.volume_db = 6.0
	main.add_child(a)
	a.global_position = _masha_pos + Vector3(0, 1.2, 0)
	a.finished.connect(a.queue_free)
	a.play()
	Game.say("…Папа?.. Папа, ты где?…", MASHA, 4.0)
	get_tree().create_timer(4.5).timeout.connect(func(): Game.say_once("masha_heard", "Это... голос Маши? Здесь? Из штольни...", Game.THOUGHT, 4.0))
	return true


## Двойник: далеко впереди по проходу стоит обходчик и слепит налобником.
func _double() -> bool:
	var p := player.global_position
	var axis := level.axis_at(p)
	var along := player.forward_flat().dot(axis)
	if absf(along) < 0.6:
		return false
	var pos := p + axis * signf(along) * randf_range(26.0, 32.0)
	pos.y = Level.FLOOR_Y
	if not level.is_walkable(pos) or level.is_lit_near(pos) or pos.z > Level.TUN_Z0 - 4.0:
		return false
	var d := Double.new()
	d.player = player
	main.add_child(d)
	d.global_position = pos
	Game.play_at(Sfx.click(), pos + Vector3(0, 1.8, 0), 0.0)
	return true


## Ложная тишина: всё замолкает. Потом из этой тишины что-то выходит — или ничего, и это хуже.
func _silence() -> bool:
	var t := randf_range(6.0, 10.0)
	main.ambience.silence(t)
	Game.say_once("silence", "Тихо. Совсем тихо. Даже капель перестала.", Game.THOUGHT, 3.5)
	get_tree().create_timer(t).timeout.connect(_after_silence)
	return true


func _after_silence() -> void:
	if main.busy or Game.day == Game.LAST_DAY - 1:
		return
	match randi_range(0, 3):
		0:
			_crawler()
		1:
			if Game.day == Game.LAST_DAY:
				_swarm()
			else:
				_hunt_t = minf(_hunt_t, 2.0)


## Табличка пикета за спиной меняет номер на «ПК 8».
func _change_picket() -> bool:
	var p := player.global_position
	for pk in level.pickets:
		var dist := pk.global_position.distance_to(p)
		if dist > 6.0 and dist < 25.0 and not player.is_looking_at(pk.global_position, 0.3) and pk.text != "ПК 8":
			pk.text = "ПК 8"
			_picket = pk
			return true
	return false


## «ВОСЬМОЙ» и нынешнее время мелом — на стене впереди, ещё в темноте.
func _write_name() -> bool:
	var p := player.global_position
	if absf(level.axis_at(p).dot(Vector3.FORWARD)) < 0.99:
		return false
	var sgn := -1.0 if player.forward_flat().z < 0.0 else 1.0
	var z := p.z + sgn * 16.0
	if z > Level.TUN_Z0 - 4.0 or z < maxf(main.day_limit() + 2.0, Level.GRATE_Z + 2.0):
		return false
	var t := Time.get_time_dict_from_system()
	_chalk = main.write_chalk(-1, -1 if randf() < 0.5 else 1, z, 1.6, "ВОСЬМОЙ\n%02d:%02d" % [t["hour"], t["minute"]])
	return true


## Седьмая смена: из темноты впереди по проходу набегает стая кусачих пауков.
func _swarm() -> bool:
	var p := player.global_position
	var axis := level.axis_at(p)
	var sgn := 1.0 if player.forward_flat().dot(axis) >= 0.0 else -1.0
	var pos := p + axis * sgn * randf_range(14.0, 20.0)
	pos.y = Level.FLOOR_Y
	if not level.is_walkable(pos) or pos.z > Level.TUN_Z0 - 8.0:
		return false
	Game.play_at(Sfx.scuttle(), pos + Vector3(0, 1.0, 0), 4.0)
	Game.say_once("swarm", "Пауки... на полу. Много. И они бегут не от меня — ко мне.", Game.THOUGHT, 4.0)
	for i in randi_range(3, 5):
		main.spawn_biter(pos + axis * randf_range(-2.0, 2.0) + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)))
	return true


## «Он» вмешивается в работу: гасит налобник, двигает ящик, захлопывает дверь, глушит генератор.
func _interfere() -> bool:
	var p := player.global_position
	var opts: Array = ["lamp", "crate", "door"]
	if Game.day >= 4:
		opts.append("generator")
	opts.shuffle()
	for o in opts:
		match o:
			"lamp":
				# Щелчок у самого уха — и налобник гаснет, батарея просела на четверть.
				if player.flashlight_on and player.battery > 30.0:
					player.battery -= 25.0
					player.flicker(1.2)
					Game.play_ui(Sfx.click(), -2.0)
					Game.say_once("lamp_drained", "Щёлкнуло прямо над ухом — и фонарь почти сел. Будто кто-то выпил батарею.", Game.THOUGHT, 4.0)
					return true
			"crate":
				for c in main.crates:
					var cr := c as FilterCrate
					if cr.global_position.distance_to(p) > 12.0 and cr.global_position.distance_to(p) < 30.0 and not player.is_looking_at(cr.global_position, 0.5):
						var axis := level.axis_at(cr.global_position)
						cr.global_position += axis * randf_range(-2.0, 2.0)
						cr.rotation.y += randf_range(-0.8, 0.8)
						Game.play_at(Sfx.creak(), cr.global_position + Vector3(0, 0.3, 0), -2.0)
						Game.say_once("crate_moved", "Скрежет... Будто волокли что-то тяжёлое по бетону.", Game.THOUGHT, 3.5)
						return true
			"door":
				for d in main.doors:
					var door := d as RoomDoor
					if door.is_open and door.global_position.distance_to(p) > 6.0 and door.global_position.distance_to(p) < 35.0:
						door.slam()
						Game.say_once("door_slam", "Дверь хлопнула. Сквозняка здесь нет.", Game.THOUGHT, 3.5)
						return true
			"generator":
				var g: Generator = main.generator
				if g.running and g.global_position.distance_to(p) > 25.0:
					g.stall()
					player.flicker(0.6)
					Game.say_once("gen_stalled", "Свет погас... Генератор? Топлива же было полно.", Game.THOUGHT, 4.0)
					return true
	return false


## Он стоит прямо за спиной. Сначала — дыхание.
func _behind() -> bool:
	var pos := player.global_position - player.forward_flat() * 3.2
	pos.y = Level.FLOOR_Y
	if not level.is_walkable(pos) or pos.z > Level.TUN_Z0 - 2.0:
		return false
	stalker.appear(pos, "behind", 9.0)
	Game.play_at(Sfx.whisper(), pos + Vector3(0, 1.7, 0), -4.0)
	return true


func _lamps_out() -> void:
	level.tunnel_lights_off = true
	player.flicker(0.8)
	Game.play_at(Sfx.clank(), player.global_position + Vector3(0, 3, -8), -2.0)
	Game.say_once("lamps", "Свет погас... весь сразу. Будто кто-то дёрнул рубильник.")
	get_tree().create_timer(20.0).timeout.connect(func(): level.tunnel_lights_off = false)


func _whisper() -> void:
	var side := -1.0 if randf() < 0.5 else 1.0
	var pos := player.global_position + Vector3(side * 1.5, 1.6, randf_range(-2.0, 2.0))
	Game.play_at(Sfx.whisper(), pos, -2.0)
	Game.say(WHISPERS.pick_random(), Game.WHISPER, 3.0)
	get_tree().create_timer(3.5).timeout.connect(func(): Game.say_once("whisper_after", "Показалось. Мне просто показалось."))


## Эхо шагов: кто-то идёт следом в такт и делает пару шагов после остановки.
func _on_step() -> void:
	if _echo_left <= 0:
		return
	_echo_left -= 1
	get_tree().create_timer(0.18).timeout.connect(_echo_step)
	if _echo_left == 0:
		get_tree().create_timer(0.8).timeout.connect(_echo_step)
		get_tree().create_timer(1.4).timeout.connect(_echo_step)
		get_tree().create_timer(3.0).timeout.connect(func(): Game.say_once("echo", "...Это не эхо."))


func _echo_step() -> void:
	var pos := player.global_position - player.forward_flat() * 7.0
	pos.y = Level.FLOOR_Y + 0.1
	Game.play_at(Sfx.step(), pos, 0.0)


func _on_vanished(m: String, seen: bool) -> void:
	match m:
		"sighting", "watch":
			if seen:
				Game.add_fear(20.0)
				player.flicker(0.5)
				Game.play_ui(Sfx.sting(), -10.0)
				Game.say_once("saw", "Там... кто-то стоял. В самом конце луча.")
		"hunt":
			_hunt_t = _next_hunt(Game.day)  # ушёл — на время
			if seen:
				Game.say_once("hunt_light", "Ушёл из луча... Не убит — просто ушёл. Он вернётся.", Game.THOUGHT, 3.5)
			elif stalker.player_hid_during_hunt():
				Game.say_once("hunt_hid", "Постоял у шкафа — и ушёл. Пересидел. На время.", Game.THOUGHT, 4.0)
				Achievements.unlock("hid")
			else:
				Game.say_once("hunt_gone", "Тихо. Он ушёл... или ждёт.", Game.WHISPER, 3.0)
		"behind":
			if seen:
				Game.add_fear(35.0)
				player.flicker(1.0)
				Game.play_ui(Sfx.sting(), -2.0)
				Game.say_once("behind", "Он стоял прямо за мной. Прямо. За. Мной.")
			else:
				Game.say_once("behind_unseen", "…кажется, кто-то дышал мне в затылок.", Game.WHISPER)
