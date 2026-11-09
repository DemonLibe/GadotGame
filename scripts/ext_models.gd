class_name ExtModels
extends RefCounted
## Сторонние модели, присланные для игры: мусор (Trash and Debris), станция и вагон метро (Metro PSX),
## паук-охотник (Huntsman Spider). В наборах все детали лежат в одном файле — отсюда берём нужные по имени.

const TRASH := "res://models/trash/trash.glb"
const METRO := "res://models/metro_psx/metro.glb"
const HUNTSMAN := "res://models/huntsman/huntsman.fbx"
const TRASH_SCALE := 0.4  # в наборе всё вдвое-втрое крупнее жизни

## Мусор по местам: что валяется в тоннеле, на станции и в старой линии.
const TUNNEL_TRASH := ["News_1", "News_2", "News_3", "Paper_1", "Paper_2", "Can_1_Crushed", "Can_3_Crushed", "Can_5_Crushed",
	"Flat_Can_1", "Flat_Can_2", "GlassBottle_1_Broken", "GlassBottle_3_Broken", "Glass_Shards_1", "Tin_1", "Tin_3",
	"Wooden_Plank_1", "Wooden_Plank_2", "Sheet_Metal_1", "Brick_1", "Brick_2", "Concrete_Debris_1", "TrashBag_1", "CardboardBox_2"]
const STATION_TRASH := ["News_Stack", "News_2", "Paper_1", "Can_2_Crushed", "Flat_Can_3", "TrashBag_2", "CardboardBox_1",
	"CardboardBox_3", "Glass_Shards_2", "GlassBottle_2", "Tin_2"]
const OLD_TRASH := ["Brick_1", "Brick_2", "Concrete_Debris_1", "Concrete_Debris_2", "Rebar", "Wooden_Plank_3",
	"Sheet_Metal_2", "Glass_Shards_1", "GlassBottle_4_Broken", "Tin_4", "Cinder_Block_1", "Paper_2"]

static var _templates := {}


static func ok(path: String) -> bool:
	return ResourceLoader.exists(path)


static func _template(path: String) -> Node:
	if not _templates.has(path):
		_templates[path] = (load(path) as PackedScene).instantiate()
	return _templates[path]


## Копия детали по имени узла (сетки общие, копия лёгкая).
static func piece(path: String, node_name: String) -> Node3D:
	var src := _template(path).find_child(node_name, false, false) as Node3D
	if src == null:
		return null
	return src.duplicate() as Node3D


## Кусок мусора на полу: деталь набора, уменьшенная до жизненного размера.
static func trash(parent: Node, node_name: String, pos: Vector3, yaw: float, scale := 1.0) -> Node3D:
	if not ok(TRASH):
		return null
	var p := piece(TRASH, node_name)
	if p == null:
		return null
	var holder := Node3D.new()
	holder.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * TRASH_SCALE * scale), pos)
	parent.add_child(holder)
	var inner := Node3D.new()
	holder.add_child(inner)
	inner.add_child(p)
	# Дном на пол: детали в наборе стоят кто выше, кто ниже нуля.
	var box := Geo.mesh_bounds(holder)
	inner.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	return holder


## Деталь станции Metro PSX, поставленная дном на ноль и центром в ноль (для скамей, урны, схемы, плакатов).
static func metro_prop(parent: Node, node_name: String, pos: Vector3, yaw: float, size := 0.0) -> Node3D:
	if not ok(METRO):
		return null
	var p := piece(METRO, node_name)
	if p == null:
		return null
	var holder := Node3D.new()
	holder.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	parent.add_child(holder)
	var inner := Node3D.new()
	holder.add_child(inner)
	inner.add_child(p)
	var box := Geo.mesh_bounds(inner)
	var k := 1.0 if size <= 0.0 else size / maxf(box.get_longest_axis_size(), 0.001)
	inner.scale = Vector3.ONE * k
	inner.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * k
	return holder


## Вагон метро целиком: корпус, двери, стёкла, сиденья и поручни из Metro PSX, ужатый под наш тоннель.
## Ось вагона — вдоль Z, дно — на нуле. Возвращает узел и длину вагона.
static func metro_car(parent: Node, height: float) -> Array:
	var holder := Node3D.new()
	parent.add_child(holder)
	var inner := Node3D.new()
	holder.add_child(inner)
	var t := _template(METRO)
	var body := t.find_child("subway_car", false, false) as Node3D
	inner.add_child(body.duplicate())
	var car := Geo.mesh_bounds(inner)
	# Всё, что стоит внутри корпуса: двери, стёкла, сиденья, поручни.
	for c in t.get_children():
		var n := String(c.name)
		if not (n.begins_with("Door") or n.begins_with("Glass") or n.begins_with("seats") or n.begins_with("Railing_V")):
			continue
		var probe := Node3D.new()
		probe.add_child((c as Node3D).duplicate())
		var b := Geo.mesh_bounds(probe)
		probe.free()
		var center := b.get_center()
		if car.grow(0.3).has_point(center):
			inner.add_child((c as Node3D).duplicate())
	var k := height / car.size.y
	inner.scale = Vector3.ONE * k
	inner.position = -Vector3(car.get_center().x, car.position.y, car.get_center().z) * k
	return [holder, car.size.z * k, car.size.x * k]


## Паук-охотник (модель без скелета): размах лап ~2 м в файле, size — размах в игре.
static func huntsman(parent: Node, size: float) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	if not ok(HUNTSMAN):
		return holder
	var m := (load(HUNTSMAN) as PackedScene).instantiate() as Node3D
	holder.add_child(m)
	var skin := ProcTex.model_skin("res://models/huntsman/huntsman_albedo.png", Color(0.55, 0.5, 0.45), 0.7)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = skin
	var box := Geo.mesh_bounds(m)
	var k := size / maxf(maxf(box.size.x, box.size.z), 0.001)
	m.scale = Vector3.ONE * k
	m.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * k
	return holder
