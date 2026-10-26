class_name Level
extends Node3D
## Статическая геометрия «Тихой»:
## комната с люком наверху → шахта с лестницей (100 м) → станция на одну вагонетку →
## круглый тоннель из чугунных тюбингов с тремя развилками в служебные штольни → решётка.

const FLOOR_Y := -15.0       # пол станции и тоннеля
const TUN_CX := 1.2          # ось основного тоннеля (по ней идут рельсы)
const TUN_HW := 1.7          # полуширина прохода (невидимые стены)
const TUN_H := 3.2
const LEFT_X := -0.5         # TUN_CX - TUN_HW
const RIGHT_X := 2.9         # TUN_CX + TUN_HW
const TUN_Z0 := -50.0        # портал тоннеля на станции
const TUN_Z1 := -265.0       # тупик
const GRATE_Z := -232.0      # решётка
const CHUNK := 14.0          # длина куска геометрии (лимит ламп на объект в браузере)
const TUBE_R := 2.1          # радиус трубы тоннеля
const TUBE_CY := FLOOR_Y + 1.2
const CHAMBER := 2.6         # полуразмер камеры-развилки
const CHAMBER_H := 4.4

const SHAFT_X := -1.6        # центр шахты
const SHAFT_Z := -32.0
const SHAFT_HALF := 0.9
const ROOM_Y := 85.0         # пол комнаты с люком

## Развилки: z камеры, направление штольни по X (-1 — налево, если идти вглубь), длина.
const BRANCHES := [
	{"z": -105.0, "dir": -1, "length": 46.0, "name": "ШТОЛЬНЯ 1"},
	{"z": -160.0, "dir": 1, "length": 56.0, "name": "ШТОЛЬНЯ 2"},
	{"z": -200.0, "dir": -1, "length": 40.0, "name": "ШТОЛЬНЯ 3"},
]

var lamps: Array[Dictionary] = []
var tunnel_lights_off := false
var blackout := false
var grate: Node3D
var zones: Array[Rect2] = []  # где можно стоять (XZ) — для событий

var m_tubbing: Material
var m_tiles: Material
var m_granite: Material
var m_ballast: Material
var m_concrete: Material
var m_floor: Material
var m_metal: Material
var m_rust: Material
var m_wood: Material
var m_rail: Material
var _time := 0.0


func build() -> void:
	m_tubbing = ProcTex.tubbing()
	m_tiles = ProcTex.tiles()
	m_granite = ProcTex.granite()
	m_ballast = ProcTex.ballast()
	m_concrete = ProcTex.concrete_rings()
	m_floor = ProcTex.concrete(Color(0.3, 0.29, 0.27), 0.5)
	m_metal = ProcTex.flat(Color(0.35, 0.36, 0.38), 0.45, 0.8)
	m_rust = ProcTex.flat(Color(0.35, 0.2, 0.12), 0.85, 0.4)
	m_wood = ProcTex.flat(Color(0.3, 0.22, 0.14), 0.9)
	m_rail = ProcTex.flat(Color(0.45, 0.42, 0.4), 0.35, 0.9)
	_build_room()
	_build_shaft()
	_build_station()
	_build_main_tunnel()
	for i in BRANCHES.size():
		_build_branch(i)
	_build_rails()
	_build_grate()
	_build_nest_decor()


func _process(delta: float) -> void:
	_time += delta
	for l in lamps:
		var light: OmniLight3D = l["light"]
		var mat: StandardMaterial3D = l["mat"]
		var mode: String = l["mode"]
		var on: bool = mode != "broken" and not blackout and not (l["tunnel"] and tunnel_lights_off)
		var f := 1.0 if on else 0.0
		if on and mode == "flicker":
			var phase: float = l["t"]
			if sin(_time * 13.0 + phase) + sin(_time * 7.3 + phase * 2.0) < -1.1:
				f = 0.05
		light.light_energy = float(l["energy"]) * f
		light.visible = f > 0.0
		mat.emission_energy_multiplier = 3.0 * f


# --- Запросы для других систем ------------------------------------------------

## Есть ли рядом горящая лампа (для счётчика страха).
func is_lit_near(pos: Vector3) -> bool:
	for l in lamps:
		var light: OmniLight3D = l["light"]
		if not light.visible or light.light_energy < 0.2:
			continue
		if light.global_position.distance_to(pos) < light.omni_range * 0.55:
			return true
	return false


