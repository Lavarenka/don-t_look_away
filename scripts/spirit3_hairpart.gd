extends SkeletonModifier3D
## Аня v3: передние пряди отводятся с лица — открыть его (крик; сцены, которым нужно её лицо).
## У причёски вида 4 лицо по умолчанию закрыто занавесью волос, как у первой Ани.
## Поворачивается только верхняя кость пряди (у корня) — прядь сдвигается к виску, а ниже висит, как висела
## (иначе длинные пряди торчали бы в стороны крыльями). Ставится в скелет сразу после физики волос (spirit.gd);
## amount (0..1) задаёт spirit.gd.

## кость у корня → углы (в осях скелета): назад (X) и наружу (Z)
const PART := {"hair_f1L_0": Vector3(0.5, 0, 1.3), "hair_f1R_0": Vector3(0.5, 0, -1.3),
	"hair_f2L_0": Vector3(0.45, 0, 1.0), "hair_f2R_0": Vector3(0.45, 0, -1.0),
	"hair_s1L_0": Vector3(0.3, 0, 0.45), "hair_s1R_0": Vector3(0.3, 0, -0.45)}
var amount := 0.0
var _b := []                   ## [кость, следующая кость, углы]


func _ready() -> void:
	var sk := get_skeleton()
	for n in PART:
		var i := sk.find_bone(n)
		var j := sk.find_bone(String(n).trim_suffix("_0") + "_1")
		if i >= 0:
			_b.append([i, j, PART[n]])


func _process_modification() -> void:
	if amount <= 0.001 or _b.is_empty():
		return
	var sk := get_skeleton()
	var k := smoothstep(0.0, 1.0, clampf(amount, 0.0, 1.0))
	for e in _b:
		var i: int = e[0]
		var j: int = e[1]
		var g := sk.get_bone_global_pose(i).basis.orthonormalized()
		var g1 := sk.get_bone_global_pose(j).basis.orthonormalized() if j >= 0 else Basis.IDENTITY
		var par := sk.get_bone_parent(i)
		var pg := sk.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis.IDENTITY
		var want := Basis.from_euler((e[2] as Vector3) * k) * g
		sk.set_bone_pose_rotation(i, (pg.inverse() * want).get_rotation_quaternion())
		if j >= 0:                                   # дальше прядь висит, как висела
			sk.set_bone_pose_rotation(j, (want.inverse() * g1).get_rotation_quaternion())
