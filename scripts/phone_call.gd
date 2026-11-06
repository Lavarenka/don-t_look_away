extends Node
## Катсцена «звонок» в зале: своя левая рука тянется к телефону, берёт трубку, подносит к уху.
## В трубке — Аня (PHONE_01, звук «из трубки»). Кладёшь трубку — тишина… и голос прямо за спиной:
## «Зачем ты положил трубку?» (PHONE_03). Управление возвращается: оборачиваешься — никого.
##
## Телефон — прежний (models/vintage/phone.fbx). Он одним мешем, но из отдельных «островков»:
## трубку и витой шнур отделяем при загрузке; шнур строится заново, пока трубка в руке.
## Тело игрока — Remy (Mixamo, как в зеркале): видна только левая рука (scripts/phone_hand.gd).
##
## Как рука и трубка двигаются вместе:
##   * хват задан относительно самой трубки: ладонь сверху на ручке, костяшки над дальней стороной,
##     пальцы обхватывают ручку (_grip_world);
##   * рука (TwoBoneIK3D + поворот кисти) идёт к этому хвату; дотянулась — сжимает пальцы;
##   * с этого момента трубка жёстко «прирастает» к кисти: каждый кадр, когда скелет посчитан
##     (сигнал skeleton_updated), трубка ставится в то же место относительно ладони. Рука и трубка
##     больше не могут разойтись, даже если рука до цели не дотянулась;
##   * у уха и на обратном пути цель руки считается из нужного положения трубки.
## Если стол не пускает к телефону — игрок наклоняется над ним ровно настолько, чтобы рука дотянулась.
## Свет: вплотную фонарь выжигает и телефон, и руку в белое пятно. Поэтому, пока идёт сцена, фонарь
## приглушается по мере приближения к телефону (как глаз привыкает), руку он не освещает вовсе,
## а руку, трубку и всё рядом мягко подсвечивает широкий «ореол» фонаря (_spill).
## Откатить: PHONE_SCENE = false в haunts.gd — прежний короткий звонок.

const BODY := "res://models/player/remy.fbx"
const EYE := 3.47                       ## высота глаз Remy в её единицах (как в mirror.gd)
const BODY_LAYER := 1 << 19             ## тело игрока — свой слой и своя подсветка
const LEAN_DROP := 0.22                 ## наклон вперёд на 1 м опускает плечи на 22 см
const FLASH_REF := 1.5                  ## ближе этого (м) к телефону фонарь приглушается
const FLASH_MIN := 0.25                 ## …но не тусклее этой доли
const SPILL := 0.85                     ## яркость ореола фонаря на руке и трубке

var L: Node
var phone: Node3D
var handset: Node3D
var cord: MeshInstance3D
var _cord_mat: Material
var _rest_xf: Transform3D       ## трубка на рычагах (относительно родителя меша)
var CORD_START: Vector3         ## гнездо шнура на корпусе (в осях меша телефона)
var CORD_END: Vector3           ## куда шнур входит в трубку (в осях трубки)
var EARPIECE: Vector3           ## слуховой стакан (в осях трубки)
## «Канон» трубки: начало — центр ручки посередине, X — от слухового стакана к микрофону,
## Y — вверх (стаканы смотрят вниз), Z — к лицевой стороне телефона (к игроку). В осях узла трубки.
var _hc := Transform3D()
var _hh := 0.02                 ## полувысота ручки
var _hd := 0.018                ## полутолщина ручки

var body: Node3D
var sk: Skeleton3D
var target: Node3D
var pole: Node3D
var _spill: SpotLight3D
var _spill_k := 0.0             ## ореол: 0 — нет, 1 — полный (плавно появляется и гаснет)
var _dim_on := false            ## фонарь приглушается по расстоянию до телефона
var _flash_e0 := 5.0            ## яркость фонаря до сцены
var _flash_mask := 0
var _hand_idx := -1
var _f_local := Vector3.RIGHT   ## куда смотрят пальцы — в осях кости кисти
var _p_local := Vector3.DOWN    ## куда смотрит ладонь — в осях кости кисти
var _palm_len := 0.09           ## от запястья до костяшек, м
var _arm_len := 0.5             ## плечо + предплечье, м
var _shoulder0 := Vector3.ZERO  ## плечо (мир) без наклона
var _body0 := Vector3.ZERO
var _head0 := Vector3.ZERO
var _fwd := Vector3.FORWARD     ## вперёд (по горизонтали) — куда наклоняется
var _right := Vector3.RIGHT
var _hand_rest_local := Vector3.ZERO   ## где висела рука (в осях тела)

