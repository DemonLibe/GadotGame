class_name Bolt
extends RigidBody3D
## Брошенный болт (G): летит по взгляду, звякает там, где упал, — и всё, что слышит, идёт туда.
## Лежит, пока его снова не подберут.

const NOISE := 16.0

var _landed := false


func _ready() -> void:
	add_to_group("day_objects")
	collision_layer = 1
	collision_mask = 1 | Geo.WALL_LAYER
	mass = 0.3
	contact_monitor = true
	max_contacts_reported = 1
	var steel := ProcTex.flat(Color(0.4, 0.4, 0.42), 0.45, 0.8)
	Geo.cylinder(self, Vector3.ZERO, 0.012, 0.09, steel)
	Geo.cylinder(self, Vector3(0, 0.04, 0), 0.022, 0.015, steel)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.025
	cap.height = 0.1
	shape.shape = cap
	add_child(shape)
	body_entered.connect(_on_hit)


func throw(from: Vector3, dir: Vector3) -> void:
	global_position = from
	linear_velocity = dir * 11.0 + Vector3(0, 2.0, 0)
	angular_velocity = Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))


func _on_hit(_body: Node) -> void:
	if linear_velocity.length() < 1.0:
		return
	Game.play_at(Sfx.clank(), global_position, -2.0 if not _landed else -10.0)
	if not _landed:
		_landed = true
		Game.make_noise(global_position, NOISE)


func get_prompt(_player) -> String:
	return "E — подобрать болт"


func interact(player) -> void:
	player.bolts += 1
	Game.play_at(Sfx.pickup(), global_position, -10.0)
	queue_free()
