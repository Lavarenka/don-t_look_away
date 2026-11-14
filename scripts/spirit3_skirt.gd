extends SkeletonModifier3D
## Аня v3 (вид 3): юбка балахона — цепочки костей skirt_<i>_<j> от бёдер к подолу (tools/anya3/s2_gown.py).
## Каждый кадр: ткань висит по тяжести (сохраняя расклёш балахона), а где мешают ноги (бедро и голень — капсулы),
## отходит от оси тела наружу, огибая их; у пола — ложится на пол. Чуть отстаёт от движения — как ткань.
## Без этого подол шёл за коленями и в присядке раздувался колоколом, а с физикой SpringBone ноги проходили насквозь.
## Ставится последним модификатором скелета (spirit.gd → _setup_skirt).

var hang := 0.75              ## 0 — форма балахона поворачивается вместе с тазом, 1 — висит строго вниз
var lift := 0.0               ## 0..1 — «всплывает» (волосы дыбом): подол приподнимается и расходится
var lag := 12.0               ## как быстро ткань догоняет (больше — жёстче)
const MARGIN := 0.015         ## зазор между тканью и ногой
const THIGH_R := 0.082         ## бедро и голень у вида 3 (95 % вершин ближе к кости — tools/anya3/leg_r.py)
const SHIN_R := 0.066
const FLOOR_Y := 0.015        ## пол — в осях скелета (ступни стоят на 0)

var _chains := []             ## [ [кость, …], … ]
var _tail := []               ## [ [конец кости в её осях, …], … ]
var _len := []                ## [ [длина, …], … ]
var _rest_dir := []           ## [ [направление кости в покое (оси скелета), …], … ]
var _flare := []              ## [ [наружу/вниз в покое, …], … ]
var _out := []                ## [наружу в покое (горизонталь) — для каждой цепочки]
var _legs := []               ## [ [кость начала, кость конца, радиус], … ]
var _root := -1
var _prev := []               ## сглаженные положения суставов (мир)
var _dt := 1.0 / 60.0
var _snap := true


func _ready() -> void:
	var sk := get_skeleton()
	_root = sk.find_bone("root")
	var i := 0
	while sk.find_bone("skirt_%d_0" % i) >= 0:
		var bl := []
		var j := 0
		while sk.find_bone("skirt_%d_%d" % [i, j]) >= 0:
			bl.append(sk.find_bone("skirt_%d_%d" % [i, j]))
			j += 1
		var tails := []; var lens := []; var dirs := []; var fl := []
		for k in bl.size():
			var b: int = bl[k]
			var t: Vector3 = sk.get_bone_rest(bl[k + 1]).origin if k + 1 < bl.size() else sk.get_bone_rest(b).origin.length() * Vector3.UP
			tails.append(t)
			lens.append(t.length())
			var g := sk.get_bone_global_rest(b)
			var d: Vector3 = (g.basis * t).normalized()
			dirs.append(d)
			fl.append(Vector2(d.x, d.z).length() / maxf(-d.y, 0.2))
		var top := sk.get_bone_global_rest(bl[0]).origin
		var rc := sk.get_bone_global_rest(_root).origin
		var o := Vector3(top.x - rc.x, 0.0, top.z - rc.z).normalized()
		_chains.append(bl); _tail.append(tails); _len.append(lens); _rest_dir.append(dirs); _flare.append(fl); _out.append(o)
		i += 1
	for sd in ["L", "R"]:
		_legs.append([sk.find_bone("upperleg01_" + sd), sk.find_bone("lowerleg01_" + sd), THIGH_R + MARGIN, true])
		_legs.append([sk.find_bone("lowerleg01_" + sd), sk.find_bone("foot_" + sd), SHIN_R + MARGIN, false])


func _process(delta: float) -> void:
	_dt = clampf(delta, 0.001, 0.1)


