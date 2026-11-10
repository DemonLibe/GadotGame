class_name Level
extends Node3D
## Геометрия «Тихой»: комната с люком наверху → шахта с лестницей (100 м) → станция на одну вагонетку
## (это всё постоянное) → сеть тоннелей, которая каждую смену собирается заново по своему зерну:
## основной тоннель из чугунных тюбингов (около 2,5 км до решётки), 10–15 служебных штолен под острым углом,
## у части штолен — свои ответвления, служебные комнаты, генераторные с резервными дизелями и пролом в старую линию.

const FLOOR_Y := -15.0       # пол станции и тоннеля
const TUN_CX := 1.2          # ось основного тоннеля (по ней идут рельсы)
const TUN_HW := 1.7          # полуширина прохода (невидимые стены)
const TUN_H := 3.2
const LEFT_X := -0.5         # TUN_CX - TUN_HW
const RIGHT_X := 2.9         # TUN_CX + TUN_HW
const TUN_Z0 := -50.0        # портал тоннеля на станции
const PICKET_STEP := 25.0    # пикеты (таблички «ПК n») по основному тоннелю
const RAIL_TILE := 2.0       # длина звена пути
const CHUNK := 14.0          # длина куска геометрии (лимит ламп на объект в браузере)
const TUBE_R := 2.1          # радиус трубы тоннеля
const TUBE_CY := FLOOR_Y + 1.2
const JUNCTION_MAIN := 8.0   # развилка: ± столько метров основного тоннеля строится через CSG
const JUNCTION_BRANCH := 10.0  # ...и столько метров штольни от оси тоннеля
const WALL_T := 0.3          # толщина обделки (для CSG-развилок)
const ROOM_SECTION := 4.0    # ± столько метров трубы у двери в комнату строится через CSG
const ROOM_W := 3.4          # служебная комната: ширина, глубина, высота (по умолчанию)
const ROOM_D := 3.4
const ROOM_H := 2.6
## Сюжетные комнаты (0–2 — сбоку от тоннеля, 3–5 — в тупиках первых штолен):
## назначение, ширина, глубина, высота, стены, пол. Остальные комнаты берут отделку отсюда же наугад.
const ROOM_KINDS := [
	{"theme": "bytovka", "w": 5.0, "d": 4.4, "h": 2.8, "wall": "plaster_peeling", "floor": "linoleum"},
	{"theme": "sklad", "w": 4.6, "d": 5.4, "h": 3.0, "wall": "concrete_wet", "floor": "concrete_floor_cracked"},
	{"theme": "workshop", "w": 6.0, "d": 4.4, "h": 3.0, "wall": "brick_soot", "floor": "concrete_floor_cracked"},
	{"theme": "medpunkt", "w": 4.4, "d": 5.0, "h": 2.7, "wall": "tile_green", "floor": "tile_white_clean"},
	{"theme": "shield", "w": 5.2, "d": 4.6, "h": 3.0, "wall": "concrete", "floor": "rubber_mat"},
	{"theme": "office", "w": 4.8, "d": 4.8, "h": 2.7, "wall": "wood_planks_dark", "floor": "linoleum"},
]
## Генераторная: проём без двери, внутри резервный дизель.
const GEN_KIND := {"theme": "genroom", "w": 4.4, "d": 4.0, "h": 3.0, "wall": "concrete", "floor": "rubber_mat"}

## Сеть по старой схеме (322 м до решётки): по ней размечены мел, гнездо, ограждения смен и прочее.
## map_z() переводит такую отметку в нынешнюю сеть — пропорционально до решётки, за ней — как есть.
const OLD_TUN_Z1 := -372.5
const OLD_GRATE_Z := -323.0
## Размер сети: основной тоннель до решётки, число штолен, их длина, ответвления.
const TRUNK_LEN := Vector2(2250.0, 2600.0)
const BRANCH_COUNT := Vector2i(10, 15)
const BRANCH_LEN := Vector2(60.0, 180.0)
const SUB_LEN := Vector2(30.0, 90.0)
const CLEAR := 10.0          # минимальный зазор между осями непересекающихся проходов

const OLD_BREACH_W := 2.2        # ширина пролома в старую линию
const OLD_BREACH_H := 2.4

const SHAFT_X := -1.6        # центр шахты
const SHAFT_Z := -32.0
const SHAFT_HALF := 0.9
const ROOM_Y := 85.0         # пол комнаты с люком

## Текущая сеть (меняется каждую смену; статические — чтобы их видели все системы как Level.X).
static var GRATE_Z := -323.0     # решётка
static var TUN_Z1 := -372.5      # тупик (до седьмой смены — глухая стена)
static var METRO_Z1 := -425.0    # за стеной — старый перегон метро, где стоит вагон (седьмая смена)
static var OLD_BREACH_Z := -110.0  # пролом в правой стене тоннеля — ход в старую линию (с третьей по шестую смену)
static var BREACH_PK := 2        # у какого пикета пролом
## Штольни: {z — точка на основном тоннеле, от которой растёт ветка (у ответвлений — их корня), side, angle,
## length, name, parent (-1 — основной тоннель, иначе индекс штольни), s — где на родителе развилка,
## origin, dir, room (есть ли комната в тупике)}. Сначала основные (по глубине), потом ответвления.
static var BRANCHES: Array = []
## Комнаты сбоку от основного тоннеля: {z, side, kind, gen}.
static var SIDE_ROOMS: Array = []

var lamps: Array[Dictionary] = []
var tunnel_lights_off := false
var power_on := true  # генераторы: без них лампы в тоннелях не горят
var blackout := false
var grate: Node3D
var _end_wall: MeshInstance3D   # глухая стена тупика
var _breach: Node3D             # пролом на её месте (седьмая смена)
var _main_seg := 0              # индекс основного тоннеля в _segments
var lower: LowerLine            # старая линия рядом с тоннелем (собирается заново каждую смену)
var _old_plug: Node3D           # кладка, которой пролом заложен, пока старая линия закрыта
var pickets: Array[Label3D] = []  # таблички «ПК n» (номер может «поменяться», пока стоишь спиной)
var rooms: Array[Dictionary] = []  # {center, basis, door, kind, gen}: basis +Z смотрит из комнаты к двери
var story_rooms: Array[int] = []   # сюжетная комната k (0–5) → индекс в rooms
var gen_rooms: Array[int] = []     # генераторные (индексы в rooms)
var _segments: Array[Dictionary] = []  # оси проходов {a, b, dir} в XZ: 0 — основной тоннель, i + 1 — штольня i
var _holes := {}                # участки проходов, построенные через CSG: tunnel → [[от, до, сторона]]
var net: Node3D                 # вся сеть тоннелей (пересобирается каждую смену)
var net_seed := 0
var hidden_branch := -1         # потайная штольня (индекс в BRANCHES) или -1
var hidden_open := false
var _plug: Node3D               # тюбинг, которым она «заложена», пока её нет
var _into: Node3D               # куда сейчас строим: self (постоянное) или net
var _static_lamps := 0
var rng := RandomNumberGenerator.new()

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
	_into = self
	_build_room()
	_build_shaft()
	_build_station()
	_static_lamps = lamps.size()
	lower = LowerLine.new()
	add_child(lower)
	net = Node3D.new()
	net.name = "Net"
	add_child(net)


## Собрать сеть тоннелей заново по зерну (после провала смены — то же зерно, та же сеть).
func generate_network(seed_value: int) -> void:
	net_seed = seed_value
	rng.seed = seed_value
	for c in net.get_children():
		net.remove_child(c)
		c.queue_free()
	lamps.resize(_static_lamps)
	pickets.clear()
	rooms.clear()
	story_rooms.clear()
	gen_rooms.clear()
	_segments.clear()
	_holes.clear()
	_plug = null
	hidden_open = false
	_plan()
	_into = net
	_build_main_tunnel()
	for i in BRANCHES.size():
		_build_junction(i)
		_build_branch(i)
	_build_rails()
	_build_grate()
	_build_nest_decor()
	_build_breach()
	_into = self
	_assign_story_rooms()


# --- План сети ---------------------------------------------------------------

var _obstacles: Array = []   # круги, куда нельзя вести проходы: [центр Vector2, радиус]
var _forbidden: Array[Rect2] = []


## Отметка старой схемы → нынешняя сеть.
static func map_z(z: float) -> float:
	if z >= TUN_Z0:
		return z
	if z >= OLD_GRATE_Z:
		return TUN_Z0 + (z - TUN_Z0) * (TUN_Z0 - GRATE_Z) / (TUN_Z0 - OLD_GRATE_Z)
	return GRATE_Z + (z - OLD_GRATE_Z)


