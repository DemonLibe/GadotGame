class_name Main
extends Node3D
## Точка входа: собирает мир, раскладывает объекты на каждый день,
## управляет сменами, паникой и финалом.

const SURFACE_SPAWN := Vector3(0, 0.1, 4.2)

# Места для большой паутины поперёк тоннеля (z).
const WEB_SPOTS := [-66.0, -98.0, -124.0, -140.0, -176.0, -198.0, -216.0]
const WEBS_PER_DAY := [0, 2, 3, 4, 5, 6]

# [позиция, поворот, имя]. Левая стена тоннеля x = -0.5, правая x = 2.9, стена станции x = -3.
const VENT_SPOTS := [
	[Vector3(-3.0, -13.6, -43.0), 90.0, "В-1"],
	[Vector3(-0.5, -13.6, -78.0), 90.0, "В-2"],
	[Vector3(2.9, -13.6, -112.0), -90.0, "В-3"],
	[Vector3(-0.5, -13.6, -148.0), 90.0, "В-4"],
	[Vector3(2.9, -13.6, -188.0), -90.0, "В-5"],
	[Vector3(-0.5, -13.6, -222.0), 90.0, "В-6"],
]
const CHARGER_SPOTS := [
	[Vector3(-3.0, -13.8, -33.0), 90.0, "station"],
	[Vector3(2.9, -13.8, -165.0), -90.0, "far"],
]
const CRATE_SPOTS := [
	Vector3(-2.3, -15.0, -46.5),
	Vector3(-0.1, -15.0, -92.0),
	Vector3(2.5, -15.0, -130.0),
	Vector3(-0.1, -15.0, -170.0),
	Vector3(2.5, -15.0, -205.0),
	Vector3(-0.1, -15.0, -226.0),
]

# Надписи мелом на стенах: [позиция, поворот, текст]. Копятся день за днём.
const NOTES := {
	2: [[Vector3(-0.48, -13.3, -104.0), 90.0, "НЕ ОСТАВАЙСЯ\nБЕЗ СВЕТА"]],
	3: [[Vector3(2.88, -13.3, -158.0), -90.0, "ПАУКИ НЕ ОПАСНЫ.\nОПАСНО ТО,\nЧЕГО БОЯТСЯ ПАУКИ"],
		[Vector3(-0.48, -13.6, -60.0), 90.0, "|||| |||| |||| ||"]],
	4: [[Vector3(-0.48, -13.3, -84.0), 90.0, "ОН СЧИТАЕТ\nТВОИ ШАГИ"],
		[Vector3(2.88, -13.3, -192.0), -90.0, "СМЕНА №7.\nНЕ ХОДИ\nЗА РЕШЁТКУ"]],
	5: [[Vector3(-0.48, -13.2, -229.0), 90.0, "ТВОЯ СМЕНА"],
		[Vector3(2.88, -13.3, -100.0), -90.0, "ОН УЖЕ ЗДЕСЬ"]],
}

const DAY_SUBTITLES := ["", "Станция «Тихая». Первая смена.", "Вторая смена.", "Третья смена.", "Четвёртая смена.", "Последняя смена."]
const DAY_THOUGHTS := [
	"",
	"Первая смена на «Тихой». Спуститься, зарядить фонарь, поменять фильтр, сжечь паутину. Ничего сложного.",
	"Вчера внизу что-то обрушилось. Надо дойти до решётки в конце тоннеля и посмотреть.",
	"Плохо спал. Всю ночь казалось, что под полом кто-то ходит.",
	"Мой предшественник продержался неделю. Никто не говорит, куда он делся.",
	"В журнале одно поручение. Почерк не мой. И не начальника.",
]

var level: Level
var player: Player
var hud: Hud
var stalker: Stalker
var director: Director
var journal: Journal
var cart: Cart
var vents: Array[Vent] = []
var chargers: Array[Charger] = []
var crates: Array[FilterCrate] = []
var busy := false
var _drip_t := 5.0