## Точка внутри тоннелей / станции (для появления «Другого»).
func is_walkable(p: Vector3) -> bool:
	if p.y > FLOOR_Y + 5.0:
		return false
	var q := Vector2(p.x, p.z)
	for r in zones:
		if r.has_point(q):
			return true
	return false


## X стенки основной трубы на высоте y. side: -1 левая, +1 правая.
static func wall_x(side: int, y: float, inset := 0.0) -> float:
	return TUN_CX + side * (_tube_half(y) - inset)


static func _tube_half(y: float) -> float:
	return sqrt(maxf(TUBE_R * TUBE_R - pow(y - TUBE_CY, 2.0), 0.0))


## Крепление на стене трубы. tunnel: -1 — основной тоннель (along = z),
## 0..2 — штольня (along = метры от развилки). Узел смотрит (+Z) внутрь тоннеля.
func wall_mount(tunnel: int, side: int, along: float, y: float, inset := 0.03) -> Transform3D:
	var off := _tube_half(y) - inset
	if tunnel < 0:
		return Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0 * side)), Vector3(TUN_CX + side * off, y, along))
	var b: Dictionary = BRANCHES[tunnel]
	var x := TUN_CX + float(b["dir"]) * (CHAMBER + along)
	var yaw := 0.0 if side < 0 else 180.0
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), Vector3(x, y, float(b["z"]) + side * off))


## Точка на полу. lateral — смещение поперёк тоннеля.
func floor_point(tunnel: int, along: float, lateral := 0.0) -> Vector3:
	if tunnel < 0:
		return Vector3(TUN_CX + lateral, FLOOR_Y, along)
	var b: Dictionary = BRANCHES[tunnel]
	return Vector3(TUN_CX + float(b["dir"]) * (CHAMBER + along), FLOOR_Y, float(b["z"]) + lateral)


## Поворот поперечной плоскости тоннеля (для паутины во всю ширину).
func cross_yaw(tunnel: int) -> float:
	return 0.0 if tunnel < 0 else PI / 2


func set_grate_open(open: bool) -> void:
	grate.rotation.y = deg_to_rad(85.0) if open else 0.0


# --- Комната с люком ---------------------------------------------------------

