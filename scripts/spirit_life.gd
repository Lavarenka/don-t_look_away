extends SkeletonModifier3D
## «Живость» призрака поверх любой анимации: резкие подёргивания головы (дёрнулась — замерла —
## медленно вернулась), неровное дыхание, мелкая дрожь плеч. Сила — life (0..1), из spirit.gd.

var life := 1.0
var shiver := 0.0            ## 0..1: дрожь (испуг, перед броском)
var _t := 0.0
var _next := 1.5
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _cur := Vector3.ZERO
var _k := 1.0                ## 0..1 — ход текущего рывка
var _hold := 0.0
var _rng := RandomNumberGenerator.new()
var _head := -1
var _neck := -1
var _sp2 := -1
var _sp1 := -1
var _sh := [-1, -1]

# ---- взгляд: голова медленно поворачивается за целью (камерой игрока) ----
var look_w := 0.0                  ## 0..1 — сила (spirit.gd плавно включает, когда игрок рядом)
var look_target := Vector3.ZERO    ## точка в мире, куда смотреть
var fwd_world := Vector3.FORWARD   ## куда повёрнуто тело (мир)
var _face_local := Vector3.ZERO    ## «вперёд лица» в осях кости головы
var _yaw := 0.0
var _pitch := 0.0
var _tilt := 0.0                   ## наклон головы набок — «разглядывает»
var _tilt_to := 0.0
var _tilt_next := 3.0
var _snap := 0.0                   ## > 0 — поворот рывком (дёрнула головой в твою сторону)


func _ready() -> void:
	_rng.randomize()
	var sk := get_skeleton()
	_head = sk.find_bone("mixamorig_Head")
	_neck = sk.find_bone("mixamorig_Neck")
	_sp1 = sk.find_bone("mixamorig_Spine1")
	_sp2 = sk.find_bone("mixamorig_Spine2")
	_sh = [sk.find_bone("mixamorig_LeftShoulder"), sk.find_bone("mixamorig_RightShoulder")]
	# в позе покоя лицо смотрит туда же, куда тело: +Z узла призрака, переведённое в оси скелета
	if _head >= 0:
		var fwd_sk: Vector3 = (sk.global_transform.basis.inverse() * (get_parent_node_3d_global_basis_z(sk))).normalized()
		_face_local = (sk.get_bone_global_rest(_head).basis.inverse() * fwd_sk).normalized()


## +Z ближайшего узла выше скелета, у которого нет своего скелета (сам призрак) — это «вперёд» тела.
func get_parent_node_3d_global_basis_z(sk: Skeleton3D) -> Vector3:
	var n: Node = sk.get_parent()
	while n and not (n.get_script() and n.has_method("set_eyes")):
		n = n.get_parent()
	if n is Node3D:
		return (n as Node3D).global_basis.z
	return sk.global_basis.z


func _process(delta: float) -> void:
	_t += delta
	if _k < 1.0:
		_k = minf(_k + delta / 0.07, 1.0)              # рывок — за 70 мс
		_cur = _from.lerp(_to, _k * _k * (3.0 - 2.0 * _k))
	elif _hold > 0.0:
		_hold -= delta
	else:
		_cur = _cur.lerp(Vector3.ZERO, 1.0 - exp(-delta * 1.6))   # медленно «вправляется» обратно
	_next -= delta
	if _next <= 0.0:
		_from = _cur
		_to = Vector3(_rng.randf_range(-0.22, 0.28), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.38, 0.38))
		_k = 0.0
		_hold = _rng.randf_range(0.25, 1.4)
		# иногда — второй рывок сразу следом
		_next = _rng.randf_range(0.18, 0.35) if _rng.randf() < 0.3 else _rng.randf_range(2.5, 7.0)
	# взгляд: куда смотреть (рыскание/тангаж в осях тела), медленно — и изредка рывком
	_tilt_next -= delta
	if _tilt_next <= 0.0:
		_tilt_to = _rng.randf_range(-0.32, 0.32) if _rng.randf() < 0.6 else 0.0
		_tilt_next = _rng.randf_range(2.0, 6.0)
		if look_w > 0.5 and _rng.randf() < 0.3:
			_snap = 0.25
	_tilt = lerpf(_tilt, _tilt_to * look_w, 1.0 - exp(-delta * 1.2))
	_snap = maxf(_snap - delta, 0.0)
	_look_dt = delta


