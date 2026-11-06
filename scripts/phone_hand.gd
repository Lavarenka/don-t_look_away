extends SkeletonModifier3D
## Для катсцены звонка (scripts/phone_call.gd). Идёт ПОСЛЕ TwoBoneIK3D: IK ставит запястье в точку,
## а здесь — всё остальное:
##   * голова и правая рука тела скрыты (камера внутри головы, правая держит фонарь);
##   * кисть поворачивается ровно так, как задано (scene.hand_goal — поворот кисти в мире),
##     с плавным смешиванием scene.hand_w; часть вращения вокруг предплечья отдаётся самому
##     предплечью — запястье не перекручивается «фантиком»;
##   * пальцы сжимаются на ручке трубки (scene.grip 0..1).

const CURL := [0.95, 1.15, 0.85]         ## сгиб фаланг 1..3 при полном хвате, рад
const TWIST_SHARE := 0.5                 ## какую долю «поворота вокруг предплечья» берёт само предплечье
var curl_axis := Vector3(1, 0, 0)        ## ось сгиба пальцев Mixamo (локальная): +X — в кулак
var grip_override := -1.0                ## для отладки
var scene: Node                          ## phone_call.gd
var _head := -1
var _rarm := -1
var _hand := -1
var _fore := -1
var _upper := -1
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
		_hand = sk.find_bone("mixamorig_LeftHand")
		_fore = sk.find_bone("mixamorig_LeftForeArm")
		_upper = sk.get_bone_parent(_fore)
		for g in ["Index", "Middle", "Ring", "Pinky"]:
			for k in 3:
				_f.append([sk.find_bone("mixamorig_LeftHand%s%d" % [g, k + 1]), k])
		for k in 3:
			_thumb.append([sk.find_bone("mixamorig_LeftHandThumb%d" % (k + 1)), k])
	if scene:
		sk.set_bone_pose_scale(_head, Vector3.ONE * 0.001)
		sk.set_bone_pose_scale(_rarm, Vector3.ONE * 0.001)
		var w: float = clampf(float(scene.get("hand_w")), 0.0, 1.0)
		if w > 0.001:
			_orient(sk, scene.get("hand_goal"), w)
	var g: float = grip_override if grip_override >= 0.0 else (float(scene.get("grip")) if scene else 0.0)
	for e in _f:
		var r := sk.get_bone_pose_rotation(e[0])
		sk.set_bone_pose_rotation(e[0], r * Quaternion(curl_axis, CURL[e[1]] * lerpf(0.12, 1.0, g)))
	for e in _thumb:
		var r := sk.get_bone_pose_rotation(e[0])
		sk.set_bone_pose_rotation(e[0], r * Quaternion(curl_axis, 0.35 * g))


## Повернуть кисть в мировой поворот goal.basis (w — насколько). Положение запястья не меняется.
func _orient(sk: Skeleton3D, goal: Transform3D, w: float) -> void:
	var S := sk.global_transform.basis.orthonormalized()
	var hd := (S.inverse() * goal.basis.orthonormalized()).orthonormalized()     # нужный поворот кисти (в осях скелета)
	var fg := sk.get_bone_global_pose(_fore)
	var hg := sk.get_bone_global_pose(_hand)
	var hc := hg.basis.orthonormalized()
	var ht := Basis(Quaternion(hc).slerp(Quaternion(hd), w))
	# поворот кисти = «вокруг оси предплечья» + остальное; долю первого отдаём предплечью
	# (вращение предплечья вокруг своей оси не сдвигает ни локоть, ни запястье)
	var fb := fg.basis.orthonormalized()
	var axis := hg.origin - fg.origin
	if axis.length_squared() > 1e-10:
		axis = axis.normalized()
		var r := Quaternion((ht * hc.inverse()).orthonormalized())
		var d := axis.dot(Vector3(r.x, r.y, r.z))
		var tw := Quaternion(axis.x * d, axis.y * d, axis.z * d, r.w)
		if tw.length_squared() > 1e-10:
			var part := Quaternion.IDENTITY.slerp(tw.normalized(), TWIST_SHARE)
			fb = (Basis(part) * fb).orthonormalized()
			var ub := sk.get_bone_global_pose(_upper).basis.orthonormalized()
			sk.set_bone_pose_rotation(_fore, Quaternion((ub.inverse() * fb).orthonormalized()))
	sk.set_bone_pose_rotation(_hand, Quaternion((fb.inverse() * ht).orthonormalized()))
