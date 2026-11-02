class_name LowerLine
extends Node3D
## Старая «Тихая» — дореволюционная линия рядом с тоннелем. Вход — пролом в правой стене тоннеля у ПК 2,
## за ним короткий кирпичный ход. Каждую смену она собирается заново: от входа по сетке клеток прорастают кирпичные
## коридоры с развилками и петлями; в тупиках — залы с колоннами, в самой дальней точке — старая платформа.
## Отдаёт существам навигацию (is_walkable, next_waypoint, axis_at), а карте — обойдённые клетки.

const Y := Level.FLOOR_Y      # пол старой линии — вровень с тоннелем
const CELL := 6.0             # клетка сетки
const W := 3.0                # ширина коридора
const H := 3.0                # высота коридора
const HALL_H := 3.8           # высота зала
const WALL := 0.4
const COLS := 9
const ROWS := 9
## Угол сетки: клетка (c, r) — от ORIGIN на c клеток по +X (прочь от тоннеля) и на r клеток по -Z (вглубь).
## Сетка лежит справа от тоннеля между ПК 2 и ПК 3 — там, где нет ни комнат, ни штолен.
const ORIGIN := Vector3(9.0, Y, -83.0)
const ENTRY := Vector2i(0, 4)  # вход — клетка у тоннеля, с запада в неё ведёт ход от пролома
const BREACH_Z := Level.OLD_BREACH_Z  # пролом в тоннеле — напротив входа (center(ENTRY).z)
const PASS_X0 := 2.85          # ход от пролома начинается у края пола тоннеля…
const MOUTH := Vector3(Level.TUN_CX + 1.0, Y, BREACH_Z)  # …а это точка в тоннеле прямо перед проломом
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const HALL_KINDS := ["hall", "platform"]

## Клетки: Vector2i → {links: Array[Vector2i], kind: "entry"/"corridor"/"hall"/"platform", dist: int}.
var cells := {}
var goal := ENTRY              # старая платформа — самая дальняя клетка
var visited := {}              # обойдённые клетки (для карты)
var rng := RandomNumberGenerator.new()
var _m := {}                   # материалы
var _boxes := {}               # кеш BoxMesh по размеру
var _st := {}                  # ключ материала → SurfaceTool текущей клетки
var _body: StaticBody3D


func _materials() -> void:
	if not _m.is_empty():
		return
	# Кладка из набора ассетов: красный кирпич в коридорах, замшелый — в залах, закопчённый свод, земляной пол.
	_m["brick"] = ProcTex.bricks()
	_m["brick_hall"] = ProcTex.kit("brick_moss", ProcTex.BRICK_TINT) if ProcTex._kit_ok("brick_moss") else _m["brick"]
	_m["floor"] = ProcTex.kit("dirt_floor", Color(0.8, 0.78, 0.75)) if ProcTex._kit_ok("dirt_floor") else ProcTex.concrete(Color(0.26, 0.24, 0.22), 0.5)
	_m["ceiling"] = ProcTex.kit("brick_soot", Color(0.8, 0.76, 0.72)) if ProcTex._kit_ok("brick_soot") else _m["brick"]
	_m["stone"] = ProcTex.kit("tile_white") if ProcTex._kit_ok("tile_white") else ProcTex.granite()
	_m["rust"] = ProcTex.flat(Color(0.33, 0.19, 0.11), 0.85, 0.4)


# --- Генерация ----------------------------------------------------------------

## Собрать линию заново: size — сколько клеток прорастёт.
func generate(seed_value: int, size: int) -> void:
	_materials()
	for c in get_children():
		c.queue_free()
	cells.clear()
	visited.clear()
	goal = ENTRY
	rng.seed = seed_value
	_grow(clampi(size, 8, COLS * ROWS - 6))
	_add_loops(0.12)
	_measure()
	_mark_rooms()
	for c in cells:
		_build_cell(c)
	_build_passage()


