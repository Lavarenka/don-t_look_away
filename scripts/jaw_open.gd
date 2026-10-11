extends SkeletonModifier3D
## Открывает челюсть поверх анимации: open 0..1 → поворот кости Jaw вниз; лёгкое дрожание при крике.

var open := 0.0
const MAX_ANGLE := 0.42
var _t := 0.0
var _b := -1


func _process(delta: float) -> void:
	_t += delta


func _process_modification() -> void:
	var sk := get_skeleton()
	if _b < 0:
		_b = sk.find_bone("mixamorig_Jaw")
		if _b < 0:
			return
	if open <= 0.001:
		return
	var a := open * MAX_ANGLE + sin(_t * 47.0) * 0.03 * open
	sk.set_bone_pose_rotation(_b, sk.get_bone_pose_rotation(_b) * Quaternion(Vector3.RIGHT, a))
