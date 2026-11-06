extends SkeletonModifier3D
## Для катсцены звонка: прячет голову тела (камера внутри неё) и сжимает пальцы левой руки на трубке.

const CURL_AXIS := Vector3(0, 0, 1)      ## ось сгиба пальцев Mixamo (локальная)
const CURL := [0.9, 1.1, 0.8]            ## сгиб фаланг 1..3 при полном хвате, рад
var scene: Node                          ## phone_call.gd (grip 0..1)
var _head := -1
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
		for g in ["Index", "Middle", "Ring", "Pinky"]:
			for k in 3:
				_f.append([sk.find_bone("mixamorig_LeftHand%s%d" % [g, k + 1]), k])
		for k in 3:
			_thumb.append([sk.find_bone("mixamorig_LeftHandThumb%d" % (k + 1)), k])
	sk.set_bone_pose_scale(_head, Vector3.ONE * 0.001)
	var g: float = scene.grip if scene else 0.0
	var open := 0.25                     # и раскрытая ладонь чуть согнута — живая
	for e in _f:
		var r := sk.get_bone_pose_rotation(e[0])
		sk.set_bone_pose_rotation(e[0], r * Quaternion(CURL_AXIS, CURL[e[1]] * lerpf(open, 1.0, g)))
	for e in _thumb:
		var r := sk.get_bone_pose_rotation(e[0])
		sk.set_bone_pose_rotation(e[0], r * Quaternion(Vector3(1, 0, 0), 0.5 * g))