var grip := 0.0                 ## пальцы: 0 — раскрыты, 1 — сжаты на ручке
var hand_w := 0.0               ## насколько кисть повёрнута «как задано» (0 — как вышло у IK)
var hand_goal := Transform3D()  ## цель кисти в мире: начало — запястье, поворот — поворот кисти
var _goal_fn := Callable()      ## если задана — цель кисти пересчитывается каждый кадр
var _hand_now := Transform3D()  ## где кисть на самом деле (после IK), обновляется с каждым кадром скелета
var _have_hand := false
var _attached := false
var _handset_in_hand := Transform3D()
var _lean := 0.0                ## насколько наклонился вперёд, м
var _pole_k := 0.0              ## локоть: 0 — вниз-наружу (тянется к столу), 1 — наружу-вперёд (у уха)
var _look_on := false
var stand_side := 0.0           ## насколько встать правее трубки (левое плечо — напротив неё), м
var grip_tilt := -0.2           ## наклон пальцев хвата: минус — костяшки ниже, кисть продолжает предплечье
var grip_yaw := -0.5           ## пальцы наискось по ручке (рад): кисть по линии предплечья
var stand_yaw := 0.0            ## доворот направления, откуда подходит (рад)
var _look_pt := Vector3.ZERO


func prepare(level: Node, ph: Node3D) -> void:
	L = level
	phone = ph
	_split(ph.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D)
	cord = MeshInstance3D.new()
	cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cord.material_override = _cord_mat
	L.add_child(cord)
	_build_cord()


## Разбор меша на острова (вершины, связанные треугольниками или совпадающие по месту).
func _split(mi: MeshInstance3D) -> void:
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var par := PackedInt32Array()
	par.resize(v.size())
	for i in v.size():
		par[i] = i
	var find := func(x: int) -> int:
		while par[x] != x:
			par[x] = par[par[x]]
			x = par[x]
		return x
	var pos := {}
	for i in v.size():
		var key := Vector3i(roundi(v[i].x * 10000), roundi(v[i].y * 10000), roundi(v[i].z * 10000))
		if pos.has(key):
			var a: int = find.call(i)
			var b: int = find.call(pos[key])
			if a != b:
				par[a] = b
		else:
			pos[key] = i
	for t in range(0, idx.size(), 3):
		for k in [1, 2]:
			var a: int = find.call(idx[t])
			var b: int = find.call(idx[t + k])
			if a != b:
				par[a] = b
	var box := {}
	var cnt := {}
	for i in v.size():
		var r: int = find.call(i)
		box[r] = (box[r] as AABB).expand(v[i]) if box.has(r) else AABB(v[i], Vector3.ZERO)
		cnt[r] = cnt.get(r, 0) + 1
	# трубка — самый высокий крупный остров; шнур — крупный остров с краю
	var hs := -1
	var cd := -1
	for r in box:
		var ab: AABB = box[r]
		if cnt[r] < 300:
			continue
		if ab.size.x < 0.13 and ab.size.y > 0.08 and ab.position.x > 0.05:
			cd = r
		elif ab.size.x > 0.2 and (hs < 0 or ab.get_center().y > (box[hs] as AABB).get_center().y):
			hs = r
	var lo := PackedInt32Array()
	var hi := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var r: int = find.call(idx[t])
		if r == cd:
			continue                                          # свой шнур — живой, строится заново
		var dst := hi if r == hs else lo
		dst.append(idx[t]); dst.append(idx[t + 1]); dst.append(idx[t + 2])
	var hab: AABB = box[hs]
	var c: Vector3 = hab.get_center()
	var cab: AABB = box[cd] if cd >= 0 else AABB(c + Vector3(0.12, -0.1, 0), Vector3.ZERO)
	CORD_START = Vector3(cab.position.x + 0.02, cab.position.y + 0.025, cab.get_center().z)
	# --- геометрия трубки: стаканы, ось, ручка посередине ---
	var e_sum := Vector3.ZERO
	var e_n := 0
	var e_ymin := 99.0
	var m_sum := Vector3.ZERO
	var m_n := 0
	var m_ymin := 99.0
	var hverts := PackedVector3Array()
	for i in v.size():
		if find.call(i) != hs:
			continue
		var q := v[i]
		hverts.append(q)
		if q.x < hab.position.x + 0.06:
			e_sum += q; e_n += 1; e_ymin = minf(e_ymin, q.y)
		elif q.x > hab.end.x - 0.06:
			m_sum += q; m_n += 1; m_ymin = minf(m_ymin, q.y)
	var ec: Vector3 = e_sum / maxf(e_n, 1)
	var mc: Vector3 = m_sum / maxf(m_n, 1)
	# слуховой — тот стакан, что дальше от шнура
	var cc := cab.get_center()
	if Vector2(ec.x - cc.x, ec.z - cc.z).length() < Vector2(mc.x - cc.x, mc.z - cc.z).length():
		var tv := ec; ec = mc; mc = tv
		var ty := e_ymin; e_ymin = m_ymin; m_ymin = ty
	var ax := Vector3(mc.x - ec.x, 0.0, mc.z - ec.z).normalized()
	var side := ax.cross(Vector3.UP).normalized()
	var mid := (ec + mc) * 0.5
	var top := -99.0
	var bot := 99.0
	var smin := 99.0
	var smax := -99.0
	for q in hverts:
		var rel := q - mid
		if absf(rel.dot(ax)) > 0.012:
			continue
		top = maxf(top, q.y)
		bot = minf(bot, q.y)
		var s := rel.dot(side)
		smin = minf(smin, s)
		smax = maxf(smax, s)
	if top < bot:                                         # на всякий случай — по габаритам
		top = hab.end.y; bot = hab.end.y - 0.04; smin = -0.018; smax = 0.018
	var hcy := (top + bot) * 0.5
	var hc_pos := Vector3(mid.x, hcy, mid.z) + side * (smin + smax) * 0.5
	_hc = Transform3D(Basis(ax, Vector3.UP, side), hc_pos - c)
	_hh = (top - bot) * 0.5
	_hd = (smax - smin) * 0.5
	var half := Vector3(mc.x - ec.x, 0.0, mc.z - ec.z).length() * 0.5
	EARPIECE = _hc * Vector3(-half, e_ymin + 0.002 - hcy, 0.0)
	CORD_END = _hc * Vector3(half - 0.015, m_ymin + 0.006 - hcy, 0.0)
	var mat := mi.get_active_material(0)
	_cord_mat = mat
	var a_lo := arr.duplicate()
	a_lo[Mesh.ARRAY_INDEX] = lo
	var a_hi := arr.duplicate()
	a_hi[Mesh.ARRAY_INDEX] = hi
	var m_lo := ArrayMesh.new()
	m_lo.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a_lo)
	var m_hi := ArrayMesh.new()
	m_hi.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a_hi)
	var hsm := mi.duplicate() as MeshInstance3D               # копия — те же материалы
	for ch in hsm.get_children():
		ch.free()
	mi.mesh = m_lo
	mi.set_surface_override_material(0, mat)
	hsm.mesh = m_hi
	hsm.set_surface_override_material(0, mat)
	handset = Node3D.new()
	handset.name = "Handset"
	mi.get_parent().add_child(handset)
	handset.transform = mi.transform * Transform3D(Basis(), c)
	handset.add_child(hsm)
	hsm.transform = Transform3D(Basis(), -c)
	_rest_xf = handset.transform


