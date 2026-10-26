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