## Ход от пролома в тоннеле до входной клетки.
func _build_passage() -> void:
	var root := Node3D.new()
	add_child(root)
	var body := StaticBody3D.new()
	root.add_child(body)
	var length := ORIGIN.x - PASS_X0
	var mid := Vector3(PASS_X0 + length / 2.0, Y, BREACH_Z)
	var parts := [
		[mid + Vector3(0, -0.15, 0), Vector3(length, 0.3, W), "floor"],
		[mid + Vector3(0, H + 0.15, 0), Vector3(length, 0.3, W), "ceiling"],
		[mid + Vector3(0, H / 2.0, W / 2.0 + WALL / 2.0), Vector3(length, H, WALL), "brick"],
		[mid + Vector3(0, H / 2.0, -W / 2.0 - WALL / 2.0), Vector3(length, H, WALL), "brick"],
	]
	for part in parts:
		Geo.box(root, part[0], part[1], _m[part[2]], false)
		Geo.collider_box(body, part[1], part[0])
	# Осыпь у пролома.
	for i in 6:
		var b := Geo.box(root, Vector3(PASS_X0 + rng.randf_range(0.3, 2.0), Y + 0.08, BREACH_Z + rng.randf_range(-1.1, 1.1)), Vector3(0.28, 0.13, 0.14), _m["brick"], false)
		b.rotation = Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4)


## Разобрать линию (в смены, когда люк завален).
func clear() -> void:
	for c in get_children():
		c.queue_free()
	cells.clear()
	visited.clear()
	goal = ENTRY


## «Растущее дерево»: чаще продолжаем последний коридор (длинные проходы), иногда ветвимся от старых клеток.
func _grow(size: int) -> void:
	cells[ENTRY] = {"links": [], "kind": "entry", "dist": 0}
	var active: Array[Vector2i] = [ENTRY]
	while cells.size() < size and not active.is_empty():
		var i := active.size() - 1 if rng.randf() < 0.7 else rng.randi_range(0, active.size() - 1)
		var c: Vector2i = active[i]
		var opts: Array[Vector2i] = []
		for d in DIRS:
			var n: Vector2i = c + d
			if _inside(n) and not cells.has(n):
				opts.append(n)
		if opts.is_empty():
			active.remove_at(i)
			continue
		var n: Vector2i = opts[rng.randi_range(0, opts.size() - 1)]
		# Прямо — чаще, чем вбок: коридоры тянутся, а не вьются в каждой клетке.
		var links: Array = cells[c]["links"]
		if not links.is_empty() and rng.randf() < 0.55:
			var straight: Vector2i = c + (c - (links[0] as Vector2i))
			if opts.has(straight):
				n = straight
		cells[n] = {"links": [c], "kind": "corridor", "dist": 0}
		links.append(n)
		active.append(n)


## Немного петель: чтобы от погони можно было уйти кругом.
func _add_loops(chance: float) -> void:
	for c in cells:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var n: Vector2i = c + d
			if cells.has(n) and not (cells[c]["links"] as Array).has(n) and rng.randf() < chance:
				cells[c]["links"].append(n)
				cells[n]["links"].append(c)


## Расстояние от входа (в клетках) — по нему ставится платформа и растёт опасность.
func _measure() -> void:
	var queue: Array[Vector2i] = [ENTRY]
	var seen := {ENTRY: true}
	cells[ENTRY]["dist"] = 0
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for n in cells[c]["links"]:
			if not seen.has(n):
				seen[n] = true
				cells[n]["dist"] = int(cells[c]["dist"]) + 1
				queue.append(n)
				if int(cells[n]["dist"]) > int(cells[goal]["dist"]):
					goal = n


func _mark_rooms() -> void:
	cells[goal]["kind"] = "platform"
	var halls := 0
	for c in cells:
		var cell: Dictionary = cells[c]
		if cell["kind"] == "corridor" and (cell["links"] as Array).size() == 1 and int(cell["dist"]) >= 3 and halls < 3 and rng.randf() < 0.6:
			cell["kind"] = "hall"
			halls += 1


func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < COLS and c.y >= 0 and c.y < ROWS


# --- Геометрия ----------------------------------------------------------------

func center(c: Vector2i) -> Vector3:
	return ORIGIN + Vector3((c.x + 0.5) * CELL, 0.0, -(c.y + 0.5) * CELL)


static func dir_world(d: Vector2i) -> Vector3:
	return Vector3(d.x, 0.0, -d.y)