func _plan() -> void:
	var length := rng.randf_range(TRUNK_LEN.x, TRUNK_LEN.y)
	GRATE_Z = TUN_Z0 - length
	TUN_Z1 = GRATE_Z + (OLD_TUN_Z1 - OLD_GRATE_Z)
	METRO_Z1 = TUN_Z1 - 52.5
	BRANCHES = []
	SIDE_ROOMS = []
	_obstacles = []
	_forbidden = []
	var trunk_used: Array = []  # занятые участки основного тоннеля [верх, низ]
	# Пролом в старую линию — там же, где по старой схеме (у пятой части пути), чуть гуляет.
	OLD_BREACH_Z = snappedf(map_z(-110.0) + rng.randf_range(-20.0, 20.0), 0.5)
	BREACH_PK = int(round((TUN_Z0 - OLD_BREACH_Z) / PICKET_STEP))
	LowerLine.place(OLD_BREACH_Z)
	trunk_used.append([OLD_BREACH_Z + ROOM_SECTION + 4.0, OLD_BREACH_Z - ROOM_SECTION - 4.0])
	_forbidden.append(LowerLine.footprint().grow(6.0))
	_forbidden.append(Rect2(-25.0, -70.0, 50.0, 70.0))  # станция
	# Комнаты сбоку: три сюжетные — у каждой своя глубина (открываются в 1-ю, 2-ю и 4-ю смены),
	# генераторные — равномерно по тоннелю, и ещё несколько закрытых.
	var plans := [[0.07, 0.2, ROOM_KINDS[0], false], [0.3, 0.5, ROOM_KINDS[1], false], [0.58, 0.9, ROOM_KINDS[2], false]]
	var gens := clampi(int(round(length / 650.0)), 3, 4)
	for g in gens:
		var f := (g + 0.6) / float(gens)
		plans.append([f - 0.12, minf(f + 0.05, 0.97), GEN_KIND, true])
	for k in rng.randi_range(3, 5):
		plans.append([0.05, 0.97, ROOM_KINDS[rng.randi_range(0, ROOM_KINDS.size() - 1)], false])
	for pn in plans.size():
		var pl: Array = plans[pn]
		for attempt in 40:
			var z := snappedf(TUN_Z0 - length * rng.randf_range(float(pl[0]), float(pl[1])), 0.5)
			var side := 1 if rng.randf() < 0.5 else -1
			var kind: Dictionary = pl[2]
			if not _trunk_free(trunk_used, z + ROOM_SECTION + 2.0, z - ROOM_SECTION - 2.0):
				continue
			var c := Vector2(TUN_CX + side * (TUBE_R + WALL_T + float(kind["d"]) / 2.0), z)
			var r := maxf(float(kind["w"]), float(kind["d"])) * 0.75 + 1.5
			if _blocked(c, r):
				continue
			trunk_used.append([z + ROOM_SECTION + 2.0, z - ROOM_SECTION - 2.0])
			_obstacles.append([c, r])
			SIDE_ROOMS.append({"z": z, "side": side, "kind": kind, "gen": pl[3], "story": pn if pn < 3 else -1})
			break
	# Основные штольни.
	var segs: Array = [[Vector2(TUN_CX, TUN_Z0), Vector2(TUN_CX, GRATE_Z - 110.0), -2]]  # [a, b, индекс ветки]
	var want := rng.randi_range(BRANCH_COUNT.x, BRANCH_COUNT.y)
	var prim: Array = []
	for attempt in 600:
		if prim.size() >= want:
			break
		var depth := rng.randf_range(70.0, length - 45.0)
		var z := snappedf(TUN_Z0 - depth, 0.5)
		if not _trunk_free(trunk_used, z + JUNCTION_MAIN + 5.0, z - JUNCTION_MAIN - 5.0):
			continue
		var side := 1 if rng.randf() < 0.5 else -1
		var angle := rng.randf_range(25.0, 55.0)
		var blen := snappedf(rng.randf_range(BRANCH_LEN.x, BRANCH_LEN.y), 0.5)
		var d := _turn(Vector3.FORWARD, side, angle)
		var o := Vector3(TUN_CX, FLOOR_Y, z)
		if not _path_clear(o, d, blen + 9.0, angle, segs, -2):
			continue
		trunk_used.append([z + JUNCTION_MAIN + 5.0, z - JUNCTION_MAIN - 5.0])
		var b := {"z": z, "side": side, "angle": angle, "length": blen, "parent": -1, "s": z, "origin": o, "dir": d, "room": false}
		prim.append(b)
		segs.append([Vector2(o.x, o.z), Vector2(o.x, o.z) + Vector2(d.x, d.z) * (blen + 9.0), -1])
	prim.sort_custom(func(a, b): return float(a["z"]) > float(b["z"]))
	# Одна штольня — «потайная»: её то нет (сплошной тюбинг), то она есть. Не из первых трёх, без комнаты.
	hidden_branch = -1
	var cand: Array = []
	for i in range(3, prim.size()):
		cand.append(i)
	if not cand.is_empty():
		hidden_branch = cand[rng.randi_range(0, cand.size() - 1)]
	var number := 1
	for i in prim.size():
		prim[i]["hidden"] = i == hidden_branch
		if i == hidden_branch:
			prim[i]["name"] = "ШТОЛЬНЯ"
		else:
			prim[i]["name"] = "ШТОЛЬНЯ %d" % number
			number += 1
		prim[i]["room"] = (i < 3 or rng.randf() < 0.45) and i != hidden_branch
		prim[i]["kind"] = ROOM_KINDS[3 + i] if i < 3 else ROOM_KINDS[rng.randi_range(0, ROOM_KINDS.size() - 1)]
		BRANCHES.append(prim[i])
	segs = [segs[0]]
	for i in prim.size():
		var o: Vector3 = prim[i]["origin"]
		var d: Vector3 = prim[i]["dir"]
		segs.append([Vector2(o.x, o.z), Vector2(o.x, o.z) + Vector2(d.x, d.z) * (float(prim[i]["length"]) + 9.0), i])
	# Ответвления от основных штолен.
	var letters := ["А", "Б", "В"]
	for pi in prim.size():
		var parent: Dictionary = BRANCHES[pi]
		if parent.get("hidden", false):
			continue
		var used: Array = []
		var count := 0
		var tries := rng.randi_range(0, 2)
		for attempt in tries * 12:
			if count >= tries:
				break
			var plen: float = parent["length"]
			var s := snappedf(rng.randf_range(JUNCTION_BRANCH + JUNCTION_MAIN + 6.0, plen - ROOM_SECTION - JUNCTION_MAIN - 8.0), 0.5)
			if s < JUNCTION_BRANCH + JUNCTION_MAIN + 6.0:
				break
			var free := true
			for u in used:
				free = free and absf(s - float(u)) > JUNCTION_MAIN * 2.0 + 10.0
			if not free:
				continue
			var side := 1 if rng.randf() < 0.5 else -1
			var angle := rng.randf_range(30.0, 60.0)
			var d := _turn(parent["dir"], side, angle)
			var o: Vector3 = parent["origin"] + (parent["dir"] as Vector3) * s
			var slen := snappedf(rng.randf_range(SUB_LEN.x, SUB_LEN.y), 0.5)
			if not _path_clear(o, d, slen + 9.0, angle, segs, pi):
				continue
			used.append(s)
			var b := {"z": parent["z"], "side": side, "angle": angle, "length": slen, "parent": pi, "s": s, "origin": o, "dir": d,
				"room": rng.randf() < 0.3, "name": "%s-%s" % [parent["name"], letters[count]],
				"kind": ROOM_KINDS[rng.randi_range(0, ROOM_KINDS.size() - 1)]}
			BRANCHES.append(b)
			segs.append([Vector2(o.x, o.z), Vector2(o.x, o.z) + Vector2(d.x, d.z) * (slen + 9.0), BRANCHES.size() - 1])
			count += 1


func _trunk_free(used: Array, hi: float, lo: float) -> bool:
	for u in used:
		if hi > float(u[1]) and lo < float(u[0]):
			return false
	return true


## Направление, повёрнутое от d на angle градусов в сторону side (+1 — вправо, если смотреть по d).
static func _turn(d: Vector3, side: int, angle: float) -> Vector3:
	var a := deg_to_rad(angle)
	return (d * cos(a) + _right_of(d) * (side * sin(a))).normalized()


func _blocked(p: Vector2, r: float) -> bool:
	for f in _forbidden:
		if f.grow(r).has_point(p):
			return true
	for o in _obstacles:
		if p.distance_to(o[0]) < float(o[1]) + r:
			return true
	return false


## Свободен ли путь новой штольни: не ближе CLEAR к другим проходам (у родителя — после выхода из развилки),
## не в запретных зонах (станция, старая линия) и не через комнаты.
func _path_clear(o: Vector3, d: Vector3, length: float, angle: float, segs: Array, parent: int) -> bool:
	var start := Vector2(o.x, o.z)
	var dir := Vector2(d.x, d.z)
	var leave := CLEAR / maxf(sin(deg_to_rad(angle)), 0.3) + 4.0  # пока ветка не отошла от родителя
	var s := 4.0
	while s <= length:
		var q := start + dir * s
		if _blocked(q, 4.0):
			return false
		for sg in segs:
			var mine := int(sg[2]) == parent
			if mine and s < leave:
				continue
			var near := Geometry2D.get_closest_point_to_segment(q, sg[0], sg[1])
			if q.distance_to(near) < CLEAR:
				# Своя развилка: точка у самого начала родителя не считается.
				if mine and near.distance_to(start) < 1.0:
					continue
				return false
		s += 3.0
	return true


## Сюжетные комнаты: 0–2 — у тоннеля (первые три запланированные), 3–5 — в тупиках трёх первых штолен.
func _assign_story_rooms() -> void:
	story_rooms.clear()
	for k in 6:
		story_rooms.append(-1)
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		if r.has("story") and int(r["story"]) >= 0:
			story_rooms[int(r["story"])] = i
	for k in 6:
		if story_rooms[k] < 0:
			story_rooms[k] = clampi(k, 0, rooms.size() - 1)


func _process(delta: float) -> void:
	_time += delta
	var cam := get_viewport().get_camera_3d()
	if cam:
		_cam_pos = cam.global_position
	_update_extra_lights()
	_update_lightning(delta)
	for l in lamps:
		var light: OmniLight3D = l["light"]
		var mat: StandardMaterial3D = l["mat"]
		var mode: String = l["mode"]
		var on: bool = mode != "broken" and not blackout and not (l["tunnel"] and (tunnel_lights_off or not power_on)) \
			and not l.get("off", false)
		var f := 1.0 if on else 0.0
		if on and mode == "flicker":
			var phase: float = l["t"]
			if sin(_time * 13.0 + phase) + sin(_time * 7.3 + phase * 2.0) < -1.1:
				f = 0.05
		light.light_energy = float(l["energy"]) * f
		light.visible = f > 0.0 and _near_camera(light.global_position)
		mat.emission_energy_multiplier = 3.0 * f