func preload_body() -> void:
	ResourceLoader.load_threaded_request(BODY)


# ---------------- витой шнур ----------------
## Ось шнура — провисающая кривая от гнезда до трубки, вокруг неё — спираль (витки), трубочка сечением 6 граней.
func _build_cord() -> void:
	var a: Vector3 = handset.get_parent().global_transform * CORD_START
	var b: Vector3 = handset.global_transform * CORD_END
	var table_y: float = phone.global_position.y + 0.006
	var dist := a.distance_to(b)
	var sag: float = clampf(0.32 - dist * 0.45, 0.02, 0.3)       # короче расстояние — сильнее провис
	var n := 240
	var turns := 34.0
	var r_coil := 0.0065
	var r_tube := 0.0022
	var pts: Array[Vector3] = []
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(b, t) + Vector3.DOWN * sag * sin(PI * t)
		p.y = maxf(p.y, table_y + r_coil)
		pts.append(p)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_ring: Array = []
	var up := Vector3.UP
	for i in n + 1:
		var t := float(i) / n
		var tan: Vector3 = (pts[mini(i + 1, n)] - pts[maxi(i - 1, 0)]).normalized()
		if absf(tan.dot(up)) > 0.95:
			up = Vector3.RIGHT
		var nx := tan.cross(up).normalized()
		var ny := nx.cross(tan).normalized()
		var ang := t * turns * TAU
		var c: Vector3 = pts[i] + (nx * cos(ang) + ny * sin(ang)) * r_coil
		var ring: Array = []
		for k in 6:
			var a2 := k * TAU / 6.0
			var d := nx * cos(a2) + ny * sin(a2)
			ring.append([c + d * r_tube, d])
		if prev_ring.size() > 0:
			for k in 6:
				var k2 := (k + 1) % 6
				for vv in [prev_ring[k], ring[k], ring[k2], prev_ring[k], ring[k2], prev_ring[k2]]:
					st.set_normal(vv[1])
					st.add_vertex(vv[0])
		prev_ring = ring
	cord.mesh = st.commit()


