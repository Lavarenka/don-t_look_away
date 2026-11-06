extends Node3D
## Вера на потолке, как паук: спиной вниз не висит — лицом (животом) к полу, ладони и ступни упираются
## в потолок, локти и колени вывернуты в стороны; голова свёрнута и смотрит на игрока перевёрнутым лицом.
## setup(): где (точка на потолке над центром тела), куда направлена голова, на что смотреть.
## Руки и ноги — TwoBoneIK3D к точкам на потолке; голову доворачивает модификатор (_Head ниже).

const DROP := 0.34                  ## таз ниже потолка, м
const TILT := 0.35                  ## верх тела приподнят к потолку (рад) — спина выгнута, как у паука
const HIPS_Y := 0.95                ## таз над ступнями у модели стоя, м

var vera: Node3D                    ## scripts/vera.gd
var look_at_node: Node3D            ## на что смотрит (камера игрока)
var twist := 1.0                    ## 1 — лицо вверх ногами (макушкой к полу), 0 — обычно
var arch := 0.28                    ## на сколько выпрямить сутулую спину (рад на позвонок; + — назад)
var _targets := {}
var _poles := {}


func setup(ceiling_point: Vector3, heading: Vector3, look: Node3D) -> void:
	look_at_node = look
	vera = preload("res://scripts/vera.gd").new()
	add_child(vera)
	vera.freeze("idle", 0.5)
	vera.mat.set_shader_parameter("rim", 0.0)       # холодный ореол по краю в этой позе подсвечивает изнанку лохмотьев
	heading = Vector3(heading.x, 0, heading.z).normalized()
	var down := Vector3.DOWN
	var side := heading.cross(down).normalized()
	# оси тела: голова — по heading, живот (вперёд у модели, +Z) — к полу
	basis = Basis(side, heading, down).rotated(side, -TILT)
	var hips := ceiling_point + down * DROP
	global_position = hips - basis.y * HIPS_Y
	var sk: Skeleton3D = vera.sk
	await get_tree().process_frame
	var sp := _Spine.new()
	sp.owner_node = self
	sk.add_child(sp)
	await get_tree().process_frame
	var cy := ceiling_point.y - 0.03
	var S := sk.global_transform
	var lim := {
		"Left": [["mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand"], 0.34, 0.3, -1.0],
		"Right": [["mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand"], 0.34, 0.3, 1.0],
		"LeftL": [["mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot"], -0.2, 0.62, -1.0],
		"RightL": [["mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot"], -0.2, 0.62, 1.0],
	}
	for k in lim:
		var bones: Array = lim[k][0]
		var root_p: Vector3 = S * sk.get_bone_global_pose(sk.find_bone(bones[0])).origin
		# в какую сторону эта рука/нога: знак — по положению кости относительно оси тела
		var sgn := signf((root_p - global_position).dot(side))
		if sgn == 0.0:
			sgn = lim[k][3]
		var t := Node3D.new()
		t.top_level = true
		add_child(t)
		var tp: Vector3 = root_p + heading * lim[k][1] + side * sgn * lim[k][2]
		tp.y = cy
		t.global_position = tp
		var po := Node3D.new()
		po.top_level = true
		add_child(po)
		# локоть/колено — наружу и вниз, к полу: как у паука под потолком, суставы ниже тела
		po.global_position = (root_p + tp) * 0.5 + side * sgn * 0.45 + down * 0.6
		var ik := TwoBoneIK3D.new()
		ik.setting_count = 1
		ik.set_root_bone_name(0, bones[0])
		ik.set_middle_bone_name(0, bones[1])
		ik.set_end_bone_name(0, bones[2])
		sk.add_child(ik)
		ik.set_target_node(0, ik.get_path_to(t))
		ik.set_pole_node(0, ik.get_path_to(po))
		_targets[k] = t
		_poles[k] = po
	var hm := _Head.new()
	hm.owner_node = self
	sk.add_child(hm)
	for k in 3:
		await get_tree().process_frame
	cull_stretched()


## В этой позе лохмотья, пришитые к рукаву и к телу сразу, вытягиваются в длинные нити от рук до одежды.
## Считаем позу на процессоре (скиннинг) и убираем треугольники, которые растянулись больше чем в STRETCH раз.
const STRETCH := 3.5
var _skin_xf := []
func _on_pose() -> void:
	var sk: Skeleton3D = vera.sk
	var mi := vera.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := mi.skin
	_skin_xf.clear()
	for i in skin.get_bind_count():
		var b := skin.get_bind_bone(i)
		if b < 0:
			b = sk.find_bone(skin.get_bind_name(i))
		_skin_xf.append(sk.get_bone_global_pose(b) * skin.get_bind_pose(i))


