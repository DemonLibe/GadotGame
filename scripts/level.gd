class_name Level
extends Node3D
## Статическая геометрия: будка на поверхности, узкий наклонный спуск,
## станция на одну вагонетку и длинный тоннель с решёткой в конце.

const FLOOR_Y := -15.0       # уровень пола станции и тоннеля
const TUN_CX := 1.2          # ось тоннеля (по ней идут рельсы)
const TUN_HW := 1.7          # половина ширины тоннеля
const TUN_H := 3.2           # высота тоннеля
const LEFT_X := -0.5         # TUN_CX - TUN_HW
const RIGHT_X := 2.9         # TUN_CX + TUN_HW
const TUN_Z0 := -50.0        # начало тоннеля (стена станции)
const TUN_Z1 := -265.0       # тупик
const GRATE_Z := -232.0      # решётка

var lamps: Array[Dictionary] = []
var tunnel_lights_off := false
var blackout := false
var grate: Node3D

var m_wall: Material
var m_floor: Material
var m_dark: Material
var m_metal: Material
var m_rust: Material
var m_wood: Material
var m_rail: Material
var _time := 0.0


func build() -> void:
	m_wall = ProcTex.concrete(Color(0.45, 0.44, 0.41), 0.35)
	m_floor = ProcTex.concrete(Color(0.3, 0.29, 0.27), 0.5)
	m_dark = ProcTex.concrete(Color(0.22, 0.22, 0.22), 0.35)
	m_metal = ProcTex.flat(Color(0.35, 0.36, 0.38), 0.45, 0.8)
	m_rust = ProcTex.flat(Color(0.35, 0.2, 0.12), 0.85, 0.4)
	m_wood = ProcTex.flat(Color(0.3, 0.22, 0.14), 0.9)
	m_rail = ProcTex.flat(Color(0.45, 0.42, 0.4), 0.35, 0.9)
	_build_surface()
	_build_descent()
	_build_station()
	_build_tunnel()
	_build_rails()
	_build_grate()
	_build_nest_decor()


func _process(delta: float) -> void:
	_time += delta
	for l in lamps:
		var light: OmniLight3D = l["light"]
		var mat: StandardMaterial3D = l["mat"]
		var mode: String = l["mode"]
		var on := mode != "broken" and not blackout and not (l["tunnel"] and tunnel_lights_off)
		var f := 1.0 if on else 0.0
		if on and mode == "flicker":
			var phase: float = l["t"]
			if sin(_time * 13.0 + phase) + sin(_time * 7.3 + phase * 2.0) < -1.1:
				f = 0.05
		light.light_energy = float(l["energy"]) * f
		mat.emission_energy_multiplier = 3.0 * f


## Есть ли рядом горящая лампа (для счётчика страха).
func is_lit_near(pos: Vector3) -> bool:
	for l in lamps:
		var light: OmniLight3D = l["light"]
		if light.light_energy < 0.2:
			continue
		if light.global_position.distance_to(pos) < light.omni_range * 0.55:
			return true
	return false


func set_grate_open(open: bool) -> void:
	grate.rotation.y = deg_to_rad(85.0) if open else 0.0


# --- Поверхность -------------------------------------------------------------

func _build_surface() -> void:
	var h := 3.0
	Geo.box(self, Vector3(0, -0.15, 3), Vector3(6.6, 0.3, 6.6), m_floor)
	Geo.box(self, Vector3(0, h + 0.15, 3), Vector3(6.6, 0.3, 6.6), m_wall)
	Geo.box(self, Vector3(0, h / 2, 6.15), Vector3(6.6, h, 0.3), m_wall)
	Geo.box(self, Vector3(-3.15, h / 2, 3), Vector3(0.3, h, 6.6), m_wall)
	Geo.box(self, Vector3(3.15, h / 2, 3), Vector3(0.3, h, 6.6), m_wall)
	# Передняя стена с проёмом к спуску (x от -0.8 до 0.8, высота 2.6).
	Geo.box(self, Vector3(-1.95, h / 2, -0.15), Vector3(2.3, h, 0.3), m_wall)
	Geo.box(self, Vector3(1.95, h / 2, -0.15), Vector3(2.3, h, 0.3), m_wall)
	Geo.box(self, Vector3(0, (2.6 + h) / 2, -0.15), Vector3(1.6, h - 2.6, 0.3), m_wall)
	_add_lamp(Vector3(0, h - 0.1, 3), Color(1.0, 0.85, 0.6), 1.4, 9.0, "ok", false)
	# Дверь домой (декор) и надписи.
	Geo.box(self, Vector3(-1.5, 1.05, 5.98), Vector3(1.0, 2.1, 0.06), m_wood, false)
	Geo.label(self, Vector3(-1.5, 2.35, 5.95), "ВЫХОД", 180, 40, Color(0.85, 0.25, 0.2))
	Geo.label(self, Vector3(0, 2.8, 0.02), "СПУСК К СТАНЦИИ «ТИХАЯ»", 0, 30, Color(0.9, 0.85, 0.7))
	# Шкафчик и вешалка.
	Geo.box(self, Vector3(-2.7, 0.95, 2.0), Vector3(0.5, 1.9, 0.6), m_metal)
	Geo.box(self, Vector3(-2.7, 0.95, 2.65), Vector3(0.5, 1.9, 0.6), m_metal)