func _build_room() -> void:
	var y := ROOM_Y
	var h := 3.0
	var x0 := SHAFT_X - 3.5
	var x1 := SHAFT_X + 3.5
	var z0 := SHAFT_Z - 3.5
	var z1 := SHAFT_Z + 3.5
	var hx0 := SHAFT_X - SHAFT_HALF
	var hx1 := SHAFT_X + SHAFT_HALF
	var hz0 := SHAFT_Z - SHAFT_HALF
	var hz1 := SHAFT_Z + SHAFT_HALF
	# Пол с отверстием люка посередине.
	Geo.box(self, Vector3(SHAFT_X, y - 0.15, (z0 + hz0) / 2), Vector3(7.6, 0.3, hz0 - z0), m_floor)
	Geo.box(self, Vector3(SHAFT_X, y - 0.15, (hz1 + z1) / 2), Vector3(7.6, 0.3, z1 - hz1), m_floor)
	Geo.box(self, Vector3((x0 - 0.3 + hx0) / 2, y - 0.15, SHAFT_Z), Vector3(hx0 - x0 + 0.3, 0.3, SHAFT_HALF * 2), m_floor)
	Geo.box(self, Vector3((hx1 + x1 + 0.3) / 2, y - 0.15, SHAFT_Z), Vector3(x1 + 0.3 - hx1, 0.3, SHAFT_HALF * 2), m_floor)
	# Стальная окантовка люка.
	for e in [[Vector3(SHAFT_X, y + 0.01, hz0 - 0.05), Vector3(1.9, 0.02, 0.1)],
			[Vector3(SHAFT_X, y + 0.01, hz1 + 0.05), Vector3(1.9, 0.02, 0.1)],
			[Vector3(hx0 - 0.05, y + 0.01, SHAFT_Z), Vector3(0.1, 0.02, 1.9)],
			[Vector3(hx1 + 0.05, y + 0.01, SHAFT_Z), Vector3(0.1, 0.02, 1.9)]]:
		Geo.box(self, e[0], e[1], m_metal, false)
	# Стены: внизу тёмно-зелёная краска, сверху побелка — как в старых подсобках.
	var green := ProcTex.paint(Color(0.2, 0.33, 0.26), "paint_green")
	var white := ProcTex.paint(Color(0.82, 0.81, 0.76), "paint_white")
	for w in [[Vector3(x0 - 0.15, 0, SHAFT_Z), Vector3(0.3, 0, 7.6)], [Vector3(x1 + 0.15, 0, SHAFT_Z), Vector3(0.3, 0, 7.6)],
			[Vector3(SHAFT_X, 0, z0 - 0.15), Vector3(7.6, 0, 0.3)], [Vector3(SHAFT_X, 0, z1 + 0.15), Vector3(7.6, 0, 0.3)]]:
		var p: Vector3 = w[0]
		var s: Vector3 = w[1]
		Geo.box(self, Vector3(p.x, y + 0.7, p.z), Vector3(s.x, 1.4, s.z), green)
		Geo.box(self, Vector3(p.x, y + 2.2, p.z), Vector3(s.x, 1.6, s.z), white, false)
	Geo.box(self, Vector3(SHAFT_X, y + h + 0.15, SHAFT_Z), Vector3(7.6, 0.3, 7.6), m_concrete)
	_add_lamp(Vector3(SHAFT_X, y + h - 0.1, SHAFT_Z + 1.2), Color(1.0, 0.85, 0.6), 1.4, 9.0, "ok", false)
	# Дверь домой, шкафчики, таблички.
	Geo.box(self, Vector3(SHAFT_X - 2.0, y + 1.05, z1 - 0.03), Vector3(1.0, 2.1, 0.06), m_wood, false)
	Geo.label(self, Vector3(SHAFT_X - 2.0, y + 2.35, z1 - 0.07), "ВЫХОД", 180, 40, Color(0.85, 0.25, 0.2))
	Geo.box(self, Vector3(x0 + 0.3, y + 0.95, SHAFT_Z + 1.6), Vector3(0.5, 1.9, 0.6), m_metal)
	Geo.box(self, Vector3(x0 + 0.3, y + 0.95, SHAFT_Z + 2.25), Vector3(0.5, 1.9, 0.6), m_metal)
	Geo.label(self, Vector3(SHAFT_X, y + 2.3, z0 + 0.02), "ШАХТА № 3 — ГЛУБИНА 100 М\nСПУСК ТОЛЬКО ПО ЛЕСТНИЦЕ", 0, 30, Color(0.15, 0.15, 0.15), true)


# --- Шахта -------------------------------------------------------------------

func _build_shaft() -> void:
	var bottom := FLOOR_Y + 4.0  # потолок станции
	var top := ROOM_Y - 0.3
	var w := SHAFT_HALF * 2.0
	var y := bottom
	while y < top - 0.01:
		var y2 := minf(y + 12.0, top)
		var cy := (y + y2) / 2.0
		var h := y2 - y
		Geo.box(self, Vector3(SHAFT_X, cy, SHAFT_Z - SHAFT_HALF - 0.15), Vector3(w + 0.6, h, 0.3), m_concrete)
		Geo.box(self, Vector3(SHAFT_X, cy, SHAFT_Z + SHAFT_HALF + 0.15), Vector3(w + 0.6, h, 0.3), m_concrete)
		Geo.box(self, Vector3(SHAFT_X - SHAFT_HALF - 0.15, cy, SHAFT_Z), Vector3(0.3, h, w), m_concrete)
		Geo.box(self, Vector3(SHAFT_X + SHAFT_HALF + 0.15, cy, SHAFT_Z), Vector3(0.3, h, w), m_concrete)
		y = y2
	# Редкие лампы: часть разбита — между ними полная темнота.
	var i := 0
	var ly := bottom + 6.0
	while ly < top - 2.0:
		var mode := "ok"
		if i % 3 == 1:
			mode = "broken"
		elif i % 4 == 2:
			mode = "flicker"
		_add_lamp(Vector3(SHAFT_X + 0.7, ly, SHAFT_Z + 0.55), Color(1.0, 0.78, 0.5), 0.6, 7.0, mode, false)
		ly += 12.0
		i += 1


