class_name Unstuck
extends RefCounted
## Помощник для существ: если тело хочет идти, но почти не сдвигается (упёрлось в угол, колонну, край проёма),
## на полсекунды уводит его вбок — так оно обходит препятствие, а не трётся о стену.

const STUCK_TIME := 0.4
const SIDESTEP := 0.6

var _t := 0.0
var _side := 0.0
var _sign := 1.0
var _last := Vector3.INF


## Желаемая горизонтальная скорость → скорость с учётом обхода.
func steer(v: Vector3, delta: float) -> Vector3:
	if _side <= 0.0 or v.length() < 0.05:
		return v
	_side -= delta
	var perp := Vector3(-v.z, 0.0, v.x) * _sign
	return (v * 0.35 + perp).normalized() * v.length()


## После move_and_slide: сколько на самом деле прошли.
func check(body: Node3D, v: Vector3, delta: float) -> void:
	var p := body.global_position
	if _last == Vector3.INF:
		_last = p
		return
	var moved := p - _last
	moved.y = 0.0
	_last = p
	if v.length() > 0.3 and moved.length() < v.length() * delta * 0.25:
		_t += delta
		if _t > STUCK_TIME:
			_t = 0.0
			_side = SIDESTEP
			if randf() < 0.5:
				_sign = -_sign
	else:
		_t = maxf(0.0, _t - delta * 0.5)


func is_sidestepping() -> bool:
	return _side > 0.0
