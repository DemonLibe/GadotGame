class_name Level
extends Node3D
## Статическая геометрия «Тихой»:
## комната с люком наверху → шахта с лестницей (100 м) → станция на одну вагонетку →
## круглый тоннель из чугунных тюбингов с тремя развилками под острым углом в служебные штольни → решётка.

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
const JUNCTION_MAIN := 8.0   # развилка: ± столько метров основного тоннеля строится через CSG
const JUNCTION_BRANCH := 10.0  # ...и столько метров штольни от оси тоннеля
const WALL_T := 0.3          # толщина обделки (для CSG-развилок)
const ROOM_SECTION := 4.0    # ± столько метров трубы у двери в комнату строится через CSG
const ROOM_W := 3.4          # служебная комната: ширина, глубина, высота
const ROOM_D := 3.4
const ROOM_H := 2.6
## Комнаты сбоку от основного тоннеля (ещё по одной — в конце каждой штольни).
const SIDE_ROOMS := [
	{"z": -72.0, "side": 1},
	{"z": -128.0, "side": -1},
	{"z": -185.0, "side": 1},
]

const SHAFT_X := -1.6        # центр шахты
const SHAFT_Z := -32.0
const SHAFT_HALF := 0.9
const ROOM_Y := 85.0         # пол комнаты с люком

## Развилки: z точки ответвления на оси, сторона (-1 — налево, если идти вглубь),
## угол от оси тоннеля (острый — штольня уходит вперёд-вбок), длина.
const BRANCHES := [
	{"z": -105.0, "side": -1, "angle": 35.0, "length": 46.0, "name": "ШТОЛЬНЯ 1"},
	{"z": -160.0, "side": 1, "angle": 40.0, "length": 56.0, "name": "ШТОЛЬНЯ 2"},
	{"z": -200.0, "side": -1, "angle": 30.0, "length": 40.0, "name": "ШТОЛЬНЯ 3"},
]

var lamps: Array[Dictionary] = []
var tunnel_lights_off := false
var blackout := false
var grate: Node3D
var rooms: Array[Dictionary] = []  # {center, basis, door}: basis +Z смотрит из комнаты к двери
var _segments: Array[Dictionary] = []  # оси проходов {a, b, dir} в XZ — для событий

var m_tubbing: Material
var m_tubbing_tri: Material
var m_room: Material
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
var _window_light: OmniLight3D
var _lightning := 12.0


func build() -> void:
	m_tubbing = ProcTex.tubbing()
	m_tubbing_tri = ProcTex.tubbing_triplanar()
	m_room = ProcTex.paint(Color(0.5, 0.5, 0.46), "paint_room")
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
		_build_junction(i)
		_build_branch(i)
	_build_rails()
	_build_grate()
	_build_nest_decor()


func _process(delta: float) -> void:
	_time += delta
	_update_lightning(delta)
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


## Молния за окном дежурки: двойная вспышка и далёкий гром.
func _update_lightning(delta: float) -> void:
	if _window_light == null:
		return
	_lightning -= delta
	var t := -_lightning
	if _lightning <= 0.0:
		_window_light.light_energy = 3.0 if (t < 0.08 or (t > 0.18 and t < 0.26)) else 0.0
		if t > 0.3:
			_lightning = randf_range(12.0, 30.0)
			if is_inside_tree() and get_viewport().get_camera_3d() and get_viewport().get_camera_3d().global_position.y > ROOM_Y - 2.0:
				Game.play_at(Sfx.rumble(), _window_light.global_position + Vector3(-6, 0, 0), -10.0)


# --- Запросы для других систем ------------------------------------------------

## Есть ли рядом хоть какой-то свет: лампа, огонёк зарядки, горящая паутина.
## Рядом со светом страх не копится.
func is_lit_near(pos: Vector3) -> bool:
	for n in get_tree().get_nodes_in_group("fear_light"):
		var light := n as OmniLight3D
		if light == null or not light.is_visible_in_tree() or light.light_energy < 0.05:
			continue
		if light.global_position.distance_to(pos) < maxf(light.omni_range * 0.6, 2.2):
			return true
	return false


## Точка внутри станции или тоннелей (для появления «Другого»).
func is_walkable(p: Vector3) -> bool:
	if p.y > FLOOR_Y + 5.0:
		return false
	if Rect2(-3.0, -50.0, 6.0, 20.0).has_point(Vector2(p.x, p.z)):
		return true
	return _nearest_segment(p).get("dist", INF) < TUN_HW


## Направление прохода, в котором стоит точка (основной тоннель или штольня).
func axis_at(p: Vector3) -> Vector3:
	return _nearest_segment(p).get("dir", Vector3.FORWARD)


func _nearest_segment(p: Vector3) -> Dictionary:
	var q := Vector2(p.x, p.z)
	var best := {}
	var best_d := INF
	for seg in _segments:
		var a: Vector2 = seg["a"]
		var b: Vector2 = seg["b"]
		var d := q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b))
		if d < best_d:
			best_d = d
			best = {"dist": d, "dir": seg["dir"]}
	return best


