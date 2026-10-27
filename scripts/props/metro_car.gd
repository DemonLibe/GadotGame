class_name MetroCar
extends StaticBody3D
## Вагон метро за проломом (седьмая смена): головной и прицепной, у кабины горят фары.
## Сесть в вагон — и уехать. Модели: Train Kit (Kenney, CC0).

const SCALE := 1.75
const STRETCH := 2.2  # вагоны в наборе короткие — вытягиваем вдоль пути
const CAR_LEN := 2.6 * SCALE * STRETCH

var main  # Main


func _ready() -> void:
	add_to_group("day_objects")
	var skin := ProcTex.model_skin("res://models/subway/Textures/colormap.png", Color(0.55, 0.55, 0.58), 0.7, 0.3)
	var basis := Basis.from_scale(Vector3(SCALE, SCALE, SCALE * STRETCH))
	# Кабина смотрит в +Z — навстречу тому, кто пришёл через пролом. Прицепной — за ним.
	Geo.model(self, "res://models/subway/subway_head.glb", skin, Vector3(0.09 * SCALE, 0, 0), basis)
	Geo.model(self, "res://models/subway/subway_car.glb", skin, Vector3(0, 0, -CAR_LEN - 0.3), basis)
	Geo.collider_box(self, Vector3(2.2, 2.8, CAR_LEN * 2.0 + 0.3), Vector3(0, 1.4, -CAR_LEN / 2.0 - 0.15))
	# Фары и слабый свет из кабины: его видно от самого пролома.
	var glow := ProcTex.emissive(Color(1.0, 0.85, 0.55), 3.0)
	for x in [-0.55, 0.55]:
		Geo.sphere(self, Vector3(x, 0.95, CAR_LEN / 2.0 + 0.02), 0.07, glow)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 1.4, CAR_LEN / 2.0 + 1.2)
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 0.9
	lamp.omni_range = 7.0
	lamp.add_to_group("fear_light")
	add_child(lamp)


func get_prompt(_player) -> String:
	return "E — сесть в вагон"


func interact(_player) -> void:
	if main:
		main.ending_metro()
