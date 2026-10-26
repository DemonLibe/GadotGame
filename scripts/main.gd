class_name Main
extends Node3D
## Точка входа Hope Light: собирает мир, показывает меню, раскладывает объекты
## на каждую смену, управляет паузой, провалом смены и финалом.

const SPAWN := Vector3(Level.SHAFT_X + 1.6, Level.ROOM_Y + 0.1, Level.SHAFT_Z + 2.4)
const SPAWN_YAW := 0.588  # atan2(1.6, 2.4) — лицом к люку
const START_BATTERY := 50.0

# Места в тоннелях. tunnel: -2 — станция (стена x = -3), -1 — основной тоннель (along = z),
# 0..2 — штольни (along = метры от развилки). side: -1 / +1 — стена.
# Вентблоки: [tunnel, side, along, имя]
const VENT_SPOTS := [
	[-2, 0, -43.0, "В-1"],
	[-1, -1, -78.0, "В-2"],
	[0, 1, 30.0, "В-3"],
	[-1, 1, -135.0, "В-4"],
	[1, -1, 38.0, "В-5"],
	[2, 1, 32.0, "В-6"],
]
# Зарядки: [tunnel, side, along, id]
const CHARGER_SPOTS := [
	[-2, 0, -34.5, "station"],
	[1, 1, 52.0, "far"],
]
# Ящики: [tunnel, along, смещение поперёк]
const CRATE_SPOTS := [
	[-2, -46.5, 0.0],
	[-1, -92.0, -1.3],
	[0, 42.0, 1.0],
	[-1, -128.0, 1.3],
	[1, 24.0, -1.0],
	[2, 37.0, -1.0],
]
# Места для большой паутины поперёк прохода: [tunnel, along]. Берутся по порядку.
const WEB_SPOTS := [
	[-1, -66.0], [-1, -88.0], [0, 16.0], [-1, -125.0], [1, 14.0],
	[-1, -145.0], [2, 15.0], [-1, -180.0], [-1, -215.0],
]
const WEBS_PER_DAY := [0, 2, 4, 5, 7, 9]

# Надписи мелом: [tunnel, side, along, высота над полом, текст]. tunnel -3 — стена шахты (along = y).
# Копятся день за днём.
const NOTES := {
	2: [[-1, -1, -98.0, 1.7, "НЕ ОСТАВАЙСЯ\nБЕЗ СВЕТА"]],
	3: [[-1, 1, -150.0, 1.7, "ПАУКИ НЕ ОПАСНЫ.\nОПАСНО ТО,\nЧЕГО БОЯТСЯ ПАУКИ"],
		[-1, -1, -60.0, 1.4, "|||| |||| |||| ||"]],
	4: [[-1, -1, -84.0, 1.7, "ОН СЧИТАЕТ\nТВОИ ШАГИ"],
		[0, 1, 40.0, 1.7, "СМЕНА №7.\nНЕ ХОДИ\nЗА РЕШЁТКУ"],
		[-3, 0, 40.0, 0.0, "НЕ СМОТРИ ВНИЗ"]],
	5: [[-1, -1, -229.0, 1.8, "ТВОЯ СМЕНА"],
		[-1, 1, -95.0, 1.7, "ОН УЖЕ ЗДЕСЬ"]],
}

const DAY_SUBTITLES := ["", "Станция «Тихая». Первая смена.", "Вторая смена.", "Третья смена.", "Четвёртая смена.", "Последняя смена."]
const DAY_THOUGHTS := [
	"",
	"Первая смена. Открыть люк, спуститься на станцию, зарядить фонарь, поменять фильтр, сжечь паутину. Ничего сложного.",
	"Вчера внизу что-то обрушилось. Надо дойти до решётки в конце тоннеля и посмотреть.",
	"Плохо спал. Всю ночь казалось, что под полом кто-то ходит.",
	"Мой предшественник продержался неделю. Никто не говорит, куда он делся.",
	"В журнале одно поручение. Почерк не мой. И не начальника.",
]

