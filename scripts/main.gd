class_name Main
extends Node3D
## Точка входа Hope Light: собирает мир, показывает меню, раскладывает объекты
## на каждую смену, управляет паузой, провалом смены и финалом.

const SPAWN := Vector3(Level.SHAFT_X + 1.6, Level.ROOM_Y + 0.1, Level.SHAFT_Z + 2.4)
const SPAWN_YAW := 0.588  # atan2(1.6, 2.4) — лицом к люку
const START_BATTERY := 50.0
const MENU_SCENE := "res://scenes/main_menu.tscn"

# Места в тоннелях. tunnel: -2 — станция (стена x = -3), -1 — основной тоннель (along = z),
# 0..2 — штольни (along = метры от развилки). side: -1 / +1 — стена.
# Вентблоки: [tunnel, side, along, имя]
const VENT_SPOTS := [
	[-2, 0, -43.0, "В-1"],
	[-1, -1, -92.0, "В-2"],
	[0, 1, 42.0, "В-3"],
	[-1, 1, -177.5, "В-4"],
	[1, -1, 53.0, "В-5"],
	[2, 1, 45.0, "В-6"],
]
# Зарядки: [tunnel, side, along, id]
const CHARGER_SPOTS := [
	[-2, 0, -34.5, "station"],
	[1, 1, 73.0, "far"],
]
# Ящики: [tunnel, along, смещение поперёк]
const CRATE_SPOTS := [
	[-2, -46.5, 0.0],
	[-1, -113.0, -1.3],
	[0, 59.0, 1.0],
	[-1, -167.0, 1.3],
	[1, 33.5, -1.0],
	[2, 52.0, -1.0],
]
# Места для большой паутины поперёк прохода: [tunnel, along]. Берутся по порядку.
const WEB_SPOTS := [
	[-1, -74.0], [-1, -107.0], [0, 22.5], [-1, -162.5], [1, 19.5],
	[-1, -192.5], [2, 21.0], [-1, -245.0], [-1, -297.5],
]
const WEBS_PER_DAY := [0, 2, 4, 5, 7, 9]
# Шкафы-укрытия: [tunnel, side, along]. tunnel -2 — станция.
const HIDEOUT_SPOTS := [
	[-2, 1, -34.0], [-1, 1, -71.0], [-1, 1, -110.0], [-1, -1, -188.0], [-1, -1, -236.0],
	[-1, 1, -305.0], [0, -1, 31.0], [1, 1, 45.0], [2, -1, 31.0],
]
## Генератор: сколько топлива в баке в начале смены и сколько канистр спрятано в тоннелях.
const GEN_FUEL := [0.0, 100.0, 70.0, 60.0, 50.0, 50.0]
const CANISTERS_PER_DAY := [0, 0, 1, 2, 2, 2]
## Затопленная штольня (четвёртая смена): номер штольни и участок воды.
const FLOOD_BRANCH := 2
const FLOOD_FROM := 18.0
# Где искрит кабель на третьей смене: [side, z].
const CABLE_SPOTS := [[-1, -101.0], [1, -152.0], [1, -185.0]]
const LETTER := ["Письмо от Маши",
	"Папа! Мама говорит, ты теперь работаешь под землёй, как гном из сказки.\n\nВрач сказал, после операции я смогу бегать. Я нарисовала тебе фонарик, чтобы тебе там не было темно.\n\nВозвращайся скорее. Маша, 7 лет."]

# Надписи мелом: [tunnel, side, along, высота над полом, текст]. tunnel -3 — стена шахты (along = y).
# Копятся день за днём.
const NOTES := {
	2: [[-1, -1, -122.0, 1.7, "НЕ ОСТАВАЙСЯ\nБЕЗ СВЕТА"]],
	3: [[-1, 1, -200.0, 1.7, "ПАУКИ НЕ ОПАСНЫ.\nОПАСНО ТО,\nЧЕГО БОЯТСЯ ПАУКИ"],
		[-1, -1, -65.0, 1.4, "|||| |||| |||| ||"]],
	4: [[-1, -1, -101.0, 1.7, "ОН СЧИТАЕТ\nТВОИ ШАГИ"],
		[0, 1, 56.0, 1.7, "СМЕНА №7.\nНЕ ХОДИ\nЗА РЕШЁТКУ"],
		[-3, 0, 40.0, 0.0, "НЕ СМОТРИ ВНИЗ"]],
	5: [[-1, -1, -318.5, 1.8, "ТВОЯ СМЕНА"],
		[-1, 1, -117.5, 1.7, "ОН УЖЕ ЗДЕСЬ"]],
}

## Карта растёт: докуда по основному тоннелю открыто в каждую смену (z ограждения)
## и с какой смены открыта каждая штольня.
const DAY_LIMIT_Z := [0.0, -117.5, -197.0, -239.0, -321.5, -1000.0]
const BRANCH_OPEN_DAY := [2, 3, 4]
## Сложность растёт: существа, коробки патронов, патроны в оружейном ящике.
const CREATURES_PER_DAY := [0, 0, 0, 2, 4, 6]
const AMMO_BOXES_PER_DAY := [0, 0, 0, 3, 3, 4]
const PISTOL_ROUNDS := [0, 0, 0, 6, 4, 6]

