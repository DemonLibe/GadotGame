class_name Pickup
extends StaticBody3D
## Предмет, который подбирают одним нажатием: коробка патронов, оружейный ящик с пистолетом,
## канистра с топливом или жетон пропавшего обходчика.

var kind := "ammo"  # ammo / pistol / fuel / token / bolts / fuse / relays / relic / bag / key / medkit / battery
var amount := 4
var title := ""  # находка из старой линии: что это
var on_taken: Callable  # вызывается, когда предмет подобран целиком


func _ready() -> void:
	add_to_group("day_objects")
	match kind:
		"pistol":
			var case := ProcTex.flat(Color(0.22, 0.26, 0.2), 0.7, 0.3)
			Geo.box(self, Vector3(0, 0.05, 0), Vector3(0.4, 0.1, 0.26), case, false)
			Geo.box(self, Vector3(0, 0.105, 0), Vector3(0.36, 0.01, 0.22), ProcTex.flat(Color(0.1, 0.1, 0.1), 1.0), false)
			# В ящике лежит настоящий пистолет (Pistol, loafbrr_1, CC0) — на боку, стволом вдоль ящика.
			var skin := ProcTex.model_skin("res://models/items/pistol_albedo.png", Color(0.7, 0.7, 0.74), 0.4, 0.7)
			Geo.model_fit(self, "res://models/items/pistol.glb", skin, 0.22, Vector3(0, 0.11, 0), Basis(Vector3.RIGHT, -PI / 2))
			Geo.collider_box(self, Vector3(0.42, 0.16, 0.3), Vector3(0, 0.08, 0))
		"fuel":
			if ResourceLoader.exists(ProcTex.KIT + "models/common/fuel_canister.glb"):
				# Армейская канистра из набора ассетов.
				ProcTex.kit_model(self, "common/fuel_canister", Vector3.ZERO, 0.0, false)
			else:
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
		"relic":
			_relic_model()
		"key":
			# Старый ключ на кольце с жестяной биркой «С-N».
			var iron := ProcTex.flat(Color(0.32, 0.26, 0.18), 0.6, 0.7)
			Geo.cylinder(self, Vector3(0, 0.01, 0), 0.035, 0.008, iron)
			Geo.box(self, Vector3(0.08, 0.01, 0), Vector3(0.11, 0.012, 0.016), iron, false)
			Geo.box(self, Vector3(0.13, 0.01, 0.015), Vector3(0.02, 0.012, 0.03), iron, false)
			Geo.box(self, Vector3(-0.06, 0.006, 0.03), Vector3(0.05, 0.003, 0.035), ProcTex.flat(Color(0.75, 0.72, 0.6), 0.5, 0.6), false)
			Geo.collider_box(self, Vector3(0.3, 0.12, 0.25), Vector3(0, 0.05, 0))
		"medkit":
			if ResourceLoader.exists(ProcTex.KIT + "models/01_duty_room/first_aid_box.glb"):
				var box := ProcTex.kit_model(self, "01_duty_room/first_aid_box", Vector3(0, 0.0, 0), 0.0, false)
				box.rotation.x = -PI / 2
				box.position.y = 0.07
			else:
				Geo.box(self, Vector3(0, 0.07, 0), Vector3(0.35, 0.14, 0.3), ProcTex.flat(Color(0.85, 0.85, 0.8), 0.6), false)
			Geo.collider_box(self, Vector3(0.4, 0.2, 0.4), Vector3(0, 0.1, 0))
		"battery":
			Geo.model_fit(self, "res://models/items/battery.glb", ProcTex.model_skin("res://models/items/survival_palette.png", Color(0.85, 0.85, 0.85), 0.5, 0.2), 0.12, Vector3(0, 0.02, 0), Basis(Vector3.FORWARD, PI / 2))
			Geo.collider_box(self, Vector3(0.25, 0.15, 0.25), Vector3(0, 0.06, 0))
		"bag":
			# Свой же вещмешок — там, где упал в прошлый раз.
			var cloth := ProcTex.flat(Color(0.24, 0.24, 0.17), 0.95)
			Geo.box(self, Vector3(0, 0.14, 0), Vector3(0.4, 0.28, 0.26), cloth, false)
			Geo.box(self, Vector3(0, 0.3, 0), Vector3(0.3, 0.06, 0.2), cloth, false)
			Geo.box(self, Vector3(0, 0.2, 0.135), Vector3(0.22, 0.12, 0.02), ProcTex.flat(Color(0.2, 0.19, 0.13), 0.95), false)
			Geo.collider_box(self, Vector3(0.45, 0.35, 0.3), Vector3(0, 0.17, 0))
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