## Сбросить отставание (показалась в другом месте).
func reset() -> void:
	_snap = true


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Повернуть кость b (оси скелета) так, чтобы направление from стало to.
static func _turn(sk: Skeleton3D, b: int, from: Vector3, to: Vector3) -> void:
	if from.length() < 0.0001 or to.length() < 0.0001:
		return
	var q := Quaternion(from.normalized(), to.normalized())
	var g := sk.get_bone_global_pose(b)
	var par := sk.get_bone_parent(b)
	var pg := sk.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(b, (pg.inverse() * (Basis(q) * g.basis.orthonormalized())).get_rotation_quaternion())


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _chains.is_empty() or _root < 0:
		return
	var xf := sk.global_transform
	var inv := xf.affine_inverse()
	var down: Vector3 = (inv.basis * Vector3.DOWN).normalized()      # тяжесть — в осях скелета
	var up := -down
	var rg := sk.get_bone_global_pose(_root)
	var rot := rg.basis.orthonormalized() * sk.get_bone_global_rest(_root).basis.orthonormalized().inverse()
	var axis := rg.origin
	var caps := []
	for lg in _legs:
		var a := sk.get_bone_global_pose(lg[0]).origin
		var b := sk.get_bone_global_pose(lg[1]).origin
		if lg[3]:
			a = a.lerp(b, 0.3)          # бедро — от трети: у тазобедренного сустава нога внутри таза, юбку там держит таз
		caps.append([a, b, lg[2]])
	var k_lag := 1.0 - exp(-lag * _dt)
	if _prev.size() != _chains.size():
		_prev.resize(_chains.size())
		_snap = true
	for ci in _chains.size():
		var bl: Array = _chains[ci]
		var p := sk.get_bone_global_pose(bl[0]).origin
		# наружу (горизонтально): покой, повёрнутый с тазом
		var o: Vector3 = rot * (_out[ci] as Vector3)
		o -= up * o.dot(up)
		o = o.normalized() if o.length() > 0.01 else Vector3.FORWARD
		var pts := [p]
		for j in bl.size():
			var L: float = _len[ci][j]
			var shape: Vector3 = rot * (_rest_dir[ci][j] as Vector3)
			var fl: float = _flare[ci][j] * (1.0 + 1.5 * lift)
			var hang_d := (down + o * fl).normalized()
			var d := shape.lerp(hang_d, hang).normalized()
			d = (d + up * 0.9 * lift * (float(j + 1) / bl.size())).normalized()
			var q := p + d * L
			# запаздывание (в мире): ткань догоняет, а не прыгает за телом
			var prev: Array = _prev[ci] if _prev[ci] != null else []
			if not _snap and prev.size() > j and (prev[j] as Vector3).distance_to(xf * q) < 0.6:
				q = inv * (prev[j] as Vector3).lerp(xf * q, k_lag)
				q = p + (q - p).normalized() * L
			# ноги — жёстко (после запаздывания): отвести кость наружу от оси тела, пока ни сустав, ни сама кость
			# (точки вдоль неё) не в капсулах; точке на доле t длины нужен сдвиг конца в 1/t раз больше (рычаг)
			var near := []                     # капсулы, до которых эта кость вообще может дотянуться
			for c in caps:
				if _seg_dist(p, c[0], c[1]) < float(c[2]) + L + 0.05:
					near.append(c)
			for it in (10 if not near.is_empty() else 0):
				var push := 0.0
				for c in near:
					for t in [0.25, 0.5, 0.75, 1.0]:
						var need := float(c[2]) - _seg_dist(p.lerp(q, t), c[0], c[1])
						if need > 0.0:
							push = maxf(push, need / t)
				if push <= 0.0:
					break
				push = minf(push, L)
				var ho := q - axis
				ho -= up * ho.dot(up)
				ho = ho.normalized() if ho.length() > 0.02 else o
				q += ho * (push + 0.004)
				q = p + (q - p).normalized() * L
			# пол: ткань ложится, а не уходит вниз
			if q.dot(up) < FLOOR_Y:
				var hp := p.dot(up) - FLOOR_Y
				var horiz := q - p
				horiz -= up * horiz.dot(up)
				horiz = horiz.normalized() if horiz.length() > 0.005 else o
				q = p - up * clampf(hp, 0.0, L) + horiz * sqrt(maxf(L * L - clampf(hp, 0.0, L) ** 2, 0.0))
			if prev.size() <= j:
				prev.resize(j + 1)
			prev[j] = xf * q
			_prev[ci] = prev
			pts.append(q)
			p = q
		# повернуть кости по найденным точкам
		for j in bl.size():
			var b: int = bl[j]
			var g := sk.get_bone_global_pose(b)
			_turn(sk, b, g.basis * (_tail[ci][j] as Vector3), (pts[j + 1] as Vector3) - g.origin)
	_snap = false
