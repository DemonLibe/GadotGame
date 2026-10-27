extends Node
## Автозагрузка Achievements: достижения и находки. Хранятся отдельно от прогресса смен
## (user://achievements.cfg) и не сбрасываются новой игрой: найденное остаётся навсегда.

signal unlocked(id: String, title: String)
signal found(id: String)

const SAVE_PATH := "user://achievements.cfg"

## id: [название, описание, скрытое — описание не показывается, пока не получено]
const LIST := {
	"shift1": ["Первая смена", "Отработать первую смену.", false],
	"shift5": ["Последняя смена", "Дожить до пятой смены.", false],
	"ending1": ["Доклад принят", "Концовка: доложить диспетчеру, где ты.", false],
	"ending2": ["Поднялся", "Концовка: выбраться наверх, не докладывая.", false],
	"ending3": ["Изнутри", "Концовка: запереть решётку изнутри.", true],
	"archivist": ["Архивариус", "Прочитать все записки прежних обходчиков.", false],
	"masha": ["Фонарик для папы", "Прочитать письмо Маши.", false],
	"pyro": ["Поджигатель", "Сжечь 30 паутин (за всё время).", false],
	"hunter": ["Пыль к пыли", "Уничтожить ползуна.", false],
	"hid": ["Тише воды", "Пересидеть охоту «Другого» в шкафу.", false],
	"quiet": ["Тихоня", "Отработать смену, ни разу не побежав.", false],
	"brave": ["Холодная голова", "Отработать смену, не дав страху подняться выше половины.", false],
	"lens": ["Дальний свет", "Найти рефлектор для фонаря.", false],
	"cell": ["Запасливый", "Найти аккумулятор повышенной ёмкости.", false],
	"pills": ["Крепкие нервы", "Найти все три упаковки успокоительного.", false],
	"duck": ["Резиновый друг", "???", true],
	"sponjik": ["Vibe check", "???", true],
	"collector": ["Коллекционер", "Найти все находки в тоннелях.", false],
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		for k in cf.get_value("a", "got", []):
			_got[str(k)] = true
		for k in cf.get_value("a", "finds", []):
			_finds[str(k)] = true
		_counters = cf.get_value("a", "counters", {})


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("a", "got", _got.keys())
	cf.set_value("a", "finds", _finds.keys())
	cf.set_value("a", "counters", _counters)
	cf.save(SAVE_PATH)


func has(id: String) -> bool:
	return _got.has(id)


func unlock(id: String) -> void:
	if _got.has(id) or not LIST.has(id):
		return
	_got[id] = true
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


## Для экрана в меню: [{title, text, got}].
func entries() -> Array:
	var out := []
	for id in LIST:
		var e: Array = LIST[id]
		var got := _got.has(id)
		out.append({"title": str(e[0]) if got or not e[2] else "???", "text": str(e[1]) if got or not e[2] else "Скрытое достижение.", "got": got})
	return out
