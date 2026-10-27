class_name WallPhone
extends StaticBody3D
## Телефон на стене комнаты с люком. Линия давно мёртвая — но в пятую и седьмую смены он звонит.
## В трубке — Маша. Повесил трубку — звонит снова.

const MASHA := Color(0.95, 0.76, 0.8)

var _calls: Array = []  # очередь звонков: [id озвучки или "", субтитр]
var _ringing := false
var _ring: AudioStreamPlayer3D
var _voice: AudioStreamPlayer


func _ready() -> void:
	var bakelite := ProcTex.flat(Color(0.08, 0.07, 0.06), 0.35, 0.1)
	Geo.box(self, Vector3(0, 0, 0.05), Vector3(0.2, 0.26, 0.1), bakelite, false)
	Geo.cylinder(self, Vector3(0, 0.0, 0.105), 0.06, 0.01, ProcTex.flat(Color(0.8, 0.78, 0.7), 0.6), Basis(Vector3.RIGHT, PI / 2))
	Geo.capsule(self, Vector3(0, 0.17, 0.08), 0.03, 0.26, bakelite, Basis(Vector3.FORWARD, PI / 2))
	Geo.cylinder(self, Vector3(0.08, -0.25, 0.04), 0.008, 0.3, bakelite)
	Geo.collider_box(self, Vector3(0.3, 0.45, 0.2), Vector3(0, 0, 0.08))
	_ring = AudioStreamPlayer3D.new()
	_ring.stream = Sfx.phone()
	_ring.unit_size = 6.0
	_ring.volume_db = 4.0
	add_child(_ring)
	_voice = AudioStreamPlayer.new()
	_voice.volume_db = 2.0
	_voice.bus = "Voice"
	add_child(_voice)


## Начать звонить; calls — очередь разговоров, по одному на каждое снятие трубки.
func ring(calls: Array) -> void:
	_calls = calls.duplicate()
	_start()


func stop() -> void:
	_calls.clear()
	_ringing = false
	_ring.stop()


func is_ringing() -> bool:
	return _ringing


func _start() -> void:
	_ringing = true
	_ring.play()


func get_prompt(_player) -> String:
	return "E — снять трубку" if _ringing else "Телефон. Гудка нет"


func interact(_player) -> void:
	if not _ringing:
		Game.say_once("phone_dead", "Гудка нет. Линию отключили, говорят, ещё в двухтысячном.", Game.THOUGHT, 3.5)
		return
	_ringing = false
	_ring.stop()
	Game.play_ui(Sfx.click(), -6.0)
	var call: Array = _calls.pop_front()
	var path := "res://voice/%s.ogg" % call[0]
	if str(call[0]) != "" and ResourceLoader.exists(path):
		_voice.stream = load(path)
		_voice.play()
	else:
		Game.play_ui(Sfx.whisper(), -10.0)
	Game.say(str(call[1]), MASHA, 6.0)
	if not _calls.is_empty():
		get_tree().create_timer(9.0).timeout.connect(func():
			if not _calls.is_empty():
				_start())