## Клетка собирается в один меш на материал (лампы в браузерном рендере считаются на меш).
func _build_cell(c: Vector2i) -> void:
	var cell: Dictionary = cells[c]
	var root := Node3D.new()
	root.position = center(c)
	add_child(root)
	_body = StaticBody3D.new()
	root.add_child(_body)
	_st.clear()
	if HALL_KINDS.has(cell["kind"]):
		_build_hall(c, root)
	else:
		_build_corridor(c, root)
	for key in _st:
		var mi := MeshInstance3D.new()
		mi.mesh = (_st[key] as SurfaceTool).commit()
		mi.material_override = _m[key]
		root.add_child(mi)
	# Арки на границах клеток — по одной на ребро.
	for d in [Vector2i(1, 0), Vector2i(0, 1)]:
		if (cell["links"] as Array).has(c + d):
			var dw := dir_world(d)
			var across := Vector3(abs(dw.z), 0.0, abs(dw.x))
			Geo.box(root, dw * (CELL / 2.0) + Vector3(0, H - 0.18, 0), across * (W + 2 * WALL) + Vector3(0, 0.36, 0) + dw.abs() * 0.4, _m["brick"], false)
	_decorate(c, root)


func _build_corridor(c: Vector2i, root: Node3D) -> void:
	var links: Array = (cells[c]["links"] as Array).duplicate()
	if c == ENTRY:
		links.append(ENTRY + Vector2i(-1, 0))  # проём к ходу от пролома
	var arm := (CELL - W) / 2.0
	_box("floor", Vector3(0, -0.15, 0), Vector3(W, 0.3, W))
	_box("ceiling", Vector3(0, H + 0.15, 0), Vector3(W, 0.3, W))
	for d in DIRS:
		var dw := dir_world(d)
		var perp := Vector3(dw.z, 0.0, dw.x).abs()
		if links.has(c + d):
			var mid := dw * (W / 2.0 + arm / 2.0)
			var along := dw.abs() * arm
			_box("floor", mid + Vector3(0, -0.15, 0), along + perp * W + Vector3(0, 0.3, 0))
			_box("ceiling", mid + Vector3(0, H + 0.15, 0), along + perp * W + Vector3(0, 0.3, 0))
			for s in [-1.0, 1.0]:
				_box("brick", mid + perp * s * (W / 2.0 + WALL / 2.0) + Vector3(0, H / 2.0, 0), along + perp * WALL + Vector3(0, H, 0))
		else:
			_box("brick", dw * (W / 2.0 + WALL / 2.0) + Vector3(0, H / 2.0, 0), dw.abs() * WALL + perp * (W + 2 * WALL) + Vector3(0, H, 0))


func _build_hall(c: Vector2i, root: Node3D) -> void:
	var links: Array = cells[c]["links"]
	var inner := CELL - 2 * WALL
	_box("stone" if cells[c]["kind"] == "platform" else "floor", Vector3(0, -0.15, 0), Vector3(CELL, 0.3, CELL))
	_box("ceiling", Vector3(0, HALL_H + 0.15, 0), Vector3(CELL, 0.3, CELL))
	for d in DIRS:
		var dw := dir_world(d)
		var perp := Vector3(dw.z, 0.0, dw.x).abs()
		var at := dw * (CELL / 2.0 - WALL / 2.0)
		if links.has(c + d):
			# Проём шириной с коридор, над ним — перемычка до высоты зала.
			var side := (CELL - W) / 2.0
			for s in [-1.0, 1.0]:
				_box("brick_hall", at + perp * s * (W / 2.0 + side / 2.0) + Vector3(0, HALL_H / 2.0, 0), dw.abs() * WALL + perp * side + Vector3(0, HALL_H, 0))
			_box("brick_hall", at + Vector3(0, (H + HALL_H) / 2.0, 0), dw.abs() * WALL + perp * W + Vector3(0, HALL_H - H, 0))
		else:
			_box("brick_hall", at + Vector3(0, HALL_H / 2.0, 0), dw.abs() * WALL + perp * CELL + Vector3(0, HALL_H, 0))
	# Колонны по углам зала.
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_box("brick", Vector3(x * inner * 0.3, HALL_H / 2.0, z * inner * 0.3), Vector3(0.45, HALL_H, 0.45))


