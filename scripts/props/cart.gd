class_name Cart
extends StaticBody3D
## Единственная вагонетка станции. Однажды она окажется не там, где стояла.


func _ready() -> void:
	# Модель: Mine Object collection (loafbrr_1, CC0). Ржавчина под тусклую палитру тоннеля.
	var rust := ProcTex.model_skin("res://models/mine/cart_albedo.png", Color(0.5, 0.42, 0.36), 0.85, 0.4)
	var m := Geo.model(self, "res://models/mine/CartFrame.fbx", rust)
	m.get_node("CartFrame/Cart_2").visible = false  # второй вариант кузова в том же файле
	Geo.collider_box(self, Vector3(1.05, 1.2, 1.75), Vector3(0, 0.6, 0))


## Поручение «докатить до ПК 2»: откуда и докуда (z), скорость толкания.
const PUSH_FROM := -40.0
const PUSH_TO := Level.TUN_Z0 - Level.PICKET_STEP * 2.0
const PUSH_SPEED := 0.7

var _creak := 0.0


func get_prompt(_player) -> String:
	if Game.has_open_task("cartpush"):
		return "Удерживай E — толкать вагонетку к ПК 2 (громко)"
	return "Вагонетка — E: осмотреть"


## Толкать, удерживая E: катится по рельсам вглубь, скрипит, слышно далеко.
func hold_interact(_player, delta: float) -> float:
	if not Game.has_open_task("cartpush"):
		return -1.0
	position.z = maxf(PUSH_TO, position.z - PUSH_SPEED * delta)
	_creak -= delta
	if _creak <= 0.0:
		_creak = 1.0
		Game.play_at(Sfx.creak(), global_position + Vector3(0, 0.4, 0), -4.0)
		Game.make_noise(global_position, 14.0)
	if position.z <= PUSH_TO + 0.01:
		Game.report("cartpush")
		Game.say("Докатил. Руки трясутся. Это было слышно, наверное, до самой решётки.", Game.THOUGHT, 4.0)
		return -1.0
	return (PUSH_FROM - position.z) / (PUSH_FROM - PUSH_TO)


func hold_cancel() -> void:
	pass


func interact(_player) -> void:
	if Game.has_open_task("cartpush"):
		return
	if Game.has_open_task("inspect:cart"):
		Game.report("inspect:cart")
		Game.say("Она стояла на станции. Одному её с места не сдвинуть... Кто её сюда прикатил?", Game.THOUGHT, 6.0)
	else:
		Game.say("Старая вагонетка. Колёса в ржавчине.")
