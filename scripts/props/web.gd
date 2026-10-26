class_name Web
extends StaticBody3D
## Паутина. Большая перекрывает тоннель целиком, маленькая висит в углу.
## Сжигается горелкой (ЛКМ).

var size := Vector2(1.2, 1.2)
var blocking := false
var regrown := false  # выросла заново за спиной игрока

var _health := 1.0
var _dead := false
var _heat := 0.0
var _t := 0.0
var _mat: StandardMaterial3D
var _mesh: MeshInstance3D
var _fire: CPUParticles3D
var _light: OmniLight3D


func _ready() -> void:
	add_to_group("webs")
	add_to_group("day_objects")
	# Слой 1 — блокирует игрока, слой 2 — только для луча взаимодействия.
	collision_layer = 3 if blocking else 2
	collision_mask = 0
	_health = 1.0 if blocking else 0.45
	_t = randf() * 10.0

	var quad := QuadMesh.new()
	quad.size = size
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = ProcTex.web_texture(randi() % 3)
	_mat.albedo_color = Color(0.9, 0.9, 0.92)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.roughness = 0.6
	_mesh = MeshInstance3D.new()
	_mesh.mesh = quad
	_mesh.material_override = _mat
	add_child(_mesh)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y, 0.15)
	shape.shape = box
	add_child(shape)

	_fire = ProcTex.fire(int(20 + size.x * 20), 0.6)
	_fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fire.emission_box_extents = Vector3(size.x * 0.45, size.y * 0.45, 0.05)
	add_child(_fire)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.omni_range = 4.0
	_light.light_energy = 0.0
	_light.add_to_group("fear_light")
	add_child(_light)


func get_prompt(_player) -> String:
	if _dead:
		return ""
	return "Паутина — зажми ЛКМ, чтобы сжечь"


func is_dead() -> bool:
	return _dead


func burn(amount: float) -> void:
	if _dead:
		return
	_health -= amount
	_heat = 0.3
	_fire.emitting = true
	var burnt := clampf(1.0 - _health, 0.0, 1.0)
	_mat.albedo_color = Color(0.9 - burnt * 0.6, 0.88 - burnt * 0.7, 0.85 - burnt * 0.75, 1.0 - burnt * 0.5)
	if _health <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	collision_layer = 0
	_heat = 0.8
	Game.report("webs")
	var tw := create_tween()
	tw.tween_property(_mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_interval(1.0)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	_mesh.rotation.x = sin(_t * 0.7) * 0.03
	if _heat > 0.0:
		_heat -= delta
		_light.light_energy = randf_range(1.2, 2.0)
		if _heat <= 0.0:
			_fire.emitting = false
			_light.light_energy = 0.0
	if regrown and not _dead:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p and p.global_position.distance_to(global_position) < 6.0:
			regrown = false
			Game.say("Я же её сжигал... Я точно её сжигал.")
