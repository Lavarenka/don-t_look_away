extends Node
## Ванная второго этажа (модель «The Bathroom (Free)», Evan, CC BY).
##
## Цепочка загадок:
## 1. Дверь отпирается сама, когда игрок подёргал несколько дверей холла.
## 2. Горячая вода в раковине → пар → зеркало запотевает, на нём пальцем написан код.
##    Код каждый раз новый. Написан «изнутри» — задом наперёд (в лоб читается наоборот):
##    догадаться, что надпись зеркальная, или посмотреть через осколок (Q).
##    Если долго смотреть в запотевшее зеркало — за туманом проступает женщина, и гаснет свет.
## 3. Кодовый замок на шкафчике под раковиной → дедов проволочный крюк.
##    Неверный код — пугалка (трубы, стук из шкафчика, силуэт в зеркале).
## 4. Крюком вытащить пробку из ванны с чёрной водой → вода уходит, из ванны поднимается Аня (скример).
## 5. На дне — ключ с биркой «Вера»: от спальни бабушки.

const SPIRIT = preload("res://scripts/spirit.gd")
const Y2 := -3.4
const O := Vector3(-1.56, -3.4, -39.33)          ## куда поставлена модель ванной
const MIRROR_LAYER := 1 << 10
const REAL_LAYER := 1 << 11
const NO_PROBE_LAYER := 1 << 12                ## отражение пробы ванной сюда не ложится (стекло окна)
const TAP := Vector3(-0.46, Y2 + 1.0, -38.62)     ## кран раковины
const MIRROR_C := Vector3(-0.455, Y2 + 1.5, -38.57)
const LOCK := Vector3(-3.035, Y2 + 0.6, -40.23)    ## замок висит на ящике тумбы у западной стены
const DRAWER := Vector3(-3.058, Y2 + 0.61, -40.23)  ## центр лицевой панели ящика (смотрит в +X)
const TUB := Vector3(0.285, Y2, -40.95)          ## центр ванны (на уровне пола)
const WATER_TOP := 0.53
const WATER_LOW := 0.2
const INNER_HINGE := Vector3(-1.685, Y2, -38.47)  ## петля двери между тамбуром и ванной
const INNER_C := Vector3(-2.115, Y2 + 1.0, -38.455)
const INNER_CLOSED := 0.733                       ## поворот петли: закрыта
const INNER_OPEN := -0.84                         ## открыта внутрь ванной
const SINK_CANDLE := Vector3(-0.89, Y2 + 1.13, -39.195)

var L: Node
var room: Node3D
var unlocked := false
var running := false
var run_t := 0.0
var fog := 0.0
var fog_done := false
var ghost_done := false
var look_t := 0.0
var lock_open := false
var has_hook := false
var drained := false
var water_m: MeshInstance3D          ## та же вода «в стекле»: прозрачная — видно дно
var hair: MeshInstance3D             ## на дне — клубок длинных чёрных волос (видно только в осколке)
var hair_eye: Node3D                 ## из глубины волос иногда открывается глаз
var drowned_key: Node3D              ## ключ запутался в волосах
var _shard_seen := false
var _move_t := 12.0                  ## когда под водой снова что-то шевельнётся
var key_taken := false
var has_bedkey := false
var exit_scare := 0       ## 0 — ещё нет, 1 — дверь захлопнется, 4 — захлопывается, 2 — ждёт за дверью, 3 — было
var mistakes := 0
var digits := [0, 0, 0]
var sel := 0
var next_drip := 2.0

var door_pivot: Node3D
var door_angle := 1.6
var inner_pivot: Node3D
var water: MeshInstance3D
var stream: MeshInstance3D
var steam: GPUParticles3D
var water_snd: AudioStreamPlayer3D
var fog_real: ShaderMaterial
var fog_true: ShaderMaterial
var CODE := []           ## код замка — каждый раз новый (написан на запотевшем зеркале)
var fig_mat: StandardMaterial3D
var candle_light: OmniLight3D
var candle_flame: MeshInstance3D
var key_mesh: Node3D
var drawer: Node3D
var drawer_hole: MeshInstance3D
var hook: Node3D
var panel: PanelContainer
var digit_labels: Array[Label] = []


func setup(level: Node) -> void:
	L = level
	_build_room()
	_build_door()
	_build_props()
	_build_fog()
	_build_panel()
	for t in [["b_tap", TAP, 0.3, 1.8], ["b_mirror", MIRROR_C, 0.35, 2.2], ["b_lock", LOCK, 0.3, 1.6],
			["b_tub", TUB + Vector3(0, 0.75, 0), 0.5, 2.0], ["b_key", TUB + Vector3(0, 0.3, 0), 0.4, 2.2]]:
		L.targets.append({"id": t[0], "pos": t[1], "th": t[2], "dist": t[3]})
	L.extra_hints["b_tap"] = "B_TAP_H"
	L.extra_hints["b_mirror"] = "B_MIRROR_H"
	L.extra_hints["b_lock"] = "B_LOCK_H"
	L.extra_hints["b_key"] = "B_KEY_H"
	L.extra_hints["b_tub"] = "B_TUB_H"