## X стенки основной трубы на высоте y. side: -1 левая, +1 правая.
static func wall_x(side: int, y: float, inset := 0.0) -> float:
	return TUN_CX + side * (_tube_half(y) - inset)


static func _tube_half(y: float) -> float:
	return sqrt(maxf(TUBE_R * TUBE_R - pow(y - TUBE_CY, 2.0), 0.0))


## Ось штольни: направление (горизонтальное) и правый перпендикуляр.
static func branch_dir(index: int) -> Vector3:
	var b: Dictionary = BRANCHES[index]
	var a := deg_to_rad(float(b["angle"]))
	return Vector3(float(b["side"]) * sin(a), 0.0, -cos(a))


static func branch_origin(index: int) -> Vector3:
	return Vector3(TUN_CX, FLOOR_Y, float(BRANCHES[index]["z"]))


static func _right_of(d: Vector3) -> Vector3:
	return Vector3(-d.z, 0.0, d.x)


## Поворот вокруг Y, переводящий локальную -Z в направление d.
static func _yaw_to(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


## Крепление на стене трубы. tunnel: -1 — основной тоннель (along = z),
## 0..2 — штольня (along = метры от точки ответвления). Узел смотрит (+Z) внутрь тоннеля.
func wall_mount(tunnel: int, side: int, along: float, y: float, inset := 0.03) -> Transform3D:
	var off := _tube_half(y) - inset
	if tunnel < 0:
		return Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0 * side)), Vector3(TUN_CX + side * off, y, along))
	var d := branch_dir(tunnel)
	var r := _right_of(d)
	var pos := branch_origin(tunnel) + d * along + r * (side * off)
	pos.y = y
	var inward := -r * side
	return Transform3D(Basis(Vector3.UP, atan2(inward.x, inward.z)), pos)


## Точка на полу. lateral — смещение поперёк тоннеля (вправо, если смотреть вглубь).
func floor_point(tunnel: int, along: float, lateral := 0.0) -> Vector3:
	if tunnel < 0:
		return Vector3(TUN_CX + lateral, FLOOR_Y, along)
	var d := branch_dir(tunnel)
	return branch_origin(tunnel) + d * along + _right_of(d) * lateral


## Поворот поперечной плоскости тоннеля (для паутины во всю ширину).
func cross_yaw(tunnel: int) -> float:
	if tunnel < 0:
		return 0.0
	var d := branch_dir(tunnel)
	return atan2(d.x, d.z)


## Оси проходов для схемы на карте: [{a, b}] в XZ.
func map_segments() -> Array[Dictionary]:
	return _segments


func set_grate_open(open: bool) -> void:
	grate.rotation.y = deg_to_rad(85.0) if open else 0.0


# --- Комната с люком ---------------------------------------------------------