func _ready() -> void:
	randomize()
	_setup_environment()
	level = Level.new()
	add_child(level)
	level.build()
	_spawn_props()

	player = Player.new()
	add_child(player)
	hud = Hud.new()
	add_child(hud)
	player.hud = hud

	stalker = Stalker.new()
	stalker.player = player
	add_child(stalker)

	director = Director.new()
	director.main = self
	director.player = player
	director.stalker = stalker
	director.level = level
	add_child(director)

	var ambience := AudioStreamPlayer.new()
	ambience.stream = Sfx.drone()
	ambience.volume_db = -14.0
	add_child(ambience)
	ambience.play()

	Game.end_day_requested.connect(end_day)
	if OS.get_cmdline_user_args().has("--smoke"):
		_smoke_test()
	else:
		start_day(1)


## Облегчённый рендер (браузер). Там нет объёмного тумана, луч рисуется отдельным конусом.
static func is_web_renderer() -> bool:
	return str(ProjectSettings.get_setting_with_override("rendering/renderer/rendering_method")) == "gl_compatibility"


## Прогон для CI (godot --headless -- --smoke): все дни, все события и финал
## должны отработать без ошибок скрипта.
func _smoke_test() -> void:
	for d in range(1, Game.FINAL_DAY + 1):
		start_day(d)
		await get_tree().create_timer(5.5).timeout
		player.global_position = Vector3(Level.TUN_CX, Level.FLOOR_Y + 0.1, -110.0)
		for ev in ["footsteps", "sighting", "behind", "lamps", "whisper", "regrow"]:
			director._run(ev)
		for v in vents:
			v.hold_interact(player, 0.1)
		for n in get_tree().get_nodes_in_group("webs"):
			var web := n as Web
			if web:
				web.burn(2.0)
		for c in crates:
			c.interact(player)
		cart.interact(player)
		journal.interact(player)
		await get_tree().create_timer(1.5).timeout
		stalker.hide_now()
	player.global_position = Vector3(Level.TUN_CX, Level.FLOOR_Y + 0.1, -230.0)
	await get_tree().create_timer(1.0).timeout
	player.global_position = Vector3(Level.TUN_CX, Level.FLOOR_Y + 0.1, -252.0)
	await get_tree().create_timer(9.0).timeout
	print("SMOKE ", "OK" if Game.ended else "FAIL: финал не сработал")
	get_tree().quit(0 if Game.ended else 1)


func _process(delta: float) -> void:
	# Капли где-то в темноте.
	_drip_t -= delta
	if _drip_t <= 0.0 and player.global_position.z < -28.0:
		_drip_t = randf_range(4.0, 11.0)
		var pos := player.global_position + Vector3(randf_range(-2.0, 2.0), 2.5, randf_range(-10.0, 10.0))
		Game.play_at(Sfx.drip(), pos, -6.0)


func _unhandled_input(event: InputEvent) -> void:
	if Game.ended and event.is_action_pressed("restart"):
		hud.hide_title()
		level.blackout = false
		start_day(1)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.35)
	env.ambient_light_energy = 0.04
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	# Обычный туман работает везде, в том числе в браузере: дальний конец тоннеля тонет в черноте.
	env.fog_enabled = true
	env.fog_light_color = Color(0.015, 0.015, 0.02)
	env.fog_density = 0.045
	if not Main.is_web_renderer():
		# На ПК с Forward+ — объёмный туман, в нём виден луч фонаря.
		env.ssao_enabled = true
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.03
		env.volumetric_fog_albedo = Color(0.6, 0.6, 0.6)
		env.volumetric_fog_length = 40.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _spawn_props() -> void:
	journal = Journal.new()
	journal.position = Vector3(2.2, 0, 4.0)
	journal.rotation.y = deg_to_rad(90.0)
	add_child(journal)
	Geo.label(level, Vector3(3.0 - 0.02, 1.9, 4.0), "ЖУРНАЛ СМЕН", -90.0, 36, Color(0.9, 0.85, 0.7))

	for s in VENT_SPOTS:
		var v := Vent.new()
		v.vent_name = s[2]
		v.position = s[0]
		v.rotation.y = deg_to_rad(s[1])
		add_child(v)
		vents.append(v)
	for s in CHARGER_SPOTS:
		var c := Charger.new()
		c.charger_id = s[2]
		c.position = s[0]
		c.rotation.y = deg_to_rad(s[1])
		add_child(c)
		chargers.append(c)
	for p in CRATE_SPOTS:
		var crate := FilterCrate.new()
		crate.position = p
		crate.rotation.y = randf_range(-0.3, 0.3)
		add_child(crate)
		crates.append(crate)
	cart = Cart.new()
	add_child(cart)


