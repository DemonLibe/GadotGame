extends Node3D
## Отдельная сцена главного меню: кусок тоннеля с мигающими лампами за меню.
## Игра (main.tscn) загружается только после выбора смены.

const GAME_SCENE := "res://scenes/main.tscn"
const LENGTH := 40.0
const TUBE_R := 2.1
const TUBE_CY := 1.2

var menu: Menu
var _camera: Camera3D
var _lamps: Array[Dictionary] = []
var _figure: Node3D
var _figure_t := 0.0
var _t := 0.0


func _ready() -> void:
	randomize()
	get_tree().paused = false
	_build_backdrop()
	if not Main.debug_flag("nofx"):
		Main.add_postfx(self)

	add_child(Ambience.new())  # гул, сквозняк, тёмный пэд и редкий далёкий стон

	menu = Menu.new()
	add_child(menu)
	menu.new_game.connect(_on_new_game)
	menu.continue_game.connect(func(): _start(Game.load_day()))
	menu.quit.connect(func(): get_tree().quit())
	Settings.changed.connect(_apply_settings)
	_apply_settings()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.show_main(Game.load_day())
	if OS.get_cmdline_user_args().has("--smoke"):
		_smoke_test()


func _on_new_game() -> void:
	Game.save_day(1)
	_start(1)


func _start(d: int) -> void:
	Game.pending_day = d
	menu.show_loading()
	# Захват мыши — сразу по нажатию: браузер разрешает его только в ответ на действие игрока.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Два кадра, чтобы надпись «Спуск…» успела показаться, пока строится уровень.
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(GAME_SCENE)


func _apply_settings() -> void:
	_camera.fov = float(Settings.get_value("fov"))


func _process(delta: float) -> void:
	_t += delta
	# Камера чуть покачивается, будто кто-то стоит и дышит.
	_camera.position = Vector3(sin(_t * 0.31) * 0.05, 1.55 + sin(_t * 0.53) * 0.025, 1.5)
	_camera.rotation = Vector3(-0.03 + sin(_t * 0.23) * 0.012, sin(_t * 0.17) * 0.025, 0.0)
	for l in _lamps:
		_update_lamp(l, delta)
	# Иногда на краю света второй лампы кто-то стоит — на долю секунды.
	_figure_t -= delta
	if _figure_t <= 0.0:
		_figure.visible = not _figure.visible
		_figure_t = randf_range(0.15, 0.4) if _figure.visible else randf_range(12.0, 25.0)


func _update_lamp(l: Dictionary, delta: float) -> void:
	var light: OmniLight3D = l["light"]
	var mat: StandardMaterial3D = l["mat"]
	if not l["flicker"]:
		return
	l["t"] = float(l["t"]) - delta
	if float(l["t"]) <= 0.0:
		l["on"] = not l["on"] if randf() < 0.7 else true
		l["t"] = randf_range(0.03, 0.15) if randf() < 0.8 else randf_range(0.8, 3.0)
	var on: bool = l["on"]
	light.light_energy = float(l["energy"]) if on else 0.05
	mat.emission_energy_multiplier = 3.0 if on else 0.1


# --- Декорация ---------------------------------------------------------------