func _build_room() -> void:
	# Дежурка обходчика: линолеум, крашеные стены, окно с дождём, люк в ограждении посередине.
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
	var lino := ProcTex.linoleum()
	var dark := ProcTex.flat(Color(0.12, 0.1, 0.09), 0.8)
	var wood := ProcTex.flat(Color(0.32, 0.2, 0.12), 0.75)
	# Пол с отверстием люка.
	Geo.box(self, Vector3(SHAFT_X, y - 0.15, (z0 + hz0) / 2), Vector3(7.6, 0.3, hz0 - z0), lino)
	Geo.box(self, Vector3(SHAFT_X, y - 0.15, (hz1 + z1) / 2), Vector3(7.6, 0.3, z1 - hz1), lino)
	Geo.box(self, Vector3((x0 - 0.3 + hx0) / 2, y - 0.15, SHAFT_Z), Vector3(hx0 - x0 + 0.3, 0.3, SHAFT_HALF * 2), lino)
	Geo.box(self, Vector3((hx1 + x1 + 0.3) / 2, y - 0.15, SHAFT_Z), Vector3(x1 + 0.3 - hx1, 0.3, SHAFT_HALF * 2), lino)
	# Предупреждающая разметка вокруг люка.
	var hazard := ProcTex.hazard()
	Geo.box(self, Vector3(SHAFT_X, y + 0.004, hz0 - 0.1), Vector3(2.2, 0.008, 0.2), hazard, false)
	Geo.box(self, Vector3(SHAFT_X, y + 0.004, hz1 + 0.1), Vector3(2.2, 0.008, 0.2), hazard, false)
	Geo.box(self, Vector3(hx0 - 0.1, y + 0.004, SHAFT_Z), Vector3(0.2, 0.008, 1.8), hazard, false)
	Geo.box(self, Vector3(hx1 + 0.1, y + 0.004, SHAFT_Z), Vector3(0.2, 0.008, 1.8), hazard, false)
	# Ограждение люка с боков (спереди — лестница, сзади — крышка на петлях).
	var red := ProcTex.flat(Color(0.6, 0.1, 0.07), 0.6, 0.3)
	for cx in [hx0 - 0.15, hx1 + 0.15]:
		for cz in [hz0 - 0.15, hz1 + 0.15]:
			Geo.cylinder(self, Vector3(float(cx), y + 0.5, float(cz)), 0.03, 1.0, red)
		for ry in [0.5, 0.95]:
			Geo.box(self, Vector3(float(cx), y + float(ry), SHAFT_Z), Vector3(0.04, 0.04, 2.1), red, false)
		Geo.solid(self, Vector3(float(cx), y + 0.5, SHAFT_Z), Vector3(0.1, 1.0, 2.1))
	# Стены: внизу тёмно-зелёная краска, сверху побелка, между ними — полоса.
	var green := ProcTex.paint(Color(0.18, 0.32, 0.26), "paint_green")
	var white := ProcTex.paint(Color(0.82, 0.8, 0.72), "paint_white")
	var stripe := ProcTex.flat(Color(0.35, 0.1, 0.08), 0.7)
	for w in [[Vector3(x0 - 0.15, 0, SHAFT_Z), Vector3(0.3, 0, 7.6), Vector3(0.02, 0, 0)],
			[Vector3(x1 + 0.15, 0, SHAFT_Z), Vector3(0.3, 0, 7.6), Vector3(-0.02, 0, 0)],
			[Vector3(SHAFT_X, 0, z0 - 0.15), Vector3(7.6, 0, 0.3), Vector3(0, 0, 0.02)],
			[Vector3(SHAFT_X, 0, z1 + 0.15), Vector3(7.6, 0, 0.3), Vector3(0, 0, -0.02)]]:
		var p: Vector3 = w[0]
		var sz: Vector3 = w[1]
		var inward: Vector3 = w[2]
		Geo.box(self, Vector3(p.x, y + 0.7, p.z), Vector3(sz.x, 1.4, sz.z), green)
		Geo.box(self, Vector3(p.x, y + 2.2, p.z), Vector3(sz.x, 1.6, sz.z), white, false)
		Geo.box(self, Vector3(p.x, y + 1.4, p.z) + inward, Vector3(maxf(sz.x, 0.3), 0.04, maxf(sz.z, 0.3)), stripe, false)
		Geo.box(self, Vector3(p.x, y + 0.05, p.z) + inward * 2.5, Vector3(maxf(sz.x, 0.3), 0.1, maxf(sz.z, 0.3)), dark, false)
	Geo.box(self, Vector3(SHAFT_X, y + h + 0.15, SHAFT_Z), Vector3(7.6, 0.3, 7.6), m_concrete)
	# Трубы под потолком.
	var along_x := Basis(Vector3.FORWARD, PI / 2)
	Geo.cylinder(self, Vector3(SHAFT_X, y + 2.8, z0 + 0.25), 0.06, 7.0, m_rust, along_x)
	Geo.cylinder(self, Vector3(SHAFT_X, y + 2.65, z0 + 0.25), 0.04, 7.0, m_metal, along_x)
	# Лампа под эмалированным абажуром над люком.
	var lamp_pos := Vector3(SHAFT_X + 0.4, y + 2.3, SHAFT_Z + 1.0)
	Geo.cylinder(self, lamp_pos + Vector3(0, 0.38, 0), 0.008, 0.6, dark)
	var shade := CylinderMesh.new()
	shade.top_radius = 0.05
	shade.bottom_radius = 0.26
	shade.height = 0.18
	var shade_mi := MeshInstance3D.new()
	shade_mi.mesh = shade
	shade_mi.material_override = ProcTex.flat(Color(0.2, 0.35, 0.28), 0.4, 0.3)
	shade_mi.position = lamp_pos + Vector3(0, 0.05, 0)
	add_child(shade_mi)
	_add_lamp(lamp_pos - Vector3(0, 0.03, 0), Color(1.0, 0.8, 0.55), 1.5, 9.0, "ok", false, false)
	# Окно на западной стене: ночь, дождь, иногда молния.
	var wz := SHAFT_Z - 1.7
	var glass := ProcTex.emissive(Color(0.05, 0.08, 0.14), 0.8)
	Geo.box(self, Vector3(x0 + 0.03, y + 1.8, wz), Vector3(0.02, 1.0, 1.4), glass, false)
	for fz in [-0.72, 0.0, 0.72]:
		Geo.box(self, Vector3(x0 + 0.05, y + 1.8, wz + float(fz)), Vector3(0.05, 1.1, 0.06), wood, false)
	for fy in [1.27, 1.8, 2.33]:
		Geo.box(self, Vector3(x0 + 0.05, y + float(fy), wz), Vector3(0.05, 0.06, 1.5), wood, false)
	Geo.box(self, Vector3(x0 + 0.12, y + 1.22, wz), Vector3(0.2, 0.04, 1.6), wood, false)
	_window_light = OmniLight3D.new()
	_window_light.position = Vector3(x0 + 0.6, y + 1.8, wz)
	_window_light.light_color = Color(0.6, 0.7, 1.0)
	_window_light.omni_range = 6.0
	_window_light.light_energy = 0.0
	add_child(_window_light)
	_room_sound(Sfx.rain(), Vector3(x0 + 0.3, y + 1.8, wz), -10.0)
	# Стол с монитором камеры у окна.
	var tx := x0 + 0.4
	var tz := SHAFT_Z - 0.2
	Geo.box(self, Vector3(tx, y + 0.72, tz), Vector3(0.6, 0.04, 0.9), wood)
	for lx in [-0.25, 0.25]:
		for lz in [-0.4, 0.4]:
			Geo.box(self, Vector3(tx + float(lx), y + 0.36, tz + float(lz)), Vector3(0.04, 0.72, 0.04), wood, false)
	Geo.box(self, Vector3(tx - 0.02, y + 0.95, tz), Vector3(0.42, 0.42, 0.45), ProcTex.flat(Color(0.75, 0.72, 0.62), 0.6))
	var screen := ProcTex.emissive(Color(0.25, 0.55, 0.35), 1.2)
	Geo.box(self, Vector3(tx + 0.2, y + 0.97, tz), Vector3(0.01, 0.3, 0.36), screen, false)
	Geo.label(self, Vector3(tx + 0.21, y + 0.98, tz), "КАМЕРА 3 — ТОННЕЛЬ\nНЕТ СИГНАЛА", 90, 18, Color(0.7, 1.0, 0.75), false, 0.0018)
	var glow := OmniLight3D.new()
	glow.position = Vector3(tx + 0.5, y + 1.0, tz)
	glow.light_color = Color(0.4, 0.9, 0.5)
	glow.omni_range = 2.0
	glow.light_energy = 0.4
	glow.add_to_group("fear_light")
	add_child(glow)
	# Часы, полка с папками, памятка, календарь, щиток, вешалка.
	var cx := SHAFT_X + 2.2
	var face := Geo.cylinder(self, Vector3(cx, y + 2.35, z0 + 0.03), 0.2, 0.04, ProcTex.flat(Color(0.9, 0.88, 0.8), 0.5), Basis(Vector3.RIGHT, PI / 2))
	face.name = "ClockFace"
	Geo.cylinder(self, Vector3(cx, y + 2.35, z0 + 0.02), 0.22, 0.03, dark, Basis(Vector3.RIGHT, PI / 2))
	var hand := Geo.box(self, Vector3(cx + 0.05, y + 2.37, z0 + 0.06), Vector3(0.12, 0.012, 0.005), dark, false)
	hand.rotation.z = 0.4
	Geo.box(self, Vector3(cx, y + 2.42, z0 + 0.06), Vector3(0.012, 0.15, 0.005), dark, false)
	_room_sound(Sfx.tick(), Vector3(cx, y + 2.35, z0 + 0.1), -18.0)
	var shx := SHAFT_X - 2.6
	for sy in [1.6, 2.1]:
		Geo.box(self, Vector3(shx, y + float(sy), z0 + 0.15), Vector3(1.2, 0.03, 0.3), wood, false)
		for k in 6:
			var col := Color(randf_range(0.2, 0.55), randf_range(0.15, 0.3), randf_range(0.1, 0.25))
			Geo.box(self, Vector3(shx - 0.45 + k * 0.17, y + float(sy) + 0.16, z0 + 0.16), Vector3(0.06, 0.3, 0.24), ProcTex.flat(col, 0.8), false)
	var paper := ProcTex.flat(Color(0.86, 0.83, 0.72), 0.95)
	Geo.box(self, Vector3(x1 - 0.01, y + 1.9, SHAFT_Z + 1.6), Vector3(0.01, 0.7, 0.5), paper, false)
	Geo.label(self, Vector3(x1 - 0.02, y + 1.9, SHAFT_Z + 1.6), "ПАМЯТКА\nОБХОДЧИКА\n\nНе спускайся\nбез фонаря.\nСвет — твоя смена.\nДокладывай\nпо рации.", -90, 22, Color(0.15, 0.12, 0.1), true, 0.0022)
	Geo.box(self, Vector3(x1 - 0.01, y + 1.7, SHAFT_Z - 0.4), Vector3(0.01, 0.45, 0.32), paper, false)
	Geo.label(self, Vector3(x1 - 0.02, y + 1.8, SHAFT_Z - 0.4), "ОКТЯБРЬ", -90, 22, Color(0.55, 0.1, 0.08), true, 0.0022)
	var panel_x := SHAFT_X + 0.9
	Geo.box(self, Vector3(panel_x, y + 1.6, z1 - 0.06), Vector3(0.5, 0.6, 0.1), ProcTex.flat(Color(0.4, 0.42, 0.4), 0.5, 0.5), false)
	for k in 3:
		Geo.box(self, Vector3(panel_x - 0.14 + k * 0.14, y + 1.55, z1 - 0.12), Vector3(0.05, 0.1, 0.03), dark, false)
	Geo.sphere(self, Vector3(panel_x + 0.15, y + 1.8, z1 - 0.11), 0.02, ProcTex.emissive(Color(1.0, 0.15, 0.1), 2.0))
	Geo.box(self, Vector3(SHAFT_X - 1.2, y + 1.2, z1 - 0.12), Vector3(0.45, 0.95, 0.12), ProcTex.flat(Color(0.2, 0.22, 0.18), 1.0), false)
	Geo.box(self, Vector3(SHAFT_X - 1.2, y + 1.72, z1 - 0.05), Vector3(0.06, 0.04, 0.1), m_metal, false)
	# Дверь домой, коврик, шкафчики.
	Geo.box(self, Vector3(SHAFT_X - 2.0, y + 1.05, z1 - 0.03), Vector3(1.0, 2.1, 0.06), wood, false)
	Geo.box(self, Vector3(SHAFT_X - 1.62, y + 1.0, z1 - 0.08), Vector3(0.04, 0.12, 0.05), m_metal, false)
	Geo.label(self, Vector3(SHAFT_X - 2.0, y + 2.35, z1 - 0.07), "ВЫХОД", 180, 40, Color(0.85, 0.25, 0.2))
	Geo.box(self, Vector3(SHAFT_X - 2.0, y + 0.006, z1 - 0.5), Vector3(0.9, 0.012, 0.6), ProcTex.flat(Color(0.25, 0.15, 0.1), 1.0), false)
	Geo.box(self, Vector3(x0 + 0.3, y + 0.95, SHAFT_Z + 1.6), Vector3(0.5, 1.9, 0.6), m_metal)
	Geo.box(self, Vector3(x0 + 0.3, y + 0.95, SHAFT_Z + 2.25), Vector3(0.5, 1.9, 0.6), m_metal)
	# Стул у стола с журналом.
	var chx := SHAFT_X + 2.2
	var chz := SHAFT_Z - 1.6
	Geo.box(self, Vector3(chx, y + 0.45, chz), Vector3(0.42, 0.04, 0.42), wood)
	Geo.box(self, Vector3(chx - 0.2, y + 0.75, chz), Vector3(0.04, 0.6, 0.42), wood, false)
	for lx in [-0.18, 0.18]:
		for lz in [-0.18, 0.18]:
			Geo.box(self, Vector3(chx + float(lx), y + 0.22, chz + float(lz)), Vector3(0.03, 0.45, 0.03), wood, false)
	Geo.label(self, Vector3(SHAFT_X, y + 2.3, z0 + 0.02), "ШАХТА № 3 — ГЛУБИНА 100 М\nСПУСК ТОЛЬКО ПО ЛЕСТНИЦЕ", 0, 30, Color(0.15, 0.15, 0.15), true)