# --- Смена дня ---------------------------------------------------------------

func start_day(d: int) -> void:
	busy = true
	Game.day = d
	Game.fear = 0.0
	Game.ended = false
	Game.build_tasks(d)
	for n in get_tree().get_nodes_in_group("day_objects"):
		n.queue_free()

	_setup_vents_and_crates(d)
	_spawn_webs(d)
	_spawn_spiders(d)
	_spawn_notes(d)
	# На третий день вагонетка уезжает в тоннель сама.
	cart.position = Vector3(Level.TUN_CX, Level.FLOOR_Y, -120.0 if d == 3 else -40.0)
	level.set_grate_open(d == Game.FINAL_DAY)
	level.tunnel_lights_off = false
	level.blackout = false
	stalker.hide_now()

	player.global_position = SURFACE_SPAWN
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	player.battery = 55.0 if d == 1 else 45.0
	player.filters = 0
	player.flashlight_on = true
	player.drain_mult = 1.0 + (d - 1) * 0.1
	player.input_locked = true

	director.start_day(d)
	hud.set_black()
	hud.show_title("День %d" % d, DAY_SUBTITLES[d], 2.5)
	await get_tree().create_timer(3.0).timeout
	await hud.fade_to(0.0, 2.0).finished
	player.input_locked = false
	busy = false
	Game.say(DAY_THOUGHTS[d], Game.THOUGHT, 6.0)
	if d == 1:
		hud.show_help(20.0)


func end_day() -> void:
	if busy:
		return
	busy = true
	player.input_locked = true
	Game.play_ui(Sfx.click())
	await hud.fade_to(1.0, 1.5).finished
	start_day(mini(Game.day + 1, Game.FINAL_DAY))


## Страх дошёл до предела: герой теряет сознание и приходит в себя у входа.
func panic() -> void:
	if busy:
		return
	busy = true
	player.input_locked = true
	stalker.hide_now()
	Game.play_ui(Sfx.sting(), 0.0)
	await hud.fade_to(1.0, 0.6).finished
	player.global_position = SURFACE_SPAWN
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	player.battery = maxf(player.battery, 30.0)
	Game.fear = 0.0
	level.tunnel_lights_off = false
	await get_tree().create_timer(1.5).timeout
	await hud.fade_to(0.0, 1.5).finished
	Game.say("Я очнулся у входа. Не помню, как поднялся. Нельзя оставаться без света.", Game.THOUGHT, 6.0)
	player.input_locked = false
	busy = false


## Финал пятого дня.
func ending() -> void:
	if busy:
		return
	busy = true
	player.input_locked = true
	level.blackout = true
	player.flicker(1.2)
	Game.play_ui(Sfx.rumble(), -4.0)
	await get_tree().create_timer(1.3).timeout
	player.flashlight_on = false
	Game.say("…", Game.WHISPER, 2.0)
	await get_tree().create_timer(2.0).timeout
	var pos := player.global_position + player.forward_flat() * 1.6
	pos.y = Level.FLOOR_Y
	stalker.appear(pos, "nest", 999.0)
	player.battery = maxf(player.battery, 20.0)
	player.flashlight_on = true
	player.flicker(0.4)
	Game.play_ui(Sfx.sting(), 2.0)
	await get_tree().create_timer(1.4).timeout
	await hud.fade_to(1.0, 0.15).finished
	stalker.hide_now()
	await get_tree().create_timer(1.5).timeout
	Game.ended = true
	hud.show_title("КОНЕЦ СМЕНЫ",
		"Утром в журнале появилась новая запись:\n«Станции „Тихая“ требуется обходчик».\n\nСпасибо за игру. Нажми R, чтобы начать заново.", 0.0)


# --- Раскладка объектов ------------------------------------------------------

