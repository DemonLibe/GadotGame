class_name Generator
extends StaticBody3D
## Дизель-генератор на платформе. Без него лампы в тоннелях не горят.
## Топливо кончается — нужны канистры. Запуск слышно на весь тоннель.
## Передняя панель смотрит по локальной +Z.

const HOLD_START := 1.5
const HOLD_STOP := 1.0
const HOLD_FUEL := 2.0
const BURN_TIME := 420.0  # полный бак — семь минут

var level: Level
var fuel := 100.0
var running := false
var _progress := 0.0
var _action := ""
var _fails := 0
var _lamp_mat: StandardMaterial3D
var _gauge: Node3D
var _engine: AudioStreamPlayer3D
var _shake := 0.0
var _body: Node3D


func _ready() -> void:
	var yellow := ProcTex.flat(Color(0.62, 0.48, 0.12), 0.6, 0.4)
	var dark := ProcTex.flat(Color(0.08, 0.08, 0.08), 0.8)
	var steel := ProcTex.flat(Color(0.3, 0.31, 0.3), 0.5, 0.7)
	# Рама на полозьях.
	Geo.box(self, Vector3(-0.42, 0.04, 0), Vector3(0.08, 0.08, 1.1), steel, false)
	Geo.box(self, Vector3(0.42, 0.04, 0), Vector3(0.08, 0.08, 1.1), steel, false)
	_body = Node3D.new()
	add_child(_body)
	Geo.box(_body, Vector3(0, 0.42, 0.05), Vector3(0.8, 0.66, 0.9), yellow, false)
	Geo.box(_body, Vector3(0, 0.8, -0.15), Vector3(0.6, 0.12, 0.45), yellow, false)  # бак
	Geo.cylinder(_body, Vector3(0.18, 0.9, -0.15), 0.05, 0.06, dark)  # крышка бака
	Geo.cylinder(_body, Vector3(-0.3, 0.95, -0.35), 0.04, 0.5, steel)  # выхлоп
	for i in 6:
		Geo.box(_body, Vector3(0, 0.25 + i * 0.07, -0.41), Vector3(0.7, 0.025, 0.02), dark, false)
	# Панель: стрелка топлива, лампа, ручка стартера.
	Geo.box(_body, Vector3(0, 0.55, 0.505), Vector3(0.5, 0.3, 0.02), dark, false)
	Geo.cylinder(_body, Vector3(-0.12, 0.58, 0.52), 0.07, 0.01, ProcTex.flat(Color(0.85, 0.82, 0.7), 0.6), Basis(Vector3.RIGHT, PI / 2))
	_gauge = Node3D.new()
	_gauge.position = Vector3(-0.12, 0.58, 0.53)
	_body.add_child(_gauge)
	Geo.box(_gauge, Vector3(0, 0.03, 0), Vector3(0.008, 0.06, 0.004), ProcTex.flat(Color(0.7, 0.1, 0.05), 0.6), false)
	_lamp_mat = ProcTex.emissive(Color(1.0, 0.2, 0.1), 2.0)
	Geo.sphere(_body, Vector3(0.12, 0.62, 0.52), 0.025, _lamp_mat)
	Geo.box(_body, Vector3(0.12, 0.48, 0.53), Vector3(0.1, 0.03, 0.03), dark, false)
	Geo.label(_body, Vector3(0, 0.9, 0.506), "ДГ-12", 0, 30, Color(0.1, 0.1, 0.1), true, 0.003)
	Geo.collider_box(self, Vector3(0.85, 1.0, 1.1), Vector3(0, 0.5, 0))
	_engine = AudioStreamPlayer3D.new()
	_engine.stream = Sfx.engine()
	_engine.unit_size = 5.0
	_engine.volume_db = -4.0
	_engine.position = Vector3(0, 0.5, 0)
	add_child(_engine)


## Новая смена: генератор заглушен, в баке — сколько осталось.
func reset(start_fuel: float) -> void:
	fuel = start_fuel
	_fails = 0
	_set_running(false)


func _set_running(value: bool) -> void:
	running = value
	if level:
		level.power_on = value
	if not is_node_ready():
		return
	if value:
		_engine.play()
	else:
		_engine.stop()
	var c := Color(0.2, 1.0, 0.3) if value else Color(1.0, 0.2, 0.1)
	_lamp_mat.albedo_color = c
	_lamp_mat.emission = c


## Заглох сам (или ему «помогли»).
func stall() -> void:
	if not running:
		return
	_set_running(false)
	Game.play_at(Sfx.clank(), global_position + Vector3(0, 0.6, 0), -2.0)


func _process(delta: float) -> void:
	_gauge.rotation.z = lerpf(1.2, -1.2, fuel / 100.0)
	if not running:
		_body.position = Vector3.ZERO
		return
	fuel = maxf(0.0, fuel - 100.0 / BURN_TIME * delta)
	_shake += delta * 40.0
	_body.position = Vector3(sin(_shake) * 0.004, absf(sin(_shake * 1.3)) * 0.004, 0)
	if fuel <= 0.0:
		stall()
		Game.say("Генератор заглох — кончилось топливо. В тоннеле погас свет.", Game.THOUGHT, 4.0)
	elif fuel < 15.0:
		Game.say_once("fuel_low", "Генератор чихает. Топливо на исходе — нужна канистра.", Game.THOUGHT, 3.5)


func _wanted(player) -> String:
	if running:
		return "fuel" if player.canisters > 0 and fuel < 85.0 else "stop"
	if fuel <= 1.0:
		return "fuel" if player.canisters > 0 else ""
	return "start"


func get_prompt(player) -> String:
	var tank := "топливо %d%%" % int(fuel)
	match _wanted(player):
		"fuel":
			return "Удерживай E — залить канистру (%s)" % tank
		"stop":
			return "Генератор работает, %s · удерживай E — заглушить" % tank
		"start":
			return "Удерживай E — дёрнуть стартер (%s)" % tank
	return "Генератор: бак пуст. Нужна канистра"


func hold_interact(player, delta: float) -> float:
	var want := _wanted(player)
	if want == "":
		return -1.0
	if want != _action:
		_action = want
		_progress = 0.0
	var need := HOLD_FUEL if want == "fuel" else (HOLD_STOP if want == "stop" else HOLD_START)
	_progress += delta / need
	if _progress < 1.0:
		return _progress
	_progress = 0.0
	match want:
		"fuel":
			player.canisters -= 1
			fuel = minf(100.0, fuel + 55.0)
			Game.play_at(Sfx.pickup(), global_position, -6.0)
			Game.say("Залил канистру. Бак: %d%%." % int(fuel), Game.SYSTEM, 2.5)
		"stop":
			stall()
			Game.say("Генератор заглушен. Тоннель обесточен.", Game.SYSTEM, 2.5)
		"start":
			# Старый дизель заводится не с первого раза.
			if _fails < 1 and Game.day >= 2 and randf() < 0.6:
				_fails += 1
				Game.play_at(Sfx.rumble(), global_position, -10.0)
				Game.make_noise(global_position, 12.0)
				Game.say_once("gen_fail", "Чихнул и заглох. Ещё раз...", Game.THOUGHT, 2.5)
				return -1.0
			_set_running(true)
			Game.make_noise(global_position, 25.0)
			Game.report("generator")
			Game.say_once("gen_on", "Завёлся. Грохот на весь тоннель... зато есть свет.", Game.THOUGHT, 3.5)
	return -1.0


func hold_cancel() -> void:
	_progress = 0.0