## Находки старой линии: монета, подстаканник, фонарь, табличка — по названию.
func _relic_model() -> void:
	var brass := ProcTex.flat(Color(0.62, 0.48, 0.22), 0.35, 0.9)
	var silver := ProcTex.flat(Color(0.7, 0.7, 0.72), 0.3, 0.9)
	var glow := ProcTex.emissive(Color(1.0, 0.8, 0.4), 0.6)
	if title.contains("ящик"):
		# Красный ящик с инструментом, ручка сверху.
		var red := ProcTex.flat(Color(0.5, 0.1, 0.07), 0.6, 0.3)
		Geo.box(self, Vector3(0, 0.09, 0), Vector3(0.45, 0.18, 0.2), red, false)
		Geo.box(self, Vector3(0, 0.2, 0), Vector3(0.22, 0.03, 0.03), ProcTex.flat(Color(0.15, 0.15, 0.15), 0.5, 0.6), false)
	elif title.contains("монет"):
		for k in 3:
			Geo.cylinder(self, Vector3(randf_range(-0.05, 0.05), 0.004 + k * 0.007, randf_range(-0.05, 0.05)), 0.03, 0.006, silver)
	elif title.contains("подстаканник"):
		Geo.cylinder(self, Vector3(0, 0.05, 0), 0.045, 0.1, silver)
		Geo.box(self, Vector3(0.055, 0.06, 0), Vector3(0.02, 0.06, 0.012), silver, false)
	elif title.contains("фонарь"):
		Geo.cylinder(self, Vector3(0, 0.12, 0), 0.06, 0.18, brass)
		Geo.cylinder(self, Vector3(0, 0.12, 0), 0.045, 0.12, ProcTex.flat(Color(0.5, 0.45, 0.3), 0.2, 0.0))
		Geo.box(self, Vector3(0, 0.25, 0), Vector3(0.02, 0.06, 0.02), brass, false)
	elif title.contains("табличк"):
		Geo.box(self, Vector3(0, 0.01, 0), Vector3(0.3, 0.012, 0.12), ProcTex.flat(Color(0.12, 0.2, 0.4), 0.6, 0.3), false)
		var plate := Geo.label(self, Vector3(0, 0.018, 0), "ТИХАЯ", 0, 24, Color(0.9, 0.88, 0.8), true, 0.002)
		plate.rotation.x = -PI / 2
	else:
		# Часы на цепочке.
		Geo.cylinder(self, Vector3(0, 0.008, 0), 0.035, 0.014, brass)
		Geo.cylinder(self, Vector3(0, 0.016, 0), 0.03, 0.002, glow)
	Geo.collider_box(self, Vector3(0.3, 0.25, 0.3), Vector3(0, 0.1, 0))


func get_prompt(_player) -> String:
	match kind:
		"relic":
			return "E — взять: %s" % title
		"key":
			return "E — взять ключ «С-%d»" % amount
		"medkit":
			return "E — аптечка"
		"battery":
			return "E — взять батарейку"
		"bag":
			return "E — забрать свой вещмешок"
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
		_gone()
		return
	if kind == "bolts":
		var took := mini(amount, player.max_bolts() - player.bolts)
		if took <= 0:
			Game.say("Карман и так полон болтов.", Game.THOUGHT, 2.0)
			return
		player.bolts += took
		amount -= took
		Game.play_at(Sfx.pickup(), global_position, -6.0)
		Game.say_once("bolts_pick", "Болты. Бросить (G) — звякнут там, где упадут.", Game.THOUGHT, 3.5)
		if amount <= 0:
			_gone()
		return
	if kind == "fuse":
		player.fuses += 1
		Game.play_at(Sfx.pickup(), global_position, -6.0)
		Game.say("Предохранитель. Теперь — к щитку.", Game.THOUGHT, 3.0)
		_gone()
		return
	if kind == "relays":
		player.relays += amount
		Game.play_at(Sfx.pickup(), global_position, -6.0)
		Game.say("Три ретранслятора. Кронштейны для них — по тоннелю, на карте отмечены.", Game.THOUGHT, 4.0)
		_gone()
		return
	if kind == "key":
		player.keys[amount] = true
		Game.play_at(Sfx.pickup(), global_position, -6.0)
		Game.say("Ключ с биркой «С-%d». Где-то здесь служебка с таким номером." % amount, Game.THOUGHT, 4.0)
		_gone()
		return
	if kind == "medkit":
		if player.health >= Player.HEALTH_MAX - 1.0:
			Game.say("Цел. Аптечку — на потом.", Game.THOUGHT, 2.0)
			return
		player.health = minf(Player.HEALTH_MAX, player.health + 60.0)
		Game.play_at(Sfx.pickup(), global_position, -6.0)
		Game.say_once("medkit_use", "Бинт, йод, анальгин. Жить можно.", Game.THOUGHT, 3.0)
		_gone()
		return
	if kind == "battery":
		if player.batteries >= player.max_batteries():
			Game.say("Карманы полны — батарейка не влезет.", Game.THOUGHT, 2.0)
			return
		player.batteries += 1
		Game.report("gear:battery")  # в шестую смену — в запас на седьмую
		Game.play_at(Sfx.pickup(), global_position, -6.0)
		_gone()
		return
	if kind == "relic" or kind == "bag":
		player.add_loot(amount)
		Game.play_at(Sfx.pickup(), global_position, -6.0)
		if kind == "bag":
			Game.say("Мой вещмешок. Всё на месте — кроме меня в прошлый раз.", Game.THOUGHT, 3.5)
		else:
			Game.say_once("relic_pick", title.left(1).to_upper() + title.substr(1) + ". Наверху за такое заплатят — если вынесу.", Game.THOUGHT, 3.5)
		_gone()
		return
	if kind == "token":
		Game.play_at(Sfx.pickup(), global_position, -6.0)
		Game.report("token")
		Game.say("Жетон № 7. На обороте нацарапано: «ВОСЬМОЙ, НЕ ВЕРЬ ГОЛОСУ».", Game.THOUGHT, 5.0)
		_gone()
		return
	if kind == "pistol":
		player.has_pistol = true
		Game.report("gear:pistol")
		Game.say("Пистолет Макарова. Тяжёлый. Пусть так и останется в кобуре.", Game.THOUGHT, 4.0)
	else:
		Game.report("gear:ammo")
	player.ammo += amount
	Game.play_at(Sfx.pickup(), global_position, -6.0)
	_gone()


## Предмет забрали целиком: сообщить хозяину (старая линия помнит, что уже вынесено) и исчезнуть.
func _gone() -> void:
	if on_taken.is_valid():
		on_taken.call()
	queue_free()