# --- Спуск -------------------------------------------------------------------

func _build_descent() -> void:
	var top := Vector3(0, 0, 0)
	var bottom := Vector3(0, FLOOR_Y, -30)
	var d := bottom - top
	var length := d.length()
	var angle := atan2(-d.y, -d.z)
	var basis := Basis(Vector3.RIGHT, -angle)
	var mid := (top + bottom) / 2.0
	var up := basis.y
	# Наклонный пол и потолок.
	Geo.box(self, mid - up * 0.15, Vector3(1.6, 0.3, length), m_floor, true, basis)
	Geo.box(self, mid + Vector3(0, 2.6, 0) + up * 0.15, Vector3(1.6, 0.3, length), m_dark, true, basis)
	# Вертикальные стены отрезками — узкий коридор шириной 1.6 м.
	var n := 10
	for i in n:
		var a := top + d * (float(i) / n)
		var b := top + d * (float(i + 1) / n)
		var y_lo := minf(a.y, b.y) - 0.4
		var y_hi := maxf(a.y, b.y) + 2.9
		var cz := (a.z + b.z) / 2.0
		var size := Vector3(0.3, y_hi - y_lo, absf(b.z - a.z) + 0.05)
		Geo.box(self, Vector3(-0.95, (y_lo + y_hi) / 2.0, cz), size, m_wall)
		Geo.box(self, Vector3(0.95, (y_lo + y_hi) / 2.0, cz), size, m_wall)
	# Поручень.
	Geo.cylinder(self, mid + Vector3(0.72, 0.95, 0), 0.03, length, m_rust, basis * Basis(Vector3.RIGHT, PI / 2))
	# Тусклые лампы, одна мигает.
	for f in [0.2, 0.5, 0.8]:
		var p := top + d * float(f) + Vector3(0, 2.45, 0)
		_add_lamp(p, Color(1.0, 0.8, 0.5), 0.7, 6.0, "flicker" if f == 0.5 else "ok", false)
	Geo.label(self, Vector3(0.79, 0.9, -1.5), "ОСТОРОЖНО!\nКРУТОЙ СПУСК", -90, 28, Color(0.9, 0.75, 0.2))


# --- Станция -----------------------------------------------------------------