# --- Станция -----------------------------------------------------------------

func _build_station() -> void:
	var cz := -40.0
	var h := 4.0
	var y := FLOOR_Y
	Geo.box(self, Vector3(0, y - 0.15, cz), Vector3(6.6, 0.3, 20.0), m_granite)
	# Потолок с проёмом шахты.
	var top := y + h + 0.15
	var hz0 := SHAFT_Z - SHAFT_HALF
	var hz1 := SHAFT_Z + SHAFT_HALF
	Geo.box(self, Vector3(0, top, (-50.0 + hz0) / 2), Vector3(6.6, 0.3, hz0 + 50.0), m_concrete)
	Geo.box(self, Vector3(0, top, (hz1 - 30.0) / 2), Vector3(6.6, 0.3, -30.0 - hz1), m_concrete)
	Geo.box(self, Vector3((-3.3 + SHAFT_X - SHAFT_HALF) / 2, top, SHAFT_Z), Vector3(SHAFT_X - SHAFT_HALF + 3.3, 0.3, SHAFT_HALF * 2), m_concrete)
	Geo.box(self, Vector3((SHAFT_X + SHAFT_HALF + 3.3) / 2, top, SHAFT_Z), Vector3(3.3 - SHAFT_X - SHAFT_HALF, 0.3, SHAFT_HALF * 2), m_concrete)
	# Стены в кафеле.
	Geo.box(self, Vector3(-3.15, y + h / 2, cz), Vector3(0.3, h, 20.6), m_tiles)
	Geo.box(self, Vector3(3.15, y + h / 2, cz), Vector3(0.3, h, 20.6), m_tiles)
	Geo.box(self, Vector3(0, y + h / 2, -29.85), Vector3(6.6, h, 0.3), m_tiles)
	# Торец с круглым порталом тоннеля.
	var portal := MeshInstance3D.new()
	portal.mesh = Geo.portal_mesh(TUBE_R, Rect2(-3.0 - TUN_CX, y - TUBE_CY, 6.0, h), 48)
	portal.material_override = m_tiles
	portal.position = Vector3(TUN_CX, TUBE_CY, TUN_Z0)
	add_child(portal)
	Geo.solid(self, Vector3((-3.0 + LEFT_X) / 2, y + 2.0, TUN_Z0 - 0.15), Vector3(LEFT_X + 3.0, 4.0, 0.3))
	Geo.solid(self, Vector3((RIGHT_X + 3.3) / 2, y + 2.0, TUN_Z0 - 0.15), Vector3(3.3 - RIGHT_X, 4.0, 0.3))
	zones.append(Rect2(-3.0, -50.0, 6.0, 20.0))
	# Свет.
	_add_lamp(Vector3(0, y + h - 0.1, -37), Color(0.8, 0.9, 1.0), 1.5, 10.0, "ok", false)
	_add_lamp(Vector3(0, y + h - 0.1, -46), Color(0.8, 0.9, 1.0), 1.5, 10.0, "flicker", false)
	# Край платформы, упор, скамья, шкафчики.
	Geo.box(self, Vector3(0.3, y + 0.005, cz), Vector3(0.15, 0.01, 19.6), ProcTex.flat(Color(0.7, 0.6, 0.1)), false)
	Geo.box(self, Vector3(TUN_CX + 0.3, y + 0.3, -30.5), Vector3(1.3, 0.6, 0.3), m_rust)
	Geo.box(self, Vector3(-2.6, y + 0.225, -41), Vector3(0.5, 0.45, 1.6), m_wood)
	Geo.box(self, Vector3(-2.65, y + 0.95, -48.6), Vector3(0.5, 1.9, 0.5), m_metal)
	Geo.box(self, Vector3(-2.65, y + 0.95, -48.0), Vector3(0.5, 1.9, 0.5), m_metal)
	# Таблички.
	Geo.label(self, Vector3(-2.98, y + 2.9, -40), "СТАНЦИЯ «ТИХАЯ»", 90, 64, Color(0.2, 0.2, 0.25), true)
	Geo.box(self, Vector3(-2.99, y + 1.6, -37.5), Vector3(0.02, 0.9, 0.8), ProcTex.flat(Color(0.75, 0.72, 0.62)), false)
	Geo.label(self, Vector3(-2.975, y + 1.6, -37.5),
		"ПРАВИЛА ОБХОДЧИКА\n\n1. Не выключай фонарь в тоннеле.\n2. Паутину — сжигать.\n3. Фильтры менять вовремя.\n4. О посторонних звуках\n    не докладывать.",
		90, 24, Color(0.1, 0.1, 0.1), true, 0.0022)


