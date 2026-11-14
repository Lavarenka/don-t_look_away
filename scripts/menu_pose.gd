extends SkeletonModifier3D
## Поза поверх анимации призрака в меню: доп. повороты костей (эйлер, рад) с плавным переходом.

var target := {}        ## имя кости → Vector3
var cur := {}
var speed := 6.0
## Аня v3: у неё другие кости. У прежнего рига оси костей спины, шеи и головы совпадают с осями скелета, поэтому те же
## углы — это повороты в осях скелета; раздаём их по костям v3 (5 костей спины, 3 — шеи). Руки у v3 ставит spirit3_reach.gd.
var v3 := false
const V3 := {"Spine": [["spine05", 1.0]], "Spine1": [["spine04", 1.0]], "Spine2": [["spine03", 1.0]],
	"Neck": [["spine02", 0.6], ["spine01", 0.4]], "Head": [["neck01", 0.2], ["neck02", 0.22], ["neck03", 0.26], ["head", 0.32]]}


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
		if v3:
			if not V3.has(k):
				continue
			var q := Quaternion.from_euler(cur[k])
			for e in V3[k]:
				var vb := sk.find_bone(e[0])
				if vb < 0:
					continue
				var gb := sk.get_bone_global_pose(vb).basis.orthonormalized()
				var d := Basis(Quaternion.IDENTITY.slerp(q, e[1]))
				sk.set_bone_pose_rotation(vb, sk.get_bone_pose_rotation(vb) * (gb.inverse() * d * gb).get_rotation_quaternion())
			continue
		var b := sk.find_bone("mixamorig_" + k)
		if b >= 0:
			sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * Quaternion.from_euler(cur[k]))