## В браузерном рендере данные о всех включённых источниках света уходят в шейдер одним блоком
## ограниченного размера; если их слишком много, весь кадр выходит чёрным. Поэтому далёкие лампы гасим.
const LIGHT_CULL_DISTANCE := 32.0
var _cam_pos := Vector3.ZERO


func _near_camera(p: Vector3) -> bool:
	return p.distance_squared_to(_cam_pos) < LIGHT_CULL_DISTANCE * LIGHT_CULL_DISTANCE


func _update_extra_lights() -> void:
	# Прочие постоянные огоньки (зарядки, монитор, фонари в комнатах) — тоже только поблизости.
	for n in get_tree().get_nodes_in_group("cull_light"):
		var l := n as Light3D
		if l:
			l.visible = _near_camera(l.global_position)


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

## Есть ток, пока работает хоть один генератор (главный на станции или резервный в генераторной).
func refresh_power() -> void:
	var on := false
	for g in get_tree().get_nodes_in_group("generators"):
		if g.running and not g.is_queued_for_deletion():
			on = true
	power_on = on


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


## Обе точки на одном ярусе: станция с тоннелями или старая линия под ней (шум сквозь тридцать метров грунта не слышен).
func same_floor(a: Vector3, b: Vector3) -> bool:
	if lower.contains(a) == lower.contains(b):
		return true
	# У пролома слышно и в тоннеле, и в старой линии.
	var m := Vector2(LowerLine.MOUTH.x + 4.0, LowerLine.MOUTH.z)
	return Vector2(a.x, a.z).distance_to(m) < 10.0 or Vector2(b.x, b.z).distance_to(m) < 10.0


## Точка внутри станции или тоннелей (для появления «Другого»).
func is_walkable(p: Vector3) -> bool:
	if lower.contains(p):
		return lower.is_walkable(p)
	if lower.in_passage(p):
		return true
	if p.y > FLOOR_Y + 5.0:
		return false
	if Rect2(-3.0, -50.0, 6.0, 20.0).has_point(Vector2(p.x, p.z)):
		return true
	return _nearest_segment(p).get("dist", INF) < TUN_HW


## Следующая точка пути из from в to: если они в разных проходах — сначала к развилке.
## Проходы: 0 — станция и основной тоннель, 1..3 — штольни.
func next_waypoint(from: Vector3, to: Vector3) -> Vector3:
	var fl := lower.contains(from)
	var tl := lower.contains(to)
	if fl and tl:
		return lower.next_waypoint(from, to)
	var entry := lower.center(LowerLine.ENTRY)
	var mouth := Vector3(LowerLine.MOUTH.x, from.y, LowerLine.MOUTH.z)
	if fl:
		# Из старой линии в тоннель: к входной клетке, потом по ходу к пролому.
		return lower.next_waypoint(from, entry) if lower.cell_of(from) != LowerLine.ENTRY else mouth
	if lower.in_passage(from):
		return entry if tl else mouth
	if tl:
		# Из тоннеля в старую линию: по тоннелю к пролому, от него — в ход.
		if Vector2(from.x, from.z).distance_to(Vector2(mouth.x, mouth.z)) < 0.8:
			return entry
		return next_waypoint(from, mouth)
	var cur := _segment_index(from)
	var goal := _segment_index(to)
	# Сеть — дерево: идём вверх до общей развилки, потом вниз к цели.
	for guard in 12:
		if cur == goal:
			return to
		var chain: Array[int] = []
		var x := goal
		while x >= 0:
			chain.append(x)
			x = _seg_parent(x)
		var nxt := _seg_parent(cur)
		var junction: Vector2 = _segments[cur]["a"]
		var at := chain.find(cur)
		if at > 0:
			nxt = chain[at - 1]
			junction = _segments[nxt]["a"]
		var j := Vector3(junction.x, from.y, junction.y)
		if from.distance_to(j) > 0.6:
			return j
		cur = nxt
	return to


## Родитель прохода в _segments: основной тоннель — корень.
func _seg_parent(i: int) -> int:
	if i <= 0:
		return -1
	return int(BRANCHES[i - 1]["parent"]) + 1


func _segment_index(p: Vector3) -> int:
	if Rect2(-3.0, -50.0, 6.0, 20.0).has_point(Vector2(p.x, p.z)):
		return 0
	var q := Vector2(p.x, p.z)
	var best := 0
	var best_d := INF
	for i in _segments.size():
		var d := q.distance_to(Geometry2D.get_closest_point_to_segment(q, _segments[i]["a"] as Vector2, _segments[i]["b"] as Vector2))
		if d < best_d:
			best_d = d
			best = i
	return best


## Направление прохода, в котором стоит точка (основной тоннель или штольня).
func axis_at(p: Vector3) -> Vector3:
	if lower.contains(p):
		return lower.axis_at(p)
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


## Ось штольни: направление (горизонтальное) и начало (точка развилки на оси родителя).
static func branch_dir(index: int) -> Vector3:
	return BRANCHES[index]["dir"]


static func branch_origin(index: int) -> Vector3:
	return BRANCHES[index]["origin"]


## Глубина корня штольни на основном тоннеле (z развилки) — по ней открываются участки сети.
static func branch_root_z(index: int) -> float:
	return float(BRANCHES[index]["z"])


## Свободна ли стена в этом месте (не развилка, не дверь, не пролом). side: -1/+1 — стена, 0 — обе.
func is_plain(tunnel: int, along: float, side := 0, margin := 2.0) -> bool:
	if tunnel >= 0:
		var b: Dictionary = BRANCHES[tunnel]
		var tail := ROOM_SECTION + 1.0 if b["room"] else 1.5
		if along < JUNCTION_BRANCH + margin or along > float(b["length"]) - tail - margin:
			return false
	elif along > TUN_Z0 - margin or along < METRO_Z1 + margin:
		return false
	for h in _holes.get(tunnel, []):
		if along < float(h[1]) + margin and along > float(h[0]) - margin and (side == 0 or int(h[2]) == 0 or int(h[2]) == side):
			return false
	return true


## Ближайшая к along свободная стена (ищет в обе стороны).
func plain_along(tunnel: int, along: float, side := 0, margin := 2.0) -> float:
	for k in 200:
		for sgn in [1.0, -1.0]:
			var a := along + float(sgn) * k * 0.5
			if is_plain(tunnel, a, side, margin):
				return a
	return along


## Длина прохода: основной тоннель — до решётки, штольня — её длина.
func tunnel_length(tunnel: int) -> float:
	return TUN_Z0 - GRATE_Z if tunnel < 0 else float(BRANCHES[tunnel]["length"])


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


## Новая смена — таблички пикетов снова со своими номерами.
func reset_pickets() -> void:
	for pk in pickets:
		pk.text = "ПК %d" % int(pk.get_meta("number"))


func set_grate_open(open: bool) -> void:
	grate.rotation.y = deg_to_rad(85.0) if open else 0.0


