class_name Lurker
extends Node3D
## Паук-охотник: огромный, сидит на стене неподвижно — пока на него не упал луч фонаря.
## Тогда срывается и в два прыжка исчезает в темноте. Не кусается — пугает.
## Модель: Huntsman Spider (без скелета) — потому и не ходит, а только замирает и срывается.

const SIZE := 0.6
const NOTICE := 0.2   # сколько секунд под лучом, прежде чем сорвётся
const RANGE := 9.0

var player: Player
var _lit := 0.0
var _gone := false
var _t := 0.0
var _model: Node3D


func _ready() -> void:
	add_to_group("day_objects")
	_model = ExtModels.huntsman(self, SIZE)
	_t = randf() * 10.0


func _process(delta: float) -> void:
	if _gone or player == null:
		return
	_t += delta
	# Изредка подёргивает лапами — едва заметно.
	_model.rotation.y = sin(_t * 0.7) * 0.03 + (0.06 if fmod(_t, 5.3) < 0.08 else 0.0)
	var d := global_position.distance_to(player.camera.global_position)
	if d < RANGE and player.is_lighting(global_position):
		_lit += delta
		if _lit > NOTICE:
			_flee(d)
	else:
		_lit = maxf(0.0, _lit - delta)


func _flee(d: float) -> void:
	_gone = true
	Game.play_at(Sfx.scuttle(), global_position, 2.0)
	Game.add_fear(lerpf(14.0, 5.0, d / RANGE))
	Game.say_once("lurker", "Паук размером с тарелку. Сидел на стене — всё это время, пока я шёл мимо.", Game.THOUGHT, 3.5)
	# Рывок вверх по стене и вбок, потом пропадает.
	var up := global_transform.basis.z  # голова смотрит вверх по стене
	var side := global_transform.basis.x * (1.0 if randf() < 0.5 else -1.0)
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + (up * 0.8 + side * 1.6), 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", global_position + (up * 2.4 + side * 2.6), 0.22)
	tw.parallel().tween_property(self, "scale", Vector3.ONE * 0.01, 0.22)
	tw.tween_callback(queue_free)


## Посадить на стену: точка на стене и нормаль внутрь прохода. Брюхом к стене, головой вверх.
func place_on_wall(at: Vector3, normal: Vector3) -> void:
	var y := normal.normalized()
	var z := (Vector3.UP - y * Vector3.UP.dot(y)).normalized()
	if z.length() < 0.1:
		z = Vector3.FORWARD
	var x := y.cross(z)
	global_transform = Transform3D(Basis(x, y, z).rotated(y, randf_range(-0.5, 0.5)), at + y * 0.02)