# --- Основной тоннель --------------------------------------------------------

func _build_main_tunnel() -> void:
	# Труба режется на отрезки между камерами развилок.
	var cuts: Array[float] = [TUN_Z0]
	for b in BRANCHES:
		cuts.append(float(b["z"]) + CHAMBER)
		cuts.append(float(b["z"]) - CHAMBER)
	cuts.append(TUN_Z1)
	for i in range(0, cuts.size(), 2):
		_main_segment(cuts[i], cuts[i + 1])
	for b in BRANCHES:
		_build_chamber(b)
	Geo.box(self, Vector3(TUN_CX, TUBE_CY, TUN_Z1 - 0.15), Vector3(TUBE_R * 2 + 0.4, TUBE_R * 2 + 0.4, 0.3), m_concrete)
	zones.append(Rect2(LEFT_X, TUN_Z1, TUN_HW * 2, TUN_Z0 - TUN_Z1))
	# Лампы на левой стене каждые 14 м (не в камерах): часть разбита, часть мигает.
	var i := 0
	var z := TUN_Z0 - 6.0
	while z > GRATE_Z + 2.0:
		var in_chamber := false
		for b in BRANCHES:
			if absf(z - float(b["z"])) < CHAMBER + 1.0:
				in_chamber = true
		if not in_chamber:
			var mode := "ok"
			if i % 4 == 3:
				mode = "broken"
			elif i % 5 == 2:
				mode = "flicker"
			var ly := FLOOR_Y + 2.5
			_add_lamp(Vector3(wall_x(-1, ly, 0.2), ly, z), Color(1.0, 0.72, 0.42), 0.9, 7.0, mode, true)
			i += 1
		z -= 14.0
	# Пикеты.
	for k in [1, 3, 4]:
		var mz := TUN_Z0 - 40.0 * k
		var ly := FLOOR_Y + 1.6
		Geo.label(self, Vector3(wall_x(1, ly, 0.03), ly, mz), "ПК %d" % k, -90, 48, Color(0.95, 0.95, 0.9), true)


func _main_segment(z_a: float, z_b: float) -> void:
	var cable := ProcTex.flat(Color(0.05, 0.05, 0.05), 0.6)
	var along := Basis(Vector3.RIGHT, PI / 2)
	var z := z_a
	while z > z_b + 0.01:
		var z2 := maxf(z - CHUNK, z_b)
		var length := z - z2
		var cz := (z + z2) / 2.0
		var tube := MeshInstance3D.new()
		tube.mesh = Geo.tube_mesh(TUBE_R, z, z2, 28, -0.6, TUBE_R * TAU / 8.0, 1.0)
		tube.material_override = m_tubbing
		tube.position = Vector3(TUN_CX, TUBE_CY, 0)
		add_child(tube)
		Geo.box(self, Vector3(TUN_CX, FLOOR_Y - 0.15, cz), Vector3(TUBE_R * 2, 0.3, length), m_ballast)
		Geo.solid(self, Vector3(LEFT_X - 0.15, FLOOR_Y + 2.0, cz), Vector3(0.3, 4.0, length))
		Geo.solid(self, Vector3(RIGHT_X + 0.15, FLOOR_Y + 2.0, cz), Vector3(0.3, 4.0, length))
		# Труба слева, пучок кабелей справа.
		Geo.cylinder(self, Vector3(wall_x(-1, FLOOR_Y + 2.2, 0.14), FLOOR_Y + 2.2, cz), 0.09, length, m_rust, along)
		for k in 3:
			var cy := FLOOR_Y + 1.9 + k * 0.09
			Geo.cylinder(self, Vector3(wall_x(1, cy, 0.05), cy, cz), 0.025, length, cable, along)
		z = z2


