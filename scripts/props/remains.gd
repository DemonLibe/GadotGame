class_name Remains
extends Node3D
## Останки прежнего обходчика: скелет из простых форм, каска, роба, фонарь.
## pose: "lying" — лежит на полу, "sitting" — сидит, привалившись к стене.

var pose := "lying"


func _ready() -> void:
	add_to_group("day_objects")
	var bone := ProcTex.flat(Color(0.74, 0.7, 0.6), 0.85)
	var cloth := ProcTex.flat(Color(0.14, 0.15, 0.13), 1.0)
	# Верх (череп, позвоночник, рёбра, руки) крепится к тазу — для позы «сидя» его поворачиваем.
	var upper := Node3D.new()
	upper.position = Vector3(0, 0.08, 0)
	add_child(upper)
	var skull := Geo.sphere(upper, Vector3(0, 0.02, -0.72), 0.1, bone)
	skull.scale = Vector3(0.85, 0.95, 1.1)
	Geo.box(upper, Vector3(0, -0.04, -0.8), Vector3(0.09, 0.03, 0.07), bone, false)
	var eye := ProcTex.flat(Color(0.03, 0.03, 0.03), 1.0)
	Geo.sphere(upper, Vector3(-0.035, 0.03, -0.81), 0.022, eye)
	Geo.sphere(upper, Vector3(0.035, 0.03, -0.81), 0.022, eye)
	for i in 7:
		Geo.box(upper, Vector3(0, 0, -0.58 + i * 0.08), Vector3(0.05, 0.05, 0.05), bone, false)
	for i in 5:
		for side in [-1.0, 1.0]:
			var rib := Geo.box(upper, Vector3(float(side) * 0.08, 0.03, -0.5 + i * 0.07), Vector3(0.16, 0.018, 0.018), bone, false)
			rib.rotation = Vector3(0, 0, float(side) * 0.5)
			var rib2 := Geo.box(upper, Vector3(float(side) * 0.15, 0.1, -0.5 + i * 0.07), Vector3(0.09, 0.018, 0.018), bone, false)
			rib2.rotation = Vector3(0, 0, float(side) * 1.2)
	var along := Basis(Vector3.RIGHT, PI / 2)
	for side in [-1.0, 1.0]:
		Geo.cylinder(upper, Vector3(float(side) * 0.24, 0, -0.42), 0.02, 0.3, bone, along)
		Geo.cylinder(upper, Vector3(float(side) * 0.27, 0, -0.14), 0.017, 0.26, bone, along)
	Geo.box(upper, Vector3(0, -0.03, -0.35), Vector3(0.42, 0.06, 0.5), cloth, false)
	# Низ: таз и ноги.
	Geo.box(self, Vector3(0, 0.06, 0.02), Vector3(0.28, 0.08, 0.15), bone, false)
	for side in [-1.0, 1.0]:
		var thigh := Geo.cylinder(self, Vector3(float(side) * 0.1, 0.05, 0.28), 0.025, 0.42, bone, along)
		thigh.rotation.y = float(side) * 0.12
		Geo.cylinder(self, Vector3(float(side) * 0.14, 0.05, 0.7), 0.02, 0.4, bone, along)
	Geo.box(self, Vector3(0, 0.03, 0.45), Vector3(0.36, 0.05, 0.6), cloth, false)
	if pose == "sitting":
		upper.rotation.x = deg_to_rad(80.0)
		upper.position = Vector3(0, 0.1, -0.05)
	# Каска и фонарь рядом.
	var helmet := Geo.sphere(self, Vector3(0.45, 0.0, -0.5), 0.16, ProcTex.flat(Color(0.75, 0.6, 0.1), 0.5))
	(helmet.mesh as SphereMesh).is_hemisphere = true
	helmet.rotation = Vector3(0.4, 0.8, 0.3)
	Geo.box(self, Vector3(-0.45, 0.1, 0.1), Vector3(0.15, 0.2, 0.25), ProcTex.flat(Color(0.3, 0.32, 0.3), 0.5, 0.6), false)