var _look_dt := 0.016


## Поворот кости b так, чтобы направление from (оси скелета) стало to, с долей k.
func _turn(sk: Skeleton3D, b: int, from: Vector3, to: Vector3, k: float) -> void:
	if b < 0 or from.length() < 0.5 or to.length() < 0.5:
		return
	var q := Quaternion(from.normalized(), to.normalized())
	q = Quaternion.IDENTITY.slerp(q, k)
	var g := sk.get_bone_global_pose(b)
	var par := sk.get_bone_parent(b)
	var pg := sk.get_bone_global_pose(par).basis if par >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(b, (pg.orthonormalized().inverse() * (Basis(q) * g.basis.orthonormalized())).get_rotation_quaternion())


func _look(sk: Skeleton3D) -> void:
	if _head < 0 or _face_local == Vector3.ZERO:
		return
	var inv := sk.global_transform.affine_inverse()
	var hp := sk.get_bone_global_pose(_head)
	var fwd := (inv.basis * fwd_world).normalized()
	var up := (inv.basis * Vector3.UP).normalized()
	var right := up.cross(fwd).normalized()
	fwd = right.cross(up).normalized()
	var d := (inv * look_target - hp.origin).normalized()
	var yaw := atan2(d.dot(right), d.dot(fwd))
	var pitch := asin(clampf(d.dot(up), -1.0, 1.0))
	# за спиной — не выворачивает шею, а плавно «отпускает»
	var behind := 1.0 - smoothstep(1.9, 2.6, absf(yaw))
	yaw = clampf(yaw, -1.2, 1.2)
	pitch = clampf(pitch, -0.55, 0.4)
	var rate := 14.0 if _snap > 0.0 else 2.2          # обычно медленно ведёт голову, иногда — рывок
	var k := 1.0 - exp(-_look_dt * rate)
	_yaw = lerpf(_yaw, yaw * behind, k)
	_pitch = lerpf(_pitch, pitch * behind, k)
	var want := (fwd * cos(_pitch) * cos(_yaw) + right * cos(_pitch) * sin(_yaw) + up * sin(_pitch)).normalized()
	var w := look_w * life
	# шея берёт часть поворота, голова — остальное
	var cur := (hp.basis.orthonormalized() * _face_local).normalized()
	_turn(sk, _neck, cur, want, 0.4 * w)
	hp = sk.get_bone_global_pose(_head)
	cur = (hp.basis.orthonormalized() * _face_local).normalized()
	_turn(sk, _head, cur, want, w)
	# наклон головы набок вокруг направления взгляда
	if absf(_tilt) > 0.001:
		hp = sk.get_bone_global_pose(_head)
		var par := sk.get_bone_parent(_head)
		var pg := sk.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis.IDENTITY
		var nb := Basis(want, _tilt) * hp.basis.orthonormalized()
		sk.set_bone_pose_rotation(_head, (pg.inverse() * nb).get_rotation_quaternion())


func _rot(sk: Skeleton3D, b: int, e: Vector3) -> void:
	if b >= 0:
		sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * Quaternion.from_euler(e * life))


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or life <= 0.001:
		return
	if look_w > 0.001:
		_look(sk)
	_rot(sk, _head, _cur)
	_rot(sk, _neck, _cur * 0.35)
	# дыхание: неровное, с задержками
	var br := sin(_t * 1.05) * 0.5 + 0.5
	br = br * br * (0.7 + 0.3 * sin(_t * 0.37))
	_rot(sk, _sp2, Vector3(-0.035 * br, 0, 0))
	_rot(sk, _sp1, Vector3(-0.015 * br, 0, 0))
	# дрожь
	var s := 0.012 + shiver * 0.05
	for i in 2:
		_rot(sk, _sh[i], Vector3(sin(_t * 37.0 + i * 2.1), 0, sin(_t * 29.0 + i)) * s)
	_rot(sk, _head, Vector3(sin(_t * 41.0), sin(_t * 33.0), 0) * shiver * 0.03)
