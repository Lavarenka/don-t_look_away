extends SkeletonModifier3D
## Руки тянутся к точкам (в мире) и хватают: плечо и предплечье выпрямляются на цель.
## Поверх анимации. targets: {"Left": Vector3, "Right": Vector3}; w — сила 0..1.
var targets := {}
var w := 1.0


func _aim(sk: Skeleton3D, b: int, child: int, want_dir: Vector3, k: float) -> void:
	var g := sk.get_bone_global_pose(b)
	var cur := (sk.get_bone_global_pose(child).origin - g.origin).normalized()
	if cur.length() < 0.5 or want_dir.length() < 0.001:
		return
	var q := Quaternion(cur, want_dir.normalized())
	q = Quaternion.IDENTITY.slerp(q, k)
	var p := sk.get_bone_parent(b)
	var pg := sk.get_bone_global_pose(p).basis if p >= 0 else Basis.IDENTITY
	var nb := Basis(q) * g.basis
	sk.set_bone_pose_rotation(b, (pg.inverse() * nb).get_rotation_quaternion())


func _process_modification() -> void:
	var sk := get_skeleton()
	if w <= 0.001 or sk == null:
		return
	var inv := sk.global_transform.affine_inverse()
	for side in targets.keys():
		var arm := sk.find_bone("mixamorig_%sArm" % side)
		var fore := sk.find_bone("mixamorig_%sForeArm" % side)
		var hand := sk.find_bone("mixamorig_%sHand" % side)
		if arm < 0 or fore < 0 or hand < 0:
			continue
		var t: Vector3 = inv * (targets[side] as Vector3)
		# плечо — на цель; потом предплечье — от нового локтя на цель
		_aim(sk, arm, fore, t - sk.get_bone_global_pose(arm).origin, w)
		_aim(sk, fore, hand, t - sk.get_bone_global_pose(fore).origin, w)
