extends Node
## Глобальное состояние (автозагрузка Game): день, поручения, страх, реплики и звук.

signal tasks_changed
signal message(text: String, color: Color, duration: float)
signal end_day_requested

const FINAL_DAY := 5
const THOUGHT := Color(0.93, 0.91, 0.84)
const WHISPER := Color(0.62, 0.64, 0.75)
const SYSTEM := Color(0.6, 0.86, 0.6)
const SAVE_PATH := "user://hope_light.cfg"

var day := 1
var tasks: Array[Dictionary] = []
var fear := 0.0
var ended := false
var notes_read := {}  # прочитанные записки (id → true), копятся за всю игру
const NOTES_TOTAL := 9
var _said := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()


# --- Поручения -------------------------------------------------------------

func build_tasks(d: int) -> void:
	tasks.clear()
	_said.clear()
	_task("radio", "Забрать рацию со стола", 1)
	match d:
		1:
			_task("charge:station", "Зарядить фонарь на станции", 1)
			_task("filters", "Заменить забитый фильтр в вентиляции", 1)
			_task("webs", "Сжечь паутину в тоннеле", 2)
		2:
			_task("inspect:end", "Осмотреть завал у ограждения", 1)
			_task("filters", "Заменить забитые фильтры", 2)
			_task("webs", "Сжечь паутину в тоннеле", 3)
		3:
			_task("inspect:cart", "Проверить вагонетку", 1)
			_task("filters", "Заменить забитые фильтры", 2)
			_task("webs", "Сжечь паутину в тоннеле", 4)
		4:
			_task("charge:far", "Зарядить фонарь у дальнего щитка", 1)
			_task("filters", "Заменить забитые фильтры", 3)
			_task("webs", "Сжечь паутину в тоннеле", 5)
		_:
			_task("inspect:grate", "Проверить решётку в конце тоннеля", 1)
	_task("return", "Доложить диспетчеру по рации", 1)
	tasks_changed.emit()


func _task(kind: String, text: String, target: int) -> void:
	tasks.append({"kind": kind, "text": text, "target": target, "progress": 0, "done": false})


## Добавляет поручение перед финальным «отметиться в журнале».
func add_task(kind: String, text: String, target: int) -> void:
	var t := {"kind": kind, "text": text, "target": target, "progress": 0, "done": false}
	tasks.insert(maxi(tasks.size() - 1, 0), t)
	tasks_changed.emit()


func report(kind: String, amount := 1) -> void:
	var changed := false
	for t in tasks:
		if t["kind"] == kind and not t["done"]:
			t["progress"] = mini(int(t["progress"]) + amount, int(t["target"]))
			if t["progress"] >= t["target"]:
				t["done"] = true
				if kind != "return":
					say("Выполнено: " + str(t["text"]), SYSTEM, 3.0)
			changed = true
	if changed:
		tasks_changed.emit()


func task_target(kind: String) -> int:
	for t in tasks:
		if t["kind"] == kind:
			return int(t["target"])
	return 0


func has_open_task(kind: String) -> bool:
	for t in tasks:
		if t["kind"] == kind and not t["done"]:
			return true
	return false


## Всё, кроме «отметиться в журнале», выполнено.
func all_done() -> bool:
	for t in tasks:
		if t["kind"] != "return" and not t["done"]:
			return false
	return true


func remaining_text() -> String:
	var parts: PackedStringArray = []
	for t in tasks:
		if t["kind"] != "return" and not t["done"]:
			parts.append(str(t["text"]).to_lower())
	return ", ".join(parts)


# --- Сохранение (какая смена следующая) ----------------------------------------

func save_day(d: int) -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "day", d)
	cf.save(SAVE_PATH)


func load_day() -> int:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return 1
	return clampi(int(cf.get_value("progress", "day", 1)), 1, FINAL_DAY)


# --- Реплики и страх -------------------------------------------------------

func say(text: String, color := THOUGHT, duration := 4.0) -> void:
	message.emit(text, color, duration)


## Реплика, которая звучит не больше одного раза за день.
func say_once(key: String, text: String, color := THOUGHT, duration := 4.0) -> void:
	if _said.has(key):
		return
	_said[key] = true
	say(text, color, duration)


func add_fear(amount: float) -> void:
	fear = clampf(fear + amount, 0.0, 100.0)


# --- Звук ------------------------------------------------------------------

func play_at(stream: AudioStream, pos: Vector3, volume_db := 0.0) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.unit_size = 8.0
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func play_ui(stream: AudioStream, volume_db := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# --- Управление ------------------------------------------------------------
# Физические клавиши: работают и на русской раскладке.

func _setup_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("run", [KEY_SHIFT])
	_bind("interact", [KEY_E])
	_bind("flashlight", [KEY_F])
	_bind("restart", [KEY_R])
	_bind("slot_1", [KEY_1])
	_bind("slot_2", [KEY_2])
	_bind("slot_3", [KEY_3])
	_bind("slot_4", [KEY_4])
	_bind("slot_5", [KEY_5])
	_bind("slot_6", [KEY_6])
	_bind("slot_7", [KEY_7])
	_bind("jump", [KEY_SPACE])
	if not InputMap.has_action("burn"):
		InputMap.add_action("burn")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("burn", mb)


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