## Коробка в меш клетки (и в её коллизию, если нужно).
func _box(key: String, pos: Vector3, size: Vector3, collide := true) -> void:
	if not _st.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[key] = st
	var skey := "%.2f_%.2f_%.2f" % [size.x, size.y, size.z]
	if not _boxes.has(skey):
		var bm := BoxMesh.new()
		bm.size = size
		_boxes[skey] = bm
	(_st[key] as SurfaceTool).append_from(_boxes[skey], 0, Transform3D(Basis.IDENTITY, pos))
	if collide:
		Geo.collider_box(_body, size, pos)


## Мелочи: лампы, мусор, лужи, таблички.
func _decorate(c: Vector2i, root: Node3D) -> void:
	var kind: String = cells[c]["kind"]
	var lamp := kind == "platform" or kind == "entry" or rng.randf() < 0.16
	if lamp:
		var l := OmniLight3D.new()
		l.position = Vector3(0, (HALL_H if HALL_KINDS.has(kind) else H) - 0.4, 0)
		l.light_color = Color(1.0, 0.62, 0.32)
		l.light_energy = 0.7 if kind != "entry" else 1.1
		l.omni_range = 7.0
		l.shadow_enabled = false
		l.add_to_group("fear_light")
		l.add_to_group("cull_light")
		root.add_child(l)
		Geo.sphere(root, l.position + Vector3(0, 0.15, 0), 0.07, ProcTex.emissive(Color(1.0, 0.65, 0.3), 2.0))
	# Осыпавшийся кирпич у стен.
	for i in rng.randi_range(0, 3):
		var p := Vector3(rng.randf_range(-1.1, 1.1), 0.08, rng.randf_range(-1.1, 1.1))
		var b := Geo.box(root, p, Vector3(0.25, 0.12, 0.12), _m["brick"], false)
		b.rotation = Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4)
	_props(c, kind, root)
	if kind == "platform":
		# Старая платформа: край в жёлтых плитках и вывеска с «ятями».
		Geo.box(root, Vector3(0, 0.005, -1.8), Vector3(CELL - 1.0, 0.01, 0.2), ProcTex.flat(Color(0.6, 0.5, 0.12), 0.7), false)
		Geo.label(root, Vector3(0, 2.6, -CELL / 2.0 + WALL + 0.02), "СТ. ТИХАЯ\n1913", 0, 72, Color(0.85, 0.8, 0.65), true, 0.004)


## Модели из набора ассетов: в залах — остов дрезины и бочки, в коридорах — стрелочные рычаги, бочки, лужи.
## Всё у стен, чтобы не мешать проходу.
func _props(c: Vector2i, kind: String, root: Node3D) -> void:
	if not ResourceLoader.exists(ProcTex.KIT + "models/06_old_line/wooden_barrel.glb"):
		return
	var links: Array = cells[c]["links"]
	var dead: Array[Vector3] = []  # глухие стены (направления)
	for d in DIRS:
		if not links.has(c + d) and not (c == ENTRY and d == Vector2i(-1, 0)):
			dead.append(dir_world(d))
	if HALL_KINDS.has(kind):
		if kind == "hall" and not dead.is_empty() and rng.randf() < 0.6:
			var w: Vector3 = dead[rng.randi_range(0, dead.size() - 1)]
			ProcTex.kit_model(root, "06_old_line/handcar_wreck", w * 1.85, atan2(w.z, -w.x) + rng.randf_range(-0.2, 0.2))
		for i in rng.randi_range(1, 2):
			var corner := Vector3(2.05 * (1.0 if rng.randf() < 0.5 else -1.0), 0.0, 2.05 * (1.0 if rng.randf() < 0.5 else -1.0))
			ProcTex.kit_model(root, "06_old_line/wooden_barrel", corner, rng.randf() * TAU)
		if kind == "platform":
			var w2: Vector3 = dead[0] if not dead.is_empty() else Vector3.RIGHT
			var side := Vector3(w2.z, 0.0, -w2.x)
			ProcTex.kit_model(root, "06_old_line/switch_lever", w2 * 2.1 + side * 1.0, atan2(-w2.x, -w2.z))
		return
	if dead.is_empty():
		return
	var w: Vector3 = dead[rng.randi_range(0, dead.size() - 1)]
	var roll := rng.randf()
	if roll < 0.12:
		ProcTex.kit_model(root, "06_old_line/switch_lever", w * (W / 2.0 - 0.3), atan2(-w.x, -w.z))
	elif roll < 0.22:
		ProcTex.kit_model(root, "06_old_line/wooden_barrel", w * (W / 2.0 - 0.4), rng.randf() * TAU)
	elif roll < 0.4:
		ProcTex.kit_model(root, "common/puddle_decal", Vector3(rng.randf_range(-0.4, 0.4), 0.01, rng.randf_range(-0.4, 0.4)), rng.randf() * TAU)


