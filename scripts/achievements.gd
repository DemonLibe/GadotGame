extends Node
## Автозагрузка Achievements: достижения и находки. Хранятся отдельно от прогресса смен
## (user://achievements.cfg) и не сбрасываются новой игрой: найденное остаётся навсегда.

signal unlocked(id: String, title: String)
signal found(id: String)

const SAVE_PATH := "user://achievements.cfg"

## id: [название, описание, скрытое — описание не показывается, пока не получено, значок]
const LIST := {
	"shift1": ["Первая смена", "Отработать первую смену.", false, "moon"],
	"shift5": ["Последняя смена", "Дожить до пятой смены.", false, "moon"],
	"ending1": ["Доклад принят", "Концовка: доложить диспетчеру, где ты.", false, "door"],
	"ending2": ["Последний поезд", "Концовка: подняться, не докладывая, вернуться ещё на две смены и уехать.", false, "door"],
	"ending3": ["Изнутри", "Концовка: запереть решётку изнутри.", true, "door"],
	"archivist": ["Архивариус", "Прочитать все записки прежних обходчиков.", false, "note"],
	"masha": ["Фонарик для папы", "Прочитать письмо Маши.", false, "note"],
	"pyro": ["Поджигатель", "Сжечь 30 паутин (за всё время).", false, "flame"],
	"hunter": ["Пыль к пыли", "Уничтожить ползуна.", false, "cross"],
	"hid": ["Тише воды", "Пересидеть охоту «Другого» в шкафу.", false, "cabinet"],
	"quiet": ["Тихоня", "Отработать смену, ни разу не побежав.", false, "steps"],
	"brave": ["Холодная голова", "Отработать смену, не дав страху подняться выше половины.", false, "heart"],
	"lens": ["Дальний свет", "Найти рефлектор для фонаря.", false, "lamp"],
	"cell": ["Запасливый", "Найти аккумулятор повышенной ёмкости.", false, "battery"],
	"pills": ["Крепкие нервы", "Найти все три упаковки успокоительного.", false, "pill"],
	"duck": ["Резиновый друг", "Найти резиновую утку там, где ей точно не место.", true, "duck"],
	"sponjik": ["Vibe check", "Найти подпись автора на стене станции.", true, "chalk"],
	"collector": ["Коллекционер", "Найти все находки в тоннелях.", false, "star"],
}

## Находки в тоннелях: id → [смена, с которой лежит, название, что даёт].
const FINDS := {
	"pills1": [1, "Успокоительное", "Предел страха выше."],
	"pills2": [2, "Успокоительное", "Предел страха выше."],
	"pills3": [4, "Успокоительное", "Предел страха выше."],
	"lens": [3, "Рефлектор", "Луч фонаря длиннее и шире."],
	"cell": [3, "Аккумулятор", "Фонарь садится медленнее."],
	"duck": [4, "Резиновая утка", "Пищит."],
	"sponjik": [2, "Надпись мелом", "Vibe Games."],
}
const FEAR_PER_PILLS := 15.0

var _got := {}      # id достижения → true
var _finds := {}    # id находки → true
var _counters := {} # накопительные счётчики (паутина и т. п.)
var _dates := {}    # id достижения → время получения (unix)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		for k in cf.get_value("a", "got", []):
			_got[str(k)] = true
		for k in cf.get_value("a", "finds", []):
			_finds[str(k)] = true
		_counters = cf.get_value("a", "counters", {})
		_dates = cf.get_value("a", "dates", {})


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("a", "got", _got.keys())
	cf.set_value("a", "finds", _finds.keys())
	cf.set_value("a", "counters", _counters)
	cf.set_value("a", "dates", _dates)
	cf.save(SAVE_PATH)


func has(id: String) -> bool:
	return _got.has(id)


func unlock(id: String) -> void:
	if _got.has(id) or not LIST.has(id):
		return
	_got[id] = true
	_dates[id] = int(Time.get_unix_time_from_system())
	_save()
	unlocked.emit(id, str(LIST[id][0]))


## Накопительный счётчик; when_reaches — сколько нужно для достижения id.
func add_count(key: String, amount: int, id: String, when_reaches: int) -> void:
	_counters[key] = int(_counters.get(key, 0)) + amount
	_save()
	if int(_counters[key]) >= when_reaches:
		unlock(id)


func count() -> int:
	return _got.size()


# --- Находки -----------------------------------------------------------------

func has_find(id: String) -> bool:
	return _finds.has(id)


func collect(id: String) -> void:
	if _finds.has(id):
		return
	_finds[id] = true
	_save()
	found.emit(id)
	match id:
		"lens", "cell", "duck", "sponjik":
			unlock(id)
	if pills_found() >= 3:
		unlock("pills")
	if _finds.size() >= FINDS.size():
		unlock("collector")


func finds_count() -> int:
	return _finds.size()


func pills_found() -> int:
	var n := 0
	for k in _finds:
		if str(k).begins_with("pills"):
			n += 1
	return n


## Предел страха: каждая найденная упаковка успокоительного поднимает его.
func fear_max() -> float:
	return 100.0 + FEAR_PER_PILLS * pills_found()


## Прогресс накопительных достижений: [сколько, из скольки] или [] у остальных.
func progress(id: String) -> Array:
	match id:
		"pyro":
			return [mini(int(_counters.get("webs", 0)), 30), 30]
		"pills":
			return [pills_found(), 3]
		"collector":
			return [_finds.size(), FINDS.size()]
		"archivist":
			return [mini(Game.notes_count(), Game.NOTES_TOTAL), Game.NOTES_TOTAL]
	return []


## Для экрана достижений: [{id, title, text, got, hidden, icon, progress, date}].
func entries() -> Array:
	# Прогресс мог набраться раньше, чем появились достижения (старые сохранения), — засчитать.
	for id in ["archivist", "pyro", "pills", "collector"]:
		var p := progress(id)
		if not p.is_empty() and int(p[0]) >= int(p[1]):
			unlock(id)
	var out := []
	for id in LIST:
		var e: Array = LIST[id]
		var got := _got.has(id)
		var secret: bool = e[2] and not got
		out.append({
			"id": id,
			"title": "Скрытое достижение" if secret else str(e[0]),
			"text": "Продолжай играть, чтобы узнать." if secret else str(e[1]),
			"got": got,
			"hidden": secret,
			"icon": "hidden" if secret else str(e[3]),
			"progress": [] if got or secret else progress(id),
			"date": int(_dates.get(id, 0)),
		})
	return out


## Находки для коллекции: [{id, title, text, got}] в порядке FINDS.
func find_entries() -> Array:
	var out := []
	for id in FINDS:
		var f: Array = FINDS[id]
		var got := _finds.has(id)
		out.append({"id": id, "title": str(f[1]) if got else "???", "text": str(f[2]) if got else "Ещё не найдено.", "got": got})
	return out
