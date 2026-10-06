extends Node3D
## Процедурное существо: высокий истощённый силуэт с длинными руками.
## Используется и для Долговязого, и для призрака Гостя (с другими настройками).
## Модель смотрит вдоль +Z. Двигается рывками, как покадровая анимация.

@export var skin_color := Color(0.36, 0.33, 0.29)
@export var arm_length := 1.0      ## 1.0 = руки ниже колен
@export var body_scale := 1.0
@export var sitting := false
@export var head_tilt := 0.45

var moving := false
var J := {}
var _acc := 0.0
var _ph := 0.0
var _t := 0.0
var _twitch := 0.0
var _next_twitch := 1.5
var _skin: StandardMaterial3D
var _dark: StandardMaterial3D
var _bone: StandardMaterial3D
var _eye: StandardMaterial3D


func _ready() -> void:
	_skin = StandardMaterial3D.new()
	_skin.albedo_color = skin_color
	_skin.roughness = 0.95
	_dark = StandardMaterial3D.new()
	_dark.albedo_color = Color.BLACK
	_dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bone = StandardMaterial3D.new()
	_bone.albedo_color = Color(0.55, 0.52, 0.44)
	_eye = StandardMaterial3D.new()
	_eye.albedo_color = Color(1, 0.22, 0.12)
	_eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye.disable_fog = true
	_build()
	scale = Vector3.ONE * body_scale
	_pose()