## Седьмая смена: обвал пятой ночи проломил стену тупика — за ней старый перегон метро.
func set_breach(open: bool) -> void:
	_end_wall.visible = not open
	(_end_wall.get_child(0) as StaticBody3D).collision_layer = 0 if open else 1
	_breach.visible = open
	for body in _breach.find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).collision_layer = 1 if open else 0
	_segments[_main_seg]["b"] = Vector2(TUN_CX, METRO_Z1 + 1.0 if open else TUN_Z1)


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
	Geo.box(_into, Vector3(SHAFT_X, y - 0.15, (z0 + hz0) / 2), Vector3(7.6, 0.3, hz0 - z0), lino)
	Geo.box(_into, Vector3(SHAFT_X, y - 0.15, (hz1 + z1) / 2), Vector3(7.6, 0.3, z1 - hz1), lino)
	Geo.box(_into, Vector3((x0 - 0.3 + hx0) / 2, y - 0.15, SHAFT_Z), Vector3(hx0 - x0 + 0.3, 0.3, SHAFT_HALF * 2), lino)
	Geo.box(_into, Vector3((hx1 + x1 + 0.3) / 2, y - 0.15, SHAFT_Z), Vector3(x1 + 0.3 - hx1, 0.3, SHAFT_HALF * 2), lino)
	# Предупреждающая разметка вокруг люка.
	var hazard := ProcTex.hazard()
	Geo.box(_into, Vector3(SHAFT_X, y + 0.004, hz0 - 0.1), Vector3(2.2, 0.008, 0.2), hazard, false)
	Geo.box(_into, Vector3(SHAFT_X, y + 0.004, hz1 + 0.1), Vector3(2.2, 0.008, 0.2), hazard, false)
	Geo.box(_into, Vector3(hx0 - 0.1, y + 0.004, SHAFT_Z), Vector3(0.2, 0.008, 1.8), hazard, false)
	Geo.box(_into, Vector3(hx1 + 0.1, y + 0.004, SHAFT_Z), Vector3(0.2, 0.008, 1.8), hazard, false)
	# Ограждение люка с боков (спереди — лестница, сзади — крышка на петлях).
	var red := ProcTex.flat(Color(0.6, 0.1, 0.07), 0.6, 0.3)
	for cx in [hx0 - 0.15, hx1 + 0.15]:
		for cz in [hz0 - 0.15, hz1 + 0.15]:
			Geo.cylinder(_into, Vector3(float(cx), y + 0.5, float(cz)), 0.03, 1.0, red)
		for ry in [0.5, 0.95]:
			Geo.box(_into, Vector3(float(cx), y + float(ry), SHAFT_Z), Vector3(0.04, 0.04, 2.1), red, false)
		Geo.solid(_into, Vector3(float(cx), y + 0.5, SHAFT_Z), Vector3(0.1, 1.0, 2.1))
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
		Geo.box(_into, Vector3(p.x, y + 0.7, p.z), Vector3(sz.x, 1.4, sz.z), green)
		Geo.box(_into, Vector3(p.x, y + 2.2, p.z), Vector3(sz.x, 1.6, sz.z), white, false)
		Geo.box(_into, Vector3(p.x, y + 1.4, p.z) + inward, Vector3(maxf(sz.x, 0.3), 0.04, maxf(sz.z, 0.3)), stripe, false)
		Geo.box(_into, Vector3(p.x, y + 0.05, p.z) + inward * 2.5, Vector3(maxf(sz.x, 0.3), 0.1, maxf(sz.z, 0.3)), dark, false)
	Geo.box(_into, Vector3(SHAFT_X, y + h + 0.15, SHAFT_Z), Vector3(7.6, 0.3, 7.6), m_concrete)
	# Трубы под потолком.
	var along_x := Basis(Vector3.FORWARD, PI / 2)
	Geo.cylinder(_into, Vector3(SHAFT_X, y + 2.8, z0 + 0.25), 0.06, 7.0, m_rust, along_x)
	Geo.cylinder(_into, Vector3(SHAFT_X, y + 2.65, z0 + 0.25), 0.04, 7.0, m_metal, along_x)
	# Лампа под эмалированным абажуром над люком.
	var lamp_pos := Vector3(SHAFT_X + 0.4, y + 2.3, SHAFT_Z + 1.0)
	Geo.cylinder(_into, lamp_pos + Vector3(0, 0.38, 0), 0.008, 0.6, dark)
	var shade := CylinderMesh.new()
	shade.top_radius = 0.05
	shade.bottom_radius = 0.26
	shade.height = 0.18
	var shade_mi := MeshInstance3D.new()
	shade_mi.mesh = shade
	shade_mi.material_override = ProcTex.flat(Color(0.2, 0.35, 0.28), 0.4, 0.3)
	shade_mi.position = lamp_pos + Vector3(0, 0.05, 0)
	_into.add_child(shade_mi)
	_add_lamp(lamp_pos - Vector3(0, 0.03, 0), Color(1.0, 0.8, 0.55), 1.5, 9.0, "ok", false, false)
	# Окно на западной стене: ночь, дождь, иногда молния.
	var wz := SHAFT_Z - 1.7
	var glass := ProcTex.emissive(Color(0.05, 0.08, 0.14), 0.8)
	Geo.box(_into, Vector3(x0 + 0.03, y + 1.8, wz), Vector3(0.02, 1.0, 1.4), glass, false)
	for fz in [-0.72, 0.0, 0.72]:
		Geo.box(_into, Vector3(x0 + 0.05, y + 1.8, wz + float(fz)), Vector3(0.05, 1.1, 0.06), wood, false)
	for fy in [1.27, 1.8, 2.33]:
		Geo.box(_into, Vector3(x0 + 0.05, y + float(fy), wz), Vector3(0.05, 0.06, 1.5), wood, false)
	Geo.box(_into, Vector3(x0 + 0.12, y + 1.22, wz), Vector3(0.2, 0.04, 1.6), wood, false)
	_window_light = OmniLight3D.new()
	_window_light.position = Vector3(x0 + 0.6, y + 1.8, wz)
	_window_light.light_color = Color(0.6, 0.7, 1.0)
	_window_light.omni_range = 6.0
	_window_light.light_energy = 0.0
	_into.add_child(_window_light)
	_room_sound(Sfx.rain(), Vector3(x0 + 0.3, y + 1.8, wz), -10.0)
	# Стол с монитором камеры у окна.
	var tx := x0 + 0.4
	var tz := SHAFT_Z - 0.2
	Geo.box(_into, Vector3(tx, y + 0.72, tz), Vector3(0.6, 0.04, 0.9), wood)
	for lx in [-0.25, 0.25]:
		for lz in [-0.4, 0.4]:
			Geo.box(_into, Vector3(tx + float(lx), y + 0.36, tz + float(lz)), Vector3(0.04, 0.72, 0.04), wood, false)
	Geo.box(_into, Vector3(tx - 0.02, y + 0.95, tz), Vector3(0.42, 0.42, 0.45), ProcTex.flat(Color(0.75, 0.72, 0.62), 0.6))
	var screen := ProcTex.emissive(Color(0.25, 0.55, 0.35), 1.2)
	Geo.box(_into, Vector3(tx + 0.2, y + 0.97, tz), Vector3(0.01, 0.3, 0.36), screen, false)
	Geo.label(_into, Vector3(tx + 0.21, y + 0.98, tz), "КАМЕРА 3 — ТОННЕЛЬ\nНЕТ СИГНАЛА", 90, 18, Color(0.7, 1.0, 0.75), false, 0.0018)
	var glow := OmniLight3D.new()
	glow.position = Vector3(tx + 0.5, y + 1.0, tz)
	glow.light_color = Color(0.4, 0.9, 0.5)
	glow.omni_range = 2.0
	glow.light_energy = 0.4
	glow.add_to_group("fear_light")
	glow.add_to_group("cull_light")
	_into.add_child(glow)
	# Часы, полка с папками, памятка, календарь, щиток, вешалка.
	var cx := SHAFT_X + 2.2
	var face := Geo.cylinder(_into, Vector3(cx, y + 2.35, z0 + 0.03), 0.2, 0.04, ProcTex.flat(Color(0.9, 0.88, 0.8), 0.5), Basis(Vector3.RIGHT, PI / 2))
	face.name = "ClockFace"
	Geo.cylinder(_into, Vector3(cx, y + 2.35, z0 + 0.02), 0.22, 0.03, dark, Basis(Vector3.RIGHT, PI / 2))
	var hand := Geo.box(_into, Vector3(cx + 0.05, y + 2.37, z0 + 0.06), Vector3(0.12, 0.012, 0.005), dark, false)
	hand.rotation.z = 0.4
	Geo.box(_into, Vector3(cx, y + 2.42, z0 + 0.06), Vector3(0.012, 0.15, 0.005), dark, false)
	_room_sound(Sfx.tick(), Vector3(cx, y + 2.35, z0 + 0.1), -18.0)
	var shx := SHAFT_X - 2.6
	for sy in [1.6, 2.1]:
		Geo.box(_into, Vector3(shx, y + float(sy), z0 + 0.15), Vector3(1.2, 0.03, 0.3), wood, false)
		for k in 6:
			var col := Color(randf_range(0.2, 0.55), randf_range(0.15, 0.3), randf_range(0.1, 0.25))
			Geo.box(_into, Vector3(shx - 0.45 + k * 0.17, y + float(sy) + 0.16, z0 + 0.16), Vector3(0.06, 0.3, 0.24), ProcTex.flat(col, 0.8), false)
	var paper := ProcTex.flat(Color(0.86, 0.83, 0.72), 0.95)
	Geo.box(_into, Vector3(x1 - 0.01, y + 1.9, SHAFT_Z + 1.6), Vector3(0.01, 0.7, 0.5), paper, false)
	Geo.label(_into, Vector3(x1 - 0.02, y + 1.9, SHAFT_Z + 1.6), "ПАМЯТКА\nОБХОДЧИКА\n\nНе спускайся\nбез фонаря.\nСвет — твоя смена.\nДокладывай\nпо рации.", -90, 22, Color(0.15, 0.12, 0.1), true, 0.0022)
	Geo.box(_into, Vector3(x1 - 0.01, y + 1.7, SHAFT_Z - 0.4), Vector3(0.01, 0.45, 0.32), paper, false)
	Geo.label(_into, Vector3(x1 - 0.02, y + 1.8, SHAFT_Z - 0.4), "ОКТЯБРЬ", -90, 22, Color(0.55, 0.1, 0.08), true, 0.0022)
	var panel_x := SHAFT_X + 0.9
	Geo.box(_into, Vector3(panel_x, y + 1.6, z1 - 0.06), Vector3(0.5, 0.6, 0.1), ProcTex.flat(Color(0.4, 0.42, 0.4), 0.5, 0.5), false)
	for k in 3:
		Geo.box(_into, Vector3(panel_x - 0.14 + k * 0.14, y + 1.55, z1 - 0.12), Vector3(0.05, 0.1, 0.03), dark, false)
	Geo.sphere(_into, Vector3(panel_x + 0.15, y + 1.8, z1 - 0.11), 0.02, ProcTex.emissive(Color(1.0, 0.15, 0.1), 2.0))
	Geo.box(_into, Vector3(SHAFT_X - 1.2, y + 1.2, z1 - 0.12), Vector3(0.45, 0.95, 0.12), ProcTex.flat(Color(0.2, 0.22, 0.18), 1.0), false)
	Geo.box(_into, Vector3(SHAFT_X - 1.2, y + 1.72, z1 - 0.05), Vector3(0.06, 0.04, 0.1), m_metal, false)
	# Дверь домой, коврик, шкафчики.
	Geo.box(_into, Vector3(SHAFT_X - 2.0, y + 1.05, z1 - 0.03), Vector3(1.0, 2.1, 0.06), wood, false)
	Geo.box(_into, Vector3(SHAFT_X - 1.62, y + 1.0, z1 - 0.08), Vector3(0.04, 0.12, 0.05), m_metal, false)
	Geo.label(_into, Vector3(SHAFT_X - 2.0, y + 2.35, z1 - 0.07), "ВЫХОД", 180, 40, Color(0.85, 0.25, 0.2))
	Geo.box(_into, Vector3(SHAFT_X - 2.0, y + 0.006, z1 - 0.5), Vector3(0.9, 0.012, 0.6), ProcTex.flat(Color(0.25, 0.15, 0.1), 1.0), false)
	Geo.box(_into, Vector3(x0 + 0.3, y + 0.95, SHAFT_Z + 1.6), Vector3(0.5, 1.9, 0.6), m_metal)
	Geo.box(_into, Vector3(x0 + 0.3, y + 0.95, SHAFT_Z + 2.25), Vector3(0.5, 1.9, 0.6), m_metal)
	# На дверце шкафчика — фотография дочери.
	Geo.box(_into, Vector3(x0 + 0.56, y + 1.45, SHAFT_Z + 1.6), Vector3(0.01, 0.17, 0.13), ProcTex.flat(Color(0.92, 0.9, 0.84), 0.9), false)
	Geo.box(_into, Vector3(x0 + 0.566, y + 1.47, SHAFT_Z + 1.6), Vector3(0.004, 0.12, 0.11), ProcTex.flat(Color(0.55, 0.45, 0.35), 0.9), false)
	Geo.sphere(_into, Vector3(x0 + 0.57, y + 1.49, SHAFT_Z + 1.6), 0.025, ProcTex.flat(Color(0.85, 0.7, 0.55), 0.9))
	Geo.label(_into, Vector3(x0 + 0.57, y + 1.385, SHAFT_Z + 1.6), "Маша, 7 лет", 90, 14, Color(0.2, 0.15, 0.4), true, 0.0016)
	Geo.box(_into, Vector3(x0 + 0.57, y + 1.54, SHAFT_Z + 1.6), Vector3(0.006, 0.015, 0.015), ProcTex.flat(Color(0.8, 0.1, 0.1), 0.6), false)
	# Стул у стола с журналом.
	var chx := SHAFT_X + 2.2
	var chz := SHAFT_Z - 1.6
	Geo.box(_into, Vector3(chx, y + 0.45, chz), Vector3(0.42, 0.04, 0.42), wood)
	Geo.box(_into, Vector3(chx - 0.2, y + 0.75, chz), Vector3(0.04, 0.6, 0.42), wood, false)
	for lx in [-0.18, 0.18]:
		for lz in [-0.18, 0.18]:
			Geo.box(_into, Vector3(chx + float(lx), y + 0.22, chz + float(lz)), Vector3(0.03, 0.45, 0.03), wood, false)
	Geo.label(_into, Vector3(SHAFT_X, y + 2.3, z0 + 0.02), "ШАХТА № 3 — ГЛУБИНА 100 М\nСПУСК ТОЛЬКО ПО ЛЕСТНИЦЕ", 0, 30, Color(0.15, 0.15, 0.15), true)


