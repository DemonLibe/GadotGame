extends Node
## Автозагрузка Meta: деньги, улучшения снаряжения и копилка на операцию Маши.
## Хранится отдельно от прогресса смен (user://meta.cfg): ни провал смены, ни новая игра деньги не отнимают.
## Копилка на операцию — своя у каждого прохождения: новая игра начинает её заново.

signal changed
signal earned(amount: int, reason: String)

const SAVE_PATH := "user://meta.cfg"
const OPERATION_COST := 5000

## Сколько платят. Поручение — по трудности; каждое — один раз за смену (повтор после провала не платят).
## За убитых существ не платят: обходчик — не охотник, патроны дороже.
const PAY_TASK := 40      # обычное поручение
const TASK_PAY := {
	"generator": 15, "crank": 10, "descend": 20, "radio": 0, "return": 0, "exit": 0,
	"platform": 70, "token": 90, "valves": 60, "relay": 60, "cartpush": 50, "photo": 50,
	"fuse": 50, "cable": 50, "water": 50, "filters": 40, "webs": 40, "sensor": 40,
}
const PAY_SHIFT := 100    # за закрытую смену…
const PAY_SHIFT_PER_DAY := 40  # …и сверху за каждую следующую: чем глубже, тем дороже
const PAY_FIND := 100     # за находку
const PAY_NOTE := 25      # за впервые прочитанную записку
## Перевод на операцию — не больше стольких рублей за смену (почта принимает раз в смену).
const OPERATION_PER_SHIFT := 1000

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
var sent_this_shift := 0         # сколько уже отложено на операцию в эту смену


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


## Плата за поручение (осмотры и сборы шестой смены — по 30 и 0).
func task_pay(kind: String) -> int:
	if TASK_PAY.has(kind):
		return int(TASK_PAY[kind])
	if kind.begins_with("inspect:"):
		return 30
	if kind.begins_with("gear:"):
		return 0
	return PAY_TASK


func shift_pay(day: int) -> int:
	return PAY_SHIFT + PAY_SHIFT_PER_DAY * (day - 1)


## Новая смена: перевод на операцию снова открыт.
func new_shift() -> void:
	sent_this_shift = 0
	changed.emit()


## Сколько ещё можно отложить в эту смену.
func can_send() -> int:
	return maxi(0, mini(OPERATION_PER_SHIFT - sent_this_shift, OPERATION_COST - savings))


## Отложить на операцию (не больше, чем осталось собрать и чем примут за смену).
func save_for_operation(amount: int) -> int:
	var put := mini(mini(amount, money), can_send())
	if put <= 0:
		return 0
	money -= put
	savings += put
	sent_this_shift += put
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