# ---------------- комната ----------------
func _build_room() -> void:
	room = load("res://models/bathroom/bathroom.glb").instantiate()
	room.position = O
	L.add_child(room)
	var skip := ["Fabric", "Cup", "Cap_", "Candle", "Hook", "Pic", "Floor", "Selling", "Curtain", "Mirror"]
	for n in room.find_children("*", "Node3D", true, false):
		if n.get_parent().name == "RootNode" and not "_00" in n.name:
			n.visible = false          # в файле лежит ещё и «набор» отдельных деталей — он не нужен
	for mi in room.find_children("*", "MeshInstance3D", true, false):
		var host: Node = mi.get_parent()
		if not host.visible:
			continue
		var solid := true
		for s in skip:
			if String(host.name).begins_with(s):
				solid = false
		if solid:
			mi.create_trimesh_collision()
		# прозрачные материалы пака (двери, ткани, стекло) — без сортировочных артефактов
		var m: Material = mi.get_active_material(0)
		if m is BaseMaterial3D and m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and not String(host.name).begins_with("Wall_corner_shelf"):
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	# свет: свеча на раковине и луна в окне над ванной
	candle_flame = MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.012
	fm.height = 0.035
	candle_flame.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.75, 0.4)
	candle_flame.material_override = fmat
	candle_flame.position = SINK_CANDLE
	L.add_child(candle_flame)
	candle_light = OmniLight3D.new()
	candle_light.light_color = Color(1.0, 0.62, 0.3)
	candle_light.light_energy = 0.5
	candle_light.omni_range = 3.2
	candle_light.shadow_enabled = true
	candle_light.position = SINK_CANDLE + Vector3(0, 0.08, -0.05)
	L.add_child(candle_light)
	var moon := SpotLight3D.new()
	moon.light_color = Color(0.5, 0.6, 0.95)
	moon.light_energy = 3.0
	moon.spot_range = 7.0
	moon.spot_angle = 26.0
	moon.shadow_enabled = true
	moon.position = Vector3(2.4, Y2 + 2.3, -41.1)
	L.add_child(moon)
	moon.look_at(Vector3(-1.2, Y2, -40.4))
	var night := MeshInstance3D.new()
	var nq := QuadMesh.new()
	nq.size = Vector2(3.4, 3.4)        # с запасом: под углом из окна не видно, что за ним
	night.mesh = nq
	var nm := StandardMaterial3D.new()
	nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nm.albedo_color = Color(0.03, 0.045, 0.08)
	night.material_override = nm
	night.position = Vector3(1.45, Y2 + 1.4, -41.07)
	night.rotation.y = -PI / 2
	night.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF     # лунный свет проходит в окно
	L.add_child(night)
	# вплотную за стеклом (внутри толщины стены) — ещё одна «ночь»: под любым углом за окном только темнота
	var night2 := MeshInstance3D.new()
	var nq2 := QuadMesh.new()
	nq2.size = Vector2(1.6, 1.75)
	night2.mesh = nq2
	night2.material_override = nm
	night2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	night2.position = Vector3(1.235, Y2 + 1.55, -41.06)
	night2.rotation.y = -PI / 2
	L.add_child(night2)
	nm.cull_mode = BaseMaterial3D.CULL_DISABLED
	# два окна в западной стене смотрят прямо в стены комнаты Веры — за ними тоже только ночь
	for wz in [-40.27, -37.70]:
		var nw := MeshInstance3D.new()
		var nwq := QuadMesh.new()
		nwq.size = Vector2(1.45, 1.6)
		nw.mesh = nwq
		nw.material_override = nm
		nw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nw.position = Vector3(-4.12, Y2 + 1.55, wz)
		nw.rotation.y = PI / 2
		L.add_child(nw)
	# стекло окон не берёт отражение из пробы ванной (на высоком качестве в нём «висела» чужая комната)
	for gname in ["Wall_Window_001_Door and windows_0", "Wall_Window_002_Door and windows_0", "Wall_Window_003_Door and windows_0"]:
		_matte_glass(room.find_child(gname, true, false) as GeometryInstance3D)


func _matte_glass(glass: GeometryInstance3D) -> void:
	if glass:
		glass.layers |= NO_PROBE_LAYER
		# и вообще ничего не отражает: у пака стекло «металлическое», и на высоком качестве
		# в нём отражалась (через тонкие стены) соседняя спальня
		var gm := (glass as MeshInstance3D).get_active_material(0).duplicate() as BaseMaterial3D
		gm.metallic = 0.0
		gm.metallic_texture = null
		gm.roughness = 0.7
		gm.roughness_texture = null
		gm.metallic_specular = 0.15
		(glass as MeshInstance3D).set_surface_override_material(0, gm)


## Дверь из холла: полотно из модуля стены — на петлю.
func _build_door() -> void:
	var leaf: Node3D = L.get_node("F2DoorBath/small_door")
	door_pivot = Node3D.new()
	L.add_child(door_pivot)
	door_pivot.global_position = Vector3(leaf.global_position.x, Y2, leaf.global_position.z)
	leaf.reparent(door_pivot, true)
	var c := Vector3.ZERO
	var meshes := leaf.find_children("*", "MeshInstance3D", true, false)
	if leaf is MeshInstance3D:
		meshes.append(leaf)
	for mi in meshes:
		c = (mi.global_transform * mi.get_aabb()).get_center()
	var body := StaticBody3D.new()
	var sh := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.87, 1.87, 0.08)
	sh.shape = box
	body.add_child(sh)
	door_pivot.add_child(body)
	body.position = Vector3(c.x - door_pivot.global_position.x, 0.935, 0)
	door_angle = -1.6 if c.x < door_pivot.global_position.x else 1.6   # открывается внутрь ванной
	# табличка «ВАННАЯ» висит на самой двери (иначе остаётся в воздухе, когда дверь открыта)
	for n in L.get_children():
		if n is Node3D and n.get_child_count() > 0 and n.get_child(n.get_child_count() - 1) is Label3D \
				and (n.get_child(n.get_child_count() - 1) as Label3D).text == tr("F2_SIGN_BATH"):
			n.reparent(leaf, true)
	# внутренняя дверь (из модели) — на петлю, сначала закрыта
	var inner: Node3D = room.find_child("Door_001", true, false)
	if inner:
		inner_pivot = Node3D.new()
		L.add_child(inner_pivot)
		inner_pivot.global_position = INNER_HINGE
		inner.reparent(inner_pivot, true)
		inner_pivot.rotation.y = INNER_CLOSED