func _build_backdrop() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.35)
	env.ambient_light_energy = 0.05
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = not Main.debug_flag("noglow")
	env.fog_enabled = true
	env.fog_light_color = Color(0.015, 0.015, 0.02)
	env.fog_density = 0.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	_camera = Camera3D.new()
	add_child(_camera)
	_camera.current = true

	var tube := MeshInstance3D.new()
	tube.mesh = Geo.tube_mesh(TUBE_R, 0.0, -LENGTH, 32, -0.6, TUBE_R * TAU / 8.0, 1.0)
	tube.material_override = ProcTex.tubbing()
	tube.position = Vector3(0, TUBE_CY, 0)
	add_child(tube)
	var chord := 2.0 * sqrt(TUBE_R * TUBE_R - TUBE_CY * TUBE_CY)
	var floor_mat := ProcTex.concrete(Color(0.3, 0.29, 0.27), 0.5)
	Geo.box(self, Vector3(0, -0.15, -LENGTH / 2), Vector3(chord, 0.3, LENGTH), floor_mat, false)

	# Рельсы на шпалах.
	var metal := ProcTex.flat(Color(0.35, 0.36, 0.38), 0.45, 0.8)
	var wood := ProcTex.flat(Color(0.16, 0.12, 0.09), 0.95)
	for x in [-0.76, 0.76]:
		Geo.box(self, Vector3(x, 0.09, -LENGTH / 2), Vector3(0.07, 0.12, LENGTH), metal, false)
	var z := 0.4
	while z < LENGTH:
		Geo.box(self, Vector3(0, 0.02, -z), Vector3(2.0, 0.06, 0.22), wood, false)
		z += 0.8

	# Кабели справа и водопровод слева.
	var along := Basis(Vector3.RIGHT, PI / 2)
	var cable := ProcTex.flat(Color(0.05, 0.05, 0.05), 0.6)
	for k in 4:
		var cy := 1.75 + k * 0.17
		Geo.cylinder(self, Vector3(_tube_half(cy) - 0.12, cy, -LENGTH / 2), 0.028, LENGTH, cable, along)
	Geo.cylinder(self, Vector3(-(_tube_half(2.2) - 0.16), 2.2, -LENGTH / 2), 0.09, LENGTH,
		ProcTex.flat(Color(0.35, 0.2, 0.12), 0.85, 0.4), along)

	_add_lamp(Vector3(-1.5, 2.3, -5.0), 1.0, false)
	_add_lamp(Vector3(1.5, 2.3, -15.0), 0.9, true)
	_add_lamp(Vector3(-1.5, 2.3, -27.0), 0.7, false)

	# Силуэт у второй лампы.
	_figure = Node3D.new()
	_figure.position = Vector3(0.4, 0, -17.5)
	add_child(_figure)
	var black := ProcTex.flat(Color(0.01, 0.01, 0.01), 1.0)
	Geo.capsule(_figure, Vector3(0, 0.95, 0), 0.24, 1.6, black)
	Geo.sphere(_figure, Vector3(0, 1.88, 0), 0.15, black)
	_figure.visible = false
	_figure_t = randf_range(6.0, 12.0)


func _add_lamp(pos: Vector3, energy: float, flicker: bool) -> void:
	var inward := Vector3(-signf(pos.x), 0, 0)
	var basis := Basis(Vector3.UP, atan2(inward.x, inward.z))
	Geo.box(self, pos - inward * 0.05, Vector3(0.25, 0.3, 0.06), ProcTex.flat(Color(0.35, 0.36, 0.38), 0.45, 0.8), false, basis)
	var color := Color(1.0, 0.74, 0.45)
	var mat := ProcTex.emissive(color, 3.0)
	Geo.sphere(self, pos + inward * 0.04, 0.07, mat)
	var light := OmniLight3D.new()
	light.position = pos + inward * 0.3 - Vector3(0, 0.2, 0)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 9.0
	light.omni_attenuation = 1.5
	add_child(light)
	_lamps.append({"light": light, "mat": mat, "energy": energy, "flicker": flicker, "on": true, "t": 1.0})


## Половина ширины трубы на высоте y над полом.
static func _tube_half(y: float) -> float:
	var dy := y - TUBE_CY
	return sqrt(maxf(TUBE_R * TUBE_R - dy * dy, 0.0))


# --- Проверка без экрана -----------------------------------------------------

func _smoke_test() -> void:
	Settings.persist = false
	menu.open_settings()
	await get_tree().process_frame
	var fov := float(Settings.get_value("fov"))
	Settings.set_value("fov", fov + 5.0)
	var ok := is_equal_approx(_camera.fov, fov + 5.0)
	Settings.reset()
	await get_tree().process_frame
	ok = ok and is_equal_approx(_camera.fov, float(Settings.DEFAULTS["fov"]))
	print("SMOKE menu: настройки ", "OK" if ok else "FAIL")
	if not ok:
		get_tree().quit(1)
		return
	# Экран достижений открывается и закрывается.
	menu.hide_all()
	menu.show_main(1)
	menu.open_achievements()
	await get_tree().process_frame
	await get_tree().process_frame
	ok = menu.is_achievements_open()
	menu._close_achievements()
	ok = ok and not menu.is_achievements_open()
	print("SMOKE menu: достижения ", "OK" if ok else "FAIL")
	if not ok:
		get_tree().quit(1)
		return
	menu.hide_all()
	_start(1)
