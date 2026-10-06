extends RefCounted
## Манекен-человек без анимаций: позы и поворот головы задаются прямо костями скелета.
## Оси в пространстве модели: Y — вверх, +Z — вперёд (куда смотрит лицо), +X — левая рука.

const P := "mixamorig1_"
## позы: список [кость, ось, градусы] — поворот в пространстве модели, по порядку от корня к кончикам
const POSES := {
	"stand": [["LeftArm", Vector3.BACK, -84], ["RightArm", Vector3.BACK, 84],
		["LeftForeArm", Vector3.RIGHT, -12], ["RightForeArm", Vector3.RIGHT, -12]],
	"tilt": [["LeftArm", Vector3.BACK, -86], ["RightArm", Vector3.BACK, 80],
		["LeftForeArm", Vector3.RIGHT, -8], ["RightForeArm", Vector3.RIGHT, -20],
		["Neck", Vector3.BACK, 18], ["Head", Vector3.BACK, 42]],
	"point": [["LeftArm", Vector3.BACK, -86], ["LeftForeArm", Vector3.RIGHT, -10],
		["RightArm", Vector3.UP, 90], ["RightArm", Vector3.RIGHT, -12],
		["RightHandMiddle1", Vector3.RIGHT, 75], ["RightHandMiddle2", Vector3.RIGHT, 70],
		["RightHandRing1", Vector3.RIGHT, 75], ["RightHandRing2", Vector3.RIGHT, 70],
		["RightHandPinky1", Vector3.RIGHT, 75], ["RightHandPinky2", Vector3.RIGHT, 70]],
	"reach": [["Spine1", Vector3.RIGHT, 8], ["LeftArm", Vector3.UP, -80], ["LeftArm", Vector3.RIGHT, -8],
		["RightArm", Vector3.UP, 80], ["RightArm", Vector3.RIGHT, -8],
		["LeftForeArm", Vector3.RIGHT, -10], ["RightForeArm", Vector3.RIGHT, -10],
		["LeftHandIndex1", Vector3.RIGHT, 35], ["LeftHandMiddle1", Vector3.RIGHT, 40], ["LeftHandRing1", Vector3.RIGHT, 45], ["LeftHandPinky1", Vector3.RIGHT, 50],
		["RightHandIndex1", Vector3.RIGHT, 35], ["RightHandMiddle1", Vector3.RIGHT, 40], ["RightHandRing1", Vector3.RIGHT, 45], ["RightHandPinky1", Vector3.RIGHT, 50]],
	"slump": [["Spine", Vector3.RIGHT, 14], ["Spine1", Vector3.RIGHT, 10], ["Spine2", Vector3.RIGHT, 6],
		["LeftArm", Vector3.BACK, -92], ["RightArm", Vector3.BACK, 92],
		["Neck", Vector3.RIGHT, 22], ["Head", Vector3.RIGHT, 24]],
	"twist": [["LeftArm", Vector3.BACK, -84], ["RightArm", Vector3.BACK, 84],
		["LeftForeArm", Vector3.RIGHT, -6], ["RightForeArm", Vector3.RIGHT, -6],
		["Neck", Vector3.UP, 35], ["Head", Vector3.UP, 75], ["Head", Vector3.BACK, 12]],
}

var node: Node3D
var sk: Skeleton3D
var idx := {}
var base_neck: Quaternion
var base_head: Quaternion
var yaw := 0.0          ## текущий поворот головы к игроку (радианы, добавочный)
var pitch := 0.0


func _init(n: Node3D) -> void:
	node = n
	var ap := n.get_node_or_null("AnimationPlayer")
	if ap:
		ap.stop()
		ap.queue_free()             # анимации не нужны — только позы
	sk = n.get_node("Skeleton3D")
	for i in sk.get_bone_count():
		idx[sk.get_bone_name(i).trim_prefix(P)] = i


func _global(b: int) -> Basis:
	var chain := []
	var i := b
	while i != -1:
		chain.push_front(i)
		i = sk.get_bone_parent(i)
	var g := Basis()
	for c in chain:
		g = g * Basis(sk.get_bone_pose_rotation(c))
	return g


func _rot(bone: String, axis: Vector3, deg: float) -> void:
	var b: int = idx[bone]
	var p := sk.get_bone_parent(b)
	var pg := _global(p) if p != -1 else Basis()
	var ng := Basis(axis, deg_to_rad(deg)) * _global(b)
	sk.set_bone_pose_rotation(b, (pg.inverse() * ng).orthonormalized().get_rotation_quaternion())


func set_pose(name: String) -> void:
	sk.reset_bone_poses()
	for r in POSES[name]:
		_rot(r[0], r[1], r[2])
	base_neck = sk.get_bone_pose_rotation(idx["Neck"])
	base_head = sk.get_bone_pose_rotation(idx["Head"])
	_apply_head()


func _apply_head() -> void:
	sk.set_bone_pose_rotation(idx["Neck"], base_neck)
	sk.set_bone_pose_rotation(idx["Head"], base_head)
	_rot("Neck", Vector3.UP, rad_to_deg(yaw) * 0.35)
	_rot("Head", Vector3.UP, rad_to_deg(yaw) * 0.65)
	_rot("Head", Vector3.RIGHT, rad_to_deg(pitch))


## Куда нужно повернуть голову, чтобы смотреть на точку (в радианах, с ограничением).
func aim_at(world: Vector3) -> Vector2:
	var head: Vector3 = node.global_position + node.global_basis.y * 1.55
	var loc: Vector3 = node.global_basis.inverse() * (world - head)
	var y := clampf(atan2(loc.x, loc.z), -1.5, 1.5)
	var p := clampf(-atan2(loc.y, Vector2(loc.x, loc.z).length()), -0.5, 0.6)
	return Vector2(y, p)


## Плавно повернуть голову к цели со скоростью speed (рад/с).
func turn_head(target: Vector2, speed: float, delta: float) -> bool:
	var ny := move_toward(yaw, target.x, speed * delta)
	var np := move_toward(pitch, target.y, speed * delta)
	if is_equal_approx(ny, yaw) and is_equal_approx(np, pitch):
		return false
	yaw = ny
	pitch = np
	_apply_head()
	return true