# ---------------- вода, кран, замок ----------------
func _build_props() -> void:
	# чёрная вода в ванне
	water = MeshInstance3D.new()
	var pmw := PlaneMesh.new()
	pmw.size = Vector2(0.7, 1.5)
	water.mesh = pmw
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/murky_water.gdshader")
	for k in [["ripple_a", 11, 0.9], ["ripple_b", 29, 1.6]]:
		var nt := NoiseTexture2D.new()
		nt.width = 256
		nt.height = 256
		nt.seamless = true
		nt.as_normal_map = true
		nt.bump_strength = 10.0
		var fn := FastNoiseLite.new()
		fn.seed = k[1]
		fn.frequency = 0.02 * k[2]
		fn.fractal_octaves = 3
		nt.noise = fn
		wm.set_shader_parameter(k[0], nt)
	# отражения комнаты в воде и в зеркале
	var probe := ReflectionProbe.new()
	probe.size = Vector3(5.4, 2.8, 5.5)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.reflection_mask = 0xFFFFF & ~NO_PROBE_LAYER
	probe.position = Vector3(-1.43, Y2 + 1.4, -39.55)
	L.add_child(probe)
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = TUB + Vector3(0, WATER_TOP, 0)
	water.layers = REAL_LAYER
	L.add_child(water)
	# в осколке вода прозрачная: на дне лежит она, а рядом ключ на ленточке
	water_m = MeshInstance3D.new()
	water_m.mesh = pmw
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.05, 0.06, 0.04, 0.45)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.roughness = 0.1
	water_m.material_override = mm
	water_m.layers = MIRROR_LAYER
	water_m.scale = Vector3(0.95, 1, 0.97)
	water_m.position = water.position
	L.add_child(water_m)
	_build_hair()
	drowned_key = load("res://models/props/key_vera.glb").instantiate()
	drowned_key.visible = true
	for mi in drowned_key.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = MIRROR_LAYER
	for li in drowned_key.find_children("*", "Light3D", true, false):
		li.queue_free()
	L.add_child(drowned_key)
	drowned_key.global_position = TUB + Vector3(0.05, 0.19, 0.2)
	drowned_key.rotation = Vector3(0, 0.7, 0)
	# струя из крана
	stream = MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.006
	sm.bottom_radius = 0.009
	sm.height = 0.16
	stream.mesh = sm
	var stm := StandardMaterial3D.new()
	stm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stm.albedo_color = Color(0.8, 0.85, 0.9, 0.45)
	stm.roughness = 0.05
	stream.material_override = stm
	stream.position = TAP + Vector3(0, -0.1, -0.1)
	stream.visible = false
	L.add_child(stream)
	# пар над раковиной
	steam = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.18, 0.02, 0.12)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 15.0
	pm.initial_velocity_min = 0.08
	pm.initial_velocity_max = 0.18
	pm.gravity = Vector3(0, 0.02, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	var curve := CurveTexture.new()
	var cv := Curve.new()
	cv.add_point(Vector2(0, 0))
	cv.add_point(Vector2(0.3, 1))
	cv.add_point(Vector2(1, 0))
	curve.curve = cv
	pm.alpha_curve = curve
	var qm := QuadMesh.new()
	qm.size = Vector2(0.25, 0.25)
	var pmat := StandardMaterial3D.new()
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pmat.vertex_color_use_as_albedo = true
	pmat.albedo_color = Color(0.85, 0.88, 0.9, 0.12)
	pmat.albedo_texture = _soft_dot()
	qm.material = pmat
	steam.amount = 60
	steam.lifetime = 3.0
	steam.process_material = pm
	steam.draw_pass_1 = qm
	steam.position = TAP + Vector3(0, -0.12, -0.25)
	steam.emitting = false
	L.add_child(steam)
	water_snd = AudioStreamPlayer3D.new()
	var ws: AudioStreamWAV = load("res://audio/water_run.wav")
	ws.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ws.loop_end = int(ws.get_length() * ws.mix_rate)
	water_snd.stream = ws
	water_snd.volume_db = -6.0
	water_snd.position = TAP
	L.add_child(water_snd)
	_build_drawer()
	# кодовый замок на ящике тумбы — модель из Blender (корпус, дужка «Shackle», три колёсика с цифрами)
	var lock: Node3D = load("res://models/props/padlock.glb").instantiate()
	lock.position = LOCK
	lock.rotation.y = -PI / 2
	lock.name = "BathLock"
	L.add_child(lock)


## Выдвижной ящик тумбы: лицевая панель — снимок настоящей панели модели (textures/vanity_drawer.jpg),
## за ней «дыра» (видна, когда ящик выдвинут), внутри — дедов проволочный крюк на тряпице.
func _build_drawer() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.2, 0.12, 0.07)
	wood.roughness = 0.8
	drawer_hole = MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(0.93, 0.12)
	drawer_hole.mesh = hq
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.01, 0.008, 0.006)
	drawer_hole.material_override = hm
	drawer_hole.position = DRAWER + Vector3(0.001, 0, 0)
	drawer_hole.rotation.y = PI / 2
	drawer_hole.visible = false
	L.add_child(drawer_hole)
	drawer = Node3D.new()
	drawer.position = DRAWER + Vector3(0.002, 0, 0)
	L.add_child(drawer)
	var front := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(0.952, 0.132)
	front.mesh = fq
	var fmat := StandardMaterial3D.new()
	fmat.albedo_texture = load("res://textures/vanity_drawer.jpg")
	fmat.roughness = 0.75
	front.material_override = fmat
	front.rotation.y = PI / 2
	drawer.add_child(front)
	# короб ящика: дно, бока, задняя стенка (уходят внутрь тумбы, в −X)
	for b in [[Vector3(0.38, 0.012, 0.9), Vector3(-0.2, -0.055, 0)], [Vector3(0.38, 0.11, 0.015), Vector3(-0.2, 0, 0.44)],
			[Vector3(0.38, 0.11, 0.015), Vector3(-0.2, 0, -0.44)], [Vector3(0.015, 0.11, 0.9), Vector3(-0.39, 0, 0)],
			[Vector3(0.015, 0.125, 0.94), Vector3(-0.008, 0, 0)]]:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b[0]
		m.mesh = bm
		m.position = b[1]
		m.material_override = wood
		drawer.add_child(m)
	# тряпица и крюк внутри
	var cloth := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.28, 0.004, 0.5)
	cloth.mesh = cm
	var clm := StandardMaterial3D.new()
	clm.albedo_color = Color(0.3, 0.26, 0.2)
	clm.roughness = 1.0
	cloth.material_override = clm
	cloth.position = Vector3(-0.18, -0.047, 0.05)
	cloth.rotation.y = 0.12
	drawer.add_child(cloth)
	hook = Node3D.new()
	hook.position = Vector3(-0.17, -0.038, 0.02)
	hook.rotation.y = PI / 2 + 0.25
	drawer.add_child(hook)
	hook.add_child(load("res://models/props/hook.glb").instantiate())   # гнутая проволока из Blender


