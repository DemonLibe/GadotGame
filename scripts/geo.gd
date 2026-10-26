class_name Geo
extends RefCounted
## Сборка геометрии из примитивов (пока нет моделей — всё строится кодом).


static func box(parent: Node, pos: Vector3, size: Vector3, mat: Material, collide := true, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := _add(parent, mesh, pos, mat, basis)
	if collide:
		var body := StaticBody3D.new()
		collider_box(body, size)
		mi.add_child(body)
	return mi


static func cylinder(parent: Node, pos: Vector3, radius: float, height: float, mat: Material, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	return _add(parent, mesh, pos, mat, basis)


static func sphere(parent: Node, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _add(parent, mesh, pos, mat, Basis.IDENTITY)


static func capsule(parent: Node, pos: Vector3, radius: float, height: float, mat: Material, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return _add(parent, mesh, pos, mat, basis)


static func collider_box(body: CollisionObject3D, size: Vector3, offset := Vector3.ZERO) -> void:
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	shape.position = offset
	body.add_child(shape)


## Надпись. Текст смотрит в +Z узла, yaw поворачивает его вокруг Y.
## shaded = true — видна только при свете (для надписей мелом).
static func label(parent: Node, pos: Vector3, text: String, yaw_deg: float, font_size := 32, color := Color.WHITE, shaded := false, pixel := 0.004) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 0
	l.shaded = shaded
	l.position = pos
	l.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(l)
	return l


static func _add(parent: Node, mesh: Mesh, pos: Vector3, mat: Material, basis: Basis) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(basis, pos)
	parent.add_child(mi)
	return mi


## Слой невидимых стен: игрок о них спотыкается, а луч взаимодействия проходит насквозь
## (иначе не дотянуться до вентблока на изогнутой стене тоннеля).
const WALL_LAYER := 8


## Невидимая стена (только столкновения, слой WALL_LAYER).
static func solid(parent: Node, pos: Vector3, size: Vector3, basis := Basis.IDENTITY) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WALL_LAYER
	body.collision_mask = 0
	body.transform = Transform3D(basis, pos)
	collider_box(body, size)
	parent.add_child(body)
	return body


## Внутренняя поверхность трубы радиуса radius вдоль локальной оси Z (от z_from до z_to).
## Ось трубы — локальные (0, 0). Сегменты, у которых sin(угла) < min_sin (ниже пола), пропускаются.
## UV: u — вдоль окружности (u_tile метров на картинку), v — вдоль оси (v_tile метров).
static func tube_mesh(radius: float, z_from: float, z_to: float, segments: int, min_sin: float, u_tile: float, v_tile: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		if sin(a0) < min_sin and sin(a1) < min_sin:
			continue
		# Обход по часовой стрелке, если смотреть изнутри трубы, — это лицевая сторона в Godot.
		var quad := [[a0, z_from], [a1, z_to], [a1, z_from], [a0, z_from], [a0, z_to], [a1, z_to]]
		for q in quad:
			var a: float = q[0]
			var z: float = q[1]
			st.set_normal(-Vector3(cos(a), sin(a), 0.0))
			st.set_uv(Vector2(a * radius / u_tile, -z / v_tile))
			st.add_vertex(Vector3(cos(a) * radius, sin(a) * radius, z))
	st.generate_tangents()
	return st.commit()


## Стена-заглушка с круглым проёмом: прямоугольник rect (относительно центра проёма,
## в плоскости XY) минус круг радиуса radius. Используется там, где труба входит в стену.
static func portal_mesh(radius: float, rect: Rect2, segments: int) -> ArrayMesh:
	var angles: Array[float] = []
	for i in segments:
		angles.append(TAU * i / segments)
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var c: Vector2 = corner
		angles.append(fposmod(c.angle(), TAU))
	angles.sort()
	angles.append(angles[0] + TAU)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in angles.size() - 1:
		var d0 := Vector2.from_angle(angles[i])
		var d1 := Vector2.from_angle(angles[i + 1])
		var o0 := d0 * _ray_to_rect(d0, rect)
		var o1 := d1 * _ray_to_rect(d1, rect)
		var i0 := d0 * minf(radius, _ray_to_rect(d0, rect))
		var i1 := d1 * minf(radius, _ray_to_rect(d1, rect))
		# Двусторонняя стена: лицевая сторона в +Z и отдельно в -Z, у каждой своя нормаль.
		for p in [i0, o1, o0, i0, i1, o1]:
			var v: Vector2 = p
			st.set_normal(Vector3.BACK)
			st.set_uv(v)
			st.add_vertex(Vector3(v.x, v.y, 0.0))
		for p in [i0, o0, o1, i0, o1, i1]:
			var v: Vector2 = p
			st.set_normal(Vector3.FORWARD)
			st.set_uv(v)
			st.add_vertex(Vector3(v.x, v.y, 0.0))
	st.generate_tangents()
	return st.commit()


static func _ray_to_rect(d: Vector2, rect: Rect2) -> float:
	var t := INF
	if d.x > 0.0001:
		t = minf(t, rect.end.x / d.x)
	elif d.x < -0.0001:
		t = minf(t, rect.position.x / d.x)
	if d.y > 0.0001:
		t = minf(t, rect.end.y / d.y)
	elif d.y < -0.0001:
		t = minf(t, rect.position.y / d.y)
	return t
