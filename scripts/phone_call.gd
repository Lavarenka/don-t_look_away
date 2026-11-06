extends Node
## Катсцена «звонок» в зале: своя левая рука тянется к телефону, снимает трубку, подносит к уху.
## В трубке — Аня (PHONE_01, звук «из трубки»). Кладёшь трубку — тишина… и голос прямо за спиной:
## «Зачем ты положил трубку?» (PHONE_03). Управление возвращается: оборачиваешься — никого.
## Телефон — свой, кнопочный кремовый (tools/blender/make_phone_push.py): корпус и трубка отдельно,
## витой шнур между ними строится каждый кадр. Старая модель телефона прячется.
## Тело игрока — Remy (Mixamo, как в зеркале): видна только левая рука (голова и правая рука скрыты).
## Рука — TwoBoneIK3D к запястью, которое «привязано» к трубке; пальцы сжимаются модификатором.
## Откатить: PHONE_SCENE = false в haunts.gd — прежний телефон и короткий звонок.

const BODY := "res://models/player/remy.fbx"
const EYE := 3.47                       ## высота глаз Remy в её единицах (как в mirror.gd)
## Модель телефона — прежняя (models/vintage/phone.fbx). Она одним мешем, но из отдельных «островков»:
## трубка (самый крупный остров сверху) и витой шнур (справа) — их отделяем при загрузке.
var _rest_xf: Transform3D       ## трубка на рычагах (относительно родителя меша)
var CORD_START: Vector3         ## гнездо шнура на корпусе (в осях телефона)
var CORD_END: Vector3           ## куда шнур входит в трубку (в осях трубки)
var EARPIECE: Vector3           ## слуховой стакан (в осях трубки)
const BODY_LAYER := 1 << 19                     ## тело игрока — свой слой и своя подсветка

var L: Node
var phone: Node3D
var handset: Node3D
var cord: MeshInstance3D
var body: Node3D
var sk: Skeleton3D
var target: Node3D
var pole: Node3D
var grip := 0.0                         ## 0 — ладонь раскрыта, 1 — сжата на трубке
var _wrist_local := Vector3.ZERO        ## где запястье относительно трубки, пока её держишь
var _holding := false
var _spill: OmniLight3D


func prepare(level: Node, ph: Node3D) -> void:
	L = level
	phone = ph
	_split(ph.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D)
	cord = MeshInstance3D.new()
	cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cord.material_override = _cord_mat
	L.add_child(cord)
	_build_cord()


var _cord_mat: Material


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
	# трубка — крупный остров, целиком выше середины корпуса; шнур — крупный остров с краю
	var hs := -1
	var cd := -1
	for r in box:
		var ab: AABB = box[r]
		if cnt[r] < 300:
			continue
		if ab.size.x < 0.13 and ab.size.y > 0.08 and ab.position.x > 0.05:
			cd = r
		elif ab.size.x > 0.2 and (hs < 0 or ab.get_center().y > (box[hs] as AABB).get_center().y):
			hs = r                                            # трубка — самый высокий крупный остров
	var lo := PackedInt32Array()
	var hi := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var r: int = find.call(idx[t])
		var dst := hi if r == hs else lo
		if r == cd:
			continue                                          # свой шнур — живой, строится каждый кадр
		dst.append(idx[t]); dst.append(idx[t + 1]); dst.append(idx[t + 2])
	var c: Vector3 = (box[hs] as AABB).get_center()
	# концы шнура и слуховой стакан
	var cab: AABB = box[cd] if cd >= 0 else AABB(c + Vector3(0.12, -0.1, 0), Vector3.ZERO)
	var hab: AABB = box[hs]
	CORD_START = Vector3(cab.position.x + 0.02, cab.position.y + 0.025, cab.get_center().z)
	CORD_END = Vector3(hab.end.x - 0.02, hab.position.y + 0.01, c.z) - c
	EARPIECE = Vector3(hab.position.x + 0.03, hab.position.y + 0.012, c.z) - c
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


