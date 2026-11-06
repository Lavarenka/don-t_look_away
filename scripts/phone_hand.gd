extends SkeletonModifier3D
## Для катсцены звонка: прячет голову и правую руку тела (камера внутри головы),
## разворачивает левую кисть как надо (ладонью вниз над трубкой, ладонью к голове у уха)
## и сжимает пальцы на ручке трубки. Идёт ПОСЛЕ TwoBoneIK3D: IK ставит запястье, тут — поворот кисти.

var curl_axis := Vector3(1, 0, 0)        ## ось сгиба пальцев Mixamo (локальная): +X — в кулак
const CURL := [0.95, 1.15, 0.85]         ## сгиб фаланг 1..3 при полном хвате, рад
var grip_override := -1.0                ## для отладки
var scene: Node                          ## phone_call.gd: grip 0..1, hand_w, hand_fwd, hand_palm
var _head := -1
var _rarm := -1
var _hand := -1
var _f := []                             ## [[кость, фаланга]]
var _thumb := []
var _fing_local := Vector3.UP            ## куда смотрят пальцы в осях кисти
var _palm_local := Vector3.DOWN          ## куда смотрит ладонь в осях кисти


func setup(s: Node) -> void:
	scene = s


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _head < 0:
		_head = sk.find_bone("mixamorig_Head")
		_rarm = sk.find_bone("mixamorig_RightArm")
		_hand = sk.find_bone("mixamorig_LeftHand")
		for g in ["Index", "Middle", "Ring", "Pinky"]:
			for k in 3:
				_f.append([sk.find_bone("mixamorig_LeftHand%s%d" % [g, k + 1]), k])
		for k in 3:
			_thumb.append([sk.find_bone("mixamorig_LeftHandThumb%d" % (k + 1)), k])
		# в T-позе (покой) левая кисть: пальцы — к средней фаланге, ладонь — вниз
		var rest := sk.get_bone_global_rest(_hand).basis.orthonormalized()
		var mid := sk.find_bone("mixamorig_LeftHandMiddle1")
		var to_mid: Vector3 = sk.get_bone_global_rest(mid).origin - sk.get_bone_global_rest(_hand).origin
		_fing_local = (rest.inverse() * to_mid).normalized()
		_palm_local = (rest.inverse() * Vector3.DOWN).normalized()
	if scene:
		sk.set_bone_pose_scale(_head, Vector3.ONE * 0.001)
		sk.set_bone_pose_scale(_rarm, Vector3.ONE * 0.001)
	# поворот кисти
	var w: float = scene.get("hand_w") if scene else 0.0
	if w > 0.001:
		var to_sk := sk.global_transform.basis.orthonormalized().inverse()
		var f: Vector3 = (to_sk * (scene.get("hand_fwd") as Vector3)).normalized()
		var pl: Vector3 = (to_sk * (scene.get("hand_palm") as Vector3))
		pl = (pl - f * f.dot(pl)).normalized()
		var a := _fing_local
		var b := (_palm_local - a * a.dot(_palm_local)).normalized()
		var Lb := Basis(a, b, a.cross(b))
		var Tb := Basis(f, pl, f.cross(pl))
		var want := Tb * Lb.inverse()
		var par := sk.get_bone_parent(_hand)
		var pg: Basis = sk.get_bone_global_pose(par).basis.orthonormalized()
		var q_want := Quaternion((pg.inverse() * want).orthonormalized())
		var q_now := sk.get_bone_pose_rotation(_hand)
		sk.set_bone_pose_rotation(_hand, q_now.slerp(q_want, clampf(w, 0.0, 1.0)))
	var g: float = grip_override if grip_override >= 0.0 else (scene.grip if scene else 0.0)
	for e in _f:
		var r := sk.get_bone_pose_rotation(e[0])
		sk.set_bone_pose_rotation(e[0], r * Quaternion(curl_axis, CURL[e[1]] * lerpf(0.12, 1.0, g)))
	for e in _thumb:
		var r := sk.get_bone_pose_rotation(e[0])
		sk.set_bone_pose_rotation(e[0], r * Quaternion(curl_axis, 0.35 * g))