# --- Навигация ----------------------------------------------------------------

func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - ORIGIN.x) / CELL), floori((ORIGIN.z - p.z) / CELL))


func contains(p: Vector3) -> bool:
	return p.y < Y + 6.0 and p.y > Y - 3.0 and p.x >= ORIGIN.x and p.x <= ORIGIN.x + COLS * CELL \
		and p.z <= ORIGIN.z and p.z >= ORIGIN.z - ROWS * CELL


## В ходе между проломом и входной клеткой (ни тоннель, ни линия).
func in_passage(p: Vector3) -> bool:
	return not cells.is_empty() and p.y < Y + 6.0 and p.y > Y - 3.0 and p.x > PASS_X0 - 0.2 and p.x < ORIGIN.x \
		and absf(p.z - BREACH_Z) < W / 2.0 - 0.3


func is_walkable(p: Vector3) -> bool:
	var c := cell_of(p)
	if not cells.has(c):
		return false
	var l := p - center(c)
	if HALL_KINDS.has(cells[c]["kind"]):
		var m := CELL / 2.0 - WALL - 0.3
		return absf(l.x) < m and absf(l.z) < m
	var half := W / 2.0 - 0.3
	if absf(l.x) < half and absf(l.z) < half:
		return true
	var arms: Array = (cells[c]["links"] as Array).duplicate()
	if c == ENTRY:
		arms.append(ENTRY + Vector2i(-1, 0))  # к ходу от пролома
	for n in arms:
		var dw := dir_world((n as Vector2i) - c)
		var along := l.dot(dw)
		var across := absf(l.dot(Vector3(dw.z, 0.0, dw.x)))
		if along > 0.0 and across < half:
			return true
	return false


## Следующая точка пути: центр своей клетки (если стоишь в боковом рукаве), потом центр следующей по пути.
func next_waypoint(from: Vector3, to: Vector3) -> Vector3:
	var a := cell_of(from)
	var b := cell_of(to)
	if a == b or not cells.has(a) or not cells.has(b):
		return to
	var path := _path(a, b)
	if path.size() < 2:
		return to
	var ca := center(a)
	var dn := (center(path[1]) - ca).normalized()
	var off := from - ca
	off.y = 0.0
	# Сначала к центру своей клетки — только если стоишь в боковом рукаве (иначе срежешь угол стены).
	if off.length() > 0.8 and (absf(off.dot(Vector3(dn.z, 0.0, dn.x))) > 0.6 or off.dot(dn) < -0.5):
		ca.y = from.y
		return ca
	var next := center(path[1])
	next.y = from.y
	return next


func _path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var prev := {a: a}
	var queue: Array[Vector2i] = [a]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == b:
			break
		for n in cells[c]["links"]:
			if not prev.has(n):
				prev[n] = c
				queue.append(n)
	var out: Array[Vector2i] = []
	if not prev.has(b):
		return out
	var c := b
	while c != a:
		out.push_front(c)
		c = prev[c]
	out.push_front(a)
	return out


## Направление прохода в точке: вдоль рукава, в котором стоишь.
func axis_at(p: Vector3) -> Vector3:
	var c := cell_of(p)
	if not cells.has(c):
		return Vector3.FORWARD
	var l := p - center(c)
	var links: Array = cells[c]["links"]
	if absf(l.x) > absf(l.z) and (links.has(c + Vector2i(1, 0)) or links.has(c + Vector2i(-1, 0))):
		return Vector3.RIGHT
	if links.has(c + Vector2i(0, 1)) or links.has(c + Vector2i(0, -1)):
		return Vector3.FORWARD
	return Vector3.RIGHT