func _build_station() -> void:
	var z0 := -30.0
	var z1 := -50.0
	var cz := -40.0
	var h := 4.0
	var y := FLOOR_Y
	Geo.box(self, Vector3(0, y - 0.15, cz), Vector3(6.6, 0.3, 20.0), m_floor)
	Geo.box(self, Vector3(0, y + h + 0.15, cz), Vector3(6.6, 0.3, 20.0), m_dark)
	Geo.box(self, Vector3(-3.15, y + h / 2, cz), Vector3(0.3, h, 20.6), m_wall)
	Geo.box(self, Vector3(3.15, y + h / 2, cz), Vector3(0.3, h, 20.6), m_wall)
	# Ближняя стена с проёмом от спуска.
	Geo.box(self, Vector3(-1.95, y + h / 2, z0 + 0.15), Vector3(2.3, h, 0.3), m_wall)
	Geo.box(self, Vector3(1.95, y + h / 2, z0 + 0.15), Vector3(2.3, h, 0.3), m_wall)
	Geo.box(self, Vector3(0, y + (2.6 + h) / 2, z0 + 0.15), Vector3(1.6, h - 2.6, 0.3), m_wall)
	# Дальняя стена с порталом тоннеля.
	Geo.box(self, Vector3((-3.3 + LEFT_X) / 2, y + h / 2, z1 - 0.15), Vector3(LEFT_X + 3.3, h, 0.3), m_wall)
	Geo.box(self, Vector3((RIGHT_X + 3.3) / 2, y + h / 2, z1 - 0.15), Vector3(3.3 - RIGHT_X, h, 0.3), m_wall)
	Geo.box(self, Vector3(TUN_CX, y + (TUN_H + h) / 2, z1 - 0.15), Vector3(TUN_HW * 2, h - TUN_H, 0.3), m_wall)
	# Свет: холодные лампы, одна мигает.
	_add_lamp(Vector3(0, y + h - 0.1, -35), Color(0.8, 0.9, 1.0), 1.5, 10.0, "ok", false)
	_add_lamp(Vector3(0, y + h - 0.1, -45), Color(0.8, 0.9, 1.0), 1.5, 10.0, "flicker", false)
	# Край платформы, тупиковый упор, скамья, шкафчики.
	Geo.box(self, Vector3(0.3, y + 0.005, cz), Vector3(0.15, 0.01, 19.6), ProcTex.flat(Color(0.7, 0.6, 0.1)), false)
	Geo.box(self, Vector3(TUN_CX + 0.3, y + 0.3, -30.5), Vector3(1.3, 0.6, 0.3), m_rust)
	Geo.box(self, Vector3(-2.6, y + 0.225, -41), Vector3(0.5, 0.45, 1.6), m_wood)
	Geo.box(self, Vector3(-2.65, y + 0.95, -48.6), Vector3(0.5, 1.9, 0.5), m_metal)
	Geo.box(self, Vector3(-2.65, y + 0.95, -48.0), Vector3(0.5, 1.9, 0.5), m_metal)
	# Таблички.
	Geo.label(self, Vector3(-2.98, y + 2.9, -40), "СТАНЦИЯ «ТИХАЯ»", 90, 64, Color(0.85, 0.82, 0.7), true)
	Geo.box(self, Vector3(-2.99, y + 1.6, -36.5), Vector3(0.02, 0.9, 0.8), ProcTex.flat(Color(0.75, 0.72, 0.62)), false)
	Geo.label(self, Vector3(-2.975, y + 1.6, -36.5),
		"ПРАВИЛА ОБХОДЧИКА\n\n1. Не выключай фонарь в тоннеле.\n2. Паутину — сжигать.\n3. Фильтры менять вовремя.\n4. О посторонних звуках\n    не докладывать.",
		90, 24, Color(0.1, 0.1, 0.1), true, 0.0022)


# --- Тоннель -----------------------------------------------------------------

func _build_tunnel() -> void:
	var length := TUN_Z0 - TUN_Z1
	var cz := (TUN_Z0 + TUN_Z1) / 2.0
	var w := TUN_HW * 2.0
	Geo.box(self, Vector3(TUN_CX, FLOOR_Y - 0.15, cz), Vector3(w + 0.6, 0.3, length), m_floor)
	Geo.box(self, Vector3(TUN_CX, FLOOR_Y + TUN_H + 0.15, cz), Vector3(w + 0.6, 0.3, length), m_dark)
	Geo.box(self, Vector3(LEFT_X - 0.15, FLOOR_Y + TUN_H / 2, cz), Vector3(0.3, TUN_H, length), m_wall)
	Geo.box(self, Vector3(RIGHT_X + 0.15, FLOOR_Y + TUN_H / 2, cz), Vector3(0.3, TUN_H, length), m_wall)
	Geo.box(self, Vector3(TUN_CX, FLOOR_Y + TUN_H / 2, TUN_Z1 - 0.15), Vector3(w + 0.6, TUN_H, 0.3), m_wall)
	# Рёбра крепи каждые 7 м — чтобы глаз чувствовал движение в темноте.
	var z := TUN_Z0 - 4.0
	while z > TUN_Z1 + 1.0:
		Geo.box(self, Vector3(LEFT_X + 0.1, FLOOR_Y + TUN_H / 2, z), Vector3(0.2, TUN_H, 0.45), m_dark, false)
		Geo.box(self, Vector3(RIGHT_X - 0.1, FLOOR_Y + TUN_H / 2, z), Vector3(0.2, TUN_H, 0.45), m_dark, false)
		Geo.box(self, Vector3(TUN_CX, FLOOR_Y + TUN_H - 0.1, z), Vector3(w, 0.2, 0.45), m_dark, false)
		z -= 7.0
	# Трубы и кабель вдоль стен.
	var along := Basis(Vector3.RIGHT, PI / 2)
	Geo.cylinder(self, Vector3(LEFT_X + 0.18, FLOOR_Y + 2.5, cz), 0.09, length, m_rust, along)
	Geo.cylinder(self, Vector3(LEFT_X + 0.14, FLOOR_Y + 2.2, cz), 0.06, length, m_metal, along)
	Geo.cylinder(self, Vector3(RIGHT_X - 0.06, FLOOR_Y + 2.7, cz), 0.025, length, ProcTex.flat(Color(0.05, 0.05, 0.05)), along)
	# Лампы каждые 14 м: часть разбита, часть мигает.
	var i := 0
	z = TUN_Z0 - 6.0
	while z > GRATE_Z + 2.0:
		var mode := "ok"
		if i % 4 == 3:
			mode = "broken"
		elif i % 5 == 2:
			mode = "flicker"
		_add_lamp(Vector3(TUN_CX, FLOOR_Y + TUN_H - 0.2, z), Color(1.0, 0.72, 0.42), 0.9, 7.0, mode, true)
		z -= 14.0
		i += 1
	# Километровые отметки.
	for k in range(1, 4):
		var mz := TUN_Z0 - 50.0 * k
		Geo.label(self, Vector3(RIGHT_X - 0.02, FLOOR_Y + 1.8, mz), "ПК %d" % k, -90, 48, Color(0.95, 0.95, 0.9), true)


