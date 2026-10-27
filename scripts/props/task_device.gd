class_name TaskDevice
extends StaticBody3D
## Устройства для поручений: искрящий кабель (cable), датчик движения (sensor),
## насос в затопленной штольне (pump), щиток (fuse), задвижка (valve), кронштейн ретранслятора (relay),
## точка осмотра для снимка (photo). Работают по удержанию E.
## Настенные смотрят по локальной +Z в тоннель, насос стоит на полу.

const HOLD := {"cable": 3.0, "sensor": 2.0, "pump": 2.0, "fuse": 2.5, "valve": 1.5, "relay": 2.0, "photo": 1.0}
const DRAIN_TIME := 30.0

var kind := "cable"
var index := 1  # номер задвижки или точки осмотра
var main  # Main — для снимка
var generator: Generator
var done := false
var water_level := 1.0  # насос: 1 — штольня затоплена, 0 — сухо
var water: MeshInstance3D
var _progress := 0.0
var _sparks: CPUParticles3D
var _spark_light: OmniLight3D
var _sound: AudioStreamPlayer3D
var _led: StandardMaterial3D
var _screen: Label3D
var _draining := false
var _blink := 0.0
var _wheel: Node3D


func _ready() -> void:
	add_to_group("day_objects")
	var dark := ProcTex.flat(Color(0.06, 0.06, 0.06), 0.8)
	var steel := ProcTex.flat(Color(0.32, 0.33, 0.32), 0.5, 0.7)
	_sound = AudioStreamPlayer3D.new()
	_sound.unit_size = 3.0
	add_child(_sound)
	match kind:
		"cable":
			# Распределительная коробка, из неё свисает перебитый кабель.
			Geo.box(self, Vector3(0, 0, 0.06), Vector3(0.35, 0.3, 0.12), steel, false)
			Geo.box(self, Vector3(0, 0.06, 0.125), Vector3(0.36, 0.04, 0.01), ProcTex.hazard(), false)
			var cable := Geo.cylinder(self, Vector3(0.05, -0.35, 0.14), 0.02, 0.45, dark)
			cable.rotation.z = 0.35
			Geo.cylinder(self, Vector3(0.2, -0.62, 0.14), 0.02, 0.2, dark, Basis(Vector3.FORWARD, 1.2))
			Geo.sphere(self, Vector3(0.12, -0.56, 0.14), 0.03, ProcTex.flat(Color(0.75, 0.45, 0.15), 0.4, 0.9))
			_sparks = CPUParticles3D.new()
			_sparks.amount = 24
			_sparks.lifetime = 0.5
			_sparks.explosiveness = 0.6
			_sparks.position = Vector3(0.12, -0.56, 0.16)
			_sparks.direction = Vector3(0, 1, 1)
			_sparks.spread = 70.0
			_sparks.initial_velocity_min = 1.0
			_sparks.initial_velocity_max = 2.5
			_sparks.gravity = Vector3(0, -6, 0)
			var q := QuadMesh.new()
			q.size = Vector2(0.015, 0.015)
			q.material = ProcTex.emissive(Color(1.0, 0.85, 0.4), 4.0)
			(q.material as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			_sparks.mesh = q
			add_child(_sparks)
			_spark_light = OmniLight3D.new()
			_spark_light.position = Vector3(0.12, -0.5, 0.4)
			_spark_light.light_color = Color(0.7, 0.8, 1.0)
			_spark_light.omni_range = 3.0
			_spark_light.add_to_group("cull_light")
			add_child(_spark_light)
			_sound.stream = Sfx.sparks()
			Geo.collider_box(self, Vector3(0.5, 0.9, 0.3), Vector3(0, -0.3, 0.1))
		"sensor":
			Geo.box(self, Vector3(0, 0, 0.05), Vector3(0.28, 0.36, 0.1), ProcTex.flat(Color(0.75, 0.73, 0.65), 0.6), false)
			Geo.sphere(self, Vector3(0, 0.08, 0.1), 0.05, ProcTex.flat(Color(0.1, 0.1, 0.12), 0.2, 0.3))
			_led = ProcTex.emissive(Color(1.0, 0.15, 0.1), 3.0)
			Geo.sphere(self, Vector3(0.09, -0.12, 0.1), 0.012, _led)
			Geo.label(self, Vector3(0, 0.25, 0.101), "ДД-3  ПИКЕТ 3", 0, 18, Color(0.2, 0.2, 0.2), true, 0.0018)
			_screen = Geo.label(self, Vector3(-0.03, -0.1, 0.101), "ОШИБКА", 0, 18, Color(1.0, 0.3, 0.2), false, 0.0018)
			Geo.collider_box(self, Vector3(0.35, 0.45, 0.15), Vector3(0, 0, 0.07))
		"pump":
			var green := ProcTex.flat(Color(0.2, 0.32, 0.25), 0.6, 0.4)
			Geo.box(self, Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.5), green, false)
			Geo.cylinder(self, Vector3(0, 0.72, 0), 0.16, 0.25, steel)
			Geo.cylinder(self, Vector3(0.35, 0.15, 0), 0.07, 0.3, dark, Basis(Vector3.FORWARD, PI / 2))
			Geo.cylinder(self, Vector3(0.9, 0.06, 0), 0.06, 0.9, dark, Basis(Vector3.FORWARD, PI / 2))
			_led = ProcTex.emissive(Color(1.0, 0.15, 0.1), 3.0)
			Geo.sphere(self, Vector3(-0.15, 0.5, 0.26), 0.02, _led)
			Geo.label(self, Vector3(0, 0.45, 0.255), "НАСОС", 0, 22, Color(0.85, 0.8, 0.6), true, 0.002)
			_sound.stream = Sfx.pump()
			Geo.collider_box(self, Vector3(0.65, 0.9, 0.55), Vector3(0, 0.45, 0))


		"fuse":
			# Серый щиток с дверцей; красный огонёк — выбит.
			Geo.box(self, Vector3(0, 0, 0.07), Vector3(0.4, 0.55, 0.14), steel, false)
			Geo.box(self, Vector3(0, 0, 0.142), Vector3(0.36, 0.5, 0.005), ProcTex.flat(Color(0.4, 0.42, 0.4), 0.5, 0.6), false)
			Geo.label(self, Vector3(0, 0.18, 0.146), "ЩИТ ОСВ.", 0, 22, Color(0.9, 0.85, 0.2), true, 0.002)
			Geo.box(self, Vector3(0, 0.06, 0.146), Vector3(0.3, 0.03, 0.002), ProcTex.hazard(), false)
			_led = ProcTex.emissive(Color(1.0, 0.15, 0.1), 3.0)
			Geo.sphere(self, Vector3(0.12, -0.18, 0.15), 0.015, _led)
			_sound.stream = Sfx.hum()
			Geo.collider_box(self, Vector3(0.45, 0.6, 0.2), Vector3(0, 0, 0.08))
		"valve":
			# Труба вдоль стены и задвижка с колесом. Номер — крупно, мелом.
			add_to_group("valves")
			Geo.cylinder(self, Vector3(0, 0, 0.12), 0.07, 1.2, ProcTex.flat(Color(0.3, 0.18, 0.12), 0.8, 0.4), Basis(Vector3.FORWARD, PI / 2))
			Geo.box(self, Vector3(0, 0, 0.12), Vector3(0.2, 0.2, 0.18), steel, false)
			_wheel = Node3D.new()
			_wheel.position = Vector3(0, 0, 0.26)
			add_child(_wheel)
			var red := ProcTex.flat(Color(0.55, 0.08, 0.06), 0.6, 0.4)
			Geo.cylinder(_wheel, Vector3.ZERO, 0.16, 0.025, red, Basis(Vector3.RIGHT, PI / 2))
			Geo.cylinder(_wheel, Vector3.ZERO, 0.02, 0.1, steel, Basis(Vector3.RIGHT, PI / 2))
			Geo.label(self, Vector3(0, 0.38, 0.03), "З-%d" % index, 0, 64, Color(0.9, 0.88, 0.8), true, 0.0035)
			_sound.stream = Sfx.hiss()
			Geo.collider_box(self, Vector3(0.45, 0.45, 0.35), Vector3(0, 0, 0.17))
		"relay":
			# Пустой кронштейн с биркой — сюда вешается ретранслятор.
			Geo.box(self, Vector3(0, -0.1, 0.08), Vector3(0.25, 0.03, 0.16), steel, false)
			Geo.box(self, Vector3(0, 0.05, 0.01), Vector3(0.25, 0.3, 0.02), steel, false)
			Geo.label(self, Vector3(0, 0.25, 0.025), "РЕТР. %d" % index, 0, 22, Color(0.85, 0.85, 0.8), true, 0.002)
			Geo.collider_box(self, Vector3(0.35, 0.45, 0.25), Vector3(0, 0, 0.1))
		"photo":
			# Круг мелом на стене и номер точки осмотра.
			var chalk := ProcTex.flat(Color(0.85, 0.83, 0.78), 1.0)
			for k in 16:
				var a := TAU * k / 16.0
				Geo.box(self, Vector3(cos(a) * 0.3, sin(a) * 0.3, 0.01), Vector3(0.13, 0.025, 0.004), chalk, false, Basis(Vector3.BACK, a + PI / 2))
			Geo.label(self, Vector3(0, -0.45, 0.012), "ТО-%d" % index, 0, 56, Color(0.85, 0.83, 0.78), true, 0.003)
			Geo.collider_box(self, Vector3(0.7, 0.9, 0.1), Vector3(0, -0.1, 0.05))


