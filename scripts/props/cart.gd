class_name Cart
extends StaticBody3D
## Единственная вагонетка станции. Однажды она окажется не там, где стояла.


func _ready() -> void:
	var rust := ProcTex.flat(Color(0.33, 0.22, 0.14), 0.8, 0.5)
	var dark := ProcTex.flat(Color(0.12, 0.12, 0.12), 0.6, 0.8)
	Geo.box(self, Vector3(0, 0.45, 0), Vector3(1.1, 0.06, 1.7), rust, false)
	Geo.box(self, Vector3(-0.53, 0.75, 0), Vector3(0.05, 0.6, 1.7), rust, false)
	Geo.box(self, Vector3(0.53, 0.75, 0), Vector3(0.05, 0.6, 1.7), rust, false)
	Geo.box(self, Vector3(0, 0.75, -0.83), Vector3(1.1, 0.6, 0.05), rust, false)
	Geo.box(self, Vector3(0, 0.75, 0.83), Vector3(1.1, 0.6, 0.05), rust, false)
	var side := Basis(Vector3.FORWARD, PI / 2)
	for z in [-0.55, 0.55]:
		Geo.cylinder(self, Vector3(0, 0.2, float(z)), 0.03, 1.2, dark, side)
		for x in [-0.55, 0.55]:
			Geo.cylinder(self, Vector3(float(x), 0.2, float(z)), 0.18, 0.08, dark, side)
	Geo.collider_box(self, Vector3(1.15, 1.05, 1.75), Vector3(0, 0.55, 0))


func get_prompt(_player) -> String:
	return "Вагонетка — E: осмотреть"


func interact(_player) -> void:
	if Game.has_open_task("inspect:cart"):
		Game.report("inspect:cart")
		Game.say("Она стояла на станции. Одному её с места не сдвинуть... Кто её сюда прикатил?", Game.THOUGHT, 6.0)
	else:
		Game.say("Старая вагонетка. Колёса в ржавчине.")
