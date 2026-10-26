class_name Hideout
extends StaticBody3D
## Железный шкаф для инструмента. В нём можно спрятаться: сквозь щели двери видно тоннель.
## Существо найдёт обходчика, только если подползёт вплотную и услышит дыхание.
## Передняя сторона шкафа смотрит по локальной +Z.

const W := 0.8
const D := 0.6
const H := 2.0

var _door: Node3D


func _ready() -> void:
	add_to_group("hideouts")
	var steel := ProcTex.flat(Color(0.3, 0.33, 0.3), 0.6, 0.6)
	var dark := ProcTex.flat(Color(0.05, 0.05, 0.05), 1.0)
	# Стенки по отдельности — изнутри шкаф тоже должен быть виден.
	var two_sided := steel.duplicate() as StandardMaterial3D
	two_sided.cull_mode = BaseMaterial3D.CULL_DISABLED
	Geo.box(self, Vector3(0, H / 2, -D / 2), Vector3(W, H, 0.03), two_sided, false)
	Geo.box(self, Vector3(-W / 2, H / 2, 0), Vector3(0.03, H, D), two_sided, false)
	Geo.box(self, Vector3(W / 2, H / 2, 0), Vector3(0.03, H, D), two_sided, false)
	Geo.box(self, Vector3(0, H, 0), Vector3(W, 0.03, D), two_sided, false)
	Geo.box(self, Vector3(0, 0.02, 0), Vector3(W, 0.04, D), dark, false)
	# Дверь из горизонтальных планок с щелями.
	_door = Node3D.new()
	_door.position = Vector3(-W / 2, 0, D / 2)
	add_child(_door)
	var y := 0.1
	while y < H - 0.05:
		Geo.box(_door, Vector3(W / 2, y, 0), Vector3(W - 0.02, 0.07, 0.02), two_sided, false)
		y += 0.11
	Geo.box(_door, Vector3(W - 0.08, 1.05, 0.03), Vector3(0.03, 0.14, 0.03), dark, false)
	Geo.label(self, Vector3(0, H - 0.25, D / 2 + 0.02), "ИНСТРУМЕНТ", 0, 22, Color(0.85, 0.8, 0.6), true, 0.002)
	Geo.collider_box(self, Vector3(W, H, D), Vector3(0, H / 2, 0))


func inside_pos() -> Vector3:
	return global_transform * Vector3(0, 0.05, 0)


## Взгляд — наружу, сквозь щели двери.
func facing_yaw() -> float:
	var f := global_transform.basis.z
	return atan2(-f.x, -f.z)


func exit_pos() -> Vector3:
	return global_transform * Vector3(0, 0.05, D / 2 + 0.55)


func get_prompt(player) -> String:
	if player.hiding:
		return "E — выйти · держи Space — задержать дыхание"
	return "E — спрятаться в шкаф"


func interact(player) -> void:
	var tw := create_tween()
	tw.tween_property(_door, "rotation:y", -1.2, 0.15)
	tw.tween_property(_door, "rotation:y", 0.0, 0.2)
	if player.hiding:
		player.exit_hide()
	else:
		player.enter_hide(self)
