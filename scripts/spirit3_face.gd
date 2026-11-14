extends SkeletonModifier3D
## Аня v3: лицо и кисти поверх анимации (ставится в скелет после spirit_life.gd).
## Мимика — «лицевые единицы» MakeHuman (models/spirit3/anya_face.json, CC0): повороты костей лица в их собственных осях.
## Взгляд — кости глаз, моргание — кости век, рот — кость челюсти и губ; пальцы — расслабленный изгиб,
## мелкие подёргивания и «когти» (claw). Всем управляет spirit.gd.

const UNITS_PATH := "res://models/spirit3/anya_face.json"
const EYE_MAX := 0.62            ## насколько глаз может отвернуться от «прямо» (рад)
static var _units := {}          ## единица → {имя кости: Quaternion}

var jaw := 0.0                   ## 0..1 — крик: рот распахнут, верхняя губа вверх, брови вниз
var grimace := 0.0               ## 0..1 — оскал: уголки рта вниз, нос морщится
var murmur := 0.0                ## 0..~0.3 — губы приоткрыты (шёпот, дыхание ртом)
var blink := 0.0                 ## 0..1 — веки закрыты
var look_w := 0.0                ## 0..1 — глаза следят за look_target
var look_target := Vector3.ZERO  ## точка в мире
var claw := 0.0                  ## 0..1 — пальцы скрючены
var finger_life := 1.0           ## подёргивания пальцев
var extra := {}                  ## ещё единицы для отдельных сцен: имя → вес

var _ub := {}                    ## единица → [[кость, Quaternion], …]
var _acc := {}
var _eyes := PackedInt32Array()
var _fingers := []               ## [кость, ось изгиба (в осях кости), сустав, палец, фаза]
var _t := 0.0


func _ready() -> void:
	var sk := get_skeleton()
	if _units.is_empty():
		var d: Dictionary = (load(UNITS_PATH) as JSON).data
		for u in d:
			var m := {}
			for b in d[u]:
				var a: Array = d[u][b]
				m[b] = Quaternion(a[0], a[1], a[2], a[3]).normalized()
			_units[u] = m
	for u in _units:
		var arr := []
		for b in _units[u]:
			var i := sk.find_bone(b)
			if i >= 0:
				arr.append([i, _units[u][b]])
		_ub[u] = arr
	_eyes = PackedInt32Array([sk.find_bone("eye_L"), sk.find_bone("eye_R")])
	for side in ["L", "R"]:
		var wrist := sk.find_bone("wrist_" + side)
		if wrist < 0:
			continue
		var pw := sk.get_bone_global_rest(wrist).origin
		var n := (sk.get_bone_global_rest(sk.find_bone("finger2_1_" + side)).origin - pw).cross(sk.get_bone_global_rest(sk.find_bone("finger5_1_" + side)).origin - pw).normalized()
		if n.y > 0.0:
			n = -n                                   # в позе покоя ладонь смотрит вниз
		for f in range(1, 6):
			for j in range(1, 4):
				var b := sk.find_bone("finger%d_%d_%s" % [f, j, side])
				if b < 0:
					continue
				var gr := sk.get_bone_global_rest(b).basis.orthonormalized()
				var axis := gr.y.cross(n)
				if axis.length() < 0.01:
					continue
				_fingers.append([b, (gr.inverse() * axis.normalized()).normalized(), j, f, randf() * 10.0])


func _process(delta: float) -> void:
	_t += delta


func _add(unit: String, w: float) -> void:
	if w <= 0.002 or not _ub.has(unit):
		return
	for e in _ub[unit]:
		_acc[e[0]] = (_acc.get(e[0], Quaternion.IDENTITY) as Quaternion) * Quaternion.IDENTITY.slerp(e[1], minf(w, 1.25))


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_acc.clear()
	var j := clampf(jaw, 0.0, 1.1)
	var g := clampf(grimace, 0.0, 1.0)
	var open := 1.0 - clampf(blink, 0.0, 1.0)
	if j > 0.002:                                    # крик
		_add("JawDropStretched", j)
		_add("UpperLipUp", 0.9 * j)
		_add("lowerLipDown", 0.7 * j)
		_add("NoseWrinkler", 0.8 * j)
		_add("LeftUpperLidOpen", 0.9 * j * open)
		_add("RightUpperLidOpen", 0.9 * j * open)
		_add("LeftCheekUp", 0.3 * j)
		_add("RightCheekUp", 0.3 * j)
	var brow := maxf(0.85 * j, 0.7 * g)
	_add("LeftBrowDown", brow)
	_add("RightBrowDown", brow)
	var corners := maxf(0.3 * j, 0.65 * g)
	_add("MouthLeftPullDown", corners)
	_add("MouthRightPullDown", corners)
	if g > 0.002:
		_add("NoseWrinkler", 0.45 * g * (1.0 - j))
		_add("UpperLipUp", 0.3 * g * (1.0 - j))
	var mm := clampf(murmur, 0.0, 0.5) * (1.0 - minf(j, 1.0))
	if mm > 0.002:
		_add("JawDrop", mm * 0.7)
		_add("LipsKiss", mm * 0.35)
	if blink > 0.002:
		_add("LeftUpperLidClosed", blink)
		_add("RightUpperLidClosed", blink)
		_add("LeftLowerLidUp", 0.5 * blink)
		_add("RightLowerLidUp", 0.5 * blink)
	for u in extra:
		_add(u, float(extra[u]))
	for b in _acc:
		sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * (_acc[b] as Quaternion))
	# глаза: ось взгляда кости — +Y
	if look_w > 0.002:
		var tgt := sk.global_transform.affine_inverse() * look_target
		for e in _eyes:
			if e < 0:
				continue
			var gp := sk.get_bone_global_pose(e)
			var d := gp.basis.orthonormalized().inverse() * (tgt - gp.origin)
			if d.length() < 0.001:
				continue
			d = d.normalized()
			var ang := Vector3.UP.angle_to(d)
			if ang < 0.0005:
				continue
			var k := look_w * minf(1.0, EYE_MAX / ang)
			if d.y < 0.0:
				k *= maxf(0.0, 1.0 + d.y * 1.5)        # цель за спиной — глаза возвращаются
			sk.set_bone_pose_rotation(e, sk.get_bone_pose_rotation(e) * Quaternion.IDENTITY.slerp(Quaternion(Vector3.UP, d), k))
	# пальцы
	var cl := clampf(claw, 0.0, 1.0)
	for f in _fingers:
		var jn: int = f[2]
		var fn: int = f[3]
		var ang: float = [0.0, 0.14, 0.24, 0.16][jn] * (1.0 + 0.14 * (fn - 3))
		ang += cl * [0.0, 0.18, 0.85, 0.7][jn]
		if fn == 1:
			ang *= 0.45
		ang += finger_life * (sin(_t * (1.1 + fn * 0.31) + f[4]) * 0.035 + sin(_t * 5.3 + f[4] * 2.0) * 0.012 * (1.0 + 2.0 * cl))
		sk.set_bone_pose_rotation(f[0], sk.get_bone_pose_rotation(f[0]) * Quaternion(f[1], ang))