## Комнаты, открытые в каждую смену: [индекс комнаты (0–2 — у тоннеля, 3–5 — в конце штолен), записка].
const ROOM_SCHEDULE := {
	1: [[0, "n1"]],
	2: [[3, "n2"], [1, "n3"]],
	3: [[4, "n4"], [0, "n5"]],
	4: [[5, "n6"], [2, "n7"]],
	5: [[1, "n8"]],
}
## Записки прежних обходчиков: из них складывается история тоннеля.
const NOTE_TEXTS := {
	"n1": ["Журнал бригады Гусева, 1979",
		"12 марта. Прокладываем перегон к «Тихой». Грунт сухой, идём быстро, план перевыполнили. Бригадир обещал премию к майским.\n\n"
		+ "17 марта. На двести семьдесят третьем метре щит упёрся в старую кладку. Кирпич дореволюционный, раствор чёрный, как дёготь. На схемах здесь ничего нет. Пробили — за стенкой пустота, тёплый воздух и звук, будто кто-то медленно дышит во сне.\n\n"
		+ "18 марта. Петров полез с фонарём и вернулся бледный. Говорит, там тоннель, старше нашего, и уходит вниз. Говорит, видел каски. Наши, жёлтые. Мы такие ещё не получали.\n\n"
		+ "19 марта. Приезжали из управления. Велели замуровать, поставить решётку и забыть. Мы замуровали. Решётку поставили.\n\n"
		+ "Забыть не получается. Петров перестал выключать свет дома."],
	"n2": ["Обходчик № 2, 1986",
		"Пишу, пока светит фонарь. Батарейку берегу, поэтому коротко — но, наверное, не получится.\n\n"
		+ "Первые две смены всё было как обещали: фильтры, паутина, генератор. На третью кто-то пошёл за мной в такт. Я останавливаюсь — он делает ещё два шага. Я считал.\n\n"
		+ "Свет его не убивает. Он просто не любит, когда на него смотрят. Если поймать его лучом — он уходит, как будто его и не было. Но потом возвращается ближе.\n\n"
		+ "Пауки чувствуют его раньше нас. Они бегут все разом, в одну сторону — от него. Если паутина свежая там, где ты её только что сжёг, — он рядом. Если пауки пропали совсем — он уже здесь.\n\n"
		+ "В шкафах для инструмента можно отсидеться. Главное — не дышать, когда он подходит. Он слушает."],
	"n3": ["Без подписи",
		"Не верь голосу в рации, если он зовёт тебя к решётке. Наверху так не говорят. Наверху говорят коротко и с матом, а этот — вежливо, по имени-отчеству.\n\n"
		+ "Я проверял: позвонил диспетчеру с поверхности после смены. Он сказал, что в ту ночь со мной не связывался. Что линия была отключена на ремонт.\n\n"
		+ "Наверху вообще не знают, что здесь. Или делают вид. Платят втрое — это не за вредность.\n\n"
		+ "Если голос просит доложить, где ты, — промолчи. Просто промолчи."],
	"n4": ["Обходчик № 4, 1993",
		"Вагонетку двигал не я. Одному её с места не сдвинуть — я пробовал, когда искал, куда закатился фильтр. Тонна железа, колёса прикипели к рельсам.\n\n"
		+ "Утром она стояла на сто пятом метре, носом к станции. Как будто кто-то катал её ночью туда-сюда и бросил на полпути.\n\n"
		+ "Он учится. Я записываю, чтобы не сойти с ума:\n"
		+ "сначала были шаги;\n"
		+ "потом голоса — моим голосом, из штольни;\n"
		+ "потом вещи — дверь, зарядка, ящики;\n"
		+ "потом — мы.\n\n"
		+ "Я не знаю, что значит последний пункт. Но он написан не моей рукой."],
	"n5": ["Обходчик № 4, последняя запись",
		"С ним пришли другие. Бледные, худые, ползают на четвереньках, как побитые собаки. В луче фонаря они медленнее — будто вязнут в свете. Без света видят шагов на пять, не больше, но слышат всё: бег, прыжок, выстрел.\n\n"
		+ "Пистолет диспетчер выдал на третью ночь. Значит, наверху знают. Значит, знали и раньше.\n\n"
		+ "Два попадания — и ползун рассыпается в пыль. Пыль пахнет как старые каски.\n\n"
		+ "Он сам — другое. Его пуля не берёт. От него только прятаться: шкаф, тишина, задержать дыхание. С каждой ночью он ищет дольше. Сегодня он стоял у моего шкафа, пока я не досчитал до трёхсот.\n\n"
		+ "Завтра не спущусь."],
	"n6": ["Обходчик № 6",
		"Седьмой — это не номер смены. Нас было семеро. Я нашёл список в столе диспетчерской, под газетой: семь фамилий, у шести стоят галочки. Последняя — пустая. Место для восьмого.\n\n"
		+ "Каждый следующий — его новая пара глаз. Он смотрит нами. Поэтому он знает, где шкафы, где зарядка, где ты прячешь батарейки.\n\n"
		+ "Вчера я видел Пятого. Он полз по третьей штольне, в своей каске, бледный, как те. Он узнал меня. Он улыбнулся.\n\n"
		+ "Я оставлю это здесь, где темнее всего. Сюда он заходит реже: тут нечего забирать."],
	"n7": ["Акт обследования, 2001",
		"АКТ № 14-с. Комиссия в составе трёх человек провела обследование перегона за станцией «Тихая».\n\n"
		+ "Обнаружено: шесть касок образца 1978 года, личные вещи, фонари (все в рабочем состоянии, батареи разряжены), журнал смен с записями после даты закрытия станции. Тел не обнаружено.\n\n"
		+ "Решётка на 273-м метре повреждена. Характер повреждений указывает на воздействие изнутри.\n\n"
		+ "Решение: станцию для пассажиров не открывать. Набор обходчиков продолжить на прежних условиях. Сведения засекретить.\n\n"
		+ "Подпись председателя неразборчива. На обороте карандашом: «Сколько ещё?»"],
	"n8": ["Обходчик № 7",
		"Решётку открыл не он. Решётку открыл я.\n\n"
		+ "Он не может открыть её сам — замок с нашей стороны. Ему нужен кто-то, кто устанет бояться. Кто придёт сюда в пятую ночь и решит, что хуже уже не будет.\n\n"
		+ "Изнутри было тише. Изнутри было не страшно. Там тепло, и все наши там, и никто не считает шаги.\n\n"
		+ "Но если ты дочитал до сюда — засов работает в обе стороны. Его можно запереть изнутри. Тогда он останется с нами, а не пойдёт наверх.\n\n"
		+ "Я не смог. Может, сможешь ты."],
	"n9": ["Без подписи. Чернила ещё свежие",
		"Если ты читаешь это — ты восьмой.\n\n"
		+ "Я писал это твоей рукой. Посмотри на почерк. Посмотри.\n\n"
		+ "Не выключай фонарь. Не докладывай, где ты. Поднимайся, пока лестница держит.\n\n"
		+ "Или останься и закрой за собой. Выбор всегда был твой — просто тебе об этом не говорили."],
}

const DAY_SUBTITLES := ["", "Станция «Тихая». Первая смена.", "Вторая смена.", "Третья смена.", "Четвёртая смена.", "Последняя смена."]
const DAY_THOUGHTS := [
	"",
	"Первая смена. Платят втрое — Маше нужна операция. Спуститься, завести генератор, зарядить фонарь, поменять фильтр, сжечь паутину. Ничего сложного.",
	"Вчера внизу что-то обрушилось. Маша спросила по телефону, страшно ли под землёй. Сказал — нет.",
	"Плохо спал. Всю ночь казалось, что под полом кто-то ходит. Ещё три смены — и хватит на операцию.",
	"Мой предшественник продержался неделю. Никто не говорит, куда он делся. У него тоже кто-то ждал дома?",
	"В журнале одно поручение. Почерк не мой. И не начальника. Последняя смена, Маша. Последняя.",
]