func _joint(parent: Node3D, p: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = p
	parent.add_child(n)
	return n


func _cyl(parent: Node3D, length: float, r0: float, r1: float, down := true) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r0 if down else r1
	m.bottom_radius = r1 if down else r0
	m.height = length
	m.radial_segments = 10
	m.rings = 2
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _skin
	mi.position.y = -length / 2.0 if down else length / 2.0
	parent.add_child(mi)
	return mi


func _ball(parent: Node3D, r: float, s := Vector3.ONE, p := Vector3.ZERO, mat: Material = null) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 14
	m.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat if mat != null else _skin
	mi.scale = s
	mi.position = p
	parent.add_child(mi)
	return mi


func _cone(parent: Node3D, r: float, h: float, p: Vector3, flip := false) -> void:
	var m := CylinderMesh.new()
	m.top_radius = 0.0 if not flip else r
	m.bottom_radius = r if not flip else 0.0
	m.height = h
	m.radial_segments = 5
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _bone
	mi.position = p
	parent.add_child(mi)


func _build() -> void:
	var hips := _joint(self, Vector3(0, 0.98, 0))
	J.hips = hips
	_ball(hips, 0.13, Vector3(1.2, 0.7, 0.9))
	var spine := _joint(hips, Vector3(0, 0.05, 0))
	J.spine = spine
	_cyl(spine, 0.34, 0.075, 0.09, false)
	for i in 6:
		_ball(spine, 0.028, Vector3(1, 0.7, 1), Vector3(0, 0.04 + i * 0.06, -0.075))
	var chest := _joint(spine, Vector3(0, 0.32, 0))
	J.chest = chest
	var cage := _cyl(chest, 0.42, 0.15, 0.11, false)
	cage.scale = Vector3(1, 1, 0.75)
	for i in 6:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.138 - i * 0.008
		tm.outer_radius = 0.16 - i * 0.008
		tm.rings = 16
		tm.ring_segments = 6
		var ti := MeshInstance3D.new()
		ti.mesh = tm
		ti.material_override = _skin
		ti.position = Vector3(0, 0.06 + i * 0.055, 0.0)
		ti.scale = Vector3(1.05, 1, 0.8)
		chest.add_child(ti)
	_ball(chest, 0.12, Vector3(1.1, 0.9, 0.8), Vector3(0, 0.36, -0.07))
	var neck := _joint(chest, Vector3(0, 0.42, 0.02))
	J.neck = neck
	_cyl(neck, 0.2, 0.045, 0.035, false)
	var head := _joint(neck, Vector3(0, 0.2, 0.02))
	J.head = head
	_ball(head, 0.12, Vector3(0.8, 1.45, 1.0), Vector3(0, 0.1, 0))
	_ball(head, 0.1, Vector3(1.0, 0.45, 0.6), Vector3(0, 0.13, 0.085))
	for k in [-1, 1]:
		_ball(head, 0.034, Vector3(1, 1.25, 0.6), Vector3(k * 0.042, 0.095, 0.105), _dark)
		_ball(head, 0.0065, Vector3.ONE, Vector3(k * 0.042, 0.092, 0.127), _eye)
		_ball(head, 0.03, Vector3(1, 1.4, 0.8), Vector3(k * 0.068, 0.03, 0.07))
	_ball(head, 0.05, Vector3(1, 1.6, 0.6), Vector3(0, -0.03, 0.1), _dark)
	for i in range(-3, 4):
		_cone(head, 0.006, 0.035, Vector3(i * 0.012, 0.0, 0.112 - abs(i) * 0.004), true)
	var jaw := _joint(head, Vector3(0, -0.01, 0))
	J.jaw = jaw
	_ball(jaw, 0.07, Vector3(0.95, 0.4, 1.1), Vector3(0, -0.06, 0.06))
	for i in range(-3, 4):
		_cone(jaw, 0.006, 0.03, Vector3(i * 0.012, -0.045, 0.12 - abs(i) * 0.004))
	J.arms = []
	for k in [-1, 1]:
		var sh := _joint(chest, Vector3(k * 0.17, 0.36, 0))
		_ball(sh, 0.05)
		_cyl(sh, 0.44 * arm_length, 0.04, 0.03)
		var el := _joint(sh, Vector3(0, -0.44 * arm_length, 0))
		_ball(el, 0.035)
		_cyl(el, 0.46 * arm_length, 0.03, 0.022)
		var wr := _joint(el, Vector3(0, -0.46 * arm_length, 0))
		_ball(wr, 0.04, Vector3(0.9, 1.3, 0.45), Vector3(0, -0.04, 0))
		var fingers := []
		for f in 4:
			var f1 := _joint(wr, Vector3((f - 1.5) * 0.018 * k, -0.08, 0.005))
			_cyl(f1, 0.11, 0.008, 0.007)
			var f2 := _joint(f1, Vector3(0, -0.11, 0))
			_cyl(f2, 0.1, 0.007, 0.004)
			_cone(f2, 0.005, 0.04, Vector3(0, -0.12, 0), true)
			f1.rotation.z = (f - 1.5) * 0.12 * k
			fingers.append([f1, f2])
		J.arms.append({"sh": sh, "el": el, "wr": wr, "fingers": fingers, "k": k})
	J.legs = []
	for k in [-1, 1]:
		var hp := _joint(hips, Vector3(k * 0.1, 0, 0))
		_cyl(hp, 0.5, 0.055, 0.035)
		var kn := _joint(hp, Vector3(0, -0.5, 0))
		_ball(kn, 0.042)
		_cyl(kn, 0.53, 0.035, 0.022)
		var an := _joint(kn, Vector3(0, -0.53, 0))
		_ball(an, 0.04, Vector3(0.8, 0.5, 2.6), Vector3(0, -0.02, 0.07))
		J.legs.append({"hp": hp, "kn": kn, "an": an, "k": k})


func _pose() -> void:
	var w := 1.0 if moving else 0.0
	var sn := sin(_ph)
	var cs := cos(_ph)
	if sitting:
		J.hips.position.y = 0.48
		J.spine.rotation.x = 0.2
		J.chest.rotation = Vector3(0.15, 0, 0)
		J.neck.rotation.x = 0.4
		J.head.rotation = Vector3(-0.5 + _twitch * 0.3, _twitch * 0.8, head_tilt + _twitch)
		J.jaw.rotation.x = 0.45
		for i in J.legs.size():
			var L: Dictionary = J.legs[i]
			L.hp.rotation = Vector3(-1.5, 0, L.k * 0.15)
			L.kn.rotation.x = 1.5
			L.an.rotation.x = 0.0
		for i in J.arms.size():
			var A: Dictionary = J.arms[i]
			A.sh.rotation = Vector3(-0.5, 0, A.k * 0.25)
			A.el.rotation.x = -1.0
			A.wr.rotation.x = 0.2
		return
	J.spine.rotation.x = 0.55 + w * 0.05 * sin(_ph * 2.0)
	J.chest.rotation = Vector3(0.35, 0, w * 0.12 * sn)
	J.neck.rotation.x = 0.55
	J.head.rotation = Vector3(-1.3 + _twitch * 0.3, _twitch * 0.8, head_tilt + _twitch)
	J.jaw.rotation.x = 0.5 + 0.15 * sin(_t * 13.0) * (1.0 if moving else 0.3)
	J.hips.position.y = 0.94 + w * 0.04 * abs(cs)
	J.hips.rotation.y = w * 0.15 * sn
	for i in J.legs.size():
		var L: Dictionary = J.legs[i]
		var p: float = _ph + i * PI
		L.hp.rotation = Vector3(-0.45 - w * 0.5 * sin(p), 0, L.k * 0.06)
		L.kn.rotation.x = 0.85 + w * 0.6 * max(0.0, cos(p))
		L.an.rotation.x = -(L.hp.rotation.x + L.kn.rotation.x)
	for i in J.arms.size():
		var A: Dictionary = J.arms[i]
		var p: float = _ph + i * PI + 0.4
		A.sh.rotation = Vector3(-1.05 + w * 0.35 * sin(p) + (1.0 - w) * 0.05 * sin(_t * 0.7 + i), 0, A.k * (0.12 + w * 0.05 * sin(p * 2.0)))
		A.el.rotation.x = -0.25 - w * 0.2 * max(0.0, sin(p))
		A.wr.rotation.x = 0.15
		for j in A.fingers.size():
			A.fingers[j][0].rotation.x = -0.4 - 0.2 * sin(_t * 3.0 + j)
			A.fingers[j][1].rotation.x = -0.6 - 0.3 * sin(_t * 4.0 + j)


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if moving:
		_ph += delta * 5.5
	_next_twitch -= delta
	if _next_twitch <= 0.0:
		_twitch = randf_range(-0.45, 0.45)
		_next_twitch = randf_range(0.3, 0.9) if moving else randf_range(1.5, 4.5)
		head_tilt = randf_range(0.3, 0.8)
	else:
		_twitch *= pow(0.02, delta)
	var fps := 9.0 if moving else 14.0
	if _acc >= 1.0 / fps:
		_acc = 0.0
		_pose()


## Повернуть лицом к точке (по горизонтали).
func face(target: Vector3) -> void:
	var d := target - global_position
	rotation.y = atan2(d.x, d.z)
