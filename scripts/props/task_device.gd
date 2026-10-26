class_name TaskDevice
extends StaticBody3D
## Устройства для поручений: искрящий кабель (cable), датчик движения (sensor),
## насос в затопленной штольне (pump). Работают по удержанию E.
## Настенные смотрят по локальной +Z в тоннель, насос стоит на полу.

const HOLD := {"cable": 3.0, "sensor": 2.0, "pump": 2.0}
const DRAIN_TIME := 30.0

var kind := "cable"
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
		"pump":
			if done:
				return "Насос работает" if _draining else "Насос: вода откачана"
			return "Удерживай E — запустить насос"
	return ""


func hold_interact(player, delta: float) -> float:
	if done:
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