## Случайная клетка не ближе min_dist клеток от входа (для существ и находок).
func random_cell(min_dist: int, exclude_goal := true) -> Vector2i:
	var pool: Array[Vector2i] = []
	for c in cells:
		if int(cells[c]["dist"]) >= min_dist and not (exclude_goal and c == goal):
			pool.append(c)
	if pool.is_empty():
		return goal
	return pool[rng.randi_range(0, pool.size() - 1)]


## Точка на полу клетки со случайным сдвигом (не в стену).
func floor_spot(c: Vector2i) -> Vector3:
	return center(c) + Vector3(rng.randf_range(-0.9, 0.9), 0.05, rng.randf_range(-0.9, 0.9))


# --- Обвалы -------------------------------------------------------------------

## Есть ли обход, если проход a—b завалит (тогда завал не отрежет ни одну клетку).
func has_detour(a: Vector2i, b: Vector2i) -> bool:
	if not cells.has(a) or not (cells[a]["links"] as Array).has(b):
		return false
	_unlink(a, b)
	var ok := _path(a, b).size() > 0
	(cells[a]["links"] as Array).append(b)
	(cells[b]["links"] as Array).append(a)
	return ok


func _unlink(a: Vector2i, b: Vector2i) -> void:
	(cells[a]["links"] as Array).erase(b)
	(cells[b]["links"] as Array).erase(a)


## Середина прохода между соседними клетками (на полу).
func link_point(a: Vector2i, b: Vector2i) -> Vector3:
	return (center(a) + center(b)) / 2.0


## Обвал: проход a—b заваливает кирпичом до свода. Навигация и карта перестают его видеть.
func collapse(a: Vector2i, b: Vector2i) -> void:
	_materials()
	_unlink(a, b)
	var dw := dir_world(b - a)
	var across := Vector3(absf(dw.z), 0.0, absf(dw.x))
	var body := StaticBody3D.new()
	body.position = link_point(a, b)
	add_child(body)
	Geo.collider_box(body, across * W + dw.abs() * 1.2 + Vector3(0, H, 0), Vector3(0, H / 2.0, 0))
	# Сплошная осыпь: ядро до свода и откос понизу в обе стороны, поверх — торчащие куски кирпича.
	Geo.box(body, Vector3(0, H / 2.0, 0), across * (W + 0.1) + dw.abs() * 0.3 + Vector3(0, H, 0), _m["brick"], false)
	for side in [-1.0, 1.0]:
		var slope := Geo.box(body, dw * side * 0.55 + Vector3(0, 0.35, 0), across * (W + 0.1) + dw.abs() * 0.9 + Vector3(0, 0.9, 0), _m["brick"], false)
		slope.rotation = across * side * 0.5
	for i in 44:
		var t := sqrt(float(i) / 44.0)
		var size := Vector3(rng.randf_range(0.35, 0.7), rng.randf_range(0.2, 0.45), rng.randf_range(0.3, 0.6)) * (1.0 - t * 0.4)
		var pos := across * rng.randf_range(-W / 2.0 + 0.2, W / 2.0 - 0.2) + dw * rng.randf_range(0.2, 1.0) * (1.0 - t * 0.6) * (-1.0 if i % 2 == 0 else 1.0) \
			+ Vector3(0, t * H * 0.95, 0)
		var brick := Geo.box(body, pos, size, _m["brick"], false)
		brick.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))


## Место на глухой стене клетки (для надписей мелом): лицом внутрь клетки. Нет глухой стены — пустой Transform.
func wall_mount(c: Vector2i, height := 1.6) -> Transform3D:
	var links: Array = cells[c]["links"]
	var depth := CELL / 2.0 - WALL if HALL_KINDS.has(cells[c]["kind"]) else W / 2.0
	for d in DIRS:
		if not links.has(c + d) and not (c == ENTRY and d == Vector2i(-1, 0)):
			var dw := dir_world(d)
			return Transform3D(Basis.looking_at(dw, Vector3.UP), center(c) + dw * (depth - 0.02) + Vector3(0, height, 0))
	return Transform3D()


## Отметить клетку как обойдённую (карта открывается по мере прохождения).
func visit(p: Vector3) -> void:
	if contains(p):
		var c := cell_of(p)
		if cells.has(c):
			visited[c] = true
