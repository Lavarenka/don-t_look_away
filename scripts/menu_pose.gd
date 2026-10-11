extends SkeletonModifier3D
## Поза поверх анимации призрака в меню: доп. повороты костей (эйлер, рад) с плавным переходом.

var target := {}        ## имя кости → Vector3
var cur := {}
var speed := 6.0


func _process(delta: float) -> void:
	for k in target.keys():
		cur[k] = (cur.get(k, Vector3.ZERO) as Vector3).lerp(target[k], minf(1.0, delta * speed))
	for k in cur.keys():
		if not target.has(k):
			cur[k] = (cur[k] as Vector3).lerp(Vector3.ZERO, minf(1.0, delta * speed))


func snap() -> void:
	cur = target.duplicate()


func _process_modification() -> void:
	var sk := get_skeleton()
	for k in cur.keys():
		var b := sk.find_bone("mixamorig_" + k)
		if b >= 0:
			sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * Quaternion.from_euler(cur[k]))
