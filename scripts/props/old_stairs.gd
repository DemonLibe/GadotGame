class_name OldStairs
extends StaticBody3D
## Ход в старую линию: ржавый люк на платформе станции (down) и скобяная лестница наверх
## в первой клетке старой линии (up). Спуск и подъём — через затемнение.

var down := true
var main  # Main


func _ready() -> void:
	add_to_group("day_objects")
	var rust := ProcTex.flat(Color(0.3, 0.17, 0.1), 0.85, 0.5)
	if down:
		# Круглая ржавая крышка в полу платформы.
		Geo.cylinder(self, Vector3(0, 0.02, 0), 0.55, 0.04, rust)
		Geo.box(self, Vector3(0, 0.05, 0), Vector3(0.5, 0.02, 0.06), ProcTex.flat(Color(0.2, 0.12, 0.08), 0.8, 0.5), false)
		Geo.collider_box(self, Vector3(1.1, 0.2, 1.1), Vector3(0, 0.1, 0))
	else:
		# Скобы в кирпичной стене уходят в темноту наверх.
		for k in 9:
			Geo.box(self, Vector3(0, 0.3 + k * 0.32, 0.08), Vector3(0.45, 0.03, 0.03), rust, false)
		Geo.box(self, Vector3(-0.22, 1.6, 0.04), Vector3(0.03, 3.2, 0.06), rust, false)
		Geo.box(self, Vector3(0.22, 1.6, 0.04), Vector3(0.03, 3.2, 0.06), rust, false)
		Geo.collider_box(self, Vector3(0.6, 3.0, 0.3), Vector3(0, 1.5, 0.15))


func get_prompt(_player) -> String:
	return "E — спуститься в старую линию" if down else "E — подняться на станцию"


func interact(_player) -> void:
	if main:
		main.use_old_stairs(down)
