class_name Remains
extends Node3D
## Останки прежнего обходчика: скелет из частей Dungeon Debris — Skull and Bones
## (Paul Wortmann, CC0), обрывки робы, каска и фонарь рядом.
## pose: "lying" — лежит на полу, "sitting" — сидит, привалившись к стене.
## Скелет лежит головой к -Z.

const DIR := "res://models/bones/"
const K := 0.4  # части в наборе крупные — уменьшаем до человеческого роста

var pose := "lying"


func _ready() -> void:
	add_to_group("day_objects")
	var bone := ProcTex.model_skin(DIR + "bone_albedo.png", Color(0.78, 0.74, 0.64), 0.85)
	var skull_mat := ProcTex.model_skin(DIR + "skull_albedo.png", Color(0.8, 0.76, 0.66), 0.8)
	var cloth := ProcTex.flat(Color(0.14, 0.15, 0.13), 1.0)
	# Верх (череп, позвоночник, рёбра, руки) крепится к тазу — для позы «сидя» его поворачиваем.
	var upper := Node3D.new()
	upper.position = Vector3(0, 0.02, 0)
	add_child(upper)
	# Части в наборе стоят «как в теле» (череп и таз — стоймя): кладём их на спину.
	_part(upper, "skull_1_001", skull_mat, Vector3(0, 0.13, -0.66), Vector3(-PI / 2, 0, 0))
	_part(upper, "spine_2_001", bone, Vector3(0, 0.08, -0.3), Vector3(0, 0, PI / 2))
	_part(upper, "ribcage_2_001", bone, Vector3(0, 0.02, -0.42), Vector3.ZERO)
	_part(upper, "arm_2_001", bone, Vector3(0.24, 0, -0.32), Vector3(0, -0.15, 0))
	_part(upper, "arm_2_001", bone, Vector3(-0.24, 0, -0.32), Vector3(0, 0.15, 0), true)
	var robe := Geo.box(upper, Vector3(0, 0.02, -0.38), Vector3(0.44, 0.04, 0.42), cloth, false)
	robe.rotation.x = 0.04
	# Низ: таз и ноги.
	_part(self, "pelvis_2_001", bone, Vector3(0, 0.09, 0.06), Vector3(-PI / 2, 0, 0))
	_part(self, "leg_2_001", bone, Vector3(0.1, 0, 0.42), Vector3(0, 0.1, 0))
	_part(self, "leg_2_001", bone, Vector3(-0.12, 0, 0.44), Vector3(0, -0.12, 0), true)
	Geo.box(self, Vector3(0, 0.03, 0.3), Vector3(0.36, 0.05, 0.42), cloth, false)
	if pose == "sitting":
		upper.rotation.x = deg_to_rad(80.0)
		upper.position = Vector3(0, 0.08, -0.05)
	# Каска и фонарь рядом.
	var helmet := Geo.sphere(self, Vector3(0.45, 0.0, -0.5), 0.16, ProcTex.flat(Color(0.75, 0.6, 0.1), 0.5))
	(helmet.mesh as SphereMesh).is_hemisphere = true
	helmet.rotation = Vector3(0.4, 0.8, 0.3)
	Geo.box(self, Vector3(-0.45, 0.1, 0.1), Vector3(0.15, 0.2, 0.25), ProcTex.flat(Color(0.3, 0.32, 0.3), 0.5, 0.6), false)


## Часть скелета (.obj из набора): масштаб K, mirror — зеркально по X (левая рука из правой).
static func _part(parent: Node3D, name: String, mat: Material, pos: Vector3, rot: Vector3, mirror := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = load(DIR + name + ".obj")
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = Vector3(-K if mirror else K, K, K)
	parent.add_child(mi)
	return mi


## Куча костей (для гнезда за решёткой).
static func bone_pile(parent: Node3D, pos: Vector3, yaw: float, size := 1.0) -> MeshInstance3D:
	var mat := ProcTex.model_skin(DIR + "bone_albedo.png", Color(0.7, 0.66, 0.56), 0.85)
	var mi := _part(parent, "bone_pile_2_001", mat, pos, Vector3(0, yaw, 0))
	mi.scale = Vector3.ONE * K * size
	return mi
