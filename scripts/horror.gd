class_name Horror
extends Node
## Второй слой страха поверх «режиссёра»: то, что работает постоянно и откликается на поведение игрока.
##  • чужой почерк в дневнике — записи, которых герой не писал, и они знают, что он делает;
##  • темнота дышит — погасил фонарь вдали от ламп, и рядом кто-то есть;
##  • когти по дверце шкафа, пока сидишь внутри;
##  • стук в трубах — три раза далеко, потом три раза ближе;
##  • жуткий фон и далёкие стоны (в старой линии — чаще).

var main  # Main
var player: Player
var level: Level

# Чужие записи: сколько за смену и когда следующая.
const FOREIGN := {3: 1, 4: 2, 5: 2, 6: 2, 7: 2}
const FOREIGN_POOL := [
	"Не оборачивайся.",
	"Ты считаешь ступеньки. Я считаю тебя.",
	"Маша спрашивала, когда ты придёшь. Я сказал — скоро.",
	"Сегодня ты шёл быстрее. Я всё равно успел.",
	"Седьмой тоже вёл дневник. Хочешь, покажу, чем он кончился?",
	"Ты пишешь «мне страшно». Правильно пишешь.",
	"Я стоял у тебя за спиной, когда ты это писал.",
]
var _foreign_left := 0
var _foreign_t := 0.0
var _used := {}

var _dark_t := 0.0          # сколько стоишь в темноте без фонаря
var _hide_t := 0.0
var _scratched := false
var _knock_t := 0.0
var _knock_stage := 0
var _knock_at := Vector3.ZERO
var _eerie_t := 0.0
var _eerie: AudioStreamPlayer


func _ready() -> void:
	_eerie = AudioStreamPlayer.new()
	_eerie.volume_db = -14.0
	add_child(_eerie)


func start_day(d: int) -> void:
	_foreign_left = int(FOREIGN.get(d, 0))
	_foreign_t = randf_range(70.0, 140.0)
	_used.clear()
	_dark_t = 0.0
	_hide_t = 0.0
	_scratched = false
	_knock_t = randf_range(50.0, 110.0)
	_knock_stage = 0
	_eerie_t = randf_range(40.0, 80.0)
	_eerie.stop()


func _process(delta: float) -> void:
	if main == null or main.busy or main.state != "playing" or main.collapsing:
		return
	var p := player.global_position
	var below := p.y < Level.FLOOR_Y + 5.0 and not player.climbing
	if not below:
		_dark_t = 0.0
		_check_photo()
		return
	_update_foreign(delta)
	if Game.day >= 2:
		_update_dark(delta)
		_update_knocks(delta)
	if Game.day >= 3:
		_update_hide(delta)
	_update_eerie(delta)


# --- Фото Маши -----------------------------------------------------------------

func _check_photo() -> void:
	if Game.day < 4 or player.global_position.distance_to(Main.PHOTO) > 2.6 or not player.is_looking_at(Main.PHOTO, 0.85):
		return
	match Game.day:
		4:
			Game.say_once("photo4", "Фото Маши на шкафчике. Лицо зацарапано. Я этого не делал.")
		5:
			Game.say_once("photo5", "Под фотографией красным: «папа не придёт». Не её почерк. И не мой.")
		_:
			Game.say_once("photo6", "Фотографии нет. На шкафчике мелом: «Она ждёт тебя внизу».")
	Game.add_fear(6.0)


# --- Чужой почерк -------------------------------------------------------------

func _update_foreign(delta: float) -> void:
	if _foreign_left <= 0:
		return
	_foreign_t -= delta
	if _foreign_t > 0.0:
		return
	_foreign_t = randf_range(90.0, 170.0)
	_foreign_left -= 1
	var text := _foreign_text()
	Game.write_foreign(text)
	Game.add_fear(8.0)
	Game.play_at(Sfx.breath(), player.global_position - player.forward_flat() * 1.2 + Vector3(0, 1.6, 0), -6.0)
	get_tree().create_timer(4.0).timeout.connect(func(): Game.say_once("foreign_%d" % Game.day,
		"В дневнике строчка, которую я не писал. Чужой почерк. Чернила ещё не высохли."))