## Код верный: катсцена — замок падает, ящик выезжает, Миша берёт крюк.
func _open_drawer() -> void:
	var p = L.player
	L.busy = true
	p.frozen = true
	p.set_physics_process(false)
	p.velocity = Vector3.ZERO
	L.hint_label.text = ""
	L.floor2._letterbox(true)
	# встать перед тумбой и посмотреть вниз, на ящик
	await L.floor2._move(Vector3(DRAWER.x + 0.95, Y2 + 0.02, DRAWER.z), PI / 2, -0.88, 1.1)
	var lock: Node3D = L.get_node("BathLock")
	var sh := lock.get_node("Shackle") as Node3D
	L._sfx3d("clink", LOCK, -2.0, 0.8)
	create_tween().tween_property(sh, "position:y", 0.075, 0.2)
	await get_tree().create_timer(0.45).timeout
	# замок соскакивает и падает на пол
	var fall := create_tween().set_parallel()
	fall.tween_property(lock, "position", Vector3(LOCK.x + 0.12, Y2 + 0.03, LOCK.z + 0.05), 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fall.tween_property(lock, "rotation", Vector3(1.4, -PI / 2 + 0.6, 0.3), 0.4)
	await fall.finished
	L._sfx3d("clink", lock.global_position, 0.0, 0.6)
	await get_tree().create_timer(0.5).timeout
	# ящик со скрипом выезжает
	drawer_hole.visible = true
	L._sfx3d("drawer", DRAWER, -2.0, 0.95)
	L._sfx3d("creak", DRAWER, -8.0, 1.7)
	var out := create_tween()
	out.tween_property(drawer, "position:x", DRAWER.x + 0.33, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await out.finished
	await get_tree().create_timer(0.7).timeout
	# крюк поднимается к камере — «взял»
	var cam_pos: Vector3 = p.cam.global_position + p.forward() * 0.35 + Vector3(0, -0.15, 0)
	var take := create_tween().set_parallel()
	take.tween_property(hook, "global_position", cam_pos, 0.7).set_trans(Tween.TRANS_SINE)
	take.tween_property(hook, "rotation:x", 0.6, 0.7)
	await take.finished
	hook.visible = false
	L.inv.add("hook", hook)
	L._sfx("pickup", -4.0, 0.8)
	L._say("B_LOCK_OK", 4.0)
	L._set_objective("B_OBJ3")
	await get_tree().create_timer(0.6).timeout
	L.floor2._letterbox(false)
	p.set_physics_process(true)
	p.frozen = false
	L.busy = false


func _soft_dot() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
	return ImageTexture.create_from_image(img)


# ---------------- запотевшее зеркало ----------------
func _build_fog() -> void:
	var en := TranslationServer.get_locale().begins_with("en")
	var suf := "_en" if en else ""
	var mats := []
	# случайный код из цифр, которые в зеркальном виде не совпадают с обычным
	var pool := [2, 3, 4, 5, 6, 7, 9]
	for i in 3:
		CODE.append(pool[randi() % pool.size()])
	for spec in [[true, REAL_LAYER], [false, MIRROR_LAYER]]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.78, 0.61)
		q.mesh = qm
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/fog.gdshader")
		m.set_shader_parameter("base_tex", load("res://textures/fog_base.png".replace(".png", suf + ".png")))   # для английского — подпись ANYA
		m.set_shader_parameter("digits", load("res://textures/fog_digits.png"))
		m.set_shader_parameter("code", Vector3(CODE[0], CODE[1], CODE[2]))
		m.set_shader_parameter("mirrored", spec[0])
		q.material_override = m
		q.layers = spec[1]
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.position = MIRROR_C + Vector3(0, 0, -0.012)
		q.rotation.y = PI
		L.add_child(q)
		mats.append(m)
	fog_real = mats[0]
	fog_true = mats[1]
	# силуэт «за туманом»
	var f := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(0.36, 0.56)
	f.mesh = fq
	fig_mat = StandardMaterial3D.new()
	fig_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fig_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fig_mat.albedo_texture = load("res://textures/fog_figure.png")
	fig_mat.albedo_color = Color(1, 1, 1, 0)
	f.material_override = fig_mat
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.position = MIRROR_C + Vector3(0.12, -0.02, -0.006)
	f.rotation.y = PI
	L.add_child(f)


# ---------------- панель кодового замка ----------------
func _build_panel() -> void:
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.045, 0.04, 0.92)
	sb.border_color = Color(0.45, 0.35, 0.18)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.visible = false
	L.hud.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var title := Label.new()
	title.text = tr("B_LOCK_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.6))
	v.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	v.add_child(row)
	for i in 3:
		var col := VBoxContainer.new()
		row.add_child(col)
		var up := _btn("▲", func(): _spin(i, 1))
		col.add_child(up)
		var l := Label.new()
		l.text = "0"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 56)
		l.custom_minimum_size = Vector2(64, 0)
		col.add_child(l)
		digit_labels.append(l)
		col.add_child(_btn("▼", func(): _spin(i, -1)))
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 20)
	v.add_child(brow)
	brow.add_child(_btn(tr("B_LOCK_TRY"), _try_code))
	brow.add_child(_btn(tr("MENU_BACK"), _close_panel))
	var hint := Label.new()
	hint.text = tr("B_LOCK_KEYS")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.55, 0.52, 0.47))
	v.add_child(hint)


