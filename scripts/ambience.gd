class_name Ambience
extends Node
## Звуковой фон (шина Ambience — громкость «Гул подземелья» в настройках):
## гул, сквозняк, тёмный пэд, который растёт вместе со страхом, тревожный пэд при сильном страхе
## и редкие далёкие звуки тоннеля — стон металла, лязг, скрип, осыпь — с разных сторон.

var player: Player  # в главном меню — null, там только фон
var _drone: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _pad: AudioStreamPlayer
var _tense: AudioStreamPlayer
var _next := 6.0


func _ready() -> void:
	_drone = _loop(Sfx.drone(), -14.0)
	_wind = _loop(Sfx.wind(), -24.0)
	_pad = _loop(Sfx.pad(), -22.0)
	_tense = _loop(Sfx.pad_tense(), -60.0)
	_next = randf_range(5.0, 10.0)


func _loop(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.bus = "Ambience"
	add_child(p)
	p.play()
	return p


func _process(delta: float) -> void:
	var fear := 0.0
	var below := false
	var climbing := false
	if player:
		fear = clampf(Game.fear / Achievements.fear_max(), 0.0, 1.0)
		below = player.global_position.y < Level.FLOOR_Y + 5.0
		climbing = player.climbing
	# Целевая громкость слоёв (дБ): внизу — гуще, в шахте — сквозняк, наверху — тише.
	var drone := -14.0 if below or player == null else -22.0
	var wind := -20.0 if below else (-11.0 if climbing else -30.0)
	var pad := lerpf(-24.0, -11.0, fear) if below else (-18.0 if player == null else -28.0)
	var tense := -60.0 if fear < 0.4 else lerpf(-32.0, -12.0, (fear - 0.4) / 0.6)
	_fade(_drone, drone, delta)
	_fade(_wind, wind, delta)
	_fade(_pad, pad, delta)
	_fade(_tense, tense, delta)
	# Редкие далёкие звуки.
	_next -= delta
	if _next <= 0.0:
		_next = randf_range(7.0, 18.0) if below else randf_range(14.0, 28.0)
		_one_shot(below)


func _fade(p: AudioStreamPlayer, target: float, delta: float) -> void:
	p.volume_db = move_toward(p.volume_db, target, delta * 6.0)


func _one_shot(below: bool) -> void:
	var options := [[Sfx.groan(), 0.0], [Sfx.clank(), -6.0], [Sfx.creak(), -4.0], [Sfx.rumble(), -10.0]]
	var pick: Array = options.pick_random()
	if player == null or not below:
		# В меню и наверху — один далёкий стон, без направления.
		var p := AudioStreamPlayer.new()
		p.stream = Sfx.groan()
		p.volume_db = -20.0
		p.pitch_scale = randf_range(0.8, 1.1)
		p.bus = "Ambience"
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
		return
	# Внизу — где-то в тоннеле, в 15–30 метрах, с какой-нибудь стороны.
	var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	var p3 := AudioStreamPlayer3D.new()
	p3.stream = pick[0]
	p3.volume_db = float(pick[1])
	p3.pitch_scale = randf_range(0.75, 1.05)
	p3.unit_size = 10.0
	p3.bus = "Ambience"
	add_child(p3)
	p3.global_position = player.global_position + dir * randf_range(15.0, 30.0) + Vector3(0, 1.5, 0)
	p3.finished.connect(p3.queue_free)
	p3.play()