## Запись подстраивается под то, что делает игрок прямо сейчас.
func _foreign_text() -> String:
	var lower: LowerLine = level.lower
	var p := player.global_position
	var cand: Array[String] = []
	if player.loot > 0:
		cand.append("Чужое не выносят. Положи, где взял.")
	if not level.power_on:
		cand.append("Тебе темно? Мне — нет.")
	if lower.contains(p):
		cand.append("Здесь я дома. А ты — в гостях.")
	if player.hiding:
		cand.append("Шкаф тесный. Я помню каждый.")
	if not player.flashlight_on:
		cand.append("Зачем ты погасил свет? Я же тебя всё равно вижу.")
	if Game.day == Game.LAST_DAY - 1:
		cand.append("Ты уже выбрался. Зачем вернулся, Восьмой?")
	if player.health < 60.0:
		cand.append("Кровь пахнет. Я иду.")
	for t in cand:
		if not _used.has(t):
			_used[t] = true
			return t
	var pool := FOREIGN_POOL.filter(func(t): return not _used.has(t))
	var pick: String = pool.pick_random() if not pool.is_empty() else FOREIGN_POOL.pick_random()
	_used[pick] = true
	return pick


# --- Темнота дышит --------------------------------------------------------------

## Без фонаря и вдали от ламп: через 6 с — дыхание за спиной, через 14 с — касание (урон). И так каждые 8 с.
func _update_dark(delta: float) -> void:
	var dark := not player.has_light() and not player.hiding and not level.is_lit_near(player.global_position)
	if not dark:
		_dark_t = 0.0
		return
	_dark_t += delta
	var behind := player.global_position - player.forward_flat() * 1.0 + Vector3(0, 1.6, 0)
	if _dark_t > 6.0 and _dark_t - delta <= 6.0:
		Game.play_at(Sfx.breath(), behind, -2.0)
		Game.add_fear(10.0)
		Game.say_once("dark_breath", "Погасил фонарь — и сразу услышал дыхание. Рядом. Совсем рядом.")
	if _dark_t > 14.0:
		_dark_t = 6.0
		Game.play_at(Sfx.sniff(), behind, 0.0)
		Game.play_ui(Sfx.sting(), -8.0)
		player.take_damage(8.0)
		Game.add_fear(14.0)
		Game.say_once("dark_touch", "Что-то коснулось шеи. Холодное. Без света здесь нельзя.")


# --- Когти по дверце -----------------------------------------------------------------

func _update_hide(delta: float) -> void:
	if not player.hiding:
		_hide_t = 0.0
		return
	_hide_t += delta
	if _scratched or _hide_t < 5.0 or _hide_t - delta >= 5.0:
		return
	if randf() < 0.45:
		_scratched = true
		var front := player.global_position - player.forward_flat() * -0.6 + Vector3(0, 1.2, 0)
		Game.play_at(Sfx.scrape(), front, 0.0)
		get_tree().create_timer(1.4).timeout.connect(func(): Game.play_at(Sfx.sniff(), front, -2.0))
		Game.add_fear(12.0)
		Game.say_once("scratch", "Пока сидел в шкафу, по дверце медленно провели когтями. Сверху вниз. Потом — тишина.")


# --- Стук в трубах --------------------------------------------------------------------

func _update_knocks(delta: float) -> void:
	_knock_t -= delta
	if _knock_t > 0.0:
		return
	var p := player.global_position
	if _knock_stage == 0:
		_knock_at = p + Vector3(randf_range(-1.0, 1.0), 2.2, -30.0 if randf() < 0.5 else 30.0)
		_knock_stage = 1
		_knock_t = randf_range(25.0, 40.0)
	else:
		_knock_at = p.lerp(Vector3(_knock_at.x, p.y + 2.2, _knock_at.z), 0.3)
		_knock_stage = 0
		_knock_t = randf_range(80.0, 150.0)
		get_tree().create_timer(2.5).timeout.connect(func(): Game.say_once("knocks", "В трубах стучат. Три раза. Через минуту — ещё три. Ближе."))
	for i in 3:
		var at := _knock_at
		get_tree().create_timer(0.55 * i).timeout.connect(func(): Game.play_at(Sfx.knock(), at, -2.0))


# --- Фон ----------------------------------------------------------------------------------

func _update_eerie(delta: float) -> void:
	_eerie_t -= delta
	if _eerie_t > 0.0 or _eerie.playing:
		return
	var in_old: bool = level.lower.contains(player.global_position)
	_eerie_t = randf_range(45.0, 90.0) if in_old else randf_range(70.0, 130.0)
	if in_old or Game.fear > Achievements.fear_max() * 0.35 or randf() < 0.5:
		_eerie.stream = Sfx.eerie()
		_eerie.play()
	if in_old and randf() < 0.6:
		var far := player.global_position + Vector3(randf_range(-14.0, 14.0), 1.5, randf_range(-14.0, 14.0))
		Game.play_at(Sfx.moan(), far, -4.0)