func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b


func _spin(i: int, d: int) -> void:
	sel = i
	digits[i] = (digits[i] + d + 10) % 10
	L._sfx("click", -14.0, 1.8)
	_show_digits()


func _show_digits() -> void:
	for i in 3:
		digit_labels[i].text = str(digits[i])
		digit_labels[i].add_theme_color_override("font_color", Color(1, 0.9, 0.6) if i == sel else Color(0.7, 0.66, 0.58))


func _open_panel() -> void:
	panel.visible = true
	L.busy = true
	L.player.frozen = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_digits()
	await get_tree().process_frame
	panel.position = (L.get_viewport().get_visible_rect().size - panel.size) / 2


func _close_panel() -> void:
	panel.visible = false
	L.busy = false
	L.player.frozen = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(e: InputEvent) -> void:
	if not panel.visible or not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.physical_keycode:
		KEY_A, KEY_LEFT:
			sel = (sel + 2) % 3
			_show_digits()
		KEY_D, KEY_RIGHT:
			sel = (sel + 1) % 3
			_show_digits()
		KEY_W, KEY_UP:
			_spin(sel, 1)
		KEY_S, KEY_DOWN:
			_spin(sel, -1)
		KEY_E, KEY_ENTER, KEY_SPACE:
			_try_code()
		KEY_ESCAPE, KEY_Q, KEY_BACKSPACE:
			_close_panel()
		_:
			return
	get_viewport().set_input_as_handled()


func _try_code() -> void:
	_close_panel()
	if digits == CODE:
		lock_open = true
		has_hook = true
		_open_drawer()
		return
	mistakes += 1
	L._sfx3d("clink", LOCK, -6.0, 1.4)
	L._say("B_LOCK_WRONG", 2.5)
	await get_tree().create_timer(0.7).timeout
	match (mistakes - 1) % 3:
		0:
			# трубы стонут, по чёрной воде идёт рябь
			L._sfx3d("pipes", TAP + Vector3(0, -0.5, 0), 2.0)
			L.player.flicker = 0.8
			L.player.shake = 0.3
			var tw := create_tween()
			for k in 8:
				tw.tween_property(water, "position:y", water.position.y + (0.012 if k % 2 == 0 else -0.012), 0.08)
		1:
			# изнутри шкафчика кто-то стучит в ответ
			for t in [0.0, 0.35, 0.35, 0.6]:
				await get_tree().create_timer(t).timeout
				L._sfx3d("knock", LOCK, 2.0, 0.9)
			L._sfx("whisper_harsh", -6.0)
		2:
			# свеча гаснет, а в зеркале на миг — она
			_candle(false)
			L._sfx("sting", -4.0, 0.8)
			fig_mat.albedo_color.a = 0.9
			L.player.flicker = 0.6
			await get_tree().create_timer(0.5).timeout
			fig_mat.albedo_color.a = 0.0
			await get_tree().create_timer(1.5).timeout
			_candle(true)


func _candle(on: bool) -> void:
	candle_flame.visible = on
	candle_light.visible = on


# ---------------- взаимодействие ----------------
func target_ok(id: String) -> bool:
	if L.phase != "floor2" or L.busy or not unlocked:
		return false
	match id:
		"b_tap": return not running
		"b_lock": return not lock_open
		"b_tub": return not drained
		"b_key": return drained and not key_taken and water.position.y < TUB.y + WATER_LOW + 0.05
	return true


func interact(id: String) -> void:
	match id:
		"b_tap":
			_run_water()
		"b_mirror":
			L._say("B_MIRROR1" if fog_done else "B_MIRROR0", 4.0)
		"b_lock":
			_open_panel()
		"b_tub":
			if has_hook:
				_drain()
			else:
				L._sfx3d("drip", TUB + Vector3(0, 0.7, 0), -4.0, 0.6)
				L._say("B_TUB0", 4.5)
		"b_key":
			key_taken = true
			has_bedkey = true
			L.inv.add("bedkey")
			key_mesh.visible = false
			L._sfx("pickup", -6.0)
			L._say("B_KEY", 4.5)
			L._set_objective("B_OBJ4")
			exit_scare = 1


## Меню «Главы» → 6: ванная уже пройдена — дверь открыта, вода спущена, ключ Веры у игрока.
func skip_solved() -> void:
	unlocked = true
	door_pivot.rotation.y = door_angle
	lock_open = true
	drained = true
	key_taken = true
	has_bedkey = true
	exit_scare = 3
	hair.visible = false
	hair_eye.visible = false
	drowned_key.visible = false
	water_m.visible = false
	(water.material_override as ShaderMaterial).set_shader_parameter("shape_a", 0.0)
	water.position.y = TUB.y + WATER_LOW
	water.scale = Vector3(0.82, 1, 0.9)


## Дверь ванной открывается сама (когда игрок подёргал несколько дверей).
func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	L._sfx3d("click", door_pivot.global_position + Vector3(0, 1, 0), -2.0, 0.7)
	await get_tree().create_timer(0.8).timeout
	L._sfx3d("creak", door_pivot.global_position + Vector3(0, 1, 0), -4.0, 0.7)
	create_tween().tween_property(door_pivot, "rotation:y", door_angle, 3.2).set_trans(Tween.TRANS_SINE)
	L._set_objective("B_OBJ1")