# ---------------- тело и рука ----------------
static func _frame(a: Vector3, b: Vector3) -> Basis:
	var x := a.normalized()
	var y := (b - x * x.dot(b)).normalized()
	return Basis(x, y, x.cross(y))


static func _smooth(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


## Квадратичная кривая Безье a → (c) → b.
static func _bez(a: Vector3, c: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(c, t).lerp(c.lerp(b, t), t)


func _bone_world(i: int) -> Transform3D:
	var t: Transform3D = sk.global_transform * sk.get_bone_global_pose(i)
	return Transform3D(t.basis.orthonormalized(), t.origin)


func _spawn_body() -> void:
	var p: Node3D = L.player
	var res: Resource = ResourceLoader.load_threaded_get(BODY) if ResourceLoader.load_threaded_get_status(BODY) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE else load(BODY)
	body = (res as PackedScene).instantiate()
	var k: float = p.head.position.y / EYE
	body.scale = Vector3(k, k, k)
	L.add_child(body)
	_fwd = -p.global_basis.z
	_fwd.y = 0.0
	_fwd = _fwd.normalized()
	_right = _fwd.cross(Vector3.UP).normalized()
	# тело чуть сзади и ниже глаз: плечи не лезут в кадр, когда смотришь вниз на телефон
	_body0 = p.global_position - _fwd * 0.2 - Vector3(0, 0.05, 0)
	body.global_position = _body0
	body.global_rotation = Vector3(0, p.global_rotation.y + PI, 0)
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.layers = BODY_LAYER
		if m.name in ["Hair", "Eyes", "Eyelashes", "Tops", "Bottoms", "Shoes"]:   # видна только рука
			m.visible = false
	p.cam.cull_mask |= BODY_LAYER
	# свет: сам фонарь руку не освещает (в 20–30 см от него она — сплошное белое пятно);
	# руку, трубку и всё рядом освещает его широкий мягкий ореол — почти одинаково на любом расстоянии
	var fl: SpotLight3D = p.flash
	_flash_mask = fl.light_cull_mask
	fl.light_cull_mask &= ~BODY_LAYER
	_spill = SpotLight3D.new()
	_spill.light_color = fl.light_color
	_spill.spot_angle = 50.0
	_spill.spot_angle_attenuation = 1.0
	_spill.spot_range = 1.6
	_spill.spot_attenuation = 0.5
	_spill.light_energy = 0.0
	_spill.light_specular = 0.25
	_spill.light_volumetric_fog_energy = 0.0
	_spill.light_bake_mode = Light3D.BAKE_DISABLED
	fl.add_child(_spill)                                  # там же, куда светит фонарь; выключен фонарь — нет и ореола
	create_tween().tween_property(self, "_spill_k", 1.0, 0.6)
	sk = body.get_node("Skeleton3D")
	var ap: AnimationPlayer = body.get_node("AnimationPlayer")
	ap.play("mixamo_com")
	ap.seek(0.3, true)
	ap.pause()
	# оси кисти — по положению костей в покое: пальцы — к средней фаланге, ладонь — поперёк
	_hand_idx = sk.find_bone("mixamorig_LeftHand")
	var hr := sk.get_bone_global_rest(_hand_idx)
	var mr := sk.get_bone_global_rest(sk.find_bone("mixamorig_LeftHandMiddle1"))
	var ir := sk.get_bone_global_rest(sk.find_bone("mixamorig_LeftHandIndex1"))
	var pr := sk.get_bone_global_rest(sk.find_bone("mixamorig_LeftHandPinky1"))
	var ar := sk.get_bone_global_rest(sk.find_bone("mixamorig_LeftArm"))
	var fr := sk.get_bone_global_rest(sk.find_bone("mixamorig_LeftForeArm"))
	var f_sk := (mr.origin - hr.origin).normalized()
	var l_sk := ir.origin - pr.origin                    # к большому пальцу
	l_sk = (l_sk - f_sk * f_sk.dot(l_sk)).normalized()
	var p_sk := f_sk.cross(l_sk).normalized()            # левая кисть: наружу из ладони
	var hb := hr.basis.orthonormalized().inverse()
	_f_local = (hb * f_sk).normalized()
	_p_local = (hb * p_sk).normalized()
	var S := sk.global_transform.basis
	_palm_len = (S * (mr.origin - hr.origin)).length()
	_arm_len = (S * (fr.origin - ar.origin)).length() + (S * (hr.origin - fr.origin)).length()
	_shoulder0 = _bone_world(sk.find_bone("mixamorig_LeftArm")).origin
	var hand0 := _bone_world(_hand_idx)
	_hand_rest_local = body.global_transform.affine_inverse() * hand0.origin
	hand_goal = hand0
	_head0 = p.head.position
	target = Node3D.new()
	target.top_level = true
	L.add_child(target)
	target.global_position = hand0.origin
	pole = Node3D.new()
	pole.top_level = true
	L.add_child(pole)
	pole.global_position = _pole_pos()
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
	sk.skeleton_updated.connect(_on_skeleton_updated)


## Скелет посчитан (IK и кисть применены) — здесь кисть уже на своём месте в этом кадре.
## Трубка в руке ставится сюда же, поэтому никогда не отстаёт от ладони.
func _on_skeleton_updated() -> void:
	if not is_instance_valid(sk):
		return
	_hand_now = _bone_world(_hand_idx)
	_have_hand = true
	if _attached:
		handset.global_transform = _hand_now * _handset_in_hand
		_build_cord()


func _process(delta: float) -> void:
	if _dim_on:
		_update_light()
	if not is_instance_valid(body):
		return
	if _goal_fn.is_valid():
		_set_goal(_goal_fn.call())
	pole.global_position = _pole_pos()
	if _look_on:
		var p = L.player
		var aim: Vector3 = _look_pt - p.cam.global_position
		var want := clampf(atan2(aim.y, Vector2(aim.x, aim.z).length()), -1.35, 0.9)
		p.head.rotation.x = lerp_angle(p.head.rotation.x, want, 1.0 - exp(-5.0 * delta))


## Фонарь тем тусклее, чем ближе к телефону (телефон не выгорает в белое); ореол мерцает вместе с фонарём.
func _update_light() -> void:
	var p = L.player
	var fl: SpotLight3D = p.flash
	var d: float = fl.global_position.distance_to(phone.global_position)
	p.flash_energy = _flash_e0 * clampf(pow(d / FLASH_REF, fl.spot_attenuation), FLASH_MIN, 1.0)
	if is_instance_valid(_spill):
		var on: float = clampf(fl.light_energy / maxf(p.flash_energy, 0.001), 0.0, 1.0)
		_spill.light_energy = SPILL * _spill_k * on


func _set_goal(xf: Transform3D) -> void:
	hand_goal = xf
	if is_instance_valid(target):
		target.global_position = xf.origin


func _lean_offset(l: float) -> Vector3:
	return _fwd * l + Vector3.DOWN * l * LEAN_DROP


func _set_lean(v: float) -> void:
	_lean = v
	if is_instance_valid(body):
		body.global_position = _body0 + _lean_offset(v)
	L.player.head.position = _head0 + Vector3(0, -v * LEAN_DROP, -v)


## Насколько наклониться, чтобы запястье дотянулось до точки (рука почти прямая).
func _lean_needed(goal: Vector3) -> float:
	for i in 101:
		var l := i * 0.01
		if (_shoulder0 + _lean_offset(l)).distance_to(goal) <= _arm_len * 0.93:
			return l
	return 1.0


func _pole_pos() -> Vector3:
	var b: Vector3 = body.global_position
	var low := b + Vector3.UP * 0.8 - _right * 0.7 - _fwd * 0.15       # тянется к столу: локоть вниз-наружу
	var high := b + Vector3.UP * 1.3 - _right * 0.75 + _fwd * 0.35     # у уха: локоть наружу и чуть вперёд
	return low.lerp(high, _pole_k)


## Хват: где должна быть кисть (запястье и поворот), чтобы держать трубку, стоящую в hx.
## Ладонь сверху на ручке, костяшки — над дальней половиной ручки, пальцы обхватывают её сзади.
func _grip_world(hx: Transform3D) -> Transform3D:
	var cf := hx * _hc
	var cb := cf.basis.orthonormalized()
	var f := (cb * Vector3(0, -grip_tilt, -1).rotated(Vector3.UP, grip_yaw)).normalized()
	var pn := (cb * Vector3.DOWN).normalized()
	var mcp := cf * Vector3(0, _hh + 0.012, -_hd * 0.4)
	return Transform3D(_frame(f, pn) * _frame(_f_local, _p_local).inverse(), mcp - f * _palm_len)


## Где будет трубка у левого уха: слуховой стакан у уха, стаканы — к голове, микрофон — ко рту.
func _ear_xf() -> Transform3D:
	var cam: Camera3D = L.player.cam
	var cb := cam.global_basis.orthonormalized()
	var to_mouth := (-cb.y * 0.85 - cb.z * 0.45 + cb.x * 0.12).normalized()
	var bc := _frame(to_mouth, -cb.x)                 # канон: X — к микрофону, Y — от стаканов (наружу от головы)
	var bn := (bc * _hc.basis.orthonormalized().inverse()).orthonormalized()
	var ear: Vector3 = cam.global_position - cb.x * 0.095 - cb.y * 0.03 + cb.z * 0.075
	return Transform3D(bn, ear - bn * EARPIECE)


func _attach() -> void:
	_handset_in_hand = _hand_now.affine_inverse() * handset.global_transform
	_attached = true


## Где встать перед телефоном: как можно ближе, но так, чтобы капсула игрока не входила в стол
## (иначе физика рывком выталкивает её назад в конце подхода).
func _stand_spot(front: Vector3, shift := Vector3.ZERO) -> Vector3:
	var p: CharacterBody3D = L.player
	var y: float = p.global_position.y
	var base: Vector3 = handset.global_position + shift
	base.y = y
	var col: CollisionShape3D = null
	for c in p.get_children():
		if c is CollisionShape3D:
			col = c
			break
	if col == null or col.shape == null:
		return base + front * 0.44
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = col.shape
	q.collision_mask = p.collision_mask
	q.exclude = [p.get_rid()]
	var space := p.get_world_3d().direct_space_state
	var off: Vector3 = col.global_position - p.global_position + Vector3.UP * 0.04    # над полом
	for i in 60:
		var s := base + front * (0.44 + i * 0.02)
		q.transform = Transform3D(col.global_basis, s + off)
		if space.intersect_shape(q, 1).is_empty():
			return s + front * 0.02
	return base + front * 0.44


func _detach() -> void:
	_attached = false
	handset.transform = _rest_xf
	_build_cord()


## Дотянулась ли кисть до точки; если нет — наклоняется ещё (не больше max_lean).
func _settle(goal: Vector3, max_lean: float) -> void:
	var t := 0.0
	while t < 0.7:
		await get_tree().process_frame
		t += get_process_delta_time()
		if _hand_now.origin.distance_to(goal) < 0.012:
			return
		_set_lean(minf(_lean + 0.015, max_lean))


## То же, но смотрим на трубку в руке: встала ли она на рычаги.
func _settle_handset(home: Vector3, max_lean: float) -> void:
	var t := 0.0
	while t < 0.7:
		await get_tree().process_frame
		t += get_process_delta_time()
		if handset.global_position.distance_to(home) < 0.012:
			return
		_set_lean(minf(_lean + 0.015, max_lean))


func _aim(at: Vector3, sec: float) -> void:
	var p: Node3D = L.player
	var aim: Vector3 = at - p.cam.global_position
	var y0: float = p.rotation.y
	var y1: float = atan2(-aim.x, -aim.z)
	var x0: float = p.head.rotation.x
	var x1: float = clampf(atan2(aim.y, Vector2(aim.x, aim.z).length()), -1.2, 1.0)
	var tw := create_tween()
	tw.tween_method(func(k: float):
		p.rotation.y = lerp_angle(y0, y1, k)
		p.head.rotation.x = lerpf(x0, x1, k), 0.0, 1.0, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _sub(key: String, sec: float) -> void:
	L.msg_label.text = tr(key)
	L.msg_label.modulate.a = 1.0
	L.msg_timer = sec


## Звук «из трубки»: свой узкий шумный канал (шина Phone).
static func phone_bus() -> String:
	if AudioServer.get_bus_index("Phone") < 0:
		AudioServer.add_bus()
		var bi := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bi, "Phone")
		AudioServer.set_bus_send(bi, "Master")
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = 420.0
		AudioServer.add_bus_effect(bi, hp)
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 3200.0
		AudioServer.add_bus_effect(bi, lp)
		var d := AudioEffectDistortion.new()
		d.mode = AudioEffectDistortion.MODE_OVERDRIVE
		d.drive = 0.25
		d.post_gain = -2.0
		AudioServer.add_bus_effect(bi, d)
	return "Phone"


func _play_phone(st: AudioStream, db := 0.0) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	a.stream = st
	a.bus = phone_bus()
	a.volume_db = db
	L.add_child(a)
	a.finished.connect(a.queue_free)
	a.play()
	return a


# ---------------- сама сцена ----------------
func run() -> void:
	var p: CharacterBody3D = L.player
	var cam: Camera3D = p.cam
	L.busy = true
	p.frozen = true
	_flash_e0 = p.flash_energy
	_dim_on = true
	# подходит к телефону (стол может не пустить вплотную — тогда наклонится над ним)
	var front: Vector3 = phone.global_basis.z
	front.y = 0.0
	front = front.normalized()
	# встаёт так, чтобы левое плечо было напротив ручки трубки вдоль пальцев хвата:
	# рука идёт к трубке прямо, кисть не выворачивается в запястье
	var cb := (handset.global_transform * _hc).basis.orthonormalized()
	var fdir: Vector3 = cb * Vector3(0, 0, -1)
	fdir.y = 0.0
	var away: Vector3 = (-fdir).normalized().rotated(Vector3.UP, stand_yaw)
	var right: Vector3 = (-away).cross(Vector3.UP).normalized()
	var spot: Vector3 = _stand_spot(away, right * stand_side)
	var walk := create_tween()
	walk.tween_property(p, "global_position", spot, clampf(p.global_position.distance_to(spot) * 0.7, 0.25, 1.2)).set_trans(Tween.TRANS_SINE)
	var look: Vector3 = handset.global_position - spot - Vector3(0, p.head.position.y, 0)
	var tw0 := create_tween().set_parallel()
	tw0.tween_property(p, "rotation:y", p.rotation.y + wrapf(atan2(-look.x, -look.z) - p.rotation.y, -PI, PI), 0.6).set_trans(Tween.TRANS_SINE)
	tw0.tween_property(p.head, "rotation:x", clampf(atan2(look.y, Vector2(look.x, look.z).length()), -1.2, 1.0), 0.7).set_trans(Tween.TRANS_SINE)
	await walk.finished
	await _aim(handset.global_position + Vector3(0, -0.04, 0), 0.5)
	_spawn_body()
	await get_tree().process_frame
	await get_tree().process_frame
	var home: Transform3D = handset.global_transform
	var grab := _grip_world(home)
	var pre := grab
	pre.origin += Vector3.UP * 0.08 - _fwd * 0.05                 # над ручкой и чуть ближе к себе
	var need := _lean_needed(grab.origin)
	var start: Vector3 = _hand_now.origin if _have_hand else target.global_position
	_look_pt = home.origin
	_look_on = true
	# 1) тянется по дуге, кисть разворачивается ладонью вниз, тело наклоняется над столом
	var ctrl := start.lerp(pre.origin, 0.35)
	ctrl.y = maxf(start.y, pre.origin.y) + 0.18          # сначала вверх, потом вперёд над столом — не сквозь край
	var tw1 := create_tween().set_parallel()
	tw1.tween_method(func(k: float):
		_set_goal(Transform3D(grab.basis, _bez(start, ctrl, pre.origin, _smooth(k)))), 0.0, 1.0, 0.9)
	tw1.tween_property(self, "hand_w", 1.0, 0.65).set_delay(0.1)
	tw1.tween_method(_set_lean, 0.0, need, 0.9).set_trans(Tween.TRANS_SINE)
	await tw1.finished
	# 2) опускает ладонь на ручку
	var tw2 := create_tween()
	tw2.tween_method(func(k: float): _set_goal(Transform3D(grab.basis, pre.origin.lerp(grab.origin, _smooth(k)))), 0.0, 1.0, 0.3)
	await tw2.finished
	await _settle(grab.origin, need + 0.3)
	# 3) сжимает пальцы — трубка «прирастает» к ладони
	var g1 := create_tween()
	g1.tween_property(self, "grip", 1.0, 0.2)
	await g1.finished
	await get_tree().process_frame
	_attach()
	L._sfx("click", -6.0, 0.8)
	var lean_grab := _lean
	# 4) поднимает к уху: выпрямляется, голова чуть клонится к трубке
	_look_on = false
	var tw3 := create_tween().set_parallel()
	tw3.tween_method(func(k: float):
		var e := _smooth(k)
		var hx := home.interpolate_with(_ear_xf(), e)
		hx.origin += Vector3.UP * 0.07 * sin(PI * e)               # дуга, а не прямая
		_set_goal(hx * _handset_in_hand.affine_inverse())
		_pole_k = e, 0.0, 1.0, 1.1)
	tw3.tween_method(_set_lean, lean_grab, 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw3.tween_property(p.head, "rotation:x", -0.05, 1.0).set_trans(Tween.TRANS_SINE)
	tw3.tween_property(cam, "rotation:z", 0.07, 1.0).set_trans(Tween.TRANS_SINE)
	await tw3.finished
	_goal_fn = func() -> Transform3D: return _ear_xf() * _handset_in_hand.affine_inverse()
	# в трубке
	var line := _play_phone(L._stream("tv_static"), -26.0)
	await get_tree().create_timer(0.9).timeout
	var v1: AudioStream = preload("res://scripts/settings.gd").voice("PHONE_01")
	var d1 := 3.5
	if v1:
		_play_phone(v1, 2.0)
		d1 = v1.get_length()
	else:
		_play_phone(L._stream("phone_call"), 0.0)
	_sub("PHONE_01", d1)
	await get_tree().create_timer(d1 + 0.8).timeout
	if is_instance_valid(line):
		line.stop()
		line.queue_free()
	# 5) кладёт трубку обратно на рычаги: снова наклоняется к телефону
	_goal_fn = Callable()
	var from: Transform3D = handset.global_transform
	_look_pt = home.origin
	_look_on = true
	var tw4 := create_tween().set_parallel()
	tw4.tween_method(func(k: float):
		var e := _smooth(k)
		var hx := from.interpolate_with(home, e)
		hx.origin += Vector3.UP * 0.07 * sin(PI * e)
		_set_goal(hx * _handset_in_hand.affine_inverse())
		_pole_k = 1.0 - e, 0.0, 1.0, 1.0)
	tw4.tween_method(_set_lean, 0.0, lean_grab, 1.0).set_trans(Tween.TRANS_SINE)
	tw4.tween_property(cam, "rotation:z", 0.0, 0.9)
	await tw4.finished
	await _settle_handset(home.origin, lean_grab + 0.3)
	_detach()
	L._sfx("click", -4.0, 0.6)
	# 6) отпускает: пальцы разжимаются, рука уходит вверх-назад и вниз, выпрямляется
	var rel: Transform3D = _hand_now
	var lean_now := _lean
	var tw5 := create_tween().set_parallel()
	tw5.tween_property(self, "grip", 0.0, 0.15)
	tw5.tween_property(self, "hand_w", 0.0, 0.6).set_delay(0.2)
	tw5.tween_method(func(k: float):
		var low: Vector3 = body.global_transform * _hand_rest_local
		var lift := rel.origin + Vector3.UP * 0.08 - _fwd * 0.04
		var back := Vector3(low.x, lift.y + 0.02, low.z)       # назад над краем стола, потом вниз
		var pos: Vector3
		if k < 0.3:
			pos = rel.origin.lerp(lift, _smooth(k / 0.3))
		else:
			pos = _bez(lift, back, low, _smooth((k - 0.3) / 0.7))
		_set_goal(Transform3D(rel.basis, pos)), 0.0, 1.0, 0.95)
	tw5.tween_method(_set_lean, lean_now, 0.0, 0.95).set_trans(Tween.TRANS_SINE)
	tw5.tween_property(self, "_spill_k", 0.0, 0.5).set_delay(0.45)
	await tw5.finished
	_look_on = false
	_despawn()
	_build_cord()
	# фонарь плавно возвращается к прежней яркости
	_dim_on = false
	create_tween().tween_property(p, "flash_energy", _flash_e0, 1.2)
	# тишина… и за спиной
	await get_tree().create_timer(1.3).timeout
	var fw: Vector3 = -cam.global_basis.z
	fw.y = 0.0
	fw = fw.normalized()
	var behind: Vector3 = cam.global_position - fw * 0.7 + Vector3(0, -0.15, 0)
	var v2: AudioStream = preload("res://scripts/settings.gd").voice("PHONE_03")
	var d2 := 2.5
	var a := AudioStreamPlayer3D.new()
	a.stream = v2 if v2 else L._stream("giggle")
	a.unit_size = 2.0
	a.volume_db = 3.0 if v2 else -4.0
	L.add_child(a)
	a.global_position = behind
	a.finished.connect(a.queue_free)
	a.play()
	if v2:
		d2 = v2.get_length()
		_sub("PHONE_03", d2)
	L._sfx("heartbeat", -8.0, 1.1)
	p.frozen = false
	L.busy = false
	# оборачивается — никого
	var t := 0.0
	while t < d2 + 5.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		var to: Vector3 = behind - cam.global_position
		if p.forward().angle_to(to) < 0.7:
			p.flicker = 0.35
			L._sfx3d("whoosh", behind, -12.0, 0.8)
			return
	L._sfx3d("breath_dark", cam.global_position - fw * 0.3, -6.0, 0.95)


func _despawn() -> void:
	_attached = false
	_goal_fn = Callable()
	if is_instance_valid(body):
		body.queue_free()
	if is_instance_valid(target):
		target.queue_free()
	if is_instance_valid(pole):
		pole.queue_free()
	if is_instance_valid(_spill):
		_spill.queue_free()
	if _flash_mask != 0:
		(L.player.flash as SpotLight3D).light_cull_mask = _flash_mask
	L.player.head.position = _head0
	L.player.cam.cull_mask &= ~BODY_LAYER