func _process(_d: float) -> void:
	if handset and (_holding or is_instance_valid(body)):
		_build_cord()
	if _holding and is_instance_valid(target):
		target.global_position = handset.global_transform * _wrist_local


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
				for v in [prev_ring[k], ring[k], ring[k2], prev_ring[k], ring[k2], prev_ring[k2]]:
					st.set_normal(v[1])
					st.add_vertex(v[0])
		prev_ring = ring
	cord.mesh = st.commit()


# ---------------- тело и рука ----------------
func _spawn_body() -> void:
	var p: Node3D = L.player
	var res: Resource = ResourceLoader.load_threaded_get(BODY) if ResourceLoader.load_threaded_get_status(BODY) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE else load(BODY)
	body = (res as PackedScene).instantiate()
	var k: float = p.head.position.y / EYE
	body.scale = Vector3(k, k, k)
	L.add_child(body)
	# тело чуть сзади и ниже глаз: грудь и плечи не лезут в кадр, когда смотришь вниз на телефон
	body.global_position = p.global_position + p.global_basis.z * 0.2 - Vector3(0, 0.05, 0)
	body.global_rotation = Vector3(0, p.global_rotation.y + PI, 0)
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.layers = BODY_LAYER
		if m.name in ["Hair", "Eyes", "Eyelashes"]:
			m.visible = false
	p.cam.cull_mask |= BODY_LAYER
	# мягкий отсвет фонаря на руку (свет только для тела — комнату не трогает)
	_spill = OmniLight3D.new()
	_spill.light_color = Color(1.0, 0.9, 0.78)
	_spill.light_energy = 0.8
	_spill.omni_range = 1.4
	_spill.light_cull_mask = BODY_LAYER
	_spill.light_volumetric_fog_energy = 0.0
	_spill.light_bake_mode = Light3D.BAKE_DISABLED
	p.cam.add_child(_spill)
	_spill.position = Vector3(0.15, 0.1, -0.1)
	sk = body.get_node("Skeleton3D")
	var ap: AnimationPlayer = body.get_node("AnimationPlayer")
	ap.play("mixamo_com")
	ap.seek(0.3, true)
	ap.pause()
	target = Node3D.new()
	target.top_level = true
	L.add_child(target)
	pole = Node3D.new()
	pole.top_level = true
	L.add_child(pole)
	var ik := TwoBoneIK3D.new()
	ik.setting_count = 1
	ik.set_root_bone_name(0, "mixamorig_LeftArm")
	ik.set_middle_bone_name(0, "mixamorig_LeftForeArm")
	ik.set_end_bone_name(0, "mixamorig_LeftHand")
	ik.set_use_virtual_end(0, false)
	sk.add_child(ik)
	ik.set_target_node(0, ik.get_path_to(target))
	ik.set_pole_node(0, ik.get_path_to(pole))
	var fingers: SkeletonModifier3D = preload("res://scripts/phone_hand.gd").new()
	fingers.call("setup", self)
	sk.add_child(fingers)
	target.global_position = _bone_pos("mixamorig_LeftHand")
	pole.global_position = p.global_position + Vector3(0, 0.8, 0) - p.global_basis.x * 0.7 + p.global_basis.z * 0.15


func _bone_pos(n: String) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(n)).origin