func _build_chamber(b: Dictionary) -> void:
	var zj: float = b["z"]
	var dir: float = b["dir"]
	var c := CHAMBER
	Geo.box(self, Vector3(TUN_CX, FLOOR_Y - 0.15, zj), Vector3(c * 2, 0.3, c * 2), m_floor)
	Geo.box(self, Vector3(TUN_CX, FLOOR_Y + CHAMBER_H + 0.15, zj), Vector3(c * 2 + 0.6, 0.3, c * 2 + 0.6), m_concrete)
	var rect := Rect2(-c, FLOOR_Y - TUBE_CY, c * 2, CHAMBER_H)
	# Торцы вдоль основного тоннеля — с круглыми проёмами.
	for side in [1.0, -1.0]:
		var p := MeshInstance3D.new()
		p.mesh = Geo.portal_mesh(TUBE_R, rect, 40)
		p.material_override = m_concrete
		p.position = Vector3(TUN_CX, TUBE_CY, zj + side * c)
		add_child(p)
		var wz := zj + side * (c + 0.15)
		Geo.solid(self, Vector3((TUN_CX - c + LEFT_X) / 2, FLOOR_Y + 2.0, wz), Vector3(LEFT_X - TUN_CX + c, 4.0, 0.3))
		Geo.solid(self, Vector3((RIGHT_X + TUN_CX + c) / 2, FLOOR_Y + 2.0, wz), Vector3(TUN_CX + c - RIGHT_X, 4.0, 0.3))
	# Боковина со входом в штольню.
	var bp := MeshInstance3D.new()
	bp.mesh = Geo.portal_mesh(TUBE_R, rect, 40)
	bp.material_override = m_concrete
	bp.transform = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(TUN_CX + dir * c, TUBE_CY, zj))
	add_child(bp)
	var bx := TUN_CX + dir * (c + 0.15)
	Geo.solid(self, Vector3(bx, FLOOR_Y + 2.0, (zj - c + zj - TUN_HW) / 2), Vector3(0.3, 4.0, c - TUN_HW))
	Geo.solid(self, Vector3(bx, FLOOR_Y + 2.0, (zj + c + zj + TUN_HW) / 2), Vector3(0.3, 4.0, c - TUN_HW))
	# Глухая боковина с указателем.
	Geo.box(self, Vector3(TUN_CX - dir * (c + 0.15), FLOOR_Y + CHAMBER_H / 2, zj), Vector3(0.3, CHAMBER_H, c * 2), m_concrete)
	var side_word := "НАЛЕВО" if dir < 0 else "НАПРАВО"
	Geo.label(self, Vector3(TUN_CX - dir * (c - 0.02), FLOOR_Y + 2.4, zj), "%s — %s\n\nТОННЕЛЬ — ПРЯМО" % [b["name"], side_word],
		90.0 * dir, 44, Color(0.9, 0.85, 0.6), true)
	_add_lamp(Vector3(TUN_CX, FLOOR_Y + CHAMBER_H - 0.1, zj), Color(1.0, 0.72, 0.42), 1.0, 8.0, "ok", true)
	zones.append(Rect2(TUN_CX - c, zj - c, c * 2, c * 2))


# --- Штольни -----------------------------------------------------------------