func _setup_vents_and_crates(d: int) -> void:
	for v in vents:
		v.set_dirty(false)
	for c in crates:
		c.set_count(0)
	var need := Game.task_target("filters")
	if need <= 0:
		return
	# Чем дальше смена, тем глубже забитые фильтры.
	var depth := mini(2 + d, vents.size() - 1)
	var candidates: Array = vents.slice(1, depth + 1)
	candidates.shuffle()
	for i in mini(need, candidates.size()):
		candidates[i].set_dirty(true)
	# Запасные фильтры разбросаны по ящикам — их надо искать.
	var spare := need + 1
	if d == 1:
		crates[0].set_count(1)
		spare -= 1
	var pool: Array = crates.slice(1, mini(2 + d, crates.size()))
	while spare > 0:
		var c: FilterCrate = pool.pick_random()
		if c.count < 3:
			c.set_count(c.count + 1)
			spare -= 1


func _spawn_webs(d: int) -> void:
	for i in WEBS_PER_DAY[mini(d, WEBS_PER_DAY.size() - 1)]:
		spawn_block_web(WEB_SPOTS[i])
	for i in 3 + d * 2:
		var left := randf() < 0.5
		var x := Level.LEFT_X + 0.45 if left else Level.RIGHT_X - 0.45
		spawn_small_web(Vector3(x, Level.FLOOR_Y + randf_range(2.0, 2.8), randf_range(-56.0, Level.GRATE_Z + 3.0)), randf_range(0.9, 1.4))
	spawn_small_web(Vector3(-2.6, Level.FLOOR_Y + 3.4, -31.0), 1.2)
	if d == Game.FINAL_DAY:
		# Гнездо за решёткой.
		for i in 12:
			var x := randf_range(Level.LEFT_X + 0.5, Level.RIGHT_X - 0.5)
			spawn_small_web(Vector3(x, Level.FLOOR_Y + randf_range(0.8, 2.8), randf_range(-262.0, -236.0)), randf_range(1.2, 2.0))


func spawn_block_web(z: float, regrown := false) -> Web:
	var w := Web.new()
	w.size = Vector2(Level.TUN_HW * 2.0, Level.TUN_H)
	w.blocking = true
	w.regrown = regrown
	w.position = Vector3(Level.TUN_CX, Level.FLOOR_Y + Level.TUN_H / 2.0, z)
	w.rotation.y = randf_range(-0.12, 0.12)
	add_child(w)
	return w


func spawn_small_web(pos: Vector3, web_size := 1.2) -> Web:
	var w := Web.new()
	w.size = Vector2(web_size, web_size)
	w.blocking = false
	w.position = pos
	w.rotation = Vector3(0, randf_range(-0.4, 0.4), randf_range(-0.5, 0.5))
	add_child(w)
	return w


## Паутина «вырастает» за спиной на месте уже сожжённой.
func regrow_web_behind(pz: float) -> bool:
	for z in WEB_SPOTS:
		if z > pz + 8.0 and z < pz + 45.0 and not _has_web_near(z):
			spawn_block_web(z, true)
			return true
	return false


func _has_web_near(z: float) -> bool:
	for n in get_tree().get_nodes_in_group("webs"):
		var w := n as Web
		if w and w.blocking and not w.is_dead() and absf(w.position.z - z) < 1.5:
			return true
	return false


func _spawn_spiders(d: int) -> void:
	if d == 1:
		# Первый паук — на станции, чтобы познакомиться.
		_add_spider(-3.0, Vector3.RIGHT, -38.0, 4.0)
	for i in d + 1:
		var left := randf() < 0.5
		_add_spider(Level.LEFT_X if left else Level.RIGHT_X, Vector3.RIGHT if left else Vector3.LEFT, randf_range(-220.0, -60.0), 6.0)


func _add_spider(wall_x: float, wall_normal: Vector3, z: float, range_z: float) -> void:
	var s := Spider.new()
	s.main = self
	s.player = player
	s.wall_x = wall_x
	s.normal = wall_normal
	s.home_z = z
	s.range_z = range_z
	s.floor_y = Level.FLOOR_Y
	add_child(s)


func _spawn_notes(d: int) -> void:
	for day in NOTES:
		if day > d:
			continue
		for n in NOTES[day]:
			var l := Geo.label(self, n[0], n[2], n[1], 72, Color(0.85, 0.83, 0.78, 0.85), true, 0.0035)
			l.rotation.z = randf_range(-0.06, 0.06)
			l.add_to_group("day_objects")
