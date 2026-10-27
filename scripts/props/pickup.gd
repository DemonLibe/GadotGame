class_name Pickup
extends StaticBody3D
## Предмет, который подбирают одним нажатием: коробка патронов, оружейный ящик с пистолетом,
## канистра с топливом или жетон пропавшего обходчика.

var kind := "ammo"  # ammo / pistol / fuel / token / bolts / fuse / relays
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
		"bolts":
			# Горсть болтов в жестяной коробке.
			var tin := ProcTex.flat(Color(0.3, 0.3, 0.28), 0.6, 0.6)
			Geo.box(self, Vector3(0, 0.03, 0), Vector3(0.18, 0.06, 0.12), tin, false)
			var steel := ProcTex.flat(Color(0.45, 0.45, 0.47), 0.4, 0.8)
			for k in 4:
				Geo.cylinder(self, Vector3(-0.05 + k * 0.035, 0.07, randf_range(-0.03, 0.03)), 0.01, 0.08, steel, Basis(Vector3.RIGHT, PI / 2 + randf_range(-0.4, 0.4)))
			Geo.collider_box(self, Vector3(0.3, 0.2, 0.25), Vector3(0, 0.1, 0))
		"fuse":
			# Керамический предохранитель с медными колпачками.
			Geo.cylinder(self, Vector3(0, 0.03, 0), 0.025, 0.12, ProcTex.flat(Color(0.85, 0.82, 0.75), 0.6), Basis(Vector3.FORWARD, PI / 2))
			for x in [-0.065, 0.065]:
				Geo.cylinder(self, Vector3(x, 0.03, 0), 0.028, 0.02, ProcTex.flat(Color(0.7, 0.45, 0.2), 0.35, 0.9), Basis(Vector3.FORWARD, PI / 2))
			Geo.collider_box(self, Vector3(0.25, 0.15, 0.2), Vector3(0, 0.07, 0))
		"relays":
			# Ящик с тремя ретрансляторами.
			Geo.box(self, Vector3(0, 0.12, 0), Vector3(0.5, 0.24, 0.35), ProcTex.flat(Color(0.2, 0.26, 0.2), 0.7, 0.2), false)
			Geo.label(self, Vector3(0, 0.12, 0.176), "РЕТР. ×3", 0, 26, Color(0.9, 0.88, 0.7), true, 0.002)
			for k in 3:
				Geo.cylinder(self, Vector3(-0.12 + k * 0.12, 0.33, 0.0), 0.006, 0.2, ProcTex.flat(Color(0.05, 0.05, 0.05), 0.5))
			Geo.collider_box(self, Vector3(0.55, 0.35, 0.4), Vector3(0, 0.17, 0))
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
		"bolts":
			return "E — взять болты (%d)" % amount
		"fuse":
			return "E — взять запасной предохранитель"
		"relays":
			return "E — взять ретрансляторы (%d)" % amount
	return "E — взять патроны (%d)" % amount


func interact(player) -> void:
	if kind == "fuel":
		player.canisters += 1
		Game.play_at(Sfx.pickup(), global_position, -6.0)
		Game.say_once("fuel_pick", "Канистра солярки. Для генератора на станции.", Game.THOUGHT, 3.0)
		queue_free()
		return
	if kind == "bolts":
		var took := mini(amount, Player.MAX_BOLTS - player.bolts)
		if took <= 0:
			Game.say("Карман и так полон болтов.", Game.THOUGHT, 2.0)
			return
		player.bolts += took
		amount -= took
		Game.play_at(Sfx.pickup(), global_position, -6.0)
		Game.say_once("bolts_pick", "Болты. Бросить (G) — звякнут там, где упадут.", Game.THOUGHT, 3.5)
		if amount <= 0:
			queue_free()
		return
	if kind == "fuse":
		player.fuses += 1
		Game.play_at(Sfx.pickup(), global_position, -6.0)
		Game.say("Предохранитель. Теперь — к щитку.", Game.THOUGHT, 3.0)
		queue_free()
		return
	if kind == "relays":
		player.relays += amount
		Game.play_at(Sfx.pickup(), global_position, -6.0)
		Game.say("Три ретранслятора. Кронштейны для них — по тоннелю, на карте отмечены.", Game.THOUGHT, 4.0)
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
		Game.report("gear:pistol")
		Game.say("Пистолет Макарова. Тяжёлый. Пусть так и останется в кобуре.", Game.THOUGHT, 4.0)
	else:
		Game.report("gear:ammo")
	player.ammo += amount
	Game.play_at(Sfx.pickup(), global_position, -6.0)
	queue_free()