var level: Level
var player: Player
var hud: Hud
var menu: Menu
var stalker: Stalker
var director: Director
var journal: Journal
var hatch: Hatch
var ladder: Ladder
var cart: Cart
var vents: Array[Vent] = []
var chargers: Array[Charger] = []
var crates: Array[FilterCrate] = []
var busy := false
var state := "menu"  # menu / playing / paused
var _drip_t := 5.0
var _uncaptured := 0.0
var _grace := 0.0
var _smoke := false


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
	hud.setup_hotbar(Player.ITEM_NAMES)
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

	menu = Menu.new()
	add_child(menu)
	menu.new_game.connect(_on_new_game)
	menu.continue_game.connect(_on_continue)
	menu.resume.connect(_on_resume)
	menu.main_menu.connect(_on_main_menu)
	menu.quit.connect(func(): get_tree().quit())

	Game.end_day_requested.connect(end_day)
	if OS.get_cmdline_user_args().has("--smoke"):
		_smoke = true
		_smoke_test()
	else:
		_show_main_menu()


## Облегчённый рендер (браузер). Там нет объёмного тумана, луч рисуется отдельным конусом.
static func is_web_renderer() -> bool:
	return str(ProjectSettings.get_setting_with_override("rendering/renderer/rendering_method")) == "gl_compatibility"


func _process(delta: float) -> void:
	_grace -= delta
	if state != "playing":
		return
	# Капли где-то в темноте.
	_drip_t -= delta
	if _drip_t <= 0.0 and player.global_position.y < Level.FLOOR_Y + 5.0:
		_drip_t = randf_range(4.0, 11.0)
		var pos := player.global_position + Vector3(randf_range(-2.0, 2.0), 2.5, randf_range(-10.0, 10.0))
		Game.play_at(Sfx.drip(), pos, -6.0)
	if busy or _smoke:
		return
	# Сорвался в шахту.
	if not player.climbing and player.velocity.y < -16.0:
		fail_day("Ты сорвался в шахту.")
		return
	# В браузере Esc снимает захват мыши сам — тогда ставим игру на паузу.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_uncaptured += delta
		if _uncaptured > 0.4 and _grace <= 0.0:
			_pause()
	else:
		_uncaptured = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if state == "playing" and event.is_action_pressed("ui_cancel"):
		_pause()
	elif Game.ended and event.is_action_pressed("restart"):
		Game.save_day(1)
		get_tree().reload_current_scene()


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


# --- Меню и пауза ------------------------------------------------------------

func _show_main_menu() -> void:
	state = "menu"
	busy = true
	player.reset_for_day(SPAWN, SPAWN_YAW, START_BATTERY)
	player.input_locked = true
	hatch.set_open(false)
	hud.set_ingame(false)
	hud.set_clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.show_main(Game.load_day())


func _on_new_game() -> void:
	Game.save_day(1)
	_begin(1)


func _on_continue() -> void:
	_begin(Game.load_day())


func _begin(d: int) -> void:
	menu.hide_all()
	state = "playing"
	hud.set_ingame(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_grace = 1.5
	start_day(d)


func _pause() -> void:
	if state != "playing" or busy:
		return
	state = "paused"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.show_pause()


func _on_resume() -> void:
	menu.hide_all()
	get_tree().paused = false
	state = "playing"
	_grace = 1.5
	_uncaptured = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# --- Раскладка ---------------------------------------------------------------

func _mount(tunnel: int, side: int, along: float, y: float) -> Transform3D:
	if tunnel == -2:
		return Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(-3.0, y, along))
	if tunnel == -3:
		return Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(Level.SHAFT_X - Level.SHAFT_HALF + 0.02, along, Level.SHAFT_Z + 0.3))
	return level.wall_mount(tunnel, side, along, y)


func _floor(tunnel: int, along: float, lateral: float) -> Vector3:
	if tunnel == -2:
		return Vector3(-2.3, Level.FLOOR_Y, along)
	return level.floor_point(tunnel, along, lateral)