func _room_sound(stream: AudioStream, pos: Vector3, volume_db: float) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.unit_size = 3.0
	p.max_distance = 20.0
	p.position = pos
	p.autoplay = true
	_into.add_child(p)


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
		Geo.box(_into, Vector3(SHAFT_X, cy, SHAFT_Z - SHAFT_HALF - 0.15), Vector3(w + 0.6, h, 0.3), m_concrete)
		Geo.box(_into, Vector3(SHAFT_X, cy, SHAFT_Z + SHAFT_HALF + 0.15), Vector3(w + 0.6, h, 0.3), m_concrete)
		Geo.box(_into, Vector3(SHAFT_X - SHAFT_HALF - 0.15, cy, SHAFT_Z), Vector3(0.3, h, w), m_concrete)
		Geo.box(_into, Vector3(SHAFT_X + SHAFT_HALF + 0.15, cy, SHAFT_Z), Vector3(0.3, h, w), m_concrete)
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
	Geo.box(_into, Vector3(0, y - 0.15, cz), Vector3(6.6, 0.3, 20.0), m_granite)
	# Потолок с проёмом шахты.
	var top := y + h + 0.15
	var hz0 := SHAFT_Z - SHAFT_HALF
	var hz1 := SHAFT_Z + SHAFT_HALF
	Geo.box(_into, Vector3(0, top, (-50.0 + hz0) / 2), Vector3(6.6, 0.3, hz0 + 50.0), m_concrete)
	Geo.box(_into, Vector3(0, top, (hz1 - 30.0) / 2), Vector3(6.6, 0.3, -30.0 - hz1), m_concrete)
	Geo.box(_into, Vector3((-3.3 + SHAFT_X - SHAFT_HALF) / 2, top, SHAFT_Z), Vector3(SHAFT_X - SHAFT_HALF + 3.3, 0.3, SHAFT_HALF * 2), m_concrete)
	Geo.box(_into, Vector3((SHAFT_X + SHAFT_HALF + 3.3) / 2, top, SHAFT_Z), Vector3(3.3 - SHAFT_X - SHAFT_HALF, 0.3, SHAFT_HALF * 2), m_concrete)
	# Стены в кафеле.
	Geo.box(_into, Vector3(-3.15, y + h / 2, cz), Vector3(0.3, h, 20.6), m_tiles)
	Geo.box(_into, Vector3(3.15, y + h / 2, cz), Vector3(0.3, h, 20.6), m_tiles)
	Geo.box(_into, Vector3(0, y + h / 2, -29.85), Vector3(6.6, h, 0.3), m_tiles)
	# Торец с круглым порталом тоннеля.
	var portal := MeshInstance3D.new()
	portal.mesh = Geo.portal_mesh(TUBE_R, Rect2(-3.0 - TUN_CX, y - TUBE_CY, 6.0, h), 48)
	portal.material_override = m_tiles
	portal.position = Vector3(TUN_CX, TUBE_CY, TUN_Z0)
	_into.add_child(portal)
	Geo.solid(_into, Vector3((-3.0 + LEFT_X) / 2, y + 2.0, TUN_Z0 - 0.15), Vector3(LEFT_X + 3.0, 4.0, 0.3))
	Geo.solid(_into, Vector3((RIGHT_X + 3.3) / 2, y + 2.0, TUN_Z0 - 0.15), Vector3(3.3 - RIGHT_X, 4.0, 0.3))
	# Свет.
	_add_lamp(Vector3(0, y + h - 0.1, -37), Color(0.8, 0.9, 1.0), 1.5, 10.0, "ok", false)
	_add_lamp(Vector3(0, y + h - 0.1, -46), Color(0.8, 0.9, 1.0), 1.5, 10.0, "flicker", false)
	# Край платформы, упор, скамья, шкафчики.
	Geo.box(_into, Vector3(0.3, y + 0.005, cz), Vector3(0.15, 0.01, 19.6), ProcTex.flat(Color(0.7, 0.6, 0.1)), false)
	Geo.box(_into, Vector3(TUN_CX + 0.3, y + 0.3, -30.5), Vector3(1.3, 0.6, 0.3), m_rust)
	Geo.box(_into, Vector3(-2.6, y + 0.225, -41), Vector3(0.5, 0.45, 1.6), m_wood)
	Geo.box(_into, Vector3(-2.65, y + 0.95, -48.6), Vector3(0.5, 1.9, 0.5), m_metal)
	Geo.box(_into, Vector3(-2.65, y + 0.95, -48.0), Vector3(0.5, 1.9, 0.5), m_metal)
	# Таблички.
	Geo.label(_into, Vector3(-2.98, y + 2.9, -40), "СТАНЦИЯ «ТИХАЯ»", 90, 64, Color(0.2, 0.2, 0.25), true)
	Geo.box(_into, Vector3(-2.99, y + 1.6, -37.5), Vector3(0.02, 0.9, 0.8), ProcTex.flat(Color(0.75, 0.72, 0.62)), false)
	Geo.label(_into, Vector3(-2.975, y + 1.6, -37.5),
		"ПРАВИЛА ОБХОДЧИКА\n\n1. Не выключай фонарь в тоннеле.\n2. Паутину — сжигать.\n3. Фильтры менять вовремя.\n4. О посторонних звуках\n    не докладывать.",
		90, 24, Color(0.1, 0.1, 0.1), true, 0.0022)


# --- Основной тоннель --------------------------------------------------------

func _build_main_tunnel() -> void:
	# Прямые куски трубы между развилками; сами развилки, двери комнат и пролом строит CSG.
	var holes: Array = []
	for b in BRANCHES:
		if int(b["parent"]) < 0:
			holes.append([float(b["z"]) - JUNCTION_MAIN, float(b["z"]) + JUNCTION_MAIN, int(b["side"])])
	for r in SIDE_ROOMS:
		holes.append([float(r["z"]) - ROOM_SECTION, float(r["z"]) + ROOM_SECTION, int(r["side"])])
	holes.append([OLD_BREACH_Z - ROOM_SECTION, OLD_BREACH_Z + ROOM_SECTION, 1])
	_holes[-1] = holes
	var sorted := holes.duplicate()
	sorted.sort_custom(func(x, y): return x[1] > y[1])
	var zc := TUN_Z0
	for h in sorted:
		_main_segment(zc, h[1])
		zc = h[0]
	# Труба идёт и за тупиком — до старого перегона; пока стена цела, туда не попасть.
	_main_segment(zc, METRO_Z1)
	for r in SIDE_ROOMS:
		_build_side_room(r)
	_build_old_breach()
	_end_wall = Geo.box(_into, Vector3(TUN_CX, TUBE_CY, TUN_Z1 - 0.15), Vector3(TUBE_R * 2 + 0.4, TUBE_R * 2 + 0.4, 0.3), m_concrete)
	Geo.box(_into, Vector3(TUN_CX, TUBE_CY, METRO_Z1 - 0.15), Vector3(TUBE_R * 2 + 0.4, TUBE_R * 2 + 0.4, 0.3), m_concrete)
	_main_seg = _segments.size()
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
		if not is_plain(-1, z, side, 1.0):
			side = -side  # не вешать светильник в проём
		if is_plain(-1, z, side, 1.0):
			var ly := FLOOR_Y + 2.45
			_add_wall_lamp(Vector3(wall_x(side, ly, 0.12), ly, z), Vector3(-side, 0, 0), mode)
		z -= 12.0
		i += 1
	# Пикеты.
	var k := 1
	while TUN_Z0 - PICKET_STEP * k > GRATE_Z + 2.0:
		var mz: float = TUN_Z0 - PICKET_STEP * k
		if is_plain(-1, mz, 1, 1.0):
			var ly := FLOOR_Y + 1.6
			var pk := Geo.label(_into, Vector3(wall_x(1, ly, 0.03), ly, mz), "ПК %d" % k, -90, 48, Color(0.95, 0.95, 0.9), true)
			pk.set_meta("number", k)
			pickets.append(pk)
		k += 1