func _build_branch(index: int) -> void:
	var b: Dictionary = BRANCHES[index]
	var zj: float = b["z"]
	var dir: float = b["dir"]
	var length: float = b["length"]
	var x_start := TUN_CX + dir * CHAMBER
	# Труба строится вдоль локальной -Z и поворачивается в сторону штольни.
	var basis := Basis(Vector3.UP, -dir * PI / 2)
	var along := Basis(Vector3.FORWARD, PI / 2)
	var d := 0.0
	while d < length - 0.01:
		var d2 := minf(d + CHUNK, length)
		var seg := d2 - d
		var mid := x_start + dir * (d + d2) / 2.0
		var tube := MeshInstance3D.new()
		tube.mesh = Geo.tube_mesh(TUBE_R, -(CHAMBER + d), -(CHAMBER + d2), 28, -0.6, TUBE_R * TAU / 8.0, 1.0)
		tube.material_override = m_tubbing
		tube.transform = Transform3D(basis, Vector3(TUN_CX, TUBE_CY, zj))
		add_child(tube)
		Geo.box(self, Vector3(mid, FLOOR_Y - 0.15, zj), Vector3(seg, 0.3, TUBE_R * 2), m_floor)
		Geo.solid(self, Vector3(mid, FLOOR_Y + 2.0, zj - TUN_HW - 0.15), Vector3(seg, 4.0, 0.3))
		Geo.solid(self, Vector3(mid, FLOOR_Y + 2.0, zj + TUN_HW + 0.15), Vector3(seg, 4.0, 0.3))
		var py := FLOOR_Y + 2.3
		Geo.cylinder(self, Vector3(mid, py, zj - _tube_half(py) + 0.14), 0.07, seg, m_rust, along)
		d = d2
	var x_end := x_start + dir * length
	Geo.box(self, Vector3(x_end + dir * 0.15, TUBE_CY, zj), Vector3(0.3, TUBE_R * 2 + 0.4, TUBE_R * 2 + 0.4), m_concrete)
	# Завал у тупика.
	for k in 6:
		var rx := x_end - dir * randf_range(0.4, 2.0)
		var rock := Geo.box(self, Vector3(rx, FLOOR_Y + 0.2, zj + randf_range(-1.2, 1.2)), Vector3.ONE * randf_range(0.3, 0.7), m_concrete, false)
		rock.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	# Почти все лампы в штольнях разбиты.
	var ld := 8.0
	var n := 0
	while ld < length - 3.0:
		var ly := FLOOR_Y + 2.5
		var lx := x_start + dir * ld
		_add_lamp(Vector3(lx, ly, zj + _tube_half(ly) - 0.2), Color(1.0, 0.7, 0.4), 0.8, 7.0, "flicker" if n == 0 else "broken", true)
		ld += 16.0
		n += 1
	zones.append(Rect2(minf(x_start, x_end), zj - TUN_HW, length, TUN_HW * 2))


# --- Пути --------------------------------------------------------------------

func _build_rails() -> void:
	var sleeper := BoxMesh.new()
	sleeper.size = Vector3(1.6, 0.06, 0.22)
	var cover := ProcTex.flat(Color(0.25, 0.2, 0.14), 0.9)
	var z_a := -29.0
	var z_end := GRATE_Z - 30.0
	while z_a > z_end + 0.01:
		var z_b := maxf(z_a - CHUNK, z_end)
		var length := z_a - z_b
		var cz := (z_a + z_b) / 2.0
		for off in [-0.55, 0.55]:
			Geo.box(self, Vector3(TUN_CX + float(off), FLOOR_Y + 0.05, cz), Vector3(0.07, 0.1, length), m_rail, false)
		# Контактный рельс под деревянным коробом.
		Geo.box(self, Vector3(TUN_CX + 1.05, FLOOR_Y + 0.15, cz), Vector3(0.08, 0.12, length), m_rail, false)
		Geo.box(self, Vector3(TUN_CX + 1.08, FLOOR_Y + 0.28, cz), Vector3(0.26, 0.03, length), cover, false)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = sleeper
		var count := int(length / 0.9)
		mm.instance_count = count
		for i in count:
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(TUN_CX, FLOOR_Y, z_a - 0.45 - i * 0.9)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = m_wood
		add_child(mmi)
		z_a = z_b


func _build_grate() -> void:
	# Шарнир у левой стенки трубы — так решётку можно «открыть». Прутья во весь круг.
	grate = Node3D.new()
	grate.position = Vector3(TUN_CX - TUBE_R, FLOOR_Y, GRATE_Z)
	add_child(grate)
	var w := TUBE_R * 2.0
	var h := TUBE_R + 1.2
	var x := 0.1
	while x < w:
		Geo.cylinder(grate, Vector3(x, h / 2, 0), 0.025, h, m_rust)
		x += 0.18
	for y in [0.3, 1.5, 2.9]:
		Geo.box(grate, Vector3(w / 2, float(y), 0), Vector3(w, 0.06, 0.06), m_rust, false)
	Geo.box(grate, Vector3(TUBE_R + 1.2, 1.1, 0.06), Vector3(0.12, 0.16, 0.06), m_metal, false)
	var body := StaticBody3D.new()
	grate.add_child(body)
	Geo.collider_box(body, Vector3(TUN_HW * 2, TUN_H, 0.15), Vector3(TUBE_R, TUN_H / 2, 0))


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