func _run_water() -> void:
	running = true
	run_t = 0.0
	stream.visible = true
	steam.emitting = true
	water_snd.play()
	L._sfx3d("pipes", TAP + Vector3(0, -0.5, 0), -10.0, 1.3)


func _stop_water() -> void:
	running = false
	stream.visible = false
	steam.emitting = false
	water_snd.stop()
	L._sfx3d("pipes", TAP + Vector3(0, -0.5, 0), -2.0, 0.8)


## Слив: вода уходит, из ванны поднимается Аня, на дне — ключ.
func _drain() -> void:
	drained = true
	hair.visible = false
	hair_eye.visible = false
	drowned_key.visible = false
	water_m.visible = false
	(water.material_override as ShaderMaterial).set_shader_parameter("shape_a", 0.0)
	L.inv.remove("hook")
	L.busy = true
	L._sfx("clink", -6.0, 0.7)
	await get_tree().create_timer(0.8).timeout
	L._sfx3d("gurgle", TUB + Vector3(0, 0.5, 0), 2.0)
	var tw := create_tween()
	tw.tween_property(water, "position:y", TUB.y + WATER_LOW, 6.0).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(water, "scale", Vector3(0.82, 1, 0.9), 6.0)   # ко дну ванна уже
	# ключ на дне
	key_mesh = load("res://models/props/key_vera.glb").instantiate()
	key_mesh.visible = true
	L.add_child(key_mesh)
	key_mesh.global_position = TUB + Vector3(0.05, WATER_LOW - 0.02, 0.2)
	key_mesh.rotation = Vector3(0, 0.7, 0)
	await get_tree().create_timer(1.6).timeout
	# она поднимается из чёрной воды
	var g: Node3D = SPIRIT.new()
	L.add_child(g)
	g.global_position = TUB + Vector3(0, -1.45, 0.1)
	var to: Vector3 = L.player.global_position - g.global_position
	g.rotation.y = atan2(to.x, to.z)
	g.play_from("zidle", 0.5, 0.6)
	g.set_blood(0.95)
	L.busy = false
	L._sfx("girl_appear", -2.0, 0.8)
	var rise := create_tween()
	rise.tween_property(g, "global_position:y", TUB.y + 0.22, 2.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await rise.finished
	L._sfx("sting", 0.0, 0.9)
	L._sfx("scream", -8.0, 1.2)
	g.scream(0.8)
	L.player.shake = 0.6
	await get_tree().create_timer(1.1).timeout
	L.player.flicker = 1.0
	_candle(false)
	await get_tree().create_timer(0.35).timeout
	g.queue_free()
	await get_tree().create_timer(1.2).timeout
	_candle(true)


func _process(delta: float) -> void:
	if L == null or L.phase != "floor2":
		return
	if exit_scare in [1, 2]:
		_update_exit_scare()
	if not drained:
		_under_water(delta)
	# капает кран (слышно и из холла)
	if not running and not drained:
		next_drip -= delta
		if next_drip <= 0.0:
			next_drip = randf_range(1.5, 3.5)
			L._sfx3d("drip", TAP + Vector3(0, -0.15, -0.1), -6.0, randf_range(0.9, 1.15))
	if running:
		run_t += delta
		fog = minf(1.0, fog + delta / 6.0)
		if fog >= 1.0 and not fog_done:
			fog_done = true
			L._say("B_FOG", 4.0)
			L._set_objective("B_OBJ2")
		if run_t > 8.0:
			_stop_water()
	var a := smoothstep(0.0, 1.0, fog)
	fog_real.set_shader_parameter("fade", a)
	fog_true.set_shader_parameter("fade", a)
	if candle_light.visible:
		candle_light.light_energy = 0.45 + randf() * 0.1
	# долго смотришь в запотевшее зеркало — за туманом проступает она, и гаснет свет
	if fog_done and not ghost_done and not L.busy:
		var cam: Camera3D = L.player.cam
		var d: Vector3 = MIRROR_C - cam.global_position
		if d.length() < 2.6 and L.player.forward().angle_to(d) < 0.3:
			look_t += delta
		else:
			look_t = maxf(0.0, look_t - delta)
		if look_t > 2.2:
			ghost_done = true
			_mirror_ghost()


## Клубок волос на дне ванны: сотни прядей-лент расходятся из одной точки (будто там голова),
## концы колышутся в воде. Посередине — глаз, сначала закрыт. Всё только на «отражённом» слое.
func _build_hair() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1977
	var core := Vector3(0.0, 0.3, -0.38)       # «голова» ближе к изголовью, волосы тянутся к ногам
	for i in 900:
		var ph := rng.randf()
		var start := core + Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.04, 0.02), rng.randf_range(-0.06, 0.05))
		# в основном текут к дальнему концу ванны, веером, и медленно оседают
		var ang := rng.randf_range(-1.25, 1.25) + (PI if rng.randf() < 0.12 else 0.0)
		var dir := Vector3(sin(ang) * 0.9, rng.randf_range(-0.25, 0.02), cos(ang)).normalized()
		var length := rng.randf_range(0.45, 1.15)
		var segs := 18
		var w := rng.randf_range(0.0012, 0.0032)
		var wave := rng.randf_range(0.6, 2.2)
		var amp := rng.randf_range(0.01, 0.04)
		var pts: Array[Vector3] = []
		var p := start
		for k in segs + 1:
			var q := p + dir.cross(Vector3.UP).normalized() * sin(k * wave * 0.5 + ph * 6.0) * amp
			var e := Vector2(q.x / 0.25, q.z / 0.62).length()
			if e > 1.0:
				q.x /= e
				q.z /= e
			q.y = clampf(q.y, 0.16, 0.46)
			pts.append(q)
			p += dir * (length / segs)
			dir.y -= 0.01
		for k in segs:
			var a := pts[k]
			var b := pts[k + 1]
			var side := (b - a).cross(Vector3.UP).normalized() * w
			var ta := float(k) / segs
			var tb := float(k + 1) / segs
			var c := Color(ph, 0, 0)
			for v in [[a - side, ta], [a + side, ta], [b + side, tb], [a - side, ta], [b + side, tb], [b - side, tb]]:
				st.set_color(c)
				st.set_uv(Vector2(v[1], 0))
				st.add_vertex(v[0])
	st.generate_normals()
	hair = MeshInstance3D.new()
	hair.mesh = st.commit()
	var hm := ShaderMaterial.new()
	hm.shader = preload("res://shaders/hair.gdshader")
	hair.material_override = hm
	hair.layers = MIRROR_LAYER
	hair.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	L.add_child(hair)
	hair.global_position = TUB
	# глаз в гуще волос: белок, тёмная радужка, веко — сжатие по высоте (0 — закрыт)
	hair_eye = Node3D.new()
	L.add_child(hair_eye)
	hair_eye.global_position = TUB + core + Vector3(0.0, 0.035, 0.03)
	hair_eye.rotation = Vector3(-PI / 2, 0.4, 0)     # смотрит вверх, из воды
	var white := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.024
	sm.height = 0.03
	white.mesh = sm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.55, 0.5, 0.4)
	wm.roughness = 0.2
	white.material_override = wm
	white.scale = Vector3(1.6, 1.0, 1.0)
	hair_eye.add_child(white)
	var iris := MeshInstance3D.new()
	var im := SphereMesh.new()
	im.radius = 0.013
	im.height = 0.026
	iris.mesh = im
	var irm := StandardMaterial3D.new()
	irm.albedo_color = Color(0.03, 0.02, 0.02)
	irm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	iris.material_override = irm
	iris.position = hair_eye.global_transform.basis.inverse() * Vector3(0, 0.02, 0)   # радужка — сверху, к смотрящему
	hair_eye.add_child(iris)
	for n in [white, iris]:
		(n as MeshInstance3D).layers = MIRROR_LAYER
	hair_eye.scale = Vector3(1, 0.05, 1)