## Общая «начинка» прямого куска трубы в локальных координатах (ось по -Z, пол на y = 0).
## Труба, бетонный лоток с водоотводом, невидимые стены, кабели на кронштейнах, труба на опорах.
func _tube_piece(parent: Node3D, s0: float, s1: float, lowered := 0.0) -> void:
	var length := s1 - s0
	var mid := -(s0 + s1) / 2.0
	# Сетка трубы — из кеша по длине и сдвигу текстуры (кусков в сети сотни, большинство одинаковые).
	var frac := fposmod(s0, 1.0)
	var key := "%.2f/%.2f" % [length, frac]
	if not _tube_cache.has(key):
		_tube_cache[key] = Geo.tube_mesh(TUBE_R, -frac, -frac - length, 32, -0.6, TUBE_R * TAU / 8.0, 1.0)
	var tube := MeshInstance3D.new()
	tube.mesh = _tube_cache[key]
	tube.material_override = m_tubbing
	tube.position = Vector3(0, TUBE_CY - FLOOR_Y, -(s0 - frac))
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


static var _tube_cache := {}


func _main_segment(z_a: float, z_b: float) -> void:
	var z := z_a
	while z > z_b + 0.01:
		var z2 := maxf(z - CHUNK, z_b)
		var piece := Node3D.new()
		piece.position = Vector3(TUN_CX, FLOOR_Y, 0)
		_into.add_child(piece)
		_tube_piece(piece, -z, -z2)
		z = z2


# --- Развилки и штольни ------------------------------------------------------

## Развилка: толстостенные трубы (родитель + штольня под углом) объединяются,
## внутренние объёмы вычитаются — получается честное пересечение тоннелей.
func _build_junction(index: int) -> void:
	var b: Dictionary = BRANCHES[index]
	var parent := int(b["parent"])
	var d := branch_dir(index)
	var o := branch_origin(index)
	var pd := Vector3.FORWARD if parent < 0 else branch_dir(parent)
	var axis := o + Vector3(0, TUBE_CY - FLOOR_Y, 0)
	var parent_basis := Basis(Vector3.UP, _yaw_to(pd)) * Basis(Vector3.RIGHT, -PI / 2)
	var branch_basis := Basis(Vector3.UP, _yaw_to(d)) * Basis(Vector3.RIGHT, -PI / 2)

	var csg := _new_csg()
	_csg_tube(csg, TUBE_R + WALL_T, JUNCTION_MAIN * 2.0, Transform3D(parent_basis, axis), m_concrete, false)
	_csg_tube(csg, TUBE_R + WALL_T, JUNCTION_BRANCH, Transform3D(branch_basis, axis + d * (JUNCTION_BRANCH / 2.0)), m_concrete, false)
	_csg_tube(csg, TUBE_R, JUNCTION_MAIN * 2.0 + 0.04, Transform3D(parent_basis, axis), m_tubbing_tri, true)
	_csg_tube(csg, TUBE_R, JUNCTION_BRANCH + 0.02, Transform3D(branch_basis, axis + d * (JUNCTION_BRANCH / 2.0 + 0.01)), m_tubbing_tri, true)

	# Пол развилки: полоса родителя и полоса штольни.
	var chord := _tube_half(FLOOR_Y) * 2.0
	Geo.box(_into, o + Vector3(0, -0.15, 0), Vector3(chord, 0.3, JUNCTION_MAIN * 2.0), m_floor, true, Basis(Vector3.UP, _yaw_to(pd)))
	var floor_b := Geo.box(_into, o + d * (JUNCTION_BRANCH / 2.0) + Vector3(0, -0.155, 0),
		Vector3(chord, 0.3, JUNCTION_BRANCH), m_floor, true, Basis(Vector3.UP, _yaw_to(d)))
	floor_b.name = "JunctionFloor%d" % index
	var side: int = b["side"]
	if b.get("hidden", false):
		_build_plug(o, pd, side)
		# В самом конце — мелом. Если дошёл.
		var tr_end := wall_mount(index, -1, float(b["length"]) - 3.0, FLOOR_Y + 1.7)
		var chalk := Geo.label(_into, tr_end.origin, "ТЫ ЕЁ\nВИДИШЬ?", 0.0, 72, Color(0.85, 0.83, 0.78, 0.85), true, 0.0035)
		chalk.basis = tr_end.basis
		return

	# Указатель на противоположной стене перед развилкой и свет.
	var word := "НАЛЕВО" if side < 0 else "НАПРАВО"
	var ly := FLOOR_Y + 2.0
	var s_on: float = b["s"]
	var before := s_on + (JUNCTION_MAIN - 1.5) * (1.0 if parent < 0 else -1.0)
	var tr := wall_mount(parent, -side, before, ly, 0.03)
	var sign_board := Geo.box(_into, tr.origin, Vector3(1.4, 0.5, 0.03), ProcTex.flat(Color(0.12, 0.25, 0.45), 0.5), false, tr.basis)
	sign_board.name = "Sign%d" % index
	var l := Geo.label(_into, tr.origin + tr.basis.z * 0.02, "%s\n%s" % [b["name"], word], 0.0, 30 if parent < 0 else 26, Color(0.95, 0.95, 0.95), true)
	l.basis = tr.basis
	_add_lamp(o + pd * 2.0 + Vector3(0, TUBE_CY - FLOOR_Y + TUBE_R - 0.25, 0), Color(1.0, 0.72, 0.42), 1.1, 9.0, "ok" if parent < 0 else "flicker", true)


## Заглушка потайной штольни: кусок стены трубы (тюбинг) поверх проёма и невидимая стена.
func _build_plug(o: Vector3, pd: Vector3, side: int) -> void:
	_plug = Node3D.new()
	_plug.transform = Transform3D(Basis(Vector3.UP, _yaw_to(pd)), o + Vector3(0, TUBE_CY - FLOOR_Y, 0))
	_into.add_child(_plug)
	var a0 := -0.62 if side > 0 else PI - 1.35
	var a1 := 1.35 if side > 0 else PI + 0.62
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := TUBE_R - 0.02
	var steps := 14
	for i in steps:
		var b0 := lerpf(a0, a1, float(i) / steps)
		var b1 := lerpf(a0, a1, float(i + 1) / steps)
		var zf := JUNCTION_MAIN
		var zt := -JUNCTION_MAIN
		for q in [[b0, zf], [b1, zt], [b1, zf], [b0, zf], [b0, zt], [b1, zt]]:
			var a: float = q[0]
			var z: float = q[1]
			st.set_normal(-Vector3(cos(a), sin(a), 0.0))
			st.set_uv(Vector2(a * r / (TUBE_R * TAU / 8.0), -z))
			st.add_vertex(Vector3(cos(a) * r, sin(a) * r, z))
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m_tubbing
	_plug.add_child(mi)
	var body := StaticBody3D.new()
	_plug.add_child(body)
	Geo.collider_box(body, Vector3(0.3, 4.0, JUNCTION_MAIN * 2.0), Vector3(side * (TUN_HW + 0.15), 2.0 - (TUBE_CY - FLOOR_Y), 0))


## Потайная штольня есть или её нет.
func set_hidden_open(open: bool) -> void:
	hidden_open = open
	if _plug == null:
		return
	_plug.visible = not open
	for body in _plug.find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).collision_layer = 0 if open else 1


## Ближайшая к точке тоннельная лампа гаснет на seconds (с щелчком). Возвращает, нашлась ли.
func flicker_lamp_near(at: Vector3, seconds: float, max_dist := 12.0) -> bool:
	var best := {}
	var best_d := max_dist
	for i in range(_static_lamps, lamps.size()):
		var l: Dictionary = lamps[i]
		if l["mode"] == "broken" or l.get("off", false):
			continue
		var d := (l["light"] as OmniLight3D).global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = l
	if best.is_empty():
		return false
	best["off"] = true
	Game.play_at(Sfx.click(), (best["light"] as OmniLight3D).global_position, -6.0)
	var lamp := best
	get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(lamp["light"]):
			lamp["off"] = false)
	return true


# --- Служебные комнаты ------------------------------------------------------

## Комната сбоку от основного тоннеля: кусок трубы, дверной проём в обделке и сама комната.
func _build_side_room(r: Dictionary) -> void:
	var zr: float = r["z"]
	var side := float(r["side"])
	var axis := Vector3(TUN_CX, TUBE_CY, zr)
	var main_basis := Basis(Vector3.RIGHT, PI / 2)
	var room_basis := Basis(Vector3.UP, atan2(-side, 0.0))  # +Z комнаты — к тоннелю
	var kind: Dictionary = r["kind"]
	var center := Vector3(TUN_CX + side * (TUBE_R + WALL_T + float(kind["d"]) / 2), FLOOR_Y, zr)
	var csg := _new_csg()
	_csg_tube(csg, TUBE_R + WALL_T, ROOM_SECTION * 2, Transform3D(main_basis, axis), m_concrete, false)
	_csg_room(csg, center, room_basis, kind)
	_csg_tube(csg, TUBE_R, ROOM_SECTION * 2 + 0.04, Transform3D(main_basis, axis), m_tubbing_tri, true)
	var d_in := 1.4
	var d_out := TUBE_R + WALL_T + 0.1
	_csg_box(csg, Vector3(d_out - d_in, 2.2, 1.3), Transform3D(Basis.IDENTITY, Vector3(TUN_CX + side * (d_in + d_out) / 2, FLOOR_Y + 1.1, zr)), m_concrete, true)
	var chord := _tube_half(FLOOR_Y) * 2.0
	Geo.box(_into, Vector3(TUN_CX, FLOOR_Y - 0.15, zr), Vector3(chord, 0.3, ROOM_SECTION * 2), m_floor)
	Geo.box(_into, Vector3(TUN_CX + side * 1.95, FLOOR_Y - 0.152, zr), Vector3(1.3, 0.3, 1.3), m_floor)
	_room_floor(center, room_basis, kind)
	if r["gen"]:
		gen_rooms.append(rooms.size())
		# Генераторная: под потолком лампа в сетке — горит, пока есть ток.
		_add_lamp(center + room_basis * Vector3(0, float(kind["h"]) - 0.15, 0.6), Color(1.0, 0.8, 0.55), 1.0, 7.0, "ok", true)
		Geo.label(_into, Vector3(TUN_CX + side * (TUBE_R - 0.05), FLOOR_Y + 2.45, zr), "ГЕНЕРАТОРНАЯ", -90.0 * side, 26, Color(0.85, 0.75, 0.2), true)
	rooms.append({"center": center, "basis": room_basis, "kind": kind, "gen": r["gen"], "story": r["story"],
		"door": Transform3D(room_basis, Vector3(TUN_CX + side * (TUBE_R + WALL_T - 0.05), FLOOR_Y, zr))})


