class_name Pickup
extends StaticBody3D
## Предмет, который подбирают одним нажатием: коробка патронов, оружейный ящик с пистолетом,
## канистра с топливом или жетон пропавшего обходчика.

var kind := "ammo"  # ammo / pistol / fuel / token
var amount := 4


func _ready() -> void:
	add_to_group("day_objects")
	match kind:
		"pistol":
			var case := ProcTex.flat(Color(0.22, 0.26, 0.2), 0.7, 0.3)
			Geo.box(self, Vector3(0, 0.05, 0), Vector3(0.4, 0.1, 0.26), case, false)
			Geo.box(self, Vector3(0, 0.105, 0), Vector3(0.36, 0.01, 0.22), ProcTex.flat(Color(0.1, 0.1, 0.1), 1.0), false)
			var gun := ProcTex.flat(Color(0.12, 0.12, 0.13), 0.35, 0.8)
			Geo.box(self, Vector3(-0.02, 0.125, 0), Vector3(0.18, 0.03, 0.035), gun, false)
			Geo.box(self, Vector3(0.06, 0.125, 0.05), Vector3(0.05, 0.025, 0.09), gun, false)
			Geo.collider_box(self, Vector3(0.42, 0.16, 0.3), Vector3(0, 0.08, 0))
		"fuel":
			var red := ProcTex.flat(Color(0.6, 0.08, 0.06), 0.5, 0.3)
			Geo.box(self, Vector3(0, 0.22, 0), Vector3(0.18, 0.44, 0.34), red, false)
			Geo.box(self, Vector3(0, 0.47, 0.06), Vector3(0.04, 0.05, 0.16), red, false)
			Geo.cylinder(self, Vector3(0, 0.48, -0.12), 0.03, 0.08, ProcTex.flat(Color(0.2, 0.2, 0.2), 0.5, 0.8))
			Geo.collider_box(self, Vector3(0.3, 0.55, 0.4), Vector3(0, 0.27, 0))
		"token":
			var brass := ProcTex.flat(Color(0.7, 0.55, 0.25), 0.35, 0.9)
			Geo.cylinder(self, Vector3(0, 0.005, 0), 0.035, 0.006, brass)
			Geo.box(self, Vector3(0.05, 0.003, 0), Vector3(0.06, 0.002, 0.004), ProcTex.flat(Color(0.3, 0.3, 0.3), 0.6, 0.8), false)
			Geo.collider_box(self, Vector3(0.25, 0.1, 0.25), Vector3(0, 0.05, 0))
		_:
			var box := ProcTex.flat(Color(0.3, 0.35, 0.2), 0.8)
			Geo.box(self, Vector3(0, 0.05, 0), Vector3(0.16, 0.1, 0.1), box, false)
			Geo.label(self, Vector3(0, 0.05, 0.051), "9×18", 0, 18, Color(0.9, 0.85, 0.6), true, 0.002)
			Geo.collider_box(self, Vector3(0.3, 0.2, 0.3), Vector3(0, 0.1, 0))


func get_prompt(_player) -> String:
	match kind:
		"pistol":
			return "E — взять пистолет"
		"fuel":
			return "E — взять канистру с топливом"
		"token":
			return "E — поднять жетон"
	return "E — взять патроны (%d)" % amount


func interact(player) -> void:
	if kind == "fuel":
		player.canisters += 1
		Game.play_at(Sfx.pickup(), global_position, -6.0)
		Game.say_once("fuel_pick", "Канистра солярки. Для генератора на станции.", Game.THOUGHT, 3.0)
		queue_free()
		return
	if kind == "token":
		Game.play_at(Sfx.pickup(), global_position, -6.0)
		Game.report("token")
		Game.say("Жетон № 7. На обороте нацарапано: «ВОСЬМОЙ, НЕ ВЕРЬ ГОЛОСУ».", Game.THOUGHT, 5.0)
		queue_free()
		return
	if kind == "pistol":
		player.has_pistol = true
		Game.say("Пистолет Макарова. Тяжёлый. Пусть так и останется в кобуре.", Game.THOUGHT, 4.0)
	player.ammo += amount
	Game.play_at(Sfx.pickup(), global_position, -6.0)
	queue_free()