var level: Level
var player: Player
var hud: Hud
var menu: Menu
var stalker: Stalker
var director: Director
var journal: Journal
var hatch: Hatch
var radio: RadioSet
var dispatcher: Dispatcher
var ladder: Ladder
var cart: Cart
var vents: Array[Vent] = []
var chargers: Array[Charger] = []
var crates: Array[FilterCrate] = []
var doors: Array[RoomDoor] = []
var generator: Generator
var pump: TaskDevice
var _reported := false   # в финале доложил диспетчеру, где он
var _station_t := 0.0
var _call_t := 0.0
var busy := false
var collapsing := false
var _rumble_t := 0.0
var _rock_t := 0.0
var state := "loading"  # loading / playing / paused
var _drip_t := 5.0
var _uncaptured := 0.0
var _grace := 0.0
var _smoke := false
var _debug_log := false
var _fear_peak := 0.0  # для достижения «Холодная голова»
var _debug_t := 0.0


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
	hud.setup_hotbar(player, not debug_flag("noicons"))
	hud.setup_map(level, player)
	hud.player = player
	player.hud = hud
	player.died.connect(func(): fail_day("Тебя утащили во тьму."))
	_debug_log = debug_flag("debug")
	if debug_flag("nomsaa"):
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	if debug_flag("novig"):
		hud.hide_vignette()
	if debug_flag("nodirector"):
		director.process_mode = Node.PROCESS_MODE_DISABLED
	if not debug_flag("nofx"):
		Main.add_postfx(self)
	dispatcher = Dispatcher.new()
	add_child(dispatcher)
	player.dispatcher = dispatcher
	radio.dispatcher = dispatcher
	dispatcher.shift_closed.connect(end_day)
	dispatcher.collapse_reported.connect(func(): _reported = true)
	Game.seal_requested.connect(_ending_seal)

	stalker = Stalker.new()
	stalker.player = player
	stalker.level = level
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
	ambience.bus = "Ambience"
	add_child(ambience)
	ambience.play()

	menu = Menu.new()
	add_child(menu)
	menu.resume.connect(_on_resume)
	menu.main_menu.connect(_on_main_menu)

	Game.end_day_requested.connect(end_day)
	if OS.get_cmdline_user_args().has("--smoke"):
		_smoke = true
		_smoke_test()
	else:
		_begin(Game.pending_day)


## Отладочные переключатели из адреса страницы, например …/index.html?nofx&noicons.
static func debug_flag(name: String) -> bool:
	if not OS.has_feature("web"):
		return false
	var search := str(JavaScriptBridge.eval("window.location.search", true))
	return search.contains(name)


## Облегчённый рендер (браузер). Там нет объёмного тумана, луч рисуется отдельным конусом.
static func is_web_renderer() -> bool:
	return str(ProjectSettings.get_setting_with_override("rendering/renderer/rendering_method")) == "gl_compatibility"