## Пролом в старую линию: кусок трубы с рваной дырой в правой стене. За ней — кирпичный ход (его строит LowerLine).
## Пока старая линия закрыта, дыра заложена кирпичом.
func _build_old_breach() -> void:
	var z := OLD_BREACH_Z
	var axis := Vector3(TUN_CX, TUBE_CY, z)
	var main_basis := Basis(Vector3.RIGHT, PI / 2)
	var csg := _new_csg()
	_csg_tube(csg, TUBE_R + WALL_T, ROOM_SECTION * 2, Transform3D(main_basis, axis), m_concrete, false)
	_csg_tube(csg, TUBE_R, ROOM_SECTION * 2 + 0.04, Transform3D(main_basis, axis), m_tubbing_tri, true)
	# Рваные края: несколько повёрнутых коробок вместо ровного проёма.
	var x_mid := TUN_CX + (TUBE_R + WALL_T) * 0.85
	_csg_box(csg, Vector3(1.6, OLD_BREACH_H, OLD_BREACH_W), Transform3D(Basis.IDENTITY, Vector3(x_mid, FLOOR_Y + OLD_BREACH_H / 2.0, z)), m_concrete, true)
	_csg_box(csg, Vector3(1.6, 0.9, 1.4), Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(x_mid, FLOOR_Y + OLD_BREACH_H, z + 0.3)), m_concrete, true)
	_csg_box(csg, Vector3(1.6, 1.2, 0.7), Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(x_mid, FLOOR_Y + 1.4, z - OLD_BREACH_W / 2.0)), m_concrete, true)
	var chord := _tube_half(FLOOR_Y) * 2.0
	Geo.box(_into, Vector3(TUN_CX, FLOOR_Y - 0.15, z), Vector3(chord, 0.3, ROOM_SECTION * 2), m_floor)
	# Невидимые стены тоннеля — по обе стороны от пролома (справа) и целиком слева.
	Geo.solid(_into, Vector3(TUN_CX - TUN_HW - 0.15, FLOOR_Y + 2.0, z), Vector3(0.3, 4.0, ROOM_SECTION * 2))
	for s in [-1.0, 1.0]:
		var seg := ROOM_SECTION - OLD_BREACH_W / 2.0
		Geo.solid(_into, Vector3(TUN_CX + TUN_HW + 0.15, FLOOR_Y + 2.0, z + s * (OLD_BREACH_W / 2.0 + seg / 2.0)), Vector3(0.3, 4.0, seg))
	# Обломки тюбинга и кирпич на полу у дыры.
	var brick := ProcTex.bricks()
	for k in 7:
		var p := Vector3(TUN_CX + randf_range(0.8, 1.6), FLOOR_Y + randf_range(0.05, 0.2), z + randf_range(-2.2, 2.2))
		Geo.box(_into, p, Vector3.ONE * randf_range(0.18, 0.4), m_concrete if k % 2 == 0 else brick, false,
			Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)))
	# Заложено кирпичом (закрыто в 1-ю, 2-ю и 7-ю смены).
	_old_plug = StaticBody3D.new()
	_into.add_child(_old_plug)
	var plug_size := Vector3(0.6, OLD_BREACH_H + 1.6, OLD_BREACH_W + 1.4)
	var plug_at := Vector3(TUN_CX + TUBE_R + 0.15, FLOOR_Y + plug_size.y / 2.0, z)
	Geo.box(_old_plug, plug_at, plug_size, brick, false)
	Geo.collider_box(_old_plug, plug_size, plug_at)


## Пролом в старую линию открыт или заложен.
func set_old_breach(open: bool) -> void:
	_old_plug.visible = not open
	for c in _old_plug.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = open


## Комната в тупике штольни: торец трубы с дверью и комната за ним.
func _build_end_room(index: int) -> void:
	var length: float = BRANCHES[index]["length"]
	var d := branch_dir(index)
	var origin := branch_origin(index)
	var yaw := _yaw_to(d)
	var room_basis := Basis(Vector3.UP, yaw)  # +Z — обратно по штольне, к двери
	var axis := origin + Vector3(0, TUBE_CY - FLOOR_Y, 0)
	var pipe := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI / 2)
	var kind: Dictionary = BRANCHES[index]["kind"]
	var center := origin + d * (length + WALL_T + float(kind["d"]) / 2)
	var csg := _new_csg()
	# Наружная труба заходит на толщину стенки дальше — получается глухой торец.
	_csg_tube(csg, TUBE_R + WALL_T, ROOM_SECTION + WALL_T, Transform3D(pipe, axis + d * (length - ROOM_SECTION / 2 + WALL_T / 2)), m_concrete, false)
	_csg_room(csg, center, room_basis, kind)
	_csg_tube(csg, TUBE_R, ROOM_SECTION + 0.02, Transform3D(pipe, axis + d * (length - ROOM_SECTION / 2 - 0.01)), m_tubbing_tri, true)
	_csg_box(csg, Vector3(1.3, 2.2, 0.8), Transform3D(room_basis, origin + d * (length + WALL_T / 2) + Vector3(0, 1.1, 0)), m_concrete, true)
	var chord := _tube_half(FLOOR_Y) * 2.0
	Geo.box(_into, origin + d * (length - ROOM_SECTION / 2) + Vector3(0, -0.155, 0), Vector3(chord, 0.3, ROOM_SECTION), m_floor, true, room_basis)
	Geo.box(_into, origin + d * (length + 0.15) + Vector3(0, -0.152, 0), Vector3(1.3, 0.3, 0.8), m_floor, true, room_basis)
	_room_floor(center, room_basis, kind)
	rooms.append({"center": center, "basis": room_basis, "kind": kind, "gen": false,
		"story": 3 + index if index < 3 and int(BRANCHES[index]["parent"]) < 0 else -1,
		"door": Transform3D(room_basis, origin + d * (length + WALL_T - 0.05))})


static func _kit_or(name: String, fallback: Material) -> Material:
	var tint := Color(0.6, 0.58, 0.55) if name == "plaster_peeling" else Color(0.78, 0.76, 0.72)
	return ProcTex.kit(name, tint) if name != "" and ProcTex._kit_ok(name) else fallback


func _csg_room(csg: Node, center: Vector3, basis: Basis, kind: Dictionary) -> void:
	var w := float(kind["w"])
	var d := float(kind["d"])
	var h := float(kind["h"])
	var c := center + Vector3(0, h / 2, 0)
	_csg_box(csg, Vector3(w + WALL_T * 2, h + WALL_T * 2, d + WALL_T * 2), Transform3D(basis, c), m_concrete, false)
	_csg_box(csg, Vector3(w, h, d), Transform3D(basis, c), _kit_or(str(kind["wall"]), m_room), true)
	# Потолок — подвесными панелями (у мастерской и склада — голый бетон).
	if kind["theme"] != "workshop" and kind["theme"] != "sklad":
		Geo.box(_into, center + Vector3(0, h - 0.02, 0), Vector3(w - 0.02, 0.03, d - 0.02), _kit_or("ceiling_panels", m_concrete), false, basis)


func _room_floor(center: Vector3, basis: Basis, kind: Dictionary) -> void:
	Geo.box(_into, center + Vector3(0, -0.15, 0), Vector3(float(kind["w"]), 0.3, float(kind["d"])), _kit_or(str(kind["floor"]), m_floor), true, basis)


func _new_csg() -> CSGCombiner3D:
	var csg := CSGCombiner3D.new()
	csg.use_collision = true
	csg.collision_layer = Geo.WALL_LAYER
	csg.collision_mask = 0
	_into.add_child(csg)
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
	var has_room: bool = b["room"]
	# Развилки ответвлений на этой штольне строит CSG — там труба прерывается.
	var holes: Array = []
	for c in BRANCHES:
		if int(c["parent"]) == index:
			holes.append([float(c["s"]) - JUNCTION_MAIN, float(c["s"]) + JUNCTION_MAIN, int(c["side"])])
	_holes[index] = holes
	var cuts := holes.duplicate()
	cuts.sort_custom(func(x, y): return x[0] < y[0])
	# Прямая часть штольни — те же куски трубы, что и в основном тоннеле, повёрнутые по оси штольни.
	var straight_end := length - ROOM_SECTION if has_room else length
	var s := JUNCTION_BRANCH
	cuts.append([straight_end, straight_end, 0])
	for h in cuts:
		while s < float(h[0]) - 0.01:
			var s2 := minf(s + CHUNK, float(h[0]))
			var piece := Node3D.new()
			piece.transform = Transform3D(Basis(Vector3.UP, yaw), origin)
			_into.add_child(piece)
			_tube_piece(piece, s, s2, 0.005)
			s = s2
		s = maxf(s, float(h[1]))
	var end := origin + d * length
	if has_room:
		_build_end_room(index)
	else:
		# Глухой торец: бетонная заглушка, за ней — грунт.
		Geo.box(_into, end + d * 0.15 + Vector3(0, TUBE_CY - FLOOR_Y, 0), Vector3(TUBE_R * 2 + 0.4, TUBE_R * 2 + 0.4, 0.3), m_concrete, true, Basis(Vector3.UP, yaw))
	# Обвалившийся грунт у торца.
	var r := _right_of(d)
	for k in 5:
		var rp := end - d * randf_range(0.6, 3.0) + r * (1.1 if k % 2 == 0 else -1.1) + Vector3(0, 0.15, 0)
		var rock := Geo.box(_into, rp, Vector3.ONE * randf_range(0.25, 0.5), m_concrete, false)
		rock.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	# В штольнях почти все светильники разбиты.
	var ld := JUNCTION_BRANCH + 4.0
	var n := 0
	while ld < length - 3.0:
		if is_plain(index, ld, -1, 1.0):
			var ly := FLOOR_Y + 2.45
			var tr := wall_mount(index, -1, ld, ly, 0.12)
			_add_wall_lamp(tr.origin, tr.basis.z, "flicker" if n % 5 == 0 else "broken")
			n += 1
		ld += 14.0
	_segments.append({"a": Vector2(origin.x, origin.z), "b": Vector2(end.x, end.z), "dir": d})