func _spawn_props() -> void:
	ladder = Ladder.new()
	ladder.setup(Level.SHAFT_X, Level.SHAFT_Z - Level.SHAFT_HALF, Level.FLOOR_Y, Level.ROOM_Y,
		Vector3(Level.SHAFT_X, Level.ROOM_Y + 0.05, Level.SHAFT_Z + 1.5))
	add_child(ladder)
	hatch = Hatch.new()
	hatch.ladder = ladder
	hatch.position = Vector3(Level.SHAFT_X, Level.ROOM_Y, Level.SHAFT_Z - Level.SHAFT_HALF)
	add_child(hatch)

	journal = Journal.new()
	journal.position = Vector3(Level.SHAFT_X + 2.9, Level.ROOM_Y, Level.SHAFT_Z - 1.6)
	journal.rotation.y = deg_to_rad(90.0)
	add_child(journal)
	Geo.label(level, Vector3(Level.SHAFT_X + 3.48, Level.ROOM_Y + 1.9, Level.SHAFT_Z - 1.6), "ЖУРНАЛ СМЕН", -90.0, 36, Color(0.15, 0.15, 0.15), true)

	var fy := Level.FLOOR_Y
	for s in VENT_SPOTS:
		var v := Vent.new()
		v.vent_name = s[3]
		v.transform = _mount(s[0], s[1], s[2], fy + 1.4)
		add_child(v)
		vents.append(v)
	for s in CHARGER_SPOTS:
		var c := Charger.new()
		c.charger_id = s[3]
		c.transform = _mount(s[0], s[1], s[2], fy + 1.2)
		add_child(c)
		chargers.append(c)
	for s in CRATE_SPOTS:
		var crate := FilterCrate.new()
		crate.position = _floor(s[0], s[1], s[2])
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
	Game.save_day(d)
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
	hatch.set_open(false)

	player.reset_for_day(SPAWN, SPAWN_YAW, START_BATTERY)
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


func end_day() -> void:
	if busy:
		return
	busy = true
	player.input_locked = true
	Game.play_ui(Sfx.click())
	await hud.fade_to(1.0, 1.5).finished
	start_day(mini(Game.day + 1, Game.FINAL_DAY))


## Смена провалена (сорвался, страх взял верх) — начинается заново. Игра всегда сложная.
func fail_day(reason: String) -> void:
	if busy:
		return
	busy = true
	player.input_locked = true
	stalker.hide_now()
	Game.play_ui(Sfx.sting(), 0.0)
	await hud.fade_to(1.0, 0.5).finished
	hud.show_title("СМЕНА ПРОВАЛЕНА", reason + "\n\nСмена начнётся заново.", 2.5)
	await get_tree().create_timer(4.0).timeout
	start_day(Game.day)


func panic() -> void:
	fail_day("Страх оказался сильнее. Ты очнулся наверху и не помнишь, как поднялся.")


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
	player.select(0)
	player.battery = maxf(player.battery, 20.0)
	player.flashlight_on = true
	player.flicker(0.4)
	Game.play_ui(Sfx.sting(), 2.0)
	await get_tree().create_timer(1.4).timeout
	await hud.fade_to(1.0, 0.15).finished
	stalker.hide_now()
	await get_tree().create_timer(1.5).timeout
	Game.ended = true
	Game.save_day(1)
	hud.set_ingame(false)
	hud.show_title("HOPE LIGHT",
		"Утром в журнале появилась новая запись:\n«Станции „Тихая“ требуется обходчик».\n\nСпасибо за игру. Нажми R, чтобы начать заново.", 0.0)


func _setup_vents_and_crates(d: int) -> void:
	for v in vents:
		v.set_dirty(false)
	for c in crates:
		c.set_contents(0, 0)
	var need := Game.task_target("filters")
	if need > 0:
		# Чем дальше смена, тем глубже забитые фильтры (в том числе в штольнях).
		var depth := mini(2 + d, vents.size() - 1)
		var candidates: Array = vents.slice(1, depth + 1)
		candidates.shuffle()
		for i in mini(need, candidates.size()):
			candidates[i].set_dirty(true)
	# Запасные фильтры и батарейки разложены по ящикам — их надо искать.
	var pool: Array = crates.slice(1, mini(2 + d, crates.size()))
	var spare_f := need + 1 if need > 0 else 0
	var spare_b := 1
	if d == 1:
		crates[0].set_contents(1, 1)
		spare_f -= 1
		spare_b = 0
	var guard := 0
	while (spare_f > 0 or spare_b > 0) and guard < 100:
		guard += 1
		var c: FilterCrate = pool.pick_random()
		if spare_f > 0 and c.filters < 3:
			c.set_contents(c.filters + 1, c.batteries)
			spare_f -= 1
		elif spare_b > 0 and c.batteries < 2:
			c.set_contents(c.filters, c.batteries + 1)
			spare_b -= 1