func _room_sound(stream: AudioStream, pos: Vector3, volume_db: float) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.unit_size = 3.0
	p.max_distance = 20.0
	p.position = pos
	p.autoplay = true
	add_child(p)


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
		_add_lamp(Vector3(SHAFT_X + 0.7, ly, SHAFT_Z - 0.55), Color(1.0, 0.78, 0.5), 0.6, 7.0, mode, false)
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
	# Прямые куски трубы между развилками; сами развилки строятся через CSG.
	# Вырезаем участки под развилки и двери комнат — их строит CSG.
	var holes: Array = []
	for b in BRANCHES:
		holes.append([float(b["z"]) + JUNCTION_MAIN, float(b["z"]) - JUNCTION_MAIN])
	for r in SIDE_ROOMS:
		holes.append([float(r["z"]) + ROOM_SECTION, float(r["z"]) - ROOM_SECTION])
	holes.sort_custom(func(a, b): return a[0] > b[0])
	var zc := TUN_Z0
	for h in holes:
		_main_segment(zc, h[0])
		zc = h[1]
	_main_segment(zc, TUN_Z1)
	for r in SIDE_ROOMS:
		_build_side_room(r)
	Geo.box(self, Vector3(TUN_CX, TUBE_CY, TUN_Z1 - 0.15), Vector3(TUBE_R * 2 + 0.4, TUBE_R * 2 + 0.4, 0.3), m_concrete)
	_segments.append({"a": Vector2(TUN_CX, TUN_Z0), "b": Vector2(TUN_CX, TUN_Z1), "dir": Vector3.FORWARD})
	# Светильники в сетках на стене через 12 м, попеременно слева и справа. Часть разбита.
	var i := 0
	var z := TUN_Z0 - 5.0
	while z > GRATE_Z + 2.0:
		var mode := "ok"
		if i % 4 == 3:
			mode = "broken"
		elif i % 5 == 2:
			mode = "flicker"
		var side := -1 if i % 2 == 0 else 1
		for r in SIDE_ROOMS:
			if absf(z - float(r["z"])) < 2.5 and side == int(r["side"]):
				side = -side  # не вешать светильник в дверной проём
		var ly := FLOOR_Y + 2.45
		_add_wall_lamp(Vector3(wall_x(side, ly, 0.12), ly, z), Vector3(-side, 0, 0), mode)
		z -= 12.0
		i += 1
	# Пикеты.
	for k in [1, 3, 4]:
		var mz: float = TUN_Z0 - 40.0 * k
		var ly := FLOOR_Y + 1.6
		Geo.label(self, Vector3(wall_x(1, ly, 0.03), ly, mz), "ПК %d" % k, -90, 48, Color(0.95, 0.95, 0.9), true)