func _build_rails() -> void:
	var z0 := -29.0
	var z1 := GRATE_Z - 30.0
	var length := z0 - z1
	var cz := (z0 + z1) / 2.0
	for off in [-0.55, 0.55]:
		Geo.box(self, Vector3(TUN_CX + float(off), FLOOR_Y + 0.05, cz), Vector3(0.07, 0.1, length), m_rail, false)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sleeper := BoxMesh.new()
	sleeper.size = Vector3(1.6, 0.06, 0.22)
	mm.mesh = sleeper
	var count := int(length / 0.9)
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(TUN_CX, FLOOR_Y, z0 - i * 0.9)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m_wood
	add_child(mmi)


func _build_grate() -> void:
	# Шарнир у левой стены — так решётку можно «открыть».
	grate = Node3D.new()
	grate.position = Vector3(LEFT_X, FLOOR_Y, GRATE_Z)
	add_child(grate)
	var w := TUN_HW * 2.0
	var x := 0.1
	while x < w:
		Geo.cylinder(grate, Vector3(x, TUN_H / 2, 0), 0.025, TUN_H, m_rust)
		x += 0.18
	for y in [0.3, 1.5, 2.9]:
		Geo.box(grate, Vector3(w / 2, float(y), 0), Vector3(w, 0.06, 0.06), m_rust, false)
	Geo.box(grate, Vector3(w - 0.35, 1.1, 0.06), Vector3(0.12, 0.16, 0.06), m_metal, false)
	var body := StaticBody3D.new()
	grate.add_child(body)
	Geo.collider_box(body, Vector3(w, TUN_H, 0.15), Vector3(w / 2, TUN_H / 2, 0))


## За решёткой — каски прежних обходчиков. Видны сквозь прутья уже на 2-й день.
func _build_nest_decor() -> void:
	var yellow := ProcTex.flat(Color(0.75, 0.6, 0.1), 0.5)
	var spots := [Vector3(0.2, 0, -237), Vector3(2.3, 0, -239.5), Vector3(0.9, 0, -243), Vector3(1.8, 0, -247),
		Vector3(0.1, 0, -251), Vector3(2.5, 0, -254), Vector3(1.3, 0, -258)]
	for p in spots:
		var pos: Vector3 = p
		var helmet := Geo.sphere(self, Vector3(pos.x, FLOOR_Y, pos.z), 0.16, yellow)
		(helmet.mesh as SphereMesh).is_hemisphere = true
		helmet.rotation = Vector3(randf_range(-0.6, 0.6), randf() * TAU, randf_range(-0.6, 0.6))
	# Старый фонарь на полу.
	Geo.box(self, Vector3(1.6, FLOOR_Y + 0.1, -249), Vector3(0.15, 0.2, 0.25), m_metal, false)


func _add_lamp(pos: Vector3, color: Color, energy: float, light_range: float, mode: String, tunnel: bool) -> void:
	Geo.box(self, pos + Vector3(0, 0.06, 0), Vector3(0.3, 0.08, 0.3), m_metal, false)
	var bulb_mat := ProcTex.emissive(color, 3.0)
	Geo.sphere(self, pos - Vector3(0, 0.05, 0), 0.07, bulb_mat)
	var light := OmniLight3D.new()
	light.position = pos - Vector3(0, 0.25, 0)
	light.light_color = color
	light.omni_range = light_range
	light.light_energy = energy
	light.omni_attenuation = 1.5
	add_child(light)
	if mode == "broken":
		bulb_mat.emission_enabled = false
		bulb_mat.albedo_color = Color(0.15, 0.15, 0.15)
	lamps.append({"light": light, "mat": bulb_mat, "energy": energy, "mode": mode, "tunnel": tunnel, "t": randf() * 10.0})
