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


func _ready() -> void:
	_rng.randomize()
	var sk := get_skeleton()
	_head = sk.find_bone("mixamorig_Head")
	_neck = sk.find_bone("mixamorig_Neck")
	_sp1 = sk.find_bone("mixamorig_Spine1")
	_sp2 = sk.find_bone("mixamorig_Spine2")
	_sh = [sk.find_bone("mixamorig_LeftShoulder"), sk.find_bone("mixamorig_RightShoulder")]


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


func _rot(sk: Skeleton3D, b: int, e: Vector3) -> void:
	if b >= 0:
		sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * Quaternion.from_euler(e * life))


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or life <= 0.001:
		return
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