## Мутная вода: иногда под поверхностью что-то медленно проплывает (тень и круги, бульканье).
## Сквозь осколок вода прозрачная — на дне лежит она, а рядом ключ.
func _under_water(delta: float) -> void:
	water_m.position = water.position
	var near: bool = L.player.global_position.distance_to(TUB) < 4.0
	if near and not _shard_seen and L.hallp.looking_through(TUB + Vector3(0, 0.3, 0), 0.4):
		_shard_seen = true
		(hair.material_override as ShaderMaterial).set_shader_parameter("speed", 1.6)   # волосы зашевелились
		create_tween().tween_property(hair_eye, "scale:y", 1.0, 0.5).set_delay(0.6)  # открылся глаз
		L._sfx("heartbeat", -6.0)
		L._sfx3d("whisper", TUB + Vector3(0, 0.4, 0), -8.0, 1.2)
		L._say("B_SHARD_TUB", 4.5)
	if not near or L.busy or running:
		return
	_move_t -= delta
	if _move_t > 0.0:
		return
	_move_t = randf_range(14.0, 24.0)
	var wm := water.material_override as ShaderMaterial
	var z0 := randf_range(0.45, 0.6) * (1.0 if randf() < 0.5 else -1.0)
	L._sfx3d("gurgle", TUB + Vector3(0, 0.45, 0), -14.0, 0.6)
	var tw := create_tween().set_parallel()
	tw.tween_method(func(v: float): wm.set_shader_parameter("shape_a", v), 0.0, 0.85, 1.2)
	tw.tween_method(func(v: float): wm.set_shader_parameter("shape_pos", Vector2(sin(v * 3.0) * 0.08, v)), z0, -z0, 4.5).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_method(func(v: float): wm.set_shader_parameter("shape_a", v), 0.85, 0.0, 1.0)


