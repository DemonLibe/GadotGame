class_name Dispatcher
extends Node
## Голос диспетчера по рации. Реплики лежат в res://voice/lines.json, озвучка —
## в res://voice/<id>.ogg (её генерирует workflow «Voice»: нейросетевой русский голос
## и эффект рации). Если файла нет — синтез речи системы или браузера.
## Субтитры идут по длине каждой реплики.

## Смена закрыта после доклада.
signal shift_closed
## В финале обходчик всё-таки доложил, где он.
signal collapse_reported

const COLOR := Color(0.65, 0.85, 1.0)
const LINES_PATH := "res://voice/lines.json"

var _lines := {}      # id → {speaker, text}
var _briefings := {}  # "день" → [id]
var _calls := {}      # "день" → [[id]]
var _closings := {}   # "день" → [id]
var _report_id := ""
var _hints := {}      # поручение → id подсказки; "lie" → [id] (с четвёртой смены голос иногда врёт)
var _collapse: Array = []
var _collapse_reply: Array = []
var _collapse_i := 0
var collapse_mode := false  # тоннель рушится: диспетчер требует доклада
var _voice := ""
var _closing := false
var _last: Array = []
var _static: AudioStreamPlayer
var _speech: AudioStreamPlayer
var _token := 0


func _ready() -> void:
	_static = AudioStreamPlayer.new()
	_static.stream = Sfx.radio()
	_static.volume_db = -10.0
	add_child(_static)
	_speech = AudioStreamPlayer.new()
	_speech.volume_db = 2.0
	add_child(_speech)
	_load_lines()


func _load_lines() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(LINES_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Не удалось прочитать " + LINES_PATH)
		return
	_lines = data["lines"]
	_briefings = data["briefings"]
	_calls = data["calls"]
	_closings = data["closings"]
	_report_id = data["report"]
	_hints = data.get("hints", {})
	_collapse = data.get("collapse", [])
	_collapse_reply = data.get("collapse_reply", [])


## ЛКМ с рацией в руке: доклад, если всё сделано, иначе — подсказка диспетчера.
func radio_pressed(day: int) -> void:
	if collapse_mode:
		collapse_mode = false
		await speak(_collapse_reply)
		collapse_reported.emit()
		return
	if Game.has_open_task("escape"):
		repeat_last()
		return
	if Game.all_done() and Game.has_open_task("return"):
		report_shift(day)
		return
	hint(day)


## Подсказка по ближайшему невыполненному поручению. С четвёртой смены отвечает иногда не он.
func hint(day: int) -> void:
	var lies: Array = _hints.get("lie", [])
	if day >= 4 and not lies.is_empty() and randf() < 0.35:
		var token := _token + 1
		await speak([lies.pick_random()])
		if token == _token:
			Game.say("...Это был не его голос. Похож — но не его.", Game.THOUGHT, 3.5)
		return
	var kind := Game.first_open_task()
	var id: String = _hints.get(kind, _hints.get("unknown", ""))
	if id != "":
		speak([id])


## В финале: «Доложи, где ты!» — по очереди.
func collapse_call() -> void:
	if _collapse.is_empty():
		return
	speak([_collapse[_collapse_i % _collapse.size()]])
	_collapse_i += 1


func briefing(day: int) -> void:
	var ids: Array = _briefings.get(str(day), [])
	if not ids.is_empty():
		speak(ids)


## Неожиданный вызов посреди смены. false — на этот день вызовов нет.
func random_call(day: int) -> bool:
	var calls: Array = _calls.get(str(day), [])
	if calls.is_empty():
		return false
	speak(calls.pick_random())
	return true


func closing_ids(day: int) -> Array:
	return _closings.get(str(day), [])


## Доклад обходчика: все дела сделаны — диспетчер закрывает смену.
func report_shift(day: int) -> void:
	if _closing:
		return
	_closing = true
	stop()
	Game.report("return")
	await _say_line(_report_id, _token)
	await get_tree().create_timer(0.6).timeout
	await speak(closing_ids(day))
	await get_tree().create_timer(1.5).timeout
	_closing = false
	shift_closed.emit()


func repeat_last() -> void:
	if _last.is_empty():
		Game.say("Рация молчит. Только шипение.", Game.THOUGHT, 2.5)
		_static.play()
		return
	speak(_last)


func stop() -> void:
	_token += 1
	_speech.stop()
	if _tts_ready():
		DisplayServer.tts_stop()


## Проиграть реплики по порядку. Можно ждать через await — вернётся, когда всё сказано.
func speak(ids: Array) -> void:
	stop()
	_last = ids
	var token := _token
	_static.play()
	await get_tree().create_timer(0.35).timeout
	if token != _token:
		return
	# Нет записанной озвучки — читает синтезатор речи, субтитры по оценке длины.
	if not ids.is_empty() and _stream_for(ids[0]) == null and _tts_ready():
		var texts: PackedStringArray = []
		for id in ids:
			texts.append(_text_of(id))
		DisplayServer.tts_speak(" ".join(texts), _voice, 80, 0.85, 0.95)
	for id in ids:
		if token != _token:
			return
		await _say_line(id, token)
	if token == _token:
		_static.play()


func _say_line(id: String, token: int) -> void:
	var entry: Dictionary = _lines.get(id, {})
	if entry.is_empty():
		return
	var text := _text_of(id)
	var is_player: bool = entry.get("speaker", "") == "player"
	var stream := _stream_for(id)
	var duration := clampf(text.length() * 0.07, 2.5, 8.0)
	if stream:
		_speech.stream = stream
		_speech.play()
		duration = stream.get_length() + 0.2
	if is_player:
		Game.say("Обходчик: " + text, Game.THOUGHT, duration)
	else:
		Game.say("Диспетчер: " + text, COLOR, duration)
	await get_tree().create_timer(duration).timeout


func _text_of(id: String) -> String:
	var entry: Dictionary = _lines.get(id, {})
	return str(entry.get("text", ""))


func _stream_for(id: String) -> AudioStream:
	var path := "res://voice/%s.ogg" % id
	if ResourceLoader.exists(path):
		return load(path)
	return null


## Голоса браузера загружаются не сразу — ищем русский голос при каждом обращении, пока не найдём.
func _tts_ready() -> bool:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return false
	if _voice == "":
		var voices := DisplayServer.tts_get_voices_for_language("ru")
		if not voices.is_empty():
			_voice = voices[0]
	return _voice != ""
