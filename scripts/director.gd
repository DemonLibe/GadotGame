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


func _ready() -> void:
	player.footstep.connect(_on_step)
	stalker.vanished.connect(_on_vanished)
	stalker.caught.connect(_on_caught)


func start_day(d: int) -> void:
	_flags = {}
	_hunt_pending = false
	_echo_left = 0
	_cooldown = randf_range(20.0, 35.0)
	match d:
		1: _budget = {}
		2: _budget = {"footsteps": 1, "sighting": 1, "radio": 1}
		3: _budget = {"footsteps": 1, "sighting": 2, "lamps": 1, "whisper": 1, "radio": 1, "crawler": 1, "interfere": 1, "hunt": 1}
		4: _budget = {"footsteps": 1, "sighting": 2, "behind": 2, "lamps": 1, "whisper": 2, "regrow": 1, "radio": 1, "crawler": 2, "interfere": 2, "hunt": 2}
		5: _budget = {"behind": 1, "whisper": 2, "lamps": 1, "footsteps": 1, "radio": 1, "crawler": 3, "interfere": 1, "hunt": 3}
		6: _budget = {}  # тихая смена: ничего
		_: _budget = {"behind": 1, "whisper": 2, "crawler": 2, "swarm": 6, "hunt": 4}


func _process(delta: float) -> void:
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


## «Он» вмешивается в работу: выдёргивает зарядку, двигает ящик, захлопывает дверь, глушит генератор.
func _interfere() -> bool:
	var p := player.global_position
	var opts: Array = ["charger", "crate", "door"]
	if Game.day >= 4:
		opts.append("generator")
	opts.shuffle()
	for o in opts:
		match o:
			"charger":
				for c in main.chargers:
					var ch := c as Charger
					if not ch.unplugged and ch.global_position.distance_to(p) > 15.0:
						ch.unplug()
						Game.play_at(Sfx.click(), p + Vector3(0, 2.0, 12.0), -6.0)
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
			if seen:
				Game.say_once("hunt_light", "Ушёл из луча... Не убит — просто ушёл. Он вернётся.", Game.THOUGHT, 3.5)
			elif stalker.player_hid_during_hunt():
				Game.say_once("hunt_hid", "Ушёл. Я пересидел его. Сердце колотится так, что он должен был услышать.", Game.THOUGHT, 4.0)
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
