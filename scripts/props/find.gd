class_name Find
extends StaticBody3D
## Находка в тоннеле: успокоительное, рефлектор и аккумулятор для фонаря, пасхалки.
## Подбирается одним нажатием и остаётся навсегда (Achievements).

var find_id := "pills1"


func _ready() -> void:
	add_to_group("day_objects")
	match find_id:
		"lens":
			var chrome := ProcTex.flat(Color(0.8, 0.8, 0.82), 0.15, 1.0)
			Geo.cylinder(self, Vector3(0, 0.02, 0), 0.06, 0.04, chrome)
			Geo.cylinder(self, Vector3(0, 0.041, 0), 0.05, 0.004, ProcTex.emissive(Color(1.0, 0.95, 0.8), 0.6))
		"cell":
			Geo.model_fit(self, "res://models/items/battery.glb", ProcTex.model_skin("res://models/items/survival_palette.png", Color(0.5, 0.7, 1.0), 0.4, 0.4), 0.14, Vector3.ZERO, Basis(Vector3.FORWARD, PI / 2))
		"duck":
			var yellow := ProcTex.flat(Color(0.95, 0.8, 0.15), 0.4)
			var body := Geo.sphere(self, Vector3(0, 0.06, 0), 0.07, yellow)
			body.scale = Vector3(1.0, 0.8, 1.3)
			Geo.sphere(self, Vector3(0, 0.13, -0.06), 0.045, yellow)
			Geo.box(self, Vector3(0, 0.125, -0.11), Vector3(0.04, 0.012, 0.03), ProcTex.flat(Color(0.95, 0.45, 0.1), 0.5), false)
			for x in [-0.02, 0.02]:
				Geo.sphere(self, Vector3(float(x), 0.145, -0.095), 0.007, ProcTex.flat(Color(0.05, 0.05, 0.05), 0.3))
		"sponjik":
			Geo.label(self, Vector3(0, 0.0, 0.02), "VIBE GAMES\nmade by Sponjik", 0.0, 64, Color(0.85, 0.83, 0.78, 0.85), true, 0.0011)
			Geo.collider_box(self, Vector3(0.6, 0.25, 0.1), Vector3(0, 0, 0))
			return
		_:
			# Упаковка таблеток: коробочка и две таблетки рядом — Pills (mxc2, CC0).
			var box := Geo.box(self, Vector3(0, 0.025, 0), Vector3(0.09, 0.05, 0.06), ProcTex.flat(Color(0.85, 0.85, 0.8), 0.7), false)
			Geo.box(box, Vector3(0, 0.001, 0.0301), Vector3(0.07, 0.02, 0.001), ProcTex.flat(Color(0.2, 0.45, 0.7), 0.7), false)
			var pill_mat := ProcTex.flat(Color(0.75, 0.15, 0.12), 0.4)
			Geo.model_fit(self, "res://models/items/pill.glb", pill_mat, 0.035, Vector3(0.08, 0.0, 0.02))
			Geo.model_fit(self, "res://models/items/pill.glb", pill_mat, 0.035, Vector3(0.07, 0.0, -0.03), Basis(Vector3.UP, 1.2))
	Geo.collider_box(self, Vector3(0.3, 0.2, 0.3), Vector3(0, 0.1, 0))


func get_prompt(_player) -> String:
	match find_id:
		"sponjik":
			return "Надпись мелом — E: прочитать"
		"duck":
			return "E — поднять резиновую утку"
		"lens":
			return "E — взять рефлектор"
		"cell":
			return "E — взять аккумулятор"
	return "E — взять таблетки"


func interact(player) -> void:
	Achievements.collect(find_id)
	match find_id:
		"sponjik":
			Game.say("«VIBE GAMES. made by Sponjik». Кто-то спускался сюда до меня... и, похоже, ему было весело.", Game.THOUGHT, 5.0)
			return
		"duck":
			Game.play_at(Sfx.click(), global_position, 2.0)
			Game.say("Резиновая утка. Здесь. В затопленной штольне. Пищит.", Game.THOUGHT, 4.0)
		"lens":
			player.apply_upgrades()
			Game.say("Рефлектор от шахтёрской лампы. Встал на фонарь как родной — луч стал длиннее.", Game.THOUGHT, 4.5)
		"cell":
			player.apply_upgrades()
			Game.say("Аккумулятор повышенной ёмкости. Фонарь продержится дольше.", Game.THOUGHT, 4.0)
		_:
			Game.add_fear(-30.0)
			Game.say("Успокоительное. Пара таблеток — и руки уже не так трясутся. (Предел страха выше.)", Game.THOUGHT, 4.5)
	Game.play_at(Sfx.pickup(), global_position, -6.0)
	queue_free()
