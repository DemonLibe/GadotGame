class_name Journal
extends StaticBody3D
## Журнал смен на поверхности: здесь заканчивается рабочий день.


func _ready() -> void:
	var wood := ProcTex.flat(Color(0.3, 0.22, 0.14), 0.85)
	Geo.box(self, Vector3(0, 0.78, 0), Vector3(1.2, 0.05, 0.6), wood, false)
	for x in [-0.55, 0.55]:
		for z in [-0.25, 0.25]:
			Geo.box(self, Vector3(float(x), 0.38, float(z)), Vector3(0.05, 0.76, 0.05), wood, false)
	Geo.box(self, Vector3(-0.1, 0.825, 0), Vector3(0.34, 0.04, 0.25), ProcTex.flat(Color(0.45, 0.08, 0.06), 0.7), false)
	Geo.box(self, Vector3(0.4, 0.95, -0.15), Vector3(0.05, 0.3, 0.05), ProcTex.flat(Color(0.1, 0.3, 0.15), 0.5, 0.5), false)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.35, 1.15, -0.05)
	lamp.light_color = Color(1.0, 0.85, 0.55)
	lamp.omni_range = 2.5
	lamp.light_energy = 0.6
	lamp.add_to_group("fear_light")
	add_child(lamp)
	Geo.collider_box(self, Vector3(1.2, 0.85, 0.6), Vector3(0, 0.42, 0))


func get_prompt(_player) -> String:
	if Game.ended:
		return ""
	if Game.day == Game.LAST_DAY - 1 and Game.all_done():
		return "Журнал смен — E: отметиться"
	return "Журнал смен — E: что осталось сделать"


func interact(_player) -> void:
	# После пятой смены докладывать некому: смену закрывает запись в журнале.
	if Game.day == Game.LAST_DAY:
		Game.say("Не до журнала. Надо выбираться — через тоннель, до конца.", Game.THOUGHT, 4.0)
		return
	if Game.day == Game.LAST_DAY - 1:
		if Game.all_done():
			Game.report("return")
			Game.say("«Смена сдана. Восьмой». На этот раз — моей рукой.", Game.THOUGHT, 4.0)
			Game.end_day_requested.emit()
		else:
			Game.say("Ещё не всё собрано: " + Game.remaining_text() + ".", Game.SYSTEM, 5.0)
		return
	if Game.all_done():
		Game.say("Всё сделано. Осталось доложить диспетчеру по рации (рацию в руки — ЛКМ).", Game.SYSTEM, 5.0)
	else:
		Game.say("Смена не закончена. Осталось: " + Game.remaining_text() + ".", Game.SYSTEM, 5.0)
