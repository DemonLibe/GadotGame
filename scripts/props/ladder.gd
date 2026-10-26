class_name Ladder
extends StaticBody3D
## Скобяная лестница в шахте. Тело на слое 2 — только для луча взаимодействия.

const RUNG_STEP := 0.3

var top_y := 85.0
var bottom_y := -15.0
var climb_x := 0.0
var climb_z := 0.0
var facing_yaw := 0.0
var exit_top := Vector3.ZERO
var _x := 0.0
var _wall_z := 0.0


## x — центр лестницы, wall_z — стена, к которой она крепится (лестница со стороны +Z).
func setup(x: float, wall_z: float, bottom: float, top: float, exit_pos: Vector3) -> void:
	_x = x
	_wall_z = wall_z
	bottom_y = bottom
	top_y = top
	climb_x = x
	climb_z = wall_z + 0.5
	exit_top = exit_pos


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var steel := ProcTex.flat(Color(0.3, 0.3, 0.32), 0.5, 0.8)
	var rz := _wall_z + 0.15
	var rung := BoxMesh.new()
	rung.size = Vector3(0.5, 0.035, 0.035)
	var y := bottom_y
	while y < top_y - 0.01:
		var y2 := minf(y + 12.0, top_y)
		var h := y2 - y
		Geo.box(self, Vector3(_x - 0.25, (y + y2) / 2, rz), Vector3(0.05, h, 0.05), steel, false)
		Geo.box(self, Vector3(_x + 0.25, (y + y2) / 2, rz), Vector3(0.05, h, 0.05), steel, false)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = rung
		var count := int(h / RUNG_STEP)
		mm.instance_count = count
		for i in count:
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(_x, y + 0.3 + i * RUNG_STEP, rz)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = steel
		add_child(mmi)
		y = y2
	Geo.collider_box(self, Vector3(0.6, top_y - bottom_y, 0.1), Vector3(_x, (top_y + bottom_y) / 2, rz))


func get_prompt(player) -> String:
	if player.climbing:
		return ""
	return "E — взяться за лестницу"


func interact(player) -> void:
	player.start_climb(self)