func _process(delta: float) -> void:
	match kind:
		"cable":
			var live := not done and generator != null and generator.running
			_sparks.emitting = live and randf() < 0.9
			_spark_light.light_energy = randf_range(0.0, 2.0) if live and randf() < 0.3 else 0.0
			if live != _sound.playing:
				if live:
					_sound.play()
				else:
					_sound.stop()
		"sensor":
			_blink += delta
			_led.emission_energy_multiplier = 3.0 if fmod(_blink, 1.0) < 0.5 else 0.2
		"relay":
			if done:
				_blink += delta
				_led.emission_energy_multiplier = 3.0 if fmod(_blink, 1.5) < 0.2 else 0.3
		"pump":
			if _draining:
				water_level = maxf(0.0, water_level - delta / DRAIN_TIME)
				if water:
					water.position.y = Level.FLOOR_Y + 0.02 + 0.33 * water_level
					water.visible = water_level > 0.01
				if water_level <= 0.0:
					_draining = false
					_sound.stop()
					Game.report("water")
					Game.say("Вода ушла. Под ногами — рельсы и... кости? Нет, просто ветки. Откуда здесь ветки?", Game.THOUGHT, 4.5)


func get_prompt(_player) -> String:
	match kind:
		"cable":
			if done:
				return "Кабель заизолирован"
			return "Удерживай E — заизолировать кабель"
		"sensor":
			return "Датчик движения перезагружен" if done else "Удерживай E — перезагрузить датчик движения"
		"fuse":
			if done:
				return "Щиток: предохранитель на месте"
			return "Удерживай E — вставить предохранитель" if _player_has(_player, "fuses") else "Щиток выбит — нужен запасной предохранитель"
		"valve":
			return "Задвижка З-%d перекрыта" % index if done else "Удерживай E — перекрыть задвижку З-%d" % index
		"relay":
			if done:
				return "Ретранслятор висит, огонёк мигает"
			return "Удерживай E — повесить ретранслятор" if _player_has(_player, "relays") else "Кронштейн для ретранслятора (ящик — на станции)"
		"photo":
			return "Точка осмотра ТО-%d — снята" % index if done else "Удерживай E — сфотографировать точку ТО-%d" % index
		"pump":
			if done:
				return "Насос работает" if _draining else "Насос: вода откачана"
			return "Удерживай E — запустить насос"
	return ""


