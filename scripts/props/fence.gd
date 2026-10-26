class_name Fence
extends StaticBody3D
## Временное ограждение: отсекает ещё не открытые участки. С каждой сменой их меньше — карта растёт.
## Узел стоит на полу посередине прохода, ограждение — в плоскости XY.


func _ready() -> void:
	add_to_group("day_objects")
	var steel := ProcTex.flat(Color(0.3, 0.3, 0.3), 0.6, 0.7)
	var w := Level.TUBE_R * 2.0
	var x := -w / 2 + 0.1
	while x < w / 2:
		Geo.box(self, Vector3(x, 1.6, 0), Vector3(0.03, 3.2, 0.03), steel, false)
		x += 0.16
	for y in [0.2, 1.2, 2.4]:
		Geo.box(self, Vector3(0, float(y), 0), Vector3(w, 0.05, 0.05), steel, false)
	var stripe := ProcTex.flat(Color(0.8, 0.65, 0.1), 0.6)
	Geo.box(self, Vector3(0, 1.4, 0.04), Vector3(1.6, 0.4, 0.02), stripe, false)
	Geo.label(self, Vector3(0, 1.4, 0.06), "ПРОХОД ЗАКРЫТ", 0, 30, Color(0.1, 0.1, 0.1), true)
	Geo.collider_box(self, Vector3(Level.TUN_HW * 2, 3.2, 0.2), Vector3(0, 1.6, 0))


func get_prompt(_player) -> String:
	return "Ограждение. Сегодня дальше не пройти"