func cull_stretched() -> void:
	var sk: Skeleton3D = vera.sk
	sk.skeleton_updated.connect(_on_pose, CONNECT_ONE_SHOT)
	await get_tree().process_frame
	await get_tree().process_frame
	if _skin_xf.is_empty():
		return
	var mi := vera.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := mi.mesh
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var per := bones.size() / v.size()
	var p := PackedVector3Array()
	p.resize(v.size())
	for i in v.size():
		var acc := Vector3.ZERO
		for j in per:
			var w := wts[i * per + j]
			if w > 0.0:
				acc += (_skin_xf[bones[i * per + j]] as Transform3D) * v[i] * w
		p[i] = acc
	var keep := PackedInt32Array()
	var cut := 0
	for t in range(0, idx.size(), 3):
		var a := idx[t]
		var b := idx[t + 1]
		var c := idx[t + 2]
		var r := maxf(maxf(v[a].distance_to(v[b]), v[b].distance_to(v[c])), v[c].distance_to(v[a]))
		var q := maxf(maxf(p[a].distance_to(p[b]), p[b].distance_to(p[c])), p[c].distance_to(p[a]))
		if q > r * STRETCH and q > 0.1:
			cut += 1
			continue
		keep.append(a); keep.append(b); keep.append(c)
	arr[Mesh.ARRAY_INDEX] = keep
	var nm := ArrayMesh.new()
	nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	nm.surface_set_material(0, mesh.surface_get_material(0))
	mi.mesh = nm
	print("vera_ceiling: убрано вытянутых треугольников ", cut)


## Спина: модель сутулая — позвонки выпрямляем назад (спина ровнее, грудь ближе к потолку).
class _Spine extends SkeletonModifier3D:
	var owner_node: Node3D
	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null or owner_node == null:
			return
		var a: float = owner_node.get("arch")
		for n in ["mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2", "mixamorig_Neck"]:
			var b := sk.find_bone(n)
			sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * Quaternion(Vector3.RIGHT, -a))


## Голова: лицо — на игрока, макушка — к полу (лицо перевёрнуто). Шея берёт часть поворота.
class _Head extends SkeletonModifier3D:
	var owner_node: Node3D
	var _h := -1
	var _n := -1

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null or owner_node == null or owner_node.get("look_at_node") == null:
			return
		if _h < 0:
			_h = sk.find_bone("mixamorig_Head")
			_n = sk.find_bone("mixamorig_Neck")
		var S := sk.global_transform
		var Sb := S.basis.orthonormalized()
		var hg := sk.get_bone_global_pose(_h)
		var hp: Vector3 = S * hg.origin
		var target: Vector3 = (owner_node.get("look_at_node") as Node3D).global_position
		var f := (target - hp).normalized()
		var tw: float = owner_node.get("twist")
		var up_hint := Vector3.DOWN.lerp(Vector3.UP, 1.0 - tw)
		if absf(up_hint.normalized().dot(f)) > 0.95:
			up_hint = Vector3.FORWARD
		var u := (up_hint - f * f.dot(up_hint)).normalized()
		var Rw := Basis(u.cross(f), u, f).orthonormalized()          # нужный «лицевой» базис в мире
		var Rs := (Sb.inverse() * Rw).orthonormalized()                  # в осях скелета
		var rest := sk.get_bone_global_rest(_h).basis.orthonormalized()  # стоя модель смотрит в +Z, макушка +Y
		var want := Rs * rest
		var cur := hg.basis.orthonormalized()
		# шея — 40% пути, голова — остальное
		var ng := sk.get_bone_global_pose(_n)
		var half := Basis(Quaternion(cur).slerp(Quaternion(want), 0.4) * Quaternion(cur).inverse())
		var neck_g := (half * ng.basis.orthonormalized()).orthonormalized()
		var np := sk.get_bone_parent(_n)
		var npg := sk.get_bone_global_pose(np).basis.orthonormalized()
		sk.set_bone_pose_rotation(_n, Quaternion((npg.inverse() * neck_g).orthonormalized()))
		sk.set_bone_pose_rotation(_h, Quaternion((neck_g.inverse() * want).orthonormalized()))