## Уходишь из ванной с ключом: дверь в тамбур захлопывается, а как только её откроешь — она сразу
## бросается из-за двери: сбивает с ног, нависает над тобой (фонарь стробит, она всё ниже),
## бросается в лицо — темнота. Приходишь в себя на полу, поднимаешься — в проёме пусто.
func _update_exit_scare() -> void:
	match exit_scare:
		1:
			var p: Vector3 = L.player.global_position
			if Vector2(p.x - INNER_C.x, p.z - INNER_C.z).length() > 1.4 and not L.busy:
				exit_scare = 4          # дверь захлопывается
				var tw := create_tween()
				tw.tween_property(inner_pivot, "rotation:y", INNER_CLOSED, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				await tw.finished
				exit_scare = 2
				L._sfx3d("door", INNER_C, 2.0, 1.3)
				L._sfx("bang", -4.0, 0.9)
				L.player.shake = 0.35
				L.player.flicker = 0.4
				_candle(false)
		2:
			if L.doors.is_open("bath_in"):
				exit_scare = 3
				_exit_ghost()


func _exit_ghost() -> void:
	var p = L.player
	L.busy = true
	p.frozen = true
	var g: Node3D = SPIRIT.new()
	L.add_child(g)
	g.set_layer(1 | MIRROR_LAYER)
	var at := Vector3(INNER_C.x - 0.1, Y2, INNER_C.z + 0.45)
	g.global_position = at
	var dir: Vector3 = p.global_position - at                 # от неё к игроку
	dir.y = 0.0
	dir = dir.normalized()
	g.rotation.y = atan2(dir.x, dir.z)
	g.set_blood(1.0)
	g.set_eyes(1.0)
	g.set_shiver(1.0)
	var face := OmniLight3D.new()                              # мертвенный свет — видно лицо в темноте
	face.light_color = Color(0.7, 0.8, 1.0)
	face.light_energy = 1.8
	face.omni_range = 1.8
	face.position = Vector3(0, 1.4, 0.5)
	g.add_child(face)
	# 1. дверь открылась — она уже летит на тебя, без паузы
	g.play_from("reach", 1.2, 1.8)
	g.scream(2.2)
	L._sfx("sting", 2.0, 1.0, true)
	L._sfx("scream", 2.0, 1.15, true)
	L._sfx("heartbeat", 0.0, 1.3, true)
	var hit := Vector3(p.global_position.x, Y2, p.global_position.z) - dir * 0.45
	var tw := create_tween()
	tw.tween_property(g, "global_position", hit, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await tw.finished
	# 3. удар: сбивает с ног — падаешь навзничь, камера у самого пола смотрит вверх
	L._sfx("thump", 4.0, 0.7, true)
	L._sfx("bang", -2.0, 0.6, true)
	p.shake = 1.4
	L.red_flash.color.a = 0.45
	var h0: float = p.head.position.y
	var dest: Vector3 = p.global_position + dir * _free_dist(p, dir, 0.7)
	var fall := create_tween().set_parallel()
	fall.tween_property(p, "global_position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fall.tween_property(p.head, "position:y", 0.28, 0.42).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(p.head, "rotation:x", 1.0, 0.42)
	fall.tween_property(p.head, "rotation:z", 0.12, 0.42)
	fall.tween_property(p, "rotation:y", atan2(dir.x, dir.z), 0.3)          # лицом к ней
	# 4. она нависает над тобой: склоняется, тянет руки вниз, волосы свисают
	var floor_p := Vector3(dest.x, Y2, dest.z)
	g.play_from("zidle", 2.2, 0.3)
	_loom(g, p, floor_p, dir, 1.0, 0.5, 0.0)
	create_tween().tween_property(L.red_flash, "color:a", 0.15, 0.6)
	await get_tree().create_timer(0.45).timeout
	L._sfx("tinnitus", -6.0, 1.0, true)
	L._sfx("whisper_harsh", -2.0, 0.7, true)
	# фонарь стробит — с каждой вспышкой она ниже и ближе
	for k in 3:
		p.flicker = 0.13
		await get_tree().create_timer(0.13).timeout
		_loom(g, p, floor_p, dir, 0.95 - 0.05 * k, 0.6 + 0.1 * k, 0.12)
		p.shake = 0.9
		L.red_flash.color.a = 0.3
		create_tween().tween_property(L.red_flash, "color:a", 0.1, 0.3)
		await get_tree().create_timer(0.3).timeout
	# 5. бросается в лицо — темнота
	g.scream(0.3)
	L._sfx("scream", 3.0, 0.8, true)
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(g, "global_position", floor_p - dir * 0.55, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw2.tween_property(g, "rotation:x", 1.05, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await tw2.finished
	L.fade.color.a = 1.0
	L.red_flash.color.a = 0.0
	g.queue_free()
	await get_tree().create_timer(1.6).timeout
	# 6. приходишь в себя на полу и поднимаешься — в проёме никого
	create_tween().tween_property(L.fade, "color:a", 0.0, 1.8)
	L._sfx("breath_dark", -8.0, 1.1, true)
	await get_tree().create_timer(1.4).timeout
	var up := create_tween().set_parallel()
	up.tween_property(p.head, "position:y", h0, 1.3).set_trans(Tween.TRANS_SINE)
	up.tween_property(p.head, "rotation:x", 0.0, 1.3).set_trans(Tween.TRANS_SINE)
	up.tween_property(p.head, "rotation:z", 0.0, 1.1).set_trans(Tween.TRANS_SINE)
	await up.finished
	p.frozen = false
	L.busy = false
	_candle(true)


## Она стоит в dist от лежащего игрока и наклоняется над ним на угол lean (вперёд, от ступней);
## взгляд игрока — прямо на её лицо.
func _loom(g: Node3D, p: Node3D, floor_p: Vector3, dir: Vector3, dist: float, lean: float, sec: float) -> void:
	var pos := floor_p - dir * dist
	var head := pos + Vector3(0, 1.5 * cos(lean), 0) + dir * 1.5 * sin(lean)
	var cam_p := floor_p + Vector3(0, 0.28, 0)
	var dh := Vector2(head.x - cam_p.x, head.z - cam_p.z).length()
	var pitch := clampf(atan2(head.y - cam_p.y, maxf(dh, 0.05)), 0.6, 1.45)
	if sec <= 0.0:
		g.global_position = pos
		g.rotation.x = lean
		p.head.rotation.x = pitch
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(g, "global_position", pos, sec)
	tw.tween_property(g, "rotation:x", lean, sec)
	tw.tween_property(p.head, "rotation:x", pitch, sec)


## На сколько можно отлететь назад (луч по направлению толчка, не в стену).
func _free_dist(p: Node3D, d: Vector3, want: float) -> float:
	var from: Vector3 = p.global_position + Vector3(0, 0.6, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + d * (want + 0.35))
	q.exclude = [p.get_rid()]
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		return want
	return clampf(from.distance_to(h["position"]) - 0.35, 0.0, want)


func _mirror_ghost() -> void:
	L._sfx("heartbeat", -4.0)
	var tw := create_tween()
	tw.tween_property(fig_mat, "albedo_color:a", 0.75, 0.9)
	await get_tree().create_timer(1.6).timeout
	L._sfx("whisper_harsh", -2.0)
	L._sfx("sting", -6.0)
	L.player.flicker = 1.8
	_candle(false)
	fig_mat.albedo_color.a = 0.0
	await get_tree().create_timer(2.0).timeout
	_candle(true)