## Общая «начинка» прямого куска трубы в локальных координатах (ось по -Z, пол на y = 0).
## Труба, бетонный лоток с водоотводом, невидимые стены, кабели на кронштейнах, труба на опорах.
func _tube_piece(parent: Node3D, s0: float, s1: float, lowered := 0.0) -> void:
	var length := s1 - s0
	var mid := -(s0 + s1) / 2.0
	var tube := MeshInstance3D.new()
	tube.mesh = Geo.tube_mesh(TUBE_R, -s0, -s1, 32, -0.6, TUBE_R * TAU / 8.0, 1.0)
	tube.material_override = m_tubbing
	tube.position = Vector3(0, TUBE_CY - FLOOR_Y, 0)
	parent.add_child(tube)
	var chord := _tube_half(FLOOR_Y) * 2.0
	Geo.box(parent, Vector3(0, -0.15 - lowered, mid), Vector3(chord, 0.3, length), m_floor)
	Geo.box(parent, Vector3(-1.25, 0.003 - lowered, mid), Vector3(0.28, 0.01, length), ProcTex.flat(Color(0.06, 0.06, 0.07), 0.3), false)
	Geo.solid(parent, Vector3(-TUN_HW - 0.15, 2.0, mid), Vector3(0.3, 4.0, length))
	Geo.solid(parent, Vector3(TUN_HW + 0.15, 2.0, mid), Vector3(0.3, 4.0, length))
	var along := Basis(Vector3.RIGHT, PI / 2)
	# Справа — кабели на кронштейнах (кронштейны частые: глазу есть за что зацепиться).
	var cable := ProcTex.flat(Color(0.05, 0.05, 0.05), 0.6)
	for k in 4:
		var cy := 1.75 + k * 0.17
		Geo.cylinder(parent, Vector3(_tube_half(FLOOR_Y + cy) - 0.12, cy, mid), 0.028, length, cable, along)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.22, 0.03, 0.04)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = arm
	var count := int(length / 1.2)
	mm.instance_count = count * 4
	for i in count:
		for k in 4:
			var cy := 1.72 + k * 0.17
			mm.set_instance_transform(i * 4 + k, Transform3D(Basis.IDENTITY, Vector3(_tube_half(FLOOR_Y + cy) - 0.11, cy, -s0 - 0.6 - i * 1.2)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m_metal
	parent.add_child(mmi)
	# Слева — водопроводная труба.
	var py := 2.2
	Geo.cylinder(parent, Vector3(-(_tube_half(FLOOR_Y + py) - 0.16), py, mid), 0.09, length, m_rust, along)


func _main_segment(z_a: float, z_b: float) -> void:
	var z := z_a
	while z > z_b + 0.01:
		var z2 := maxf(z - CHUNK, z_b)
		var piece := Node3D.new()
		piece.position = Vector3(TUN_CX, FLOOR_Y, 0)
		add_child(piece)
		_tube_piece(piece, -z, -z2)
		z = z2


# --- Развилки и штольни ------------------------------------------------------

## Развилка: толстостенные трубы (основная + штольня под углом) объединяются,
## внутренние объёмы вычитаются — получается честное пересечение тоннелей.
func _build_junction(index: int) -> void:
	var b: Dictionary = BRANCHES[index]
	var zj: float = b["z"]
	var d := branch_dir(index)
	var axis := Vector3(TUN_CX, TUBE_CY, zj)
	var main_basis := Basis(Vector3.RIGHT, PI / 2)
	var branch_basis := Basis(Vector3.UP, _yaw_to(d)) * Basis(Vector3.RIGHT, -PI / 2)

	var csg := CSGCombiner3D.new()
	csg.use_collision = true
	csg.collision_layer = Geo.WALL_LAYER
	csg.collision_mask = 0
	add_child(csg)
	_csg_tube(csg, TUBE_R + WALL_T, JUNCTION_MAIN * 2.0, Transform3D(main_basis, axis), m_concrete, false)
	_csg_tube(csg, TUBE_R + WALL_T, JUNCTION_BRANCH, Transform3D(branch_basis, axis + d * (JUNCTION_BRANCH / 2.0)), m_concrete, false)
	_csg_tube(csg, TUBE_R, JUNCTION_MAIN * 2.0 + 0.04, Transform3D(main_basis, axis), m_tubbing_tri, true)
	_csg_tube(csg, TUBE_R, JUNCTION_BRANCH + 0.02, Transform3D(branch_basis, axis + d * (JUNCTION_BRANCH / 2.0 + 0.01)), m_tubbing_tri, true)

	# Пол развилки: полоса основного тоннеля и полоса штольни.
	var chord := _tube_half(FLOOR_Y) * 2.0
	Geo.box(self, Vector3(TUN_CX, FLOOR_Y - 0.15, zj), Vector3(chord, 0.3, JUNCTION_MAIN * 2.0), m_floor)
	var floor_b := Geo.box(self, branch_origin(index) + d * (JUNCTION_BRANCH / 2.0) + Vector3(0, -0.155, 0),
		Vector3(chord, 0.3, JUNCTION_BRANCH), m_floor, true, Basis(Vector3.UP, _yaw_to(d)))
	floor_b.name = "JunctionFloor%d" % index

	# Указатель на противоположной стене перед развилкой и свет.
	var side: int = b["side"]
	var word := "НАЛЕВО" if side < 0 else "НАПРАВО"
	var ly := FLOOR_Y + 2.0
	var tr := wall_mount(-1, -side, zj + JUNCTION_MAIN - 1.5, ly, 0.03)
	var sign_board := Geo.box(self, tr.origin, Vector3(1.4, 0.5, 0.03), ProcTex.flat(Color(0.12, 0.25, 0.45), 0.5), false, tr.basis)
	sign_board.name = "Sign%d" % index
	var l := Geo.label(self, tr.origin + tr.basis.z * 0.02, "%s\n%s" % [b["name"], word], 0.0, 30, Color(0.95, 0.95, 0.95), true)
	l.basis = tr.basis
	_add_lamp(Vector3(TUN_CX, TUBE_CY + TUBE_R - 0.25, zj - 2.0), Color(1.0, 0.72, 0.42), 1.1, 9.0, "ok", true)


# --- Служебные комнаты ------------------------------------------------------

## Комната сбоку от основного тоннеля: кусок трубы, дверной проём в обделке и сама комната.
func _build_side_room(r: Dictionary) -> void:
	var zr: float = r["z"]
	var side := float(r["side"])
	var axis := Vector3(TUN_CX, TUBE_CY, zr)
	var main_basis := Basis(Vector3.RIGHT, PI / 2)
	var room_basis := Basis(Vector3.UP, atan2(-side, 0.0))  # +Z комнаты — к тоннелю
	var center := Vector3(TUN_CX + side * (TUBE_R + WALL_T + ROOM_D / 2), FLOOR_Y, zr)
	var csg := _new_csg()
	_csg_tube(csg, TUBE_R + WALL_T, ROOM_SECTION * 2, Transform3D(main_basis, axis), m_concrete, false)
	_csg_room(csg, center, room_basis)
	_csg_tube(csg, TUBE_R, ROOM_SECTION * 2 + 0.04, Transform3D(main_basis, axis), m_tubbing_tri, true)
	var d_in := 1.4
	var d_out := TUBE_R + WALL_T + 0.1
	_csg_box(csg, Vector3(d_out - d_in, 2.2, 1.3), Transform3D(Basis.IDENTITY, Vector3(TUN_CX + side * (d_in + d_out) / 2, FLOOR_Y + 1.1, zr)), m_concrete, true)
	var chord := _tube_half(FLOOR_Y) * 2.0
	Geo.box(self, Vector3(TUN_CX, FLOOR_Y - 0.15, zr), Vector3(chord, 0.3, ROOM_SECTION * 2), m_floor)
	Geo.box(self, Vector3(TUN_CX + side * 1.95, FLOOR_Y - 0.152, zr), Vector3(1.3, 0.3, 1.3), m_floor)
	_room_floor(center, room_basis)
	rooms.append({"center": center, "basis": room_basis,
		"door": Transform3D(room_basis, Vector3(TUN_CX + side * (TUBE_R + WALL_T - 0.05), FLOOR_Y, zr))})


## Комната в тупике штольни: торец трубы с дверью и комната за ним.
func _build_end_room(index: int) -> void:
	var length: float = BRANCHES[index]["length"]
	var d := branch_dir(index)
	var origin := branch_origin(index)
	var yaw := _yaw_to(d)
	var room_basis := Basis(Vector3.UP, yaw)  # +Z — обратно по штольне, к двери
	var axis := origin + Vector3(0, TUBE_CY - FLOOR_Y, 0)
	var pipe := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI / 2)
	var center := origin + d * (length + WALL_T + ROOM_D / 2)
	var csg := _new_csg()
	# Наружная труба заходит на толщину стенки дальше — получается глухой торец.
	_csg_tube(csg, TUBE_R + WALL_T, ROOM_SECTION + WALL_T, Transform3D(pipe, axis + d * (length - ROOM_SECTION / 2 + WALL_T / 2)), m_concrete, false)
	_csg_room(csg, center, room_basis)
	_csg_tube(csg, TUBE_R, ROOM_SECTION + 0.02, Transform3D(pipe, axis + d * (length - ROOM_SECTION / 2 - 0.01)), m_tubbing_tri, true)
	_csg_box(csg, Vector3(1.3, 2.2, 0.8), Transform3D(room_basis, origin + d * (length + WALL_T / 2) + Vector3(0, 1.1, 0)), m_concrete, true)
	var chord := _tube_half(FLOOR_Y) * 2.0
	Geo.box(self, origin + d * (length - ROOM_SECTION / 2) + Vector3(0, -0.155, 0), Vector3(chord, 0.3, ROOM_SECTION), m_floor, true, room_basis)
	Geo.box(self, origin + d * (length + 0.15) + Vector3(0, -0.152, 0), Vector3(1.3, 0.3, 0.8), m_floor, true, room_basis)
	_room_floor(center, room_basis)
	rooms.append({"center": center, "basis": room_basis,
		"door": Transform3D(room_basis, origin + d * (length + WALL_T - 0.05))})


func _csg_room(csg: Node, center: Vector3, basis: Basis) -> void:
	var c := center + Vector3(0, ROOM_H / 2, 0)
	_csg_box(csg, Vector3(ROOM_W + WALL_T * 2, ROOM_H + WALL_T * 2, ROOM_D + WALL_T * 2), Transform3D(basis, c), m_concrete, false)
	_csg_box(csg, Vector3(ROOM_W, ROOM_H, ROOM_D), Transform3D(basis, c), m_room, true)


func _room_floor(center: Vector3, basis: Basis) -> void:
	Geo.box(self, center + Vector3(0, -0.15, 0), Vector3(ROOM_W, 0.3, ROOM_D), m_floor, true, basis)


func _new_csg() -> CSGCombiner3D:
	var csg := CSGCombiner3D.new()
	csg.use_collision = true
	csg.collision_layer = Geo.WALL_LAYER
	csg.collision_mask = 0
	add_child(csg)
	return csg


func _csg_box(parent: Node, size: Vector3, xf: Transform3D, mat: Material, subtract: bool) -> void:
	var b := CSGBox3D.new()
	b.size = size
	b.material = mat
	b.transform = xf
	if subtract:
		b.operation = CSGShape3D.OPERATION_SUBTRACTION
	parent.add_child(b)


func _csg_tube(parent: Node, radius: float, height: float, xf: Transform3D, mat: Material, subtract: bool) -> void:
	var c := CSGCylinder3D.new()
	c.radius = radius
	c.height = height
	c.sides = 32
	c.smooth_faces = true
	c.material = mat
	c.transform = xf
	if subtract:
		c.operation = CSGShape3D.OPERATION_SUBTRACTION
	parent.add_child(c)


func _build_branch(index: int) -> void:
	var b: Dictionary = BRANCHES[index]
	var length: float = b["length"]
	var d := branch_dir(index)
	var origin := branch_origin(index)
	var yaw := _yaw_to(d)
	# Прямая часть штольни — те же куски трубы, что и в основном тоннеле, повёрнутые по оси штольни.
	var s := JUNCTION_BRANCH
	var straight_end := length - ROOM_SECTION
	while s < straight_end - 0.01:
		var s2 := minf(s + CHUNK, straight_end)
		var piece := Node3D.new()
		piece.transform = Transform3D(Basis(Vector3.UP, yaw), origin)
		add_child(piece)
		_tube_piece(piece, s, s2, 0.005)
		s = s2
	var end := origin + d * length
	_build_end_room(index)
	# Обвалившийся грунт у стены перед дверью.
	var r := _right_of(d)
	for k in 5:
		var rp := end - d * randf_range(0.6, 3.0) + r * (1.1 if k % 2 == 0 else -1.1) + Vector3(0, 0.15, 0)
		var rock := Geo.box(self, rp, Vector3.ONE * randf_range(0.25, 0.5), m_concrete, false)
		rock.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	# В штольнях почти все светильники разбиты.
	var ld := JUNCTION_BRANCH + 4.0
	var n := 0
	while ld < length - 3.0:
		var ly := FLOOR_Y + 2.45
		var tr := wall_mount(index, -1, ld, ly, 0.12)
		_add_wall_lamp(tr.origin, tr.basis.z, "flicker" if n == 0 else "broken")
		ld += 14.0
		n += 1
	_segments.append({"a": Vector2(origin.x, origin.z), "b": Vector2(end.x, end.z), "dir": d})


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


## Тоннельный светильник в сетке на стене. inward — куда смотрит (внутрь тоннеля).
func _add_wall_lamp(pos: Vector3, inward: Vector3, mode: String) -> void:
	var basis := Basis(Vector3.UP, atan2(inward.x, inward.z))
	Geo.box(self, pos - inward * 0.05, Vector3(0.25, 0.3, 0.06), m_metal, false, basis)
	var cage := ProcTex.flat(Color(0.15, 0.15, 0.15), 0.5, 0.8)
	for k in 3:
		Geo.box(self, pos + inward * 0.06 + Vector3(0, -0.1 + k * 0.1, 0), Vector3(0.2, 0.012, 0.012), cage, false, basis)
	_add_lamp(pos + inward * 0.04 + Vector3(0, 0.05, 0), Color(1.0, 0.74, 0.45), 1.1, 9.0, mode, true, false)


func _add_lamp(pos: Vector3, color: Color, energy: float, light_range: float, mode: String, tunnel: bool, fixture := true) -> void:
	if fixture:
		Geo.box(self, pos + Vector3(0, 0.06, 0), Vector3(0.3, 0.08, 0.3), m_metal, false)
	var bulb_mat := ProcTex.emissive(color, 3.0)
	Geo.sphere(self, pos - Vector3(0, 0.05, 0), 0.07, bulb_mat)
	var light := OmniLight3D.new()
	light.position = pos - Vector3(0, 0.25, 0)
	light.light_color = color
	light.omni_range = light_range
	light.light_energy = energy
	light.omni_attenuation = 1.5
	light.add_to_group("fear_light")
	add_child(light)
	if mode == "broken":
		bulb_mat.emission_enabled = false
		bulb_mat.albedo_color = Color(0.15, 0.15, 0.15)
	lamps.append({"light": light, "mat": bulb_mat, "energy": energy, "mode": mode, "tunnel": tunnel, "t": randf() * 10.0})