func _spawn_webs(d: int) -> void:
	for i in WEBS_PER_DAY[mini(d, WEBS_PER_DAY.size() - 1)]:
		var spot: Array = WEB_SPOTS[i]
		spawn_block_web(spot[0], spot[1])
	for i in 3 + d * 2:
		var left := randf() < 0.5
		var y := Level.FLOOR_Y + randf_range(2.0, 2.6)
		var x := Level.wall_x(-1 if left else 1, y, 0.5)
		spawn_small_web(Vector3(x, y, randf_range(-56.0, Level.GRATE_Z + 3.0)), randf_range(0.9, 1.4))
	spawn_small_web(Vector3(-2.6, Level.FLOOR_Y + 3.4, -36.0), 1.2)
	if d == Game.FINAL_DAY:
		# Гнездо за решёткой.
		for i in 12:
			var x := randf_range(Level.LEFT_X + 0.5, Level.RIGHT_X - 0.5)
			spawn_small_web(Vector3(x, Level.FLOOR_Y + randf_range(0.8, 2.8), randf_range(-262.0, -236.0)), randf_range(1.2, 2.0))


func spawn_block_web(tunnel: int, along: float, regrown := false) -> Web:
	var w := Web.new()
	w.size = Vector2(Level.TUN_HW * 2.0, Level.TUN_H)
	w.blocking = true
	w.regrown = regrown
	w.position = level.floor_point(tunnel, along) + Vector3(0, Level.TUN_H / 2.0, 0)
	w.rotation.y = level.cross_yaw(tunnel) + randf_range(-0.12, 0.12)
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


## Паутина «вырастает» за спиной на месте уже сожжённой (только в основном тоннеле).
func regrow_web_behind(pz: float) -> bool:
	for spot in WEB_SPOTS:
		if spot[0] != -1:
			continue
		var z: float = spot[1]
		if z > pz + 8.0 and z < pz + 45.0 and not _has_web_near(z):
			spawn_block_web(-1, z, true)
			return true
	return false


func _has_web_near(z: float) -> bool:
	for n in get_tree().get_nodes_in_group("webs"):
		var w := n as Web
		if w and w.blocking and not w.is_dead() and absf(w.position.z - z) < 1.5 and absf(w.position.x - Level.TUN_CX) < 1.0:
			return true
	return false


func _spawn_spiders(d: int) -> void:
	if d == 1:
		# Первый паук — на станции, чтобы познакомиться.
		_add_spider(-3.0, Vector3.RIGHT, -40.0, 3.0)
	for i in d + 1:
		var left := randf() < 0.5
		var z := randf_range(-220.0, -60.0)
		# Не в камерах развилок — там стены другие.
		for b in Level.BRANCHES:
			if absf(z - float(b["z"])) < Level.CHAMBER + 7.0:
				z += 12.0
		_add_spider(Level.wall_x(-1 if left else 1, Level.FLOOR_Y + 1.5, 0.02), Vector3.RIGHT if left else Vector3.LEFT, z, 5.0)


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
			var tr := _mount(n[0], n[1], n[2], Level.FLOOR_Y + float(n[3]))
			var l := Geo.label(self, tr.origin, n[4], 0.0, 72, Color(0.85, 0.83, 0.78, 0.85), true, 0.0035)
			l.basis = tr.basis
			l.rotate_object_local(Vector3.FORWARD, randf_range(-0.06, 0.06))
			l.add_to_group("day_objects")


## Прогон для CI (godot --headless -- --smoke): все дни, предметы, лестница, события и финал
## должны отработать без ошибок скрипта.
func _smoke_test() -> void:
	state = "playing"
	hud.set_ingame(true)
	for d in range(1, Game.FINAL_DAY + 1):
		start_day(d)
		await get_tree().create_timer(5.5).timeout
		hatch.hold_interact(player, 2.0)
		hatch.interact(player)
		await get_tree().create_timer(0.5).timeout
		player.stop_climb(Vector3(Level.TUN_CX, Level.FLOOR_Y + 0.1, -110.0))
		for ev in ["footsteps", "sighting", "behind", "lamps", "whisper", "regrow"]:
			director._run(ev)
		player.batteries = 1
		player.select(3)
		player.use_item()
		player.filters = 3
		player.select(2)
		for v in vents:
			v.hold_interact(player, 2.5)
		for n in get_tree().get_nodes_in_group("webs"):
			var web := n as Web
			if web:
				web.burn(2.0)
		for c in crates:
			c.interact(player)
		player.cycle(1)
		player.select(0)
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