func _move(to: Vector3, sec: float) -> void:
	var tw := create_tween()
	tw.tween_property(target, "global_position", to, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


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


## Где будет трубка у левого уха: слуховой стакан у уха, чашки к голове, микрофон — ко рту.
func _ear_xf() -> Transform3D:
	var cam: Camera3D = L.player.cam
	var cb := cam.global_basis
	var x_axis: Vector3 = (cb.y * 0.92 + cb.z * 0.25 + cb.x * 0.15).normalized() * signf(EARPIECE.x)   # к стакану у уха — вверх
	var y_axis: Vector3 = -cb.x                                                    # чашки — к голове (вправо)
	y_axis = (y_axis - x_axis * x_axis.dot(y_axis)).normalized()
	var bas := Basis(x_axis, y_axis, x_axis.cross(y_axis))
	var ear: Vector3 = cam.global_position - cb.x * 0.085 - cb.y * 0.03 + cb.z * 0.04
	return Transform3D(bas, ear - bas * EARPIECE)


func _handset_move(from: Transform3D, to: Transform3D, sec: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var e := k * k * (3.0 - 2.0 * k)
		var xf := from.interpolate_with(to, e)
		xf.origin += Vector3.UP * 0.08 * sin(PI * e)          # дуга, а не прямая
		handset.global_transform = xf, 0.0, 1.0, sec)
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
	# подходит вплотную к телефону — иначе рука не дотянется (стоять — в полуметре перед трубкой)
	var front: Vector3 = phone.global_basis.z
	front.y = 0.0
	front = front.normalized()
	var spot: Vector3 = handset.global_position + front * 0.5
	spot.y = p.global_position.y
	var walk := create_tween()
	walk.tween_property(p, "global_position", spot, clampf(p.global_position.distance_to(spot) * 0.7, 0.25, 1.2)).set_trans(Tween.TRANS_SINE)
	# пока подходит — поворачивается к телефону; когда встал — смотрит на трубку
	var look: Vector3 = handset.global_position - spot - Vector3(0, p.head.position.y, 0)
	var tw0 := create_tween().set_parallel()
	tw0.tween_property(p, "rotation:y", p.rotation.y + wrapf(atan2(-look.x, -look.z) - p.rotation.y, -PI, PI), 0.6).set_trans(Tween.TRANS_SINE)
	tw0.tween_property(p.head, "rotation:x", clampf(atan2(look.y, Vector2(look.x, look.z).length()), -1.2, 1.0), 0.7).set_trans(Tween.TRANS_SINE)
	await walk.finished
	await _aim(handset.global_position + Vector3(0, -0.04, 0), 0.5)
	_spawn_body()
	await get_tree().process_frame
	# тянется к трубке: запястье — над ручкой, чуть ближе к себе
	var home: Transform3D = handset.global_transform
	# ладонь ложится на середину ручки сверху: запястье — на длину кисти ближе к плечу
	var shoulder: Vector3 = _bone_pos("mixamorig_LeftArm")
	var dir: Vector3 = (handset.global_position - shoulder)
	dir.y *= 0.35
	dir = dir.normalized()
	var grab: Vector3 = handset.global_position - dir * 0.085 + Vector3.UP * 0.05
	await _move(grab, 1.0)
	var g1 := create_tween()
	g1.tween_property(self, "grip", 1.0, 0.2)
	await g1.finished
	L._sfx("click", -6.0, 0.8)
	_wrist_local = handset.global_transform.affine_inverse() * target.global_position
	_holding = true
	# поднимает к уху, голова чуть клонится к трубке
	var tw := create_tween().set_parallel()
	tw.tween_property(p.head, "rotation:x", -0.05, 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cam, "rotation:z", 0.07, 1.0).set_trans(Tween.TRANS_SINE)
	await _handset_move(home, _ear_xf(), 1.0)
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
	# кладёт трубку
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(cam, "rotation:z", 0.0, 0.9)
	tw2.tween_property(p.head, "rotation:x", -0.6, 0.9).set_trans(Tween.TRANS_SINE)
	await _handset_move(handset.global_transform, home, 0.9)
	_holding = false
	handset.transform = _rest_xf
	L._sfx("click", -4.0, 0.6)
	var g2 := create_tween()
	g2.tween_property(self, "grip", 0.0, 0.15)
	await _move(p.global_position + Vector3(0, 0.8, 0) - p.global_basis.x * 0.25, 0.6)
	_despawn()
	_build_cord()
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
	if is_instance_valid(body):
		body.queue_free()
	if is_instance_valid(target):
		target.queue_free()
	if is_instance_valid(pole):
		pole.queue_free()
	if is_instance_valid(_spill):
		_spill.queue_free()
	L.player.cam.cull_mask &= ~BODY_LAYER
