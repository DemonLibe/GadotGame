extends Node
## Автозагрузка Meta: деньги, улучшения снаряжения и копилка на операцию Маши.
## Хранится отдельно от прогресса смен (user://meta.cfg): ни провал смены, ни новая игра деньги не отнимают.
## Копилка на операцию — своя у каждого прохождения: новая игра начинает её заново.

signal changed
signal earned(amount: int, reason: String)

const SAVE_PATH := "user://meta.cfg"
const OPERATION_COST := 5000

## Сколько платят.
const PAY_TASK := 40      # за выполненное поручение
const PAY_SHIFT := 150    # за закрытую смену
const PAY_FIND := 100     # за находку
const PAY_NOTE := 25      # за впервые прочитанную записку
const PAY_CRAWLER := 30
const PAY_BITER := 5

## Расходники в шкафчике снабжения: id → [название, описание, цена].
const SUPPLIES := {
	"battery": ["Батарейка", "Заряжает фонарь сразу.", 60],
	"ammo": ["Патроны, 3 шт.", "К пистолету. Сам пистолет выдаёт диспетчер.", 45],
	"bolts": ["Болты, 3 шт.", "Бросить (G) — отвлечь.", 20],
	"canister": ["Канистра солярки", "Для генератора на станции.", 70],
}
## Улучшения: id → [название, описание, цены уровней]. Покупаются навсегда.
const UPGRADES := {
	"lamp": ["Налобник", "Луч длиннее и шире.", [300, 600]],
	"dynamo": ["Шестерня динамо", "Ручка заряжает быстрее и трещит тише.", [250, 500]],
	"boots": ["Тихие ботинки", "Шаги слышно вдвое ближе.", [300]],
	"vest": ["Разгрузка", "Карманы: +1 батарейка, +1 фильтр, +2 болта.", [350]],
}

var money := 0
var savings := 0                 # отложено на операцию (это прохождение)
var _levels := {}                # id улучшения → уровень


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		money = int(cf.get_value("meta", "money", 0))
		savings = int(cf.get_value("meta", "savings", 0))
		_levels = cf.get_value("meta", "levels", {})


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "money", money)
	cf.set_value("meta", "savings", savings)
	cf.set_value("meta", "levels", _levels)
	cf.save(SAVE_PATH)


func earn(amount: int, reason: String) -> void:
	if amount <= 0:
		return
	money += amount
	_save()
	earned.emit(amount, reason)
	changed.emit()


func spend(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	_save()
	changed.emit()
	return true


func level(id: String) -> int:
	return int(_levels.get(id, 0))


## Цена следующего уровня улучшения или -1, если уже всё куплено.
func upgrade_price(id: String) -> int:
	var prices: Array = UPGRADES[id][2]
	var l := level(id)
	return int(prices[l]) if l < prices.size() else -1


func buy_upgrade(id: String) -> bool:
	var price := upgrade_price(id)
	if price < 0 or not spend(price):
		return false
	_levels[id] = level(id) + 1
	_save()
	changed.emit()
	return true


## Отложить на операцию (не больше, чем осталось собрать).
func save_for_operation(amount: int) -> int:
	var put := mini(mini(amount, money), OPERATION_COST - savings)
	if put <= 0:
		return 0
	money -= put
	savings += put
	_save()
	changed.emit()
	return put


func operation_paid() -> bool:
	return savings >= OPERATION_COST


## Новая игра: копилка на операцию — заново. Деньги и снаряжение остаются.
func new_run() -> void:
	savings = 0
	_save()
	changed.emit()
