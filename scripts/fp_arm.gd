extends Node
## Рука для катсцен: тело Remy (Mixamo), видна только левая рука. TwoBoneIK3D ставит запястье в точку,
## scripts/phone_hand.gd поворачивает кисть и сжимает пальцы. Владелец задаёт каждый кадр:
##   set_goal(xf) — где запястье и как повёрнута кисть (в мире), hand_w — насколько слушаться поворота,
##   grip — пальцы (0 раскрыты … 1 сжаты), pole.global_position — куда смотрит локоть.
## Используется в катсцене под кроватью (bed_grab.gd): своя рука игрока и детская рука из-под кровати.
## (Звонок, phone_call.gd, устроен так же, но со своей копией — его не трогаем.)

const BODY := "res://models/player/remy.fbx"
const EYE := 3.47                       ## высота глаз Remy в её единицах
const HIDE := ["Hair", "Eyes", "Eyelashes", "Tops", "Bottoms", "Shoes"]

var body: Node3D
var sk: Skeleton3D
var target: Node3D
var pole: Node3D
var hand_goal := Transform3D()
var hand_w := 0.0
var grip := 0.0
var hand_now := Transform3D()           ## где кисть на самом деле (после IK), каждый кадр скелета
var fore_now := Vector3.ZERO            ## локоть (начало предплечья) — тоже после IK
var have := false
var f_local := Vector3.RIGHT            ## куда смотрят пальцы — в осях кости кисти
var p_local := Vector3.DOWN             ## куда смотрит ладонь — в осях кости кисти
var palm_len := 0.09                    ## от запястья до костяшек, м
var arm_len := 0.5                      ## плечо + предплечье, м
var _hand := -1
var _fore := -1


## pos/yaw — где стоит тело (yaw — как у узла игрока: «вперёд» = -Z), k — масштаб, layer — слой мешей.
func spawn(parent: Node, pos: Vector3, yaw: float, k: float, layer: int) -> void:
	var res: Resource = ResourceLoader.load_threaded_get(BODY) if ResourceLoader.load_threaded_get_status(BODY) == ResourceLoader.THREAD_LOAD_LOADED else load(BODY)
	body = (res as PackedScene).instantiate()
	body.scale = Vector3(k, k, k)
	parent.add_child(body)
	body.global_position = pos
	body.global_rotation = Vector3(0, yaw + PI, 0)
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.layers = layer
		if m.name in HIDE:
			m.visible = false
	sk = body.get_node("Skeleton3D")
	var ap: AnimationPlayer = body.get_node("AnimationPlayer")
	ap.play("mixamo_com")
	ap.seek(0.3, true)
	ap.pause()
	_hand = sk.find_bone("mixamorig_LeftHand")
	_fore = sk.find_bone("mixamorig_LeftForeArm")
	var hr := sk.get_bone_global_rest(_hand)
	var mr := sk.get_bone_global_rest(sk.find_bone("mixamorig_LeftHandMiddle1"))
	var ir := sk.get_bone_global_rest(sk.find_bone("mixamorig_LeftHandIndex1"))
	var pr := sk.get_bone_global_rest(sk.find_bone("mixamorig_LeftHandPinky1"))
	var ar := sk.get_bone_global_rest(sk.find_bone("mixamorig_LeftArm"))
	var fr := sk.get_bone_global_rest(sk.find_bone("mixamorig_LeftForeArm"))
	var f_sk := (mr.origin - hr.origin).normalized()
	var l_sk := ir.origin - pr.origin
	l_sk = (l_sk - f_sk * f_sk.dot(l_sk)).normalized()
	var p_sk := f_sk.cross(l_sk).normalized()
	var hb := hr.basis.orthonormalized().inverse()
	f_local = (hb * f_sk).normalized()
	p_local = (hb * p_sk).normalized()
	var S := sk.global_transform.basis
	palm_len = (S * (mr.origin - hr.origin)).length()
	arm_len = (S * (fr.origin - ar.origin)).length() + (S * (hr.origin - fr.origin)).length()
	hand_goal = bone_world(_hand)
	target = Node3D.new()
	target.top_level = true
	parent.add_child(target)
	target.global_position = hand_goal.origin
	pole = Node3D.new()
	pole.top_level = true
	parent.add_child(pole)
	pole.global_position = pos + Vector3.UP * 0.5
	var ik := TwoBoneIK3D.new()
	ik.setting_count = 1
	ik.set_root_bone_name(0, "mixamorig_LeftArm")
	ik.set_middle_bone_name(0, "mixamorig_LeftForeArm")
	ik.set_end_bone_name(0, "mixamorig_LeftHand")
	ik.set_use_virtual_end(0, false)
	sk.add_child(ik)
	ik.set_target_node(0, ik.get_path_to(target))
	ik.set_pole_node(0, ik.get_path_to(pole))
	var hand_mod: SkeletonModifier3D = preload("res://scripts/phone_hand.gd").new()
	hand_mod.call("setup", self)
	sk.add_child(hand_mod)
	sk.skeleton_updated.connect(_on_updated)


func _on_updated() -> void:
	if is_instance_valid(sk):
		hand_now = bone_world(_hand)
		fore_now = bone_world(_fore).origin
		have = true


func set_goal(xf: Transform3D) -> void:
	hand_goal = xf
	if is_instance_valid(target):
		target.global_position = xf.origin


func bone_world(i: int) -> Transform3D:
	var t: Transform3D = sk.global_transform * sk.get_bone_global_pose(i)
	return Transform3D(t.basis.orthonormalized(), t.origin)


## Положение кости в мире в позе покоя анимации (до IK) — для плеча, которое IK не двигает.
func bone_pos(n: String) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(n)).origin


static func frame(a: Vector3, b: Vector3) -> Basis:
	var x := a.normalized()
	var y := (b - x * x.dot(b)).normalized()
	return Basis(x, y, x.cross(y))


## Где должно быть запястье и как повёрнута кисть, чтобы пальцы смотрели вдоль f, ладонь — в сторону pn,
## а костяшки (основание среднего пальца) были в точке mcp.
func grip_xf(f: Vector3, pn: Vector3, mcp: Vector3) -> Transform3D:
	var b := frame(f, pn) * frame(f_local, p_local).inverse()
	return Transform3D(b, mcp - f.normalized() * palm_len)


func set_material(m: Material) -> void:
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m


## Исходная текстура кожи (для своего материала).
func skin_texture() -> Texture2D:
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.name in HIDE or m.mesh == null:
			continue
		var mat := m.get_active_material(0)
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture:
			return (mat as BaseMaterial3D).albedo_texture
	return null


func remove() -> void:
	for n in [body, target, pole]:
		if is_instance_valid(n):
			n.queue_free()
	queue_free()