func _player_has(player, what: String) -> bool:
	return player != null and int(player.get(what)) > 0


func hold_interact(player, delta: float) -> float:
	if done:
		return -1.0
	if (kind == "fuse" and not _player_has(player, "fuses")) or (kind == "relay" and not _player_has(player, "relays")):
		return -1.0
	if kind in ["fuse", "valve", "relay", "photo"] and not Game.has_open_task({"fuse": "fuse", "valve": "valves", "relay": "relay", "photo": "photo"}[kind]):
		return -1.0
	if kind == "cable" and generator != null and generator.running:
		_progress = 0.0
		player.take_damage(15.0)
		player.flicker(0.6)
		Game.play_at(Sfx.sparks(), global_position, 4.0)
		Game.say("Ударило током! Сначала заглушить генератор на станции.", Game.THOUGHT, 3.5)
		return -1.0
	_progress += delta / float(HOLD[kind])
	if _progress < 1.0:
		return _progress
	done = true
	match kind:
		"cable":
			Game.play_at(Sfx.click(), global_position, -4.0)
			Game.report("cable")
			Game.say("Готово. Теперь — назад к генератору, запустить снова.", Game.THOUGHT, 3.5)
		"sensor":
			_led.albedo_color = Color(0.2, 1.0, 0.3)
			_led.emission = Color(0.2, 1.0, 0.3)
			_screen.text = "ДВИЖЕНИЕ: 2"
			_screen.modulate = Color(0.4, 1.0, 0.5)
			Game.play_at(Sfx.pickup(), global_position, -4.0)
			Game.report("sensor")
			get_tree().create_timer(1.5).timeout.connect(func(): Game.say("Датчик перезагружен. «Движение: 2». Здесь. Сейчас. Нас двое.", Game.THOUGHT, 4.5))
		"fuse":
			player.fuses -= 1
			_led.albedo_color = Color(0.2, 1.0, 0.3)
			_led.emission = Color(0.2, 1.0, 0.3)
			_sound.play()
			Game.play_at(Sfx.clank(), global_position, -2.0)
			Game.report("fuse")
			Game.say("Щёлк — и щиток загудел. Теперь отсюда — подальше.", Game.THOUGHT, 3.5)
		"valve":
			if Game.valve_order[Game.tasks_progress("valves")] != index:
				# Не та — пар срывает все уже перекрытые задвижки.
				done = false
				_progress = 0.0
				_sound.play()
				Game.make_noise(global_position, 25.0)
				Game.play_at(Sfx.hiss(), global_position + Vector3(0, 0.5, 0), 6.0)
				for n in get_tree().get_nodes_in_group("valves"):
					(n as TaskDevice).reopen()
				Game.reset_task("valves")
				Game.say("Не та! Пар засвистел на весь тоннель — и все задвижки сорвало. Заново, по порядку из журнала.", Game.THOUGHT, 4.5)
				return -1.0
			_wheel.rotation.z += PI
			Game.play_at(Sfx.creak(), global_position, -4.0)
			Game.report("valves")
		"relay":
			player.relays -= 1
			_led = ProcTex.emissive(Color(0.2, 1.0, 0.3), 3.0)
			Geo.box(self, Vector3(0, -0.02, 0.09), Vector3(0.18, 0.13, 0.12), ProcTex.flat(Color(0.2, 0.25, 0.2), 0.6, 0.3), false)
			Geo.cylinder(self, Vector3(0.06, 0.15, 0.09), 0.006, 0.22, ProcTex.flat(Color(0.05, 0.05, 0.05), 0.5))
			Geo.sphere(self, Vector3(-0.05, 0.02, 0.152), 0.012, _led)
			Game.play_at(Sfx.click(), global_position, -4.0)
			Game.report("relay")
		"photo":
			if main:
				main.take_photo(self)
			Game.report("photo")
		"pump":
			_draining = true
			_sound.play()
			_led.albedo_color = Color(0.2, 1.0, 0.3)
			_led.emission = Color(0.2, 1.0, 0.3)
			Game.make_noise(global_position, 20.0)
			Game.say("Насос загудел. Вода пошла... Громко. Слишком громко.", Game.THOUGHT, 3.5)
	return -1.0


func hold_cancel() -> void:
	_progress = 0.0


## Задвижку сорвало паром — снова открыта.
func reopen() -> void:
	if kind == "valve" and done:
		done = false
		_wheel.rotation.z -= PI
