extends SkeletonModifier3D
## Аня v3: кисть тянется к точке — двухзвенная ИК (плечо — локоть — запястье) поверх анимации.
## Ставится в скелет после «живости» и до мимики (spirit.gd: face). Пример — рука на косяке в меню (menu.gd).

var side := "R"                    ## "L" или "R" — задать до добавления в скелет
var target := Vector3.ZERO         ## куда тянется запястье (мир)
var weight := 0.0                  ## 0..1
var pole := Vector3(0, -1, 0)      ## куда смотрит локоть (мир)
var _b := PackedInt32Array()


func _ready() -> void:
	var sk := get_skeleton()
	_b = PackedInt32Array([sk.find_bone("upperarm01_" + side), sk.find_bone("lowerarm01_" + side), sk.find_bone("wrist_" + side)])


## Повернуть кость b (в осях скелета) так, чтобы направление from стало to, с долей k.
func _turn(sk: Skeleton3D, b: int, from: Vector3, to: Vector3, k: float) -> void:
	if from.length() < 0.0001 or to.length() < 0.0001 or k <= 0.0:
		return
	var q := Quaternion.IDENTITY.slerp(Quaternion(from.normalized(), to.normalized()), k)
	var g := sk.get_bone_global_pose(b)
	var par := sk.get_bone_parent(b)
	var pg := sk.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(b, (pg.inverse() * (Basis(q) * g.basis.orthonormalized())).get_rotation_quaternion())


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or weight <= 0.001 or _b.has(-1):
		return
	var inv := sk.global_transform.affine_inverse()
	var a0 := sk.get_bone_global_pose(_b[0]).origin
	var b0 := sk.get_bone_global_pose(_b[1]).origin
	var c0 := sk.get_bone_global_pose(_b[2]).origin
	var la := a0.distance_to(b0)
	var lb := b0.distance_to(c0)
	var dir: Vector3 = inv * target - a0
	var d := clampf(dir.length(), absf(la - lb) + 0.01, la + lb - 0.005)
	dir = dir.normalized()
	var x := (la * la - lb * lb + d * d) / (2.0 * d)
	var h := sqrt(maxf(la * la - x * x, 0.0))
	var p: Vector3 = (inv.basis * pole).normalized()
	p -= dir * p.dot(dir)
	p = p.normalized() if p.length() > 0.001 else dir.cross(Vector3.RIGHT).normalized()
	var b1 := a0 + dir * x + p * h           # где должен быть локоть
	var c1 := a0 + dir * d                   # где должно быть запястье
	_turn(sk, _b[0], b0 - a0, b1 - a0, weight)
	b0 = sk.get_bone_global_pose(_b[1]).origin
	c0 = sk.get_bone_global_pose(_b[2]).origin
	_turn(sk, _b[1], c0 - b0, c1 - b0, weight)
