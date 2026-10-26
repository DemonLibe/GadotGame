class_name Pickup
extends StaticBody3D
## Предмет, который подбирают одним нажатием: коробка патронов или оружейный ящик с пистолетом.

var kind := "ammo"  # ammo / pistol
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
		_:
			var box := ProcTex.flat(Color(0.3, 0.35, 0.2), 0.8)
			Geo.box(self, Vector3(0, 0.05, 0), Vector3(0.16, 0.1, 0.1), box, false)
			Geo.label(self, Vector3(0, 0.05, 0.051), "9×18", 0, 18, Color(0.9, 0.85, 0.6), true, 0.002)
			Geo.collider_box(self, Vector3(0.3, 0.2, 0.3), Vector3(0, 0.1, 0))


func get_prompt(_player) -> String:
	return "E — взять пистолет" if kind == "pistol" else "E — взять патроны (%d)" % amount


func interact(player) -> void:
	if kind == "pistol":
		player.has_pistol = true
		Game.say("Пистолет Макарова. Тяжёлый. Пусть так и останется в кобуре.", Game.THOUGHT, 4.0)
	player.ammo += amount
	Game.play_at(Sfx.pickup(), global_position, -6.0)
	queue_free()