# --- Пути --------------------------------------------------------------------

func _build_rails() -> void:
	# Звено пути (рельсы на шпалах) — Rail из Mine Object collection (loafbrr_1, CC0).
	# В модели путь идёт вдоль X; поворачиваем вдоль тоннеля и растягиваем шпалы под колею вагонетки.
	var tile := load("res://models/mine/Rail.fbx").instantiate() as Node3D
	var rail_mesh := (tile.find_child("Rail", true, false) as MeshInstance3D).mesh
	tile.free()
	var rail_mat := ProcTex.model_skin("res://models/mine/rails_albedo.png", Color(0.5, 0.45, 0.42), 0.6, 0.5)
	var basis := Basis(Vector3.UP, PI / 2) * Basis.from_scale(Vector3(RAIL_TILE / 2.0, 1.2, 1.15))
	var cover := ProcTex.flat(Color(0.25, 0.2, 0.14), 0.9)
	var z_a := -29.0
	var z_end := METRO_Z1 + 1.0
	while z_a > z_end + 0.01:
		var z_b := maxf(z_a - CHUNK, z_end)
		var length := z_a - z_b
		var cz := (z_a + z_b) / 2.0
		# Контактный рельс под деревянным коробом.
		Geo.box(_into, Vector3(TUN_CX + 1.05, FLOOR_Y + 0.15, cz), Vector3(0.08, 0.12, length), m_rail, false)
		Geo.box(_into, Vector3(TUN_CX + 1.08, FLOOR_Y + 0.28, cz), Vector3(0.26, 0.03, length), cover, false)
		# Звенья по одному мешу на кусок: свет считается на кусок, как и у остальной геометрии.
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = rail_mesh
		var count := ceili(length / RAIL_TILE - 0.01)
		mm.instance_count = count
		for i in count:
			mm.set_instance_transform(i, Transform3D(basis, Vector3(TUN_CX, FLOOR_Y, z_a - RAIL_TILE * (i + 0.5))))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = rail_mat
		_into.add_child(mmi)
		z_a = z_b


func _build_grate() -> void:
	# Шарнир у левой стенки трубы — так решётку можно «открыть». Прутья во весь круг.
	grate = Node3D.new()
	grate.position = Vector3(TUN_CX - TUBE_R, FLOOR_Y, GRATE_Z)
	_into.add_child(grate)
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
	var spots := [Vector3(0.2, 0, -330.5), Vector3(2.3, 0, -334.0), Vector3(0.9, 0, -339.5), Vector3(1.8, 0, -345.5),
		Vector3(0.1, 0, -351.5), Vector3(2.5, 0, -356.0), Vector3(1.3, 0, -362.0)]
	for p in spots:
		var pos: Vector3 = p
		var helmet := Geo.sphere(_into, Vector3(pos.x, FLOOR_Y, map_z(pos.z)), 0.16, yellow)
		(helmet.mesh as SphereMesh).is_hemisphere = true
		helmet.rotation = Vector3(randf_range(-0.6, 0.6), randf() * TAU, randf_range(-0.6, 0.6))
	Geo.box(_into, Vector3(1.6, FLOOR_Y + 0.1, map_z(-348.5)), Vector3(0.15, 0.2, 0.25), m_metal, false)
	# Кости тех, кто ушёл за решётку раньше.
	for p in [Vector3(1.0, 0, GRATE_Z - 9.0), Vector3(2.2, 0, GRATE_Z - 17.0), Vector3(0.4, 0, GRATE_Z - 26.0)]:
		Remains.bone_pile(_into, Vector3(p.x, FLOOR_Y, p.z), randf() * TAU, randf_range(0.8, 1.1))


## Пролом в стене тупика: обломки кольца по краям, старая кирпичная кладка, завал вдоль стен.
## Посередине — проход в человеческий рост.
func _build_breach() -> void:
	_breach = Node3D.new()
	_into.add_child(_breach)
	var z := TUN_Z1 - 0.15
	var brick := ProcTex.flat(Color(0.32, 0.16, 0.11), 0.95)
	for side in [-1.0, 1.0]:
		# Уцелевшие куски стены по бокам и сверху.
		Geo.box(_breach, Vector3(TUN_CX + side * 1.55, TUBE_CY - 0.3, z), Vector3(1.4, 3.6, 0.3), m_concrete, true,
			Basis(Vector3.FORWARD, side * 0.06))
		# Завал вдоль стен: бетон и кирпич.
		for k in 5:
			var p := Vector3(TUN_CX + side * randf_range(0.9, 1.5), FLOOR_Y + randf_range(0.1, 0.3), z + randf_range(-2.5, 2.5))
			var size := Vector3.ONE * randf_range(0.25, 0.6)
			Geo.box(_breach, p, size, m_concrete if k % 2 == 0 else brick, false,
				Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)))
	Geo.box(_breach, Vector3(TUN_CX, TUBE_CY + 1.6, z), Vector3(2.0, 1.2, 0.3), m_concrete, true, Basis(Vector3.FORWARD, 0.1))
	# За проломом — кладка старше тоннеля (её помнят записки бригады 1979 года).
	for side in [-1.0, 1.0]:
		Geo.box(_breach, Vector3(TUN_CX + side * 1.25, FLOOR_Y + 1.0, z - 0.6), Vector3(0.6, 2.0, 0.5), brick, false)
	_breach.visible = false


## Волна темноты: лампы тоннеля впереди гаснут одна за другой — от дальней к ближней, с лязгом.
## Возвращает точку у последней погасшей (там можно поставить фигуру) или Vector3.INF.
func dark_wave(from: Vector3, dir_z: float) -> Vector3:
	var picked: Array = []
	for l in lamps:
		if not l["tunnel"] or l["mode"] == "broken":
			continue
		var lz: float = (l["light"] as OmniLight3D).global_position.z
		var ahead: float = (lz - from.z) * dir_z
		if ahead > 6.0 and ahead < 70.0 and absf((l["light"] as OmniLight3D).global_position.x - TUN_CX) < 4.0:
			picked.append(l)
	if picked.size() < 3:
		return Vector3.INF
	picked.sort_custom(func(a, b): return absf((a["light"] as OmniLight3D).global_position.z - from.z) > absf((b["light"] as OmniLight3D).global_position.z - from.z))
	for i in picked.size():
		var l: Dictionary = picked[i]
		get_tree().create_timer(0.45 * i).timeout.connect(func():
			if not is_instance_valid(l["light"]):
				return  # сеть уже пересобрана (новая смена)
			l["off"] = true
			Game.play_at(Sfx.click(), (l["light"] as OmniLight3D).global_position, -2.0))
	var last: Vector3 = (picked[-1]["light"] as OmniLight3D).global_position
	get_tree().create_timer(0.45 * picked.size() + 9.0).timeout.connect(func():
		for l in picked:
			l["off"] = false)
	return Vector3(TUN_CX, FLOOR_Y, last.z)


## Тоннельный светильник в сетке на стене. inward — куда смотрит (внутрь тоннеля).
func _add_wall_lamp(pos: Vector3, inward: Vector3, mode: String) -> void:
	var basis := Basis(Vector3.UP, atan2(inward.x, inward.z))
	Geo.box(_into, pos - inward * 0.05, Vector3(0.25, 0.3, 0.06), m_metal, false, basis)
	var cage := ProcTex.flat(Color(0.15, 0.15, 0.15), 0.5, 0.8)
	for k in 3:
		Geo.box(_into, pos + inward * 0.06 + Vector3(0, -0.1 + k * 0.1, 0), Vector3(0.2, 0.012, 0.012), cage, false, basis)
	_add_lamp(pos + inward * 0.04 + Vector3(0, 0.05, 0), Color(1.0, 0.74, 0.45), 1.1, 9.0, mode, true, false)


func _add_lamp(pos: Vector3, color: Color, energy: float, light_range: float, mode: String, tunnel: bool, fixture := true) -> void:
	if fixture:
		Geo.box(_into, pos + Vector3(0, 0.06, 0), Vector3(0.3, 0.08, 0.3), m_metal, false)
	var bulb_mat := ProcTex.emissive(color, 3.0)
	Geo.sphere(_into, pos - Vector3(0, 0.05, 0), 0.07, bulb_mat)
	var light := OmniLight3D.new()
	light.position = pos - Vector3(0, 0.25, 0)
	light.light_color = color
	light.omni_range = light_range
	light.light_energy = energy
	light.omni_attenuation = 1.5
	light.add_to_group("fear_light")
	_into.add_child(light)
	if mode == "broken":
		bulb_mat.emission_enabled = false
		bulb_mat.albedo_color = Color(0.15, 0.15, 0.15)
	lamps.append({"light": light, "mat": bulb_mat, "energy": energy, "mode": mode, "tunnel": tunnel, "t": randf() * 10.0})
