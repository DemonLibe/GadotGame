class_name PlayerBody
extends Node3D
## Тело обходчика от первого лица: посмотришь вниз — видно робу, руки и ноги; ноги шагают в такт.
## Та же фигура, что у двойника (Universal Base Characters, Quaternius, CC0), в той же робе, — только без головы:
## камера стоит на её месте.

const HEIGHT := 1.74
const BACK := 0.13         # тело почти под камерой: посмотришь вниз — грудь, руки, ноги
const ARM_DOWN := 74.0
const STRIDE := 0.55       # размах бедра при шаге, рад

var _suit: ShaderMaterial
var _skel: Skeleton3D
var _rest := {}            # кость → поза покоя
var _model: Node3D
var _base_y := 0.0


func _ready() -> void:
	if not ResourceLoader.exists(Double.WORKER):
		return
	_model = (load(Double.WORKER) as PackedScene).instantiate() as Node3D
	_model.rotation.y = PI  # лицом туда же, куда смотрит обходчик (-Z)
	add_child(_model)
	_suit = ShaderMaterial.new()
	_suit.shader = Double.SUIT
	_suit.set_shader_parameter("skin_tex", load("res://models/worker/worker_albedo.png"))
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.material_override = _suit
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if String(mi.name) == "Eyes" or String(mi.name) == "Eyebrows":
			mi.visible = false
	var sk := _model.find_children("*", "Skeleton3D", true, false)
	if not sk.is_empty():
		_skel = sk[0] as Skeleton3D
		# Головы нет — на её месте камера.
		for bone in ["Head", "neck_01"]:
			var b := _skel.find_bone(bone)
			if b >= 0:
				_skel.set_bone_pose_scale(b, Vector3.ONE * 0.001)
		for side in [["upperarm_l", -1.0], ["upperarm_r", 1.0]]:
			_turn(str(side[0]), Vector3.BACK, deg_to_rad(ARM_DOWN) * float(side[1]))
		for bone in ["thigh_l", "thigh_r", "calf_l", "calf_r", "upperarm_l", "upperarm_r"]:
			var b := _skel.find_bone(bone)
			if b >= 0:
				_rest[bone] = _skel.get_bone_pose_rotation(b)
	var box := Geo.mesh_bounds(_model)
	var k := HEIGHT / maxf(box.size.y, 0.001)
	_model.scale = Vector3.ONE * k
	_base_y = -box.position.y * k
	_model.position = Vector3(0, _base_y, BACK)


## Повернуть кость на angle вокруг оси в осях модели (от позы покоя, если она запомнена).
func _turn(bone: String, axis: Vector3, angle: float) -> void:
	var b := _skel.find_bone(bone)
	if b < 0:
		return
	var pg := _skel.get_bone_global_pose(_skel.get_bone_parent(b)).basis.get_rotation_quaternion()
	var base: Quaternion = _rest.get(bone, _skel.get_bone_pose_rotation(b))
	_skel.set_bone_pose_rotation(b, pg.inverse() * Quaternion(axis, angle) * pg * base)


## phase — фаза шага (та же, что качает камеру), amp — 0..1 (стоит / идёт), crouch — 0..1.
func animate(phase: float, amp: float, crouch: float) -> void:
	if _skel == null:
		return
	_suit.set_shader_parameter("base_y", global_position.y)
	var s := sin(phase) * STRIDE * amp
	var bend := crouch * 0.9
	_turn("thigh_l", Vector3.RIGHT, s - bend)
	_turn("thigh_r", Vector3.RIGHT, -s - bend)
	_turn("calf_l", Vector3.RIGHT, maxf(0.0, -s) * 0.9 + bend * 1.6)
	_turn("calf_r", Vector3.RIGHT, maxf(0.0, s) * 0.9 + bend * 1.6)
	_model.position.y = _base_y - crouch * 0.45  # приседает вместе с камерой
