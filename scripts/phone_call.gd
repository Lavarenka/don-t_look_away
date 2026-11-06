extends Node
## Катсцена «звонок» в зале: своя рука тянется к телефону, снимает трубку, подносит к уху.
## В трубке — Аня (PHONE_01, звук «из трубки»). Кладёшь трубку — тишина… и тот же голос прямо за спиной:
## «Зачем ты положил трубку?» (PHONE_03). Управление возвращается: оборачиваешься — никого.
## Тело игрока — Remy (Mixamo, как в зеркале), видна только левая рука: голова скрыта, правая держит фонарь.
## Рука — TwoBoneIK3D к цели, пальцы сжимаются отдельным модификатором.
## Откатить: PHONE_SCENE = false в haunts.gd — будет прежний короткий звонок.

const BODY := "res://models/player/remy.fbx"
const EYE := 3.47               ## высота глаз Remy в её единицах (как в mirror.gd)
const GRIP_BONES := ["Index", "Middle", "Ring", "Pinky"]

var L: Node
var phone: Node3D
var handset: Node3D             ## трубка — отдельный узел (вырезана из модели телефона)
var _handset_home: Transform3D
var _home_node: Node3D
var body: Node3D
var sk: Skeleton3D
var target: Node3D
var pole: Node3D
var grip := 0.0                 ## 0 — ладонь раскрыта, 1 — сжата на трубке
var _fingers: SkeletonModifier3D


## Трубку отделяем от корпуса один раз: треугольники выше 12,5 см — это трубка (и верх шнура).
func prepare(level: Node, ph: Node3D) -> void:
	L = level
	phone = ph
	var mi := ph.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var lo := PackedInt32Array()
	var hi := PackedInt32Array()
	var c := Vector3.ZERO
	var n := 0
	for t in range(0, idx.size(), 3):
		var ce: Vector3 = (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
		var dst := hi if ce.y > 0.125 else lo
		dst.append(idx[t]); dst.append(idx[t + 1]); dst.append(idx[t + 2])
		if ce.y > 0.125:
			c += ce
			n += 1
	c /= maxf(n, 1)
	var mat := mi.mesh.surface_get_material(0)
	var a_lo := arr.duplicate()
	a_lo[Mesh.ARRAY_INDEX] = lo
	var a_hi := arr.duplicate()
	a_hi[Mesh.ARRAY_INDEX] = hi
	var m_lo := ArrayMesh.new()
	m_lo.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a_lo)
	m_lo.surface_set_material(0, mat)
	var m_hi := ArrayMesh.new()
	m_hi.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a_hi)
	m_hi.surface_set_material(0, mat)
	var hs := mi.duplicate() as MeshInstance3D       # копия сохраняет материалы-оверрайды
	for ch in hs.get_children():
		ch.free()
	mi.mesh = m_lo
	hs.mesh = m_hi
	handset = Node3D.new()
	handset.name = "Handset"
	_home_node = mi.get_parent()
	_home_node.add_child(handset)
	handset.transform = mi.transform.translated_local(c)
	handset.add_child(hs)
	hs.transform = Transform3D(Basis(), -c)
	_handset_home = handset.transform


## Тело грузим заранее, пока звонит телефон, — без подвисания в начале сцены.
func preload_body() -> void:
	ResourceLoader.load_threaded_request(BODY)


func handset_pos() -> Vector3:
	return handset.global_position


# ---------------- тело и рука ----------------
func _spawn_body() -> void:
	var p: Node3D = L.player
	var res: Resource = ResourceLoader.load_threaded_get(BODY) if ResourceLoader.load_threaded_get_status(BODY) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE else load(BODY)
	body = (res as PackedScene).instantiate()
	var k: float = p.head.position.y / EYE
	body.scale = Vector3(k, k, k)
	L.add_child(body)
	body.global_position = p.global_position
	body.global_rotation = Vector3(0, p.global_rotation.y + PI, 0)
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if m.name in ["Hair", "Eyes", "Eyelashes"]:
			m.visible = false
	sk = body.get_node("Skeleton3D")
	var ap: AnimationPlayer = body.get_node("AnimationPlayer")
	ap.play("mixamo_com")
	ap.seek(0.3, true)
	ap.pause()
	# цель и «локоть» для IK
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
	_fingers = preload("res://scripts/phone_hand.gd").new()
	_fingers.call("setup", self)
	sk.add_child(_fingers)
	# старт руки — у бедра (где она сейчас по анимации)
	target.global_position = _bone_pos("mixamorig_LeftHand")
	_update_pole()


func _bone_pos(n: String) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(n)).origin


func _update_pole() -> void:
	# локоть — вниз и наружу (влево от игрока)
	var p: Node3D = L.player
	pole.global_position = p.global_position + Vector3(0, 0.9, 0) - p.global_basis.x * 0.6 + p.global_basis.z * 0.1


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


## Точка у левого уха — относительно камеры.
func _ear() -> Vector3:
	var cam: Camera3D = L.player.cam
	return cam.global_position - cam.global_basis.x * 0.11 - cam.global_basis.y * 0.04 + cam.global_basis.z * 0.03


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
	L.busy = true
	p.frozen = true
	var cam: Camera3D = p.cam
	await _aim(handset_pos() + Vector3(0, -0.05, 0), 0.7)
	_spawn_body()
	await get_tree().process_frame
	# тянется к трубке
	await _move(handset_pos() + p.global_basis.z * 0.02 + Vector3(0, 0.02, 0), 0.9)
	var grip_tw := create_tween()
	grip_tw.tween_property(self, "grip", 1.0, 0.18)
	await grip_tw.finished
	L._sfx("click", -6.0, 0.8)
	var hand := BoneAttachment3D.new()
	hand.bone_name = "mixamorig_LeftHand"
	sk.add_child(hand)
	await get_tree().process_frame
	handset.reparent(hand, true)
	# подносит к уху, голова чуть клонится к трубке
	var tw := create_tween().set_parallel()
	tw.tween_property(p.head, "rotation:x", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cam, "rotation:z", -0.08, 0.9).set_trans(Tween.TRANS_SINE)
	await _move(_ear(), 0.9)
	# в трубке
	var line := _play_phone(L._stream("tv_static"), -24.0)            # шорох линии
	await get_tree().create_timer(1.0).timeout
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
	tw2.tween_property(cam, "rotation:z", 0.0, 0.8)
	tw2.tween_property(p.head, "rotation:x", -0.55, 0.8).set_trans(Tween.TRANS_SINE)
	var home: Vector3 = _home_node.global_transform * _handset_home.origin
	await _move(home + Vector3(0, 0.02, 0), 0.8)
	handset.reparent(_home_node, true)
	handset.transform = _handset_home
	L._sfx("click", -4.0, 0.6)
	var g2 := create_tween()
	g2.tween_property(self, "grip", 0.0, 0.15)
	await _move(_bone_rest_low(), 0.6)
	_despawn()
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


func _bone_rest_low() -> Vector3:
	var p: Node3D = L.player
	return p.global_position + Vector3(0, 0.85, 0) - p.global_basis.x * 0.25


func _despawn() -> void:
	if is_instance_valid(body):
		body.queue_free()
	if is_instance_valid(target):
		target.queue_free()
	if is_instance_valid(pole):
		pole.queue_free()