func _process(delta: float) -> void:
	_grace -= delta
	if _debug_log:
		_debug_t -= delta
		if _debug_t <= 0.0:
			_debug_t = 1.0
			var cam := get_viewport().get_camera_3d()
			var lights := 0
			for l in get_tree().root.find_children("*", "Light3D", true, false):
				if (l as Light3D).is_visible_in_tree():
					lights += 1
			print("DBG lights=%d day_objects=%d draws=%d objects=%d prims=%d" % [lights, get_tree().get_nodes_in_group("day_objects").size(),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
			print("DBG state=%s busy=%s player=%s rot=%s cam=%s campos=%s fade=%s fps=%d" % [state, busy,
				player.global_position, player.rotation, cam.get_path() if cam else "none",
				cam.global_position if cam else Vector3.ZERO, hud.fade_alpha(), Engine.get_frames_per_second()])
	if state != "playing":
		return
	# Капли где-то в темноте.
	_drip_t -= delta
	if _drip_t <= 0.0 and player.global_position.y < Level.FLOOR_Y + 5.0:
		_drip_t = randf_range(4.0, 11.0)
		var pos := player.global_position + Vector3(randf_range(-2.0, 2.0), 2.5, randf_range(-10.0, 10.0))
		Game.play_at(Sfx.drip(), pos, -6.0)
	_fear_peak = maxf(_fear_peak, Game.fear)
	if collapsing and not busy:
		_update_collapse(delta)
	_update_water()
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
		Game.pending_day = 1
		get_tree().reload_current_scene()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.35)
	env.ambient_light_energy = 0.04
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = not debug_flag("noglow")
	# Обычный туман работает везде, в том числе в браузере: дальний конец тоннеля тонет в черноте.
	env.fog_enabled = true
	env.fog_light_color = Color(0.015, 0.015, 0.02)
	env.fog_density = 0.022
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

func _begin(d: int) -> void:
	state = "playing"
	hud.set_ingame(not debug_flag("noingame"))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_grace = 1.5
	if debug_flag("skipstart"):
		player.input_locked = false
		busy = false
		return
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
	get_tree().change_scene_to_file(MENU_SCENE)


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
	# Лестница — у стены напротив петель люка (петли на северной кромке).
	ladder.setup(Level.SHAFT_X, Level.SHAFT_Z + Level.SHAFT_HALF, -1.0, Level.FLOOR_Y, Level.ROOM_Y,
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
	radio = RadioSet.new()
	radio.position = Vector3(Level.SHAFT_X + 2.9, Level.ROOM_Y + 0.805, Level.SHAFT_Z - 1.15)
	radio.rotation.y = deg_to_rad(-70.0)
	add_child(radio)
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
	generator = Generator.new()
	generator.level = level
	generator.position = Vector3(-2.4, Level.FLOOR_Y, -44.6)
	generator.rotation.y = deg_to_rad(90.0)
	add_child(generator)
	for h in HIDEOUT_SPOTS:
		var cab := Hideout.new()
		var t: int = h[0]
		if t == -2:
			cab.position = Vector3(2.55, Level.FLOOR_Y, float(h[2]))
			cab.rotation.y = deg_to_rad(-90.0)
		else:
			var axis := Vector3.FORWARD if t < 0 else Level.branch_dir(t)
			var right := Vector3(-axis.z, 0.0, axis.x)
			cab.position = level.floor_point(t, float(h[2]), float(h[1]) * 1.05)
			var front := -right * float(h[1])
			cab.rotation.y = atan2(front.x, front.z)
		add_child(cab)
	for room in level.rooms:
		var door := RoomDoor.new()
		door.transform = room["door"]
		add_child(door)
		doors.append(door)


# --- Смена дня ---------------------------------------------------------------

func start_day(d: int) -> void:
	busy = true
	collapsing = false
	Game.day = d
	Game.fear = 0.0
	Game.ended = false
	if not debug_flag("s_save"):
		Game.save_day(d)
	if not debug_flag("s_tasks"):
		Game.build_tasks(d)
	for n in get_tree().get_nodes_in_group("day_objects"):
		n.queue_free()

	if not debug_flag("novents"):
		_setup_vents_and_crates(d)
	if not debug_flag("nowebs"):
		_spawn_webs(d)
	if not debug_flag("nospiders"):
		_spawn_spiders(d)
	if not debug_flag("nonotes"):
		_spawn_notes(d)
	if not debug_flag("noaccess"):
		_setup_access(d)
	if not debug_flag("norooms"):
		_setup_rooms(d)
	_spawn_finds(d)
	_spawn_threats(d)
	_setup_power(d)
	_spawn_task_devices(d)
	_reported = false
	_station_t = 0.0
	dispatcher.collapse_mode = false
	# На третий день вагонетка уезжает в тоннель сама.
	if not debug_flag("s_misc"):
		cart.position = Vector3(Level.TUN_CX, Level.FLOOR_Y, -155.0 if d == 3 else -40.0)
		level.set_grate_open(d == Game.FINAL_DAY)
		level.tunnel_lights_off = false
		level.blackout = false
		stalker.hide_now()
		hatch.set_open(false)
	if not debug_flag("noradio"):
		radio.reset()
	if not debug_flag("s_disp"):
		dispatcher.stop()

	if not debug_flag("s_reset"):
		player.reset_for_day(SPAWN, SPAWN_YAW, START_BATTERY)
	player.drain_mult = 1.0 + (d - 1) * 0.15
	_fear_peak = 0.0
	if d == Game.FINAL_DAY:
		Achievements.unlock("shift5")
	for c in chargers:
		c.reset()
	player.input_locked = true

	if not debug_flag("s_dir"):
		director.start_day(d)
	if not debug_flag("s_fade"):
		hud.set_black()
		hud.show_title("День %d" % d, DAY_SUBTITLES[d], 2.5)
		await get_tree().create_timer(3.0).timeout
		await hud.fade_to(0.0, 2.0).finished
	player.input_locked = false
	busy = false
	if debug_flag("flashoff"):
		player.flashlight_on = false
	if debug_flag("select2"):
		player.hold("burner")
	if debug_flag("lookup"):
		player.debug_look(0.9, 0.0)
	if debug_flag("lookback"):
		player.debug_look(0.0, PI)
	if debug_flag("lookleft"):
		player.debug_look(0.0, PI / 2)
	if not debug_flag("s_say"):
		Game.say(DAY_THOUGHTS[d], Game.THOUGHT, 6.0)
		Game.say("На столе шипит рация. Диспетчер ждёт.", Game.THOUGHT, 3.5)
		if d == 1:
			Game.say("Рация в руке (4) и ЛКМ — спросить диспетчера, куда идти. Шуметь внизу не стоит: приседай (C).", Game.SYSTEM, 6.0)


func end_day() -> void:
	if busy:
		return
	busy = true
	# Достижения за смену.
	if Game.day == 1:
		Achievements.unlock("shift1")
	if not player.ran_today:
		Achievements.unlock("quiet")
	if _fear_peak <= Achievements.fear_max() * 0.5:
		Achievements.unlock("brave")
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


## Финал пятого дня, часть 1: за решёткой тоннель начинает рушиться — бежать.
## Дальше — одна из трёх концовок:
##   1. доложил диспетчеру, где он, — у станции его уже ждут;
##   2. не доложил и поднялся по лестнице — выбрался... но не один;
##   3. прочитал все записки и запер решётку изнутри.
func ending() -> void:
	if collapsing or busy:
		return
	collapsing = true
	Game.tasks.clear()
	Game.add_task("escape", "БЕЖАТЬ К ЛЕСТНИЦЕ", 1)
	stalker.hide_now()
	Game.play_ui(Sfx.rumble(), 0.0)
	player.flicker(0.8)
	Game.say("Тоннель рушится! Бежать! К станции, к лестнице — быстрее!", Game.THOUGHT, 5.0)
	_rumble_t = 0.0
	_rock_t = 0.0
	_call_t = 5.0
	_station_t = 0.0
	dispatcher.collapse_mode = true
	if Game.notes_count() >= Game.NOTES_TOTAL:
		get_tree().create_timer(6.0).timeout.connect(func(): Game.say("…Решётку можно запереть изнутри. Как Седьмой. «Изнутри было тише».", Game.WHISPER, 5.0))


## Обвал во время бегства: камни с потолка, тряска, гул, диспетчер требует доклада.
func _update_collapse(delta: float) -> void:
	var p := player.global_position
	var below := p.y < Level.FLOOR_Y + 5.0
	player.extra_shake = 0.03 if below else 0.012
	Game.fear = minf(Game.fear, 85.0)
	_rumble_t -= delta
	if _rumble_t <= 0.0:
		_rumble_t = randf_range(2.0, 3.5)
		Game.play_ui(Sfx.rumble(), -4.0 if below else -12.0)
		if randf() < 0.4:
			player.flicker(0.3)
	if not _reported and dispatcher.collapse_mode:
		_call_t -= delta
		if _call_t <= 0.0:
			_call_t = 13.0
			dispatcher.collapse_call()
	if below and p.z < Level.TUN_Z0:
		_rock_t -= delta
		if _rock_t <= 0.0:
			_rock_t = randf_range(0.25, 0.7)
			_drop_rock(p + Vector3(randf_range(-1.4, 1.4), 0, randf_range(-6.0, 4.0)))
	# Наверху — выбрался.
	if p.y > Level.ROOM_Y - 1.0 and not player.climbing:
		_ending_climb()
		return
	if not below or p.z < -47.0:
		return
	# У станции: кто доложил — того уже ждут. Кто промолчал — у того есть минута на лестницу.
	if _reported:
		_final_scene()
		return
	if _station_t == 0.0:
		player.climb_mult = 5.0
		Game.say("Здесь никого... Наверх! По лестнице — пока оно не пришло!", Game.THOUGHT, 4.0)
	_station_t += delta
	if _station_t > 20.0 and not player.climbing:
		_final_scene()


func _drop_rock(pos: Vector3) -> void:
	var rock := Geo.box(self, Vector3(pos.x, Level.FLOOR_Y + 3.0, pos.z), Vector3.ONE * randf_range(0.2, 0.5), level.m_concrete, false)
	rock.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	rock.add_to_group("day_objects")
	var tw := create_tween()
	tw.tween_property(rock, "position:y", Level.FLOOR_Y + 0.15, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## Концовка 1: у станции существо съедает героя. Потом газета и скример.
func _final_scene() -> void:
	collapsing = false
	busy = true
	dispatcher.collapse_mode = false
	player.extra_shake = 0.0
	player.input_locked = true
	if player.climbing:
		player.stop_climb(Vector3(Level.SHAFT_X + 0.5, Level.FLOOR_Y + 0.05, Level.SHAFT_Z - 2.0))
	if player.hiding:
		player.exit_hide()
	# Он стоит у подножия лестницы.
	var pos := Vector3(Level.SHAFT_X, Level.FLOOR_Y, Level.SHAFT_Z + 0.2)
	var to := pos - player.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.hold("")
	player.flashlight_on = true
	player.battery = maxf(player.battery, 40.0)
	stalker.appear(pos, "nest", 999.0)
	Game.play_ui(Sfx.sting(), 0.0)
	await get_tree().create_timer(1.2).timeout
	# Рывок.
	var target := player.global_position + player.forward_flat() * 0.6
	target.y = Level.FLOOR_Y
	var tw := create_tween()
	tw.tween_property(stalker, "global_position", target, 0.35).set_ease(Tween.EASE_IN)
	await tw.finished
	Game.play_ui(Sfx.gunshot(), 4.0)
	Game.play_ui(Sfx.sting(), 4.0)
	hud.set_black()
	hud.set_ingame(false)
	stalker.hide_now()
	await get_tree().create_timer(2.5).timeout
	await _newspaper("A")
	await _screamer()
	Achievements.unlock("ending1")
	_finish("Концовка 1 из 3 — «Доклад принят»")


## Концовка 2: не доложил и выбрался наверх. В журнале — запись его почерком.
func _ending_climb() -> void:
	collapsing = false
	busy = true
	dispatcher.collapse_mode = false
	dispatcher.stop()
	player.extra_shake = 0.0
	player.input_locked = true
	var to := journal.global_position - player.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	Game.say("Выбрался... Живой. В журнале смен — свежая запись. Моим почерком: «Смена сдана. Восьмой».", Game.THOUGHT, 5.0)
	await get_tree().create_timer(3.0).timeout
	Game.say("Я этого не писал.", Game.THOUGHT, 3.0)
	Game.play_at(Sfx.rung(), Vector3(Level.SHAFT_X, Level.ROOM_Y - 4.0, Level.SHAFT_Z), 0.0)
	await get_tree().create_timer(1.2).timeout
	Game.play_at(Sfx.rung(), Vector3(Level.SHAFT_X, Level.ROOM_Y - 3.0, Level.SHAFT_Z), 2.0)
	await hud.fade_to(1.0, 2.0).finished
	hud.set_ingame(false)
	await get_tree().create_timer(1.5).timeout
	await _newspaper("B")
	await _screamer()
	Achievements.unlock("ending2")
	_finish("Концовка 2 из 3 — «Поднялся»")


## Концовка 3: все записки прочитаны — решётка заперта изнутри. Скримера нет.
func _ending_seal() -> void:
	if busy or not collapsing:
		return
	collapsing = false
	busy = true
	dispatcher.collapse_mode = false
	dispatcher.stop()
	player.extra_shake = 0.0
	player.input_locked = true
	level.set_grate_open(false)
	Game.play_at(Sfx.clank(), Vector3(Level.TUN_CX, Level.FLOOR_Y + 1.2, Level.GRATE_Z), 4.0)
	Game.say("Щёлкнул засов. Грохот стих. Стало тихо... впервые за пять ночей — тихо.", Game.THOUGHT, 5.0)
	await get_tree().create_timer(4.0).timeout
	await hud.fade_to(1.0, 4.0).finished
	hud.set_ingame(false)
	hud.show_title("ИЗНУТРИ БЫЛО ТИШЕ", "", 3.0)
	await get_tree().create_timer(4.5).timeout
	await _newspaper("C")
	Achievements.unlock("ending3")
	_finish("Концовка 3 из 3 — «Изнутри»")


func _newspaper(variant: String) -> void:
	Game.play_ui(Sfx.pickup(), -6.0)
	hud.show_newspaper(variant)
	await hud.newspaper_closed
	await get_tree().create_timer(1.0).timeout


func _finish(which: String) -> void:
	Game.ended = true
	Game.save_day(1)
	hud.set_black()
	hud.show_title("HOPE LIGHT", which + "\n\nСпасибо за игру.\nНажми R, чтобы начать заново.", 0.0)


func _screamer() -> void:
	var t := Time.get_time_dict_from_system()
	var clock := "%02d:%02d" % [t["hour"], t["minute"]]
	var cam := player.camera
	var face := cam.global_position - cam.global_transform.basis.z * 0.55
	face.y -= 1.95
	stalker.appear(face, "nest", 999.0)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.95, 0.9)
	flash.omni_range = 3.0
	flash.light_energy = 4.0
	add_child(flash)
	flash.global_position = cam.global_position - cam.global_transform.basis.z * 0.2
	hud.set_clear()
	player.extra_shake = 0.06
	Game.play_ui(Sfx.scream(), 4.0)
	Game.play_ui(Sfx.sting(), 6.0)
	Game.play_ui(Sfx.hiss(), 6.0)
	hud.show_scream("Сейчас %s. Ты ведь не спишь.\n\nЖДИ НАС.\nМЫ ИДЁМ ЗА ТОБОЙ." % clock)
	await get_tree().create_timer(2.8).timeout
	hud.hide_scream()
	hud.set_black()
	player.extra_shake = 0.0
	stalker.hide_now()
	flash.queue_free()
	await get_tree().create_timer(1.5).timeout


func _setup_vents_and_crates(d: int) -> void:
	for v in vents:
		v.set_dirty(false)
	for c in crates:
		c.set_contents(0, 0)
	var need := Game.task_target("filters")
	if need > 0:
		# Чем дальше смена, тем глубже забитые фильтры (в том числе в штольнях).
		var candidates: Array = []
		for i in range(1, vents.size()):
			if _reachable(VENT_SPOTS[i][0], VENT_SPOTS[i][2]):
				candidates.append(vents[i])
		candidates.shuffle()
		for i in mini(need, candidates.size()):
			candidates[i].set_dirty(true)
	# Запасные фильтры и батарейки разложены по ящикам — их надо искать.
	var pool: Array = []
	for i in range(1, crates.size()):
		if _reachable(CRATE_SPOTS[i][0], CRATE_SPOTS[i][1]):
			pool.append(crates[i])
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
	var left_to_place: int = WEBS_PER_DAY[mini(d, WEBS_PER_DAY.size() - 1)]
	for spot in WEB_SPOTS:
		if left_to_place > 0 and _reachable(spot[0], spot[1]):
			spawn_block_web(spot[0], spot[1])
			left_to_place -= 1
	for i in 3 + d * 2:
		var left := randf() < 0.5
		var y := Level.FLOOR_Y + randf_range(2.0, 2.6)
		var x := Level.wall_x(-1 if left else 1, y, 0.5)
		spawn_small_web(Vector3(x, y, randf_range(-56.0, maxf(day_limit() + 3.0, Level.GRATE_Z + 3.0))), randf_range(0.9, 1.4))
	spawn_small_web(Vector3(-2.6, Level.FLOOR_Y + 3.4, -36.0), 1.2)
	if d == Game.FINAL_DAY:
		# Гнездо за решёткой.
		for i in 12:
			var x := randf_range(Level.LEFT_X + 0.5, Level.RIGHT_X - 0.5)
			spawn_small_web(Vector3(x, Level.FLOOR_Y + randf_range(0.8, 2.8), randf_range(-368.0, -329.0)), randf_range(1.2, 2.0))


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
		var z := randf_range(maxf(day_limit() + 6.0, Level.GRATE_Z + 12.0), -60.0)
		# Не в камерах развилок — там стены другие.
		for b in Level.BRANCHES:
			if absf(z - float(b["z"])) < Level.JUNCTION_MAIN + 4.0:
				z += 12.0
		_add_spider(Level.wall_x(-1 if left else 1, Level.FLOOR_Y + 1.5, 0.02), Vector3.RIGHT if left else Vector3.LEFT, z, 5.0)


## Паук-«гонец» на стене основного тоннеля (бежит от «Другого» и пропадает).
func add_runner_spider(z: float, left: bool) -> Spider:
	return _add_spider(Level.wall_x(-1 if left else 1, Level.FLOOR_Y + 1.5, 0.02), Vector3.RIGHT if left else Vector3.LEFT, z, 2.0)


func _add_spider(wall_x: float, wall_normal: Vector3, z: float, range_z: float) -> Spider:
	var s := Spider.new()
	s.main = self
	s.player = player
	s.wall_x = wall_x
	s.normal = wall_normal
	s.home_z = z
	s.range_z = range_z
	s.floor_y = Level.FLOOR_Y
	add_child(s)
	return s


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


# --- Доступ, комнаты, угрозы -------------------------------------------------

func day_limit() -> float:
	return DAY_LIMIT_Z[clampi(Game.day, 0, DAY_LIMIT_Z.size() - 1)]


## Открыт ли сегодня этот участок.
func _reachable(tunnel: int, along: float) -> bool:
	if tunnel == -2:
		return true
	if tunnel == -1:
		return along > day_limit() + 1.0
	return Game.day >= BRANCH_OPEN_DAY[tunnel] and float(Level.BRANCHES[tunnel]["z"]) > day_limit()


## Ограждения на закрытых участках и схема на карте.
func _setup_access(d: int) -> void:
	var limit := day_limit()
	if limit > Level.GRATE_Z + 2.0:
		var f := Fence.new()
		f.position = Vector3(Level.TUN_CX, Level.FLOOR_Y, limit)
		add_child(f)
	var open: Array = []
	for i in Level.BRANCHES.size():
		if _reachable(i, 0.0):
			open.append(i)
		elif float(Level.BRANCHES[i]["z"]) > limit:
			var f := Fence.new()
			f.position = level.floor_point(i, Level.JUNCTION_BRANCH + 1.0)
			f.rotation.y = level.cross_yaw(i)
			add_child(f)
	var charger_spots: Array[Vector3] = []
	for i in chargers.size():
		if _reachable(CHARGER_SPOTS[i][0], CHARGER_SPOTS[i][2]):
			charger_spots.append(chargers[i].global_position)
	var rooms_open: Array = []
	for r in ROOM_SCHEDULE.get(d, []):
		rooms_open.append(r[0])
	hud.update_map(limit, open, rooms_open, charger_spots)


## Каждую смену открыты другие комнаты: в них останки и записки прежних обходчиков.
func _setup_rooms(d: int) -> void:
	for door in doors:
		door.set_open(false)
	var k := 0
	for entry in ROOM_SCHEDULE.get(d, []):
		var ri: int = entry[0]
		doors[ri].set_open(true)
		var room: Dictionary = level.rooms[ri]
		var c: Vector3 = room["center"]
		var b: Basis = room["basis"]
		var bones := Remains.new()
		bones.pose = "sitting" if k % 2 == 0 else "lying"
		bones.position = c + b * Vector3(0.6, 0, -1.0)
		bones.basis = b * Basis(Vector3.UP, PI * 0.5 if bones.pose == "sitting" else 0.3)
		add_child(bones)
		_spawn_note(entry[1], c + b * Vector3(-0.7, 0, 0.3))
		# Догорающий фонарь — единственный свет в комнате.
		var lamp := OmniLight3D.new()
		lamp.position = c + b * Vector3(-1.2, 0.3, -1.2)
		lamp.light_color = Color(1.0, 0.6, 0.3)
		lamp.omni_range = 3.5
		lamp.light_energy = 0.5
		lamp.add_to_group("fear_light")
		lamp.add_to_group("cull_light")
		lamp.add_to_group("day_objects")
		add_child(lamp)
		k += 1
	if d == Game.FINAL_DAY:
		var nest := Remains.new()
		nest.position = Vector3(Level.TUN_CX - 0.6, Level.FLOOR_Y, -341.0)
		nest.rotation.y = 0.7
		add_child(nest)
		_spawn_note("n9", Vector3(Level.TUN_CX + 0.4, Level.FLOOR_Y, -339.0))


## Находки: лежат с определённой смены и пропадают навсегда, когда их подобрали.
func _spawn_finds(d: int) -> void:
	var spots := {
		"pills1": _room_spot(0, Vector3(1.2, 0, -1.2)),
		"pills2": level.floor_point(0, float(Level.BRANCHES[0]["length"]) - 8.0, 1.3),
		"pills3": level.floor_point(2, float(Level.BRANCHES[2]["length"]) - 8.0, -1.3),
		"lens": level.floor_point(-1, -229.0, -1.35),
		"cell": level.floor_point(1, float(Level.BRANCHES[1]["length"]) - 7.0, -1.3),
		"duck": _room_spot(5, Vector3(1.1, 0, 0.9)),
	}
	for id in Achievements.FINDS:
		if Achievements.has_find(id) or d < int(Achievements.FINDS[id][0]):
			continue
		var f := Find.new()
		f.find_id = id
		if id == "sponjik":
			# Надпись мелом у самого пола, за генератором.
			f.transform = _mount(-2, 0, -47.6, Level.FLOOR_Y + 0.45)
		else:
			f.position = spots[id]
			f.rotation.y = randf() * TAU
		add_child(f)


func _room_spot(index: int, local: Vector3) -> Vector3:
	var room: Dictionary = level.rooms[index]
	return room["center"] + (room["basis"] as Basis) * local


func _spawn_note(id: String, pos: Vector3) -> void:
	var n := Note.new()
	n.note_id = id
	n.title = NOTE_TEXTS[id][0]
	n.text = NOTE_TEXTS[id][1]
	n.hud = hud
	n.position = pos
	add_child(n)


## С третьей ночи: оружейный ящик на столе, патроны в тоннелях, существа в темноте.
func _spawn_threats(d: int) -> void:
	if PISTOL_ROUNDS[d] > 0:
		var gun := Pickup.new()
		gun.kind = "pistol"
		gun.amount = PISTOL_ROUNDS[d]
		gun.position = Vector3(Level.SHAFT_X + 2.75, Level.ROOM_Y + 0.81, Level.SHAFT_Z - 1.8)
		gun.rotation.y = deg_to_rad(80.0)
		add_child(gun)
	for i in AMMO_BOXES_PER_DAY[d]:
		var box := Pickup.new()
		box.kind = "ammo"
		box.amount = 3
		box.position = _random_floor_spot(30.0)
		box.rotation.y = randf() * TAU
		add_child(box)
	for i in CREATURES_PER_DAY[d]:
		spawn_crawler(_random_floor_spot(60.0))


func spawn_crawler(pos: Vector3) -> Crawler:
	var c := Crawler.new()
	c.player = player
	c.level = level
	c.speed = 2.1 + (Game.day - 3) * 0.3
	c.hp = 2 if Game.day < 5 else 3
	c.position = pos + Vector3(0, 0.1, 0)
	add_child(c)
	return c


## Генератор: заглушен, в баке — сколько осталось. Канистры спрятаны в тоннелях.
func _setup_power(d: int) -> void:
	generator.reset(GEN_FUEL[d])
	for i in CANISTERS_PER_DAY[d]:
		var can := Pickup.new()
		can.kind = "fuel"
		can.position = _random_floor_spot(25.0)
		can.rotation.y = randf() * TAU
		add_child(can)


## Устройства для поручений смены, письмо дочери, засов решётки.
func _spawn_task_devices(d: int) -> void:
	pump = null
	var letter := Note.new()
	letter.note_id = "masha"
	letter.title = LETTER[0]
	letter.text = LETTER[1]
	letter.hud = hud
	letter.position = Vector3(Level.SHAFT_X - 3.1, Level.ROOM_Y + 0.745, Level.SHAFT_Z + 0.35)
	add_child(letter)
	if Game.has_open_task("sensor"):
		var sensor := TaskDevice.new()
		sensor.kind = "sensor"
		sensor.transform = level.wall_mount(-1, 1, Level.TUN_Z0 - Level.PICKET_STEP * 3.0 + 1.5, Level.FLOOR_Y + 1.5)
		add_child(sensor)
	if Game.has_open_task("cable"):
		var spot: Array = CABLE_SPOTS.pick_random()
		var cable := TaskDevice.new()
		cable.kind = "cable"
		cable.generator = generator
		cable.transform = level.wall_mount(-1, spot[0], spot[1], Level.FLOOR_Y + 1.7)
		add_child(cable)
	if Game.has_open_task("water"):
		var axis := Level.branch_dir(FLOOD_BRANCH)
		var right := Vector3(-axis.z, 0.0, axis.x)
		pump = TaskDevice.new()
		pump.kind = "pump"
		pump.position = level.floor_point(FLOOD_BRANCH, FLOOD_FROM - 2.0, 1.1)
		pump.rotation.y = atan2(-right.x, -right.z)
		add_child(pump)
		var flood_len: float = float(Level.BRANCHES[FLOOD_BRANCH]["length"]) - FLOOD_FROM
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.08, 0.1, 0.07, 0.82)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.05
		mat.metallic = 0.4
		var water := Geo.box(self, level.floor_point(FLOOD_BRANCH, FLOOD_FROM + flood_len / 2.0) + Vector3(0, 0.35, 0),
			Vector3(3.6, 0.02, flood_len), mat, false, Basis(Vector3.UP, atan2(axis.x, axis.z)))
		water.add_to_group("day_objects")
		pump.water = water
	if Game.has_open_task("token"):
		var room: Dictionary = level.rooms[5]
		var token := Pickup.new()
		token.kind = "token"
		token.position = room["center"] + (room["basis"] as Basis) * Vector3(0.2, 0.0, -0.3)
		add_child(token)
	if d == Game.FINAL_DAY:
		var lock := GrateLock.new()
		lock.main = self
		lock.transform = level.wall_mount(-1, 1, Level.GRATE_Z - 0.5, Level.FLOOR_Y + 1.1)
		add_child(lock)


## Вода в затопленной штольне замедляет и хлюпает.
func _update_water() -> void:
	var slow := 1.0
	if pump != null and is_instance_valid(pump) and pump.water_level > 0.05:
		var o := Level.branch_origin(FLOOD_BRANCH)
		var axis := Level.branch_dir(FLOOD_BRANCH)
		var rel := player.global_position - o
		var along := rel.dot(axis)
		var lateral := absf(rel.dot(Vector3(-axis.z, 0.0, axis.x)))
		if along > FLOOD_FROM and lateral < 2.2 and player.global_position.y < Level.FLOOR_Y + 2.0:
			slow = lerpf(1.0, 0.5, pump.water_level)
			Game.say_once("water", "Вода по колено. Ледяная. И каждый шаг — на весь тоннель.", Game.THOUGHT, 3.5)
	player.speed_mult = slow


## Случайная точка в открытом сегодня проходе, не ближе min_depth метров от станции.
func _random_floor_spot(min_depth: float) -> Vector3:
	for attempt in 20:
		var t := randi_range(-1, Level.BRANCHES.size() - 1)
		var along: float
		if t == -1:
			var deep := maxf(day_limit() + 3.0, Level.GRATE_Z + 3.0)
			var near := Level.TUN_Z0 - min_depth
			if deep >= near:
				continue
			along = randf_range(deep, near)
		else:
			along = randf_range(Level.JUNCTION_BRANCH + 2.0, float(Level.BRANCHES[t]["length"]) - 1.0)
		if not _reachable(t, along):
			continue
		return level.floor_point(t, along, randf_range(-1.2, 1.2))
	return Vector3(Level.TUN_CX + 1.0, Level.FLOOR_Y, -95.0)


## Визуальный стиль: чуть пониженное разрешение, жёсткий контраст, плёночное зерно (под интерфейсом).
## Яркость и зерно берутся из настроек. Общий для игры и главного меню.
static func add_postfx(parent: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	parent.add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = POSTFX_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	layer.add_child(rect)
	Settings.bind_postfx(rect, mat)


const POSTFX_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float pixel_size = 2.0;
uniform float grain = 0.035;
uniform float aberration = 0.35;
uniform float brightness = 1.0;
void fragment() {
	// Лёгкое понижение разрешения: соседние пиксели усредняются, без узора-сетки.
	vec2 px = SCREEN_PIXEL_SIZE * pixel_size;
	vec2 uv = (floor(SCREEN_UV / px) + 0.5) * px;
	vec2 off = vec2(aberration * px.x, 0.0) * (length(SCREEN_UV - 0.5) * 2.0);
	vec3 c = vec3(texture(screen_tex, uv + off).r, texture(screen_tex, uv).g, texture(screen_tex, uv - off).b) * brightness;
	// Жёсткий контраст, холодно-зелёные тени, тёплые светлые места.
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 0.78);
	c = pow(max(c, vec3(0.0)), vec3(1.15)) * 1.12;
	c = mix(c * vec3(0.86, 0.96, 0.92), c * vec3(1.07, 1.0, 0.9), smoothstep(0.08, 0.6, l));
	// Мягкое плёночное зерно на каждом экранном пикселе — меняется каждый кадр, сетки не образует.
	float n = fract(sin(dot(FRAGCOORD.xy + fract(TIME * 7.13) * 431.0, vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain * (1.0 - l * 0.6);
	// Виньетка.
	// Границы smoothstep обязаны идти по возрастанию: перевёрнутые дают в WebGL ноль — чёрный экран.
	float v = 1.0 - smoothstep(0.35, 0.95, length(SCREEN_UV - 0.5));
	COLOR = vec4(clamp(c * mix(0.75, 1.0, v), 0.0, 1.0), 1.0);
}
"""


## Прогон для CI (godot --headless -- --smoke): все дни, предметы, лестница, события и финал
## должны отработать без ошибок скрипта.
func _smoke_test() -> void:
	state = "playing"
	hud.set_ingame(true)
	for d in range(1, Game.FINAL_DAY + 1):
		start_day(d)
		await get_tree().create_timer(5.5).timeout
		hatch.hold_interact(player, 2.0)
		radio.interact(player)
		player.hold("radio")
		player.use_item()
		hatch.hold_interact(player, 2.0)
		hatch.interact(player)
		await get_tree().create_timer(0.5).timeout
		player.stop_climb(Vector3(Level.TUN_CX, Level.FLOOR_Y + 0.1, -140.0))
		for ev in ["footsteps", "sighting", "behind", "lamps", "whisper", "regrow", "interfere", "crawler", "hunt"]:
			director._run(ev)
		# Генератор: запуск (со второй попытки, если чихнул), заправка, остановка.
		generator.hold_interact(player, 2.0)
		generator.hold_interact(player, 2.0)
		player.canisters = 1
		generator.hold_interact(player, 2.5)
		# Шкаф: спрятаться, задержать дыхание, выйти.
		var cab: Hideout = get_tree().get_nodes_in_group("hideouts")[1]
		cab.interact(player)
		Input.action_press("jump")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release("jump")
		cab.interact(player)
		Input.action_press("crouch")
		await get_tree().physics_frame
		Input.action_release("crouch")
		Game.make_noise(player.global_position, 50.0)
		for n in get_tree().get_nodes_in_group("day_objects"):
			var dev := n as TaskDevice
			if dev:
				dev.hold_interact(player, 1.0)
				generator.stall()
				dev.hold_interact(player, 5.0)
		await get_tree().create_timer(0.3).timeout
		generator.hold_interact(player, 2.0)
		chargers[0].unplug()
		chargers[0].interact(player)
		doors[0].set_open(true)
		doors[0].slam()
		doors[0].interact(player)
		player.hold("radio")
		dispatcher.radio_pressed(d)
		player.batteries = 1
		player.hold("battery")
		player.use_item()
		player.filters = 3
		player.hold("filter")
		for v in vents:
			v.hold_interact(player, 2.5)
		for n in get_tree().get_nodes_in_group("webs"):
			var web := n as Web
			if web:
				web.burn(2.0)
		for c in crates:
			c.interact(player)
		player.cycle(1)
		player.cycle(-1)
		player.hold("")
		player.toggle_light()
		player.toggle_light()
		Input.action_press("jump")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release("jump")
		dispatcher.random_call(d)
		dispatcher.speak(dispatcher.closing_ids(d))
		for n in get_tree().get_nodes_in_group("day_objects"):
			var note := n as Note
			if note:
				note.interact(player)
				hud.close_note()
			var pickup := n as Pickup
			if pickup:
				pickup.interact(player)
		for i in 30:
			_update_water()
		player.hold("map")
		await get_tree().process_frame
		player.hold("pistol")
		player.use_item()
		for n in get_tree().get_nodes_in_group("creatures"):
			var cr := n as Crawler
			if cr:
				cr.hit()
				cr.hit()
				cr.hit()
		player.take_damage(10.0)
		doors[0].interact(player)
		player.global_position = level.rooms[0]["center"] + Vector3(0, 0.1, 0)
		await get_tree().physics_frame
		cart.interact(player)
		journal.interact(player)
		await get_tree().create_timer(1.5).timeout
		stalker.hide_now()
	player.global_position = Vector3(Level.TUN_CX, Level.FLOOR_Y + 0.1, Level.GRATE_Z + 2.0)
	await get_tree().create_timer(1.0).timeout
	player.global_position = Vector3(Level.TUN_CX, Level.FLOOR_Y + 0.1, Level.GRATE_Z - 28.0)
	await get_tree().create_timer(1.5).timeout
	# Концовка 1: доложил → у станции съеден → газета → скример.
	dispatcher.radio_pressed(5)
	_reported = true
	player.global_position = Vector3(Level.TUN_CX, Level.FLOOR_Y + 0.1, -45.0)
	await get_tree().create_timer(6.0).timeout
	hud.close_newspaper()
	await get_tree().create_timer(7.0).timeout
	var ok := Game.ended
	# Концовка 3: все записки, засов решётки изнутри.
	start_day(5)
	await get_tree().create_timer(5.5).timeout
	player.global_position = Vector3(Level.TUN_CX, Level.FLOOR_Y + 0.1, Level.GRATE_Z - 28.0)
	await get_tree().create_timer(1.0).timeout
	for i in 9:
		Game.notes_read["n%d" % (i + 1)] = true
	player.global_position = Vector3(Level.TUN_CX, Level.FLOOR_Y + 0.1, Level.GRATE_Z - 2.0)
	await get_tree().physics_frame
	for n in get_tree().get_nodes_in_group("day_objects"):
		var lock := n as GrateLock
		if lock:
			lock.get_prompt(player)
			lock.interact(player)
	await get_tree().create_timer(14.0).timeout
	hud.close_newspaper()
	await get_tree().create_timer(1.5).timeout
	ok = ok and Game.ended
	# Концовка 2: не доложил, поднялся наверх.
	start_day(5)
	await get_tree().create_timer(5.5).timeout
	player.global_position = Vector3(Level.TUN_CX, Level.FLOOR_Y + 0.1, Level.GRATE_Z - 28.0)
	await get_tree().create_timer(1.0).timeout
	player.global_position = SPAWN
	await get_tree().create_timer(10.0).timeout
	hud.close_newspaper()
	await get_tree().create_timer(6.0).timeout
	Game.ended = ok and Game.ended
	print("SMOKE ", "OK" if Game.ended else "FAIL: финал не сработал")
	get_tree().quit(0 if Game.ended else 1)
