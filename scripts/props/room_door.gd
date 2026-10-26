class_name RoomDoor
extends Node3D
## Железная дверь служебной комнаты. Каждую смену открыты разные двери.
## Узел стоит в дверном проёме на полу, +Z смотрит в тоннель.

var is_open := false
var _leaf: StaticBody3D


func _ready() -> void:
	var frame := ProcTex.flat(Color(0.2, 0.2, 0.21), 0.6, 0.7)
	Geo.box(self, Vector3(-0.66, 1.1, 0), Vector3(0.06, 2.2, 0.12), frame, false)
	Geo.box(self, Vector3(0.66, 1.1, 0), Vector3(0.06, 2.2, 0.12), frame, false)
	Geo.box(self, Vector3(0, 2.17, 0), Vector3(1.38, 0.06, 0.12), frame, false)
	# Створка на петлях у левого края.
	_leaf = StaticBody3D.new()
	_leaf.position = Vector3(-0.62, 0, 0)
	add_child(_leaf)
	var plate := ProcTex.plate()
	Geo.box(_leaf, Vector3(0.62, 1.07, 0), Vector3(1.22, 2.12, 0.05), plate, false)
	Geo.box(_leaf, Vector3(1.08, 1.05, 0.05), Vector3(0.04, 0.16, 0.04), frame, false)
	Geo.label(_leaf, Vector3(0.62, 1.7, 0.03), "СЛУЖЕБНОЕ\nПОМЕЩЕНИЕ", 0, 22, Color(0.85, 0.8, 0.6), true)
	Geo.collider_box(_leaf, Vector3(1.22, 2.12, 0.08), Vector3(0.62, 1.07, 0))


func set_open(value: bool) -> void:
	is_open = value
	if not is_node_ready():
		await ready
	# Открытая створка уходит внутрь комнаты (в сторону -Z).
	_leaf.rotation.y = deg_to_rad(100.0) if value else 0.0
	_leaf.collision_layer = 0 if value else 1


func get_prompt(_player) -> String:
	return "" if is_open else "Дверь заперта"


func interact(_player) -> void:
	if is_open:
		return
	Game.play_at(Sfx.clank(), global_position + Vector3(0, 1.1, 0), -8.0)
	Game.say_once("door_locked_%d" % get_index(), "Заперто. Вчера здесь двери не было... или была?", Game.THOUGHT, 3.0)
