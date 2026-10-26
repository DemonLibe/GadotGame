class_name Cart
extends StaticBody3D
## Единственная вагонетка станции. Однажды она окажется не там, где стояла.


func _ready() -> void:
	# Модель: Mine Object collection (loafbrr_1, CC0). Ржавчина под тусклую палитру тоннеля.
	var rust := ProcTex.model_skin("res://models/mine/cart_albedo.png", Color(0.5, 0.42, 0.36), 0.85, 0.4)
	var m := Geo.model(self, "res://models/mine/CartFrame.fbx", rust)
	m.get_node("CartFrame/Cart_2").visible = false  # второй вариант кузова в том же файле
	Geo.collider_box(self, Vector3(1.05, 1.2, 1.75), Vector3(0, 0.6, 0))


func get_prompt(_player) -> String:
	return "Вагонетка — E: осмотреть"


func interact(_player) -> void:
	if Game.has_open_task("inspect:cart"):
		Game.report("inspect:cart")
		Game.say("Она стояла на станции. Одному её с места не сдвинуть... Кто её сюда прикатил?", Game.THOUGHT, 6.0)
	else:
		Game.say("Старая вагонетка. Колёса в ржавчине.")
