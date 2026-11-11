extends SkeletonModifier3D
## Аня сгибается вперёд поверх любой своей анимации: спина гнётся в пояснице, ноги стоят как стояли,
## грудь, шея и голова — одним целым (тогда волосы, привязанные к шее и груди, не рвутся, и шейдер может
## повесить их отвесно — spirit.gdshader, hang). Руки повисают вниз, к тому, над кем она нависла.
## Сцена «она над тобой» в детской (nursery.gd: _bend_on). Ставится в скелет ПЕРЕД spirit_life.gd.

var angle := 1.35            ## наклон вперёд, рад (≈ 77°)
var amount := 1.0            ## 0..1 — доля наклона (можно вести твином)
var chain := [["mixamorig_Spine", 0.6], ["mixamorig_Spine1", 0.4]]   ## где гнётся спина и какая доля угла
var arms := 1.0              ## 0..1 — руки висят отвесно (а не торчат вперёд вместе с согнутой спиной)
var reach_to := Vector3.INF  ## если задано (мир) — руки тянутся к этой точке, а не просто вниз
var _chain := []
var _arms := []              ## [плечо, предплечье, кисть] слева и справа


func _ready() -> void:
	var sk := get_skeleton()
	for b in chain:
		var i := sk.find_bone(b[0])
		if i >= 0:
			_chain.append([i, float(b[1])])
	for s in ["Left", "Right"]:
		var a := [sk.find_bone("mixamorig_%sArm" % s), sk.find_bone("mixamorig_%sForeArm" % s), sk.find_bone("mixamorig_%sHand" % s)]
		if not a.has(-1):
			_arms.append(a)


## Ось наклона: «вбок» тела (ось X узла призрака), в осях скелета.
func _axis(sk: Skeleton3D) -> Vector3:
	var n: Node = sk.get_parent()
	while n and not (n.get_script() and n.has_method("set_eyes")):
		n = n.get_parent()
	var x: Vector3 = (n as Node3D).global_basis.x if n is Node3D else sk.global_basis.x
	return (sk.global_basis.inverse() * x).normalized()


## Повернуть кость b (глобально, в осях скелета) так, чтобы направление from стало to, с долей k.
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
	if sk == null or amount <= 0.001 or _chain.is_empty():
		return
	var ax := _axis(sk)
	for c in _chain:
		var b: int = c[0]
		var g := sk.get_bone_global_pose(b)
		var par := sk.get_bone_parent(b)
		var pg := sk.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis.IDENTITY
		var nb := Basis(ax, angle * amount * float(c[1])) * g.basis.orthonormalized()
		sk.set_bone_pose_rotation(b, (pg.inverse() * nb).get_rotation_quaternion())
	if arms <= 0.0:
		return
	var inv := sk.global_transform.affine_inverse()
	var down := (inv.basis * Vector3.DOWN).normalized()
	for a in _arms:
		var p0 := sk.get_bone_global_pose(a[0]).origin
		var want := down
		if reach_to != Vector3.INF:
			want = ((inv * reach_to) - p0).normalized()
		_turn(sk, a[0], sk.get_bone_global_pose(a[1]).origin - p0, want, arms * amount)
		var p1 := sk.get_bone_global_pose(a[1]).origin
		if reach_to != Vector3.INF:
			want = ((inv * reach_to) - p1).normalized()
		_turn(sk, a[1], sk.get_bone_global_pose(a[2]).origin - p1, want, arms * amount)
