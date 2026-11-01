class_name SupplyLocker
extends StaticBody3D
## Шкафчик снабжения в дежурке: E — открыть (батарейки, патроны, снаряжение, копилка на операцию).


func _ready() -> void:
	# Табличка на дверце второго шкафчика (сам шкафчик — часть комнаты).
	Geo.box(self, Vector3(0, 0, 0.005), Vector3(0.36, 0.12, 0.01), ProcTex.flat(Color(0.8, 0.75, 0.55), 0.8), false)
	Geo.label(self, Vector3(0, 0, 0.012), "СНАБЖЕНИЕ", 0, 22, Color(0.15, 0.12, 0.08), true, 0.0018)
	Geo.collider_box(self, Vector3(0.5, 1.6, 0.1), Vector3(0, -0.5, 0.05))


func get_prompt(_player) -> String:
	return "E — шкафчик снабжения (%d ₽)" % Meta.money


func interact(player) -> void:
	if player.hud:
		player.hud.open_shop(player)
