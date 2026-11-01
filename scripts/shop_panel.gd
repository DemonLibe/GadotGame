class_name ShopPanel
extends PanelContainer
## Шкафчик снабжения в дежурке: расходники на смену, снаряжение навсегда и копилка на операцию Маши.
## Деньги — Meta (не теряются ни при провале смены, ни при новой игре).

signal closed

const AMBER := Color(1.0, 0.75, 0.3)
const TEXT := Color(0.85, 0.83, 0.78)
const DIM := Color(0.6, 0.58, 0.54)

var player: Player
var _money: Label
var _list: VBoxContainer
var _bar: ProgressBar
var _fund: Label
var _first: Button


func _ready() -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.055, 0.05, 0.96)
	st.border_color = Color(0.35, 0.3, 0.22)
	st.set_border_width_all(2)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(22)
	add_theme_stylebox_override("panel", st)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(640, 0)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(_label("СНАБЖЕНИЕ", 28, AMBER, true))
	_money = _label("", 22, TEXT)
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_money)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	box.add_child(_list)
	# Копилка на операцию.
	box.add_child(_label("ОПЕРАЦИЯ МАШИ", 16, AMBER))
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 10)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	var fill := StyleBoxFlat.new()
	fill.bg_color = AMBER
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_bar)
	var fund_row := HBoxContainer.new()
	fund_row.add_theme_constant_override("separation", 12)
	box.add_child(fund_row)
	_fund = _label("", 15, DIM, true)
	fund_row.add_child(_fund)
	fund_row.add_child(_button("Отложить 100 ₽", func(): _save(100)))
	fund_row.add_child(_button("Отложить всё", func(): _save(Meta.money)))
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(bottom)
	bottom.add_child(_button("Закрыть (Esc)", func(): closed.emit()))
	Meta.changed.connect(_rebuild)
	visible = false


func open(who: Player) -> void:
	player = who
	visible = true
	_rebuild()
	if _first:
		_first.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact")):
		get_viewport().set_input_as_handled()
		closed.emit()


func _rebuild() -> void:
	if not visible:
		return
	for c in _list.get_children():
		c.queue_free()
	_first = null
	_money.text = "%d ₽" % Meta.money
	_list.add_child(_label("На смену", 16, AMBER))
	for id in Meta.SUPPLIES:
		var s: Array = Meta.SUPPLIES[id]
		_row(str(s[0]), str(s[1]), "%d ₽" % int(s[2]), "Купить", int(s[2]) <= Meta.money and _room_for(id), _buy_supply.bind(id))
	_list.add_child(_label("Снаряжение — навсегда", 16, AMBER))
	for id in Meta.UPGRADES:
		var u: Array = Meta.UPGRADES[id]
		var price := Meta.upgrade_price(id)
		var levels: int = (u[2] as Array).size()
		var title := str(u[0]) + (" · ур. %d/%d" % [Meta.level(id), levels] if levels > 1 else "")
		if price < 0:
			_row(title, str(u[1]), "куплено", "—", false, Callable())
		else:
			_row(title, str(u[1]), "%d ₽" % price, "Купить", price <= Meta.money, _buy_upgrade.bind(id))
	_bar.value = 100.0 * Meta.savings / Meta.OPERATION_COST
	_fund.text = "Отложено %d из %d ₽" % [Meta.savings, Meta.OPERATION_COST] + ("  ·  хватает!" if Meta.operation_paid() else "")


func _row(title: String, desc: String, price: String, action: String, enabled: bool, on_buy: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_list.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	col.add_child(_label(title, 17, TEXT))
	col.add_child(_label(desc, 13, DIM))
	var p := _label(price, 16, TEXT)
	p.custom_minimum_size = Vector2(80, 0)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(p)
	var b := _button(action, on_buy if on_buy.is_valid() else func(): pass)
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(96, 0)
	row.add_child(b)
	if enabled and _first == null:
		_first = b


## Есть ли место в карманах.
func _room_for(id: String) -> bool:
	if player == null:
		return false
	match id:
		"battery":
			return player.batteries < player.max_batteries()
		"bolts":
			return player.bolts < player.max_bolts()
		"canister":
			return player.canisters < 2
	return true


func _buy_supply(id: String) -> void:
	if not _room_for(id) or not Meta.spend(int(Meta.SUPPLIES[id][2])):
		return
	match id:
		"battery":
			player.batteries += 1
		"ammo":
			player.ammo += 3
		"bolts":
			player.bolts = mini(player.bolts + 3, player.max_bolts())
		"canister":
			player.canisters += 1
	Game.play_ui(Sfx.pickup(), -6.0)


func _buy_upgrade(id: String) -> void:
	if Meta.buy_upgrade(id):
		player.apply_upgrades()
		Game.play_ui(Sfx.clank(), -8.0)


func _save(amount: int) -> void:
	if Meta.save_for_operation(amount) > 0:
		Game.play_ui(Sfx.pickup(), -8.0)


func _label(text: String, size: int, color: Color, expand := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", AMBER)
	b.add_theme_color_override("font_focus_color", AMBER)
	b.pressed.connect(action)
	return b
