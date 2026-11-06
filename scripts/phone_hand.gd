extends SkeletonModifier3D
## Для катсцены звонка: прячет голову и правую руку тела (камера внутри головы, фонарь «в руке» не нужен)
## и сжимает пальцы левой руки на трубке.

var curl_axis := Vector3(1, 0, 0)        ## ось сгиба пальцев Mixamo (локальная): +X — в кулак
const CURL := [0.95, 1.15, 0.85]         ## сгиб фаланг 1..3 при полном хвате, рад
var grip_override := -1.0                ## для отладки
var scene: Node                          ## phone_call.gd (grip 0..1)
var _head := -1
var _rarm := -1
var _f := []                             ## [[кость, фаланга]]
var _thumb := []


func setup(s: Node) -> void:
	scene = s


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _head < 0:
		_head = sk.find_bone("mixamorig_Head")
		_rarm = sk.find_bone("mixamorig_RightArm")
		for g in ["Index", "Middle", "Ring", "Pinky"]:
			for k in 3:
				_f.append([sk.find_bone("mixamorig_LeftHand%s%d" % [g, k + 1]), k])
		for k in 3:
			_thumb.append([sk.find_bone("mixamorig_LeftHandThumb%d" % (k + 1)), k])
	if scene:
		sk.set_bone_pose_scale(_head, Vector3.ONE * 0.001)
		sk.set_bone_pose_scale(_rarm, Vector3.ONE * 0.001)
	var g: float = grip_override if grip_override >= 0.0 else (scene.grip if scene else 0.0)
	for e in _f:
		var r := sk.get_bone_pose_rotation(e[0])
		sk.set_bone_pose_rotation(e[0], r * Quaternion(curl_axis, CURL[e[1]] * lerpf(0.12, 1.0, g)))
	for e in _thumb:
		var r := sk.get_bone_pose_rotation(e[0])
		sk.set_bone_pose_rotation(e[0], r * Quaternion(curl_axis, 0.35 * g))
