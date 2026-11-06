extends Node
## Спальня Веры — глава (тестовая версия загадок).
##
## 1. Свет: дверь захлопнулась — лампы гаснут одна за другой, остаётся ночник у кровати.
##    На тумбочке свеча и спички: взял оба — зажёг, дальше ходишь со свечой (маленький дрожащий свет).
## 2. Скример «кровать»: под одеялом кто-то лежит; подходишь со свечой и смотришь — одеяло опадает, пусто.
## 3. Шкатулка с балериной: мелодия обрывается — у гребёнки не хватает трёх зубцов. Зубцы разбросаны по
##    комнате. Открыл без всех зубцов — ошибка: мелодия ломается, свеча гаснет, шёпот за спиной.
## 4. Шкатулка доиграла — из её основания выдвигается потайной ящичек: стеклянный глаз.
## 5. В углу в кресле — фарфоровая кукла Веры без правого глаза. Вставил глаз — кукла медленно поворачивает
##    голову к платяному шкафу, и дверца шкафа со скрипом приоткрывается (до этого шкаф заперт).
## 6. В шкафу — письмо Веры. Прочитал, закрыл — кукла уже сидит на полу у тебя за спиной. Посмотрел на неё —
##    мигнула и пропала; она снова в кресле и теперь всё время поворачивает голову за тобой.
## Все звуки здесь — с force = true (в спальне звуки дома выключены, см. level.hush).

const Y2 := -3.4
const MIRROR_LAYER := 1 << 10        ## видно только в зеркале (камера игрока этот слой не рисует)
const REAL_LAYER := 1 << 11          ## видно только наяву (камера зеркала не рисует)
const HELD_LAYER := 1 << 12          ## свеча в руке — в зеркале не отражается
const NIGHT_LAMP := 5                ## индекс ночника у кровати в bedroom.LAMPS — он не гаснет
const BED_C := Vector3(-9.04, Y2 + 0.70, -32.03)        ## верх матраса, центр
const BED_FOOT := Vector3(-9.04, 0.0, -30.6)            ## изножье (высота — лучом)
const CANDLE_XZ := Vector2(-11.2, -30.0)                ## свеча горит на полу посреди комнаты
const PEEK_XZ := Vector2(-9.4, -29.6)                  ## там в темноте стоит Вера и тянет руку
const MATCH_XZ := Vector2(-10.85, -33.02)
const BOX_XZ := Vector2(-10.5, -28.03)                  ## шкатулка на комоде у южной стены
const FRAME_XZ := Vector2(-6.25, -32.95)                ## фото на комоде со стеклянными дверцами
const SHAWL_XZ := Vector2(-13.56, -30.62)               ## шаль на комоде под зеркалом
const KEY_XZ := Vector2(-13.55, -31.45)
const DOLL_XZ := Vector2(-7.0, -28.55)                  ## кресло с куклой — северо-восточный угол
const WARD_XZ := Vector2(-5.9, -31.5)                   ## платяной шкаф у восточной стены, лицом в комнату (на запад)
const DOLL_SCALE := 0.75
const TEETH := [Vector3(-6.75, 1.0, -32.85), Vector3(-9.5, 1.0, -33.2), Vector3(-13.42, 0.7, -29.85)]   ## y — откуда пускать луч
## Фотография из шкафа: её место — пустой гвоздь в коридоре у самого входа (южная стена, справа от жирафа)
const HANG_FROM := Vector3(-5.22, Y2 + 1.75, -35.5)     ## откуда луч к стене (стена — на -Z)
const PHOTO_W := 0.3
const PHOTO_H := 0.4
const CREEPY_PICTURES := "res://textures/bedroom_pictures_creepy.png"   ## картины коридора после шкафа
const GLASS_C := Vector3(-13.762, Y2 + 1.7, -31.165)    ## стекло зеркала над комодом (смотрит на +X)
const GLASS_W := 0.76
const GLASS_H := 0.98

var L: Node
var B: Node                          ## bedroom.gd
var started := false                 ## дверь захлопнулась — глава идёт
var lit := false                     ## свеча горит
var candle: Node3D                   ## свеча на тумбочке
var matches: Node3D
var held: Node3D                     ## свеча в руке
var refl_candle: Node3D              ## та же свеча в руке отражения (видна только в зеркале)
var refl_flame: MeshInstance3D
const HELD_POS := Vector3(0.26, -0.3, -0.5)
const HELD_FWD := Vector3(0.2, -0.25, -0.66)   ## Q / ПКМ — вытянул свечу вперёд (вместо осколка, он сломался)
var push_hold := false
var _push := 0.0
var flame_light: OmniLight3D
var flame: MeshInstance3D
var gutter := 0.0                    ## > 0 — пламя почти гаснет
var _ft := 0.0
var blanket: MeshInstance3D
var bed_done := false
var bed_near_t := 0.0
var box: Node3D
var box_lid: Node3D
var box_twin_lid: Node3D
var ballerina_pivot: Node3D
var box_done := false
var box_busy := false
var teeth: Array[Node3D] = []
var shawl_pile: Node3D
var shawl_drape: Node3D
var shawl_twin: Node3D
var frame: Node3D
var frame_twin: Node3D
var frame_fixed := false
var shawl_fixed := false
var mirror_done := false
var vera_m: Node3D                   ## Вера — только в отражении
var letter: Node                     ## катсцена «Письмо Веры» (vera_letter.gd)
var portrait: Node                   ## овальный портрет в торце коридора (vera_portrait.gd)
var key_node: Node3D
# кукла, шкаф, глаз
var chair: Node3D
var doll: Node3D                     ## кукла в кресле
var doll_head: Node3D
var doll_eye: Node3D                 ## правый глаз куклы (пока не вставлен — скрыт)
var floor_doll: Node3D               ## та же кукла — на полу за спиной (скример)
var ward: Node3D
var ward_doors: Array[Node3D] = []
var ward_unlocked := false
var ward_open := false
var secret: Node3D                   ## потайной ящичек шкатулки
var eye_item: MeshInstance3D         ## стеклянный глаз в ящичке
var letter_node: MeshInstance3D
var photo_node: Node3D               ## фотография в шкафу (коридор, у двери стоит Аня)
var hang_pos := Vector3.ZERO         ## где висеть фотографии (на стене) и куда смотреть стене
var hang_n := Vector3.BACK
var hang_mark: Node3D                ## гвоздь и светлый след от рамы на обоях
var photo_hung := false
var pictures_creepy := false
var doll_state := "chair"            ## chair → armed (прочитал письмо) → floor → back (следит за тобой)
var _doll_t := 0.0
var vp: SubViewport
var mcam: Camera3D
var glass: MeshInstance3D
var _mframe := 0


func setup(level: Node, bedroom: Node) -> void:
	L = level
	B = bedroom
	L.player.cam.cull_mask &= ~MIRROR_LAYER          # «отражённое» видно только в зеркале
	await get_tree().physics_frame          # столкновения комнаты уже в мире — можно мерить лучами
	await get_tree().physics_frame
	_place_props()
	_make_hang_spot()
	_make_mirror()
	portrait = preload("res://scripts/vera_portrait.gd").new()
	add_child(portrait)
	portrait.setup(L, self)


# ---------------------------------------------------------------- расстановка
func _top(x: float, z: float, from_h := 1.05) -> float:
	var sp: PhysicsDirectSpaceState3D = L.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, Y2 + from_h, z), Vector3(x, Y2 - 0.3, z))
	var h := sp.intersect_ray(q)
	return h.position.y if not h.is_empty() else Y2


func _glb(path: String) -> Node3D:
	return load(path).instantiate()


func _set_layers(n: Node, mask: int) -> void:
	for v in n.find_children("*", "VisualInstance3D", true, false):
		(v as VisualInstance3D).layers = mask
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = mask


func _target(id: String, pos: Vector3, hint: String, th := 0.4, dist := 2.2) -> void:
	L.targets.append({"id": id, "pos": pos, "th": th, "dist": dist})
	L.extra_hints[id] = hint


func _place_props() -> void:
	var room: Node3D = L
	# свеча уже горит — стоит на полу посреди комнаты (спички не нужны)
	candle = _glb("res://models/bedroom/vera_candle.glb")
	room.add_child(candle)
	candle.global_position = Vector3(CANDLE_XZ.x, _top(CANDLE_XZ.x, CANDLE_XZ.y, 0.4), CANDLE_XZ.y)
	candle.rotation.y = 0.6
	floor_flame = MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(0.03, 0.066)
	floor_flame.mesh = fq
	var ffm := ShaderMaterial.new()
	ffm.shader = preload("res://shaders/candle_flame.gdshader")
	floor_flame.material_override = ffm
	floor_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	candle.add_child(floor_flame)
	floor_flame.position = Vector3(0, 0.19, 0)
	floor_light = OmniLight3D.new()
	floor_light.light_color = Color(1.0, 0.68, 0.38)
	floor_light.omni_range = 4.0
	floor_light.omni_attenuation = 1.6
	floor_light.shadow_enabled = true
	floor_light.shadow_bias = 0.05
	floor_light.visible = false                         # загорается, когда дверь захлопнулась
	floor_flame.visible = false
	candle.add_child(floor_light)
	floor_light.position = Vector3(0, 0.24, 0)
	_target("v_candle", candle.global_position + Vector3(0, 0.12, 0), "BR_CANDLE", 0.45, 2.4)
	matches = Node3D.new()                              # спичек больше нет (в коде остаётся пустышка)
	room.add_child(matches)
	matches.visible = false
	# Вера: еле видна в темноте за свечой, выглядывает и тянет руку
	peek = preload("res://scripts/vera.gd").new()
	room.add_child(peek)
	peek.global_position = Vector3(PEEK_XZ.x, Y2, PEEK_XZ.y)
	peek.visible = false
	# одеяло, под которым кто-то лежит
	var bl := _glb("res://models/bedroom/vera_blanket.glb")
	room.add_child(bl)
	bl.global_position = BED_C
	blanket = bl.find_child("Blanket", true, false) as MeshInstance3D
	blanket.material_override = _cloth_mat(Color(0.6, 0.58, 0.54), 0.5)
	blanket.set_blend_shape_value(blanket.find_blend_shape_by_name("Flat"), 0.0)
	# шкатулка (передом в комнату, на север)
	box = _glb("res://models/bedroom/vera_musicbox.glb")
	room.add_child(box)
	box.global_position = Vector3(BOX_XZ.x, _top(BOX_XZ.x, BOX_XZ.y), BOX_XZ.y)
	box.rotation.y = PI
	box_lid = box.find_child("Lid", true, false)
	var bal: Node3D = box.find_child("Ballerina", true, false)
	ballerina_pivot = Node3D.new()
	bal.get_parent().add_child(ballerina_pivot)
	ballerina_pivot.position = Vector3(0.05, 0, 0.02)
	bal.reparent(ballerina_pivot, true)
	_target("v_box", box.global_position + Vector3(0, 0.1, 0), "BR_MB")
	# три обломка гребёнки
	for i in TEETH.size():
		var p: Vector3 = TEETH[i]
		var t := _glb("res://models/bedroom/vera_tooth.glb")
		room.add_child(t)
		t.global_position = Vector3(p.x, _top(p.x, p.z, p.y) + 0.002, p.z)
		t.rotation.y = randf() * TAU
		t.scale = Vector3.ONE * 1.4
		var gl := OmniLight3D.new()                     # еле заметный блик — иначе в темноте не найти
		gl.light_color = Color(1.0, 0.85, 0.6)
		gl.light_energy = 0.06
		gl.omni_range = 0.25
		gl.position = Vector3(0, 0.05, 0)
		t.add_child(gl)
		teeth.append(t)
		_target("v_tooth%d" % (i + 1), t.global_position + Vector3(0, 0.03, 0), "LVL_44", 0.35, 1.8)
	# шаль кучкой на комоде под зеркалом и фото Веры на комоде — просто обстановка
	var sh := _glb("res://models/bedroom/vera_shawl.glb")
	room.add_child(sh)
	shawl_pile = sh.find_child("Pile", true, false)
	(shawl_pile as MeshInstance3D).material_override = _wool_mat()
	shawl_pile.reparent(room)
	shawl_pile.global_position = Vector3(SHAWL_XZ.x, _top(SHAWL_XZ.x, SHAWL_XZ.y), SHAWL_XZ.y)
	shawl_pile.rotation.y = 0.3
	sh.queue_free()
	frame = _glb("res://models/bedroom/vera_frame.glb")
	room.add_child(frame)
	var ph := frame.find_child("Photo", true, false) as MeshInstance3D
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = load("res://textures/photo_vera_small.png")
	pm.roughness = 0.6
	ph.material_override = pm
	frame.global_position = Vector3(FRAME_XZ.x, _top(FRAME_XZ.x, FRAME_XZ.y), FRAME_XZ.y)
	frame.rotation.y = -0.25
	_place_doll()
	_place_wardrobe()
	_place_secret()


## Кресло в углу, на нём фарфоровая кукла (без правого глаза), лицом в комнату.
func _place_doll() -> void:
	chair = _glb("res://models/bedroom/vera_armchair.glb")
	L.add_child(chair)
	var fl := _top(DOLL_XZ.x, DOLL_XZ.y, 0.3)
	chair.global_position = Vector3(DOLL_XZ.x, fl, DOLL_XZ.y)
	chair.rotation.y = -PI / 2                          # лицом к двери — кукла смотрит на входящего
	_box_body(chair, Vector3(0.66, 0.95, 0.62), Vector3(0, 0.475, 0))
	doll = _make_doll()
	chair.add_child(doll)
	doll.position = Vector3(0, 0.45, -0.1)
	doll_head = doll.find_child("Head", true, false)
	doll_eye = doll.find_child("EyeR", true, false)
	doll_eye.visible = false
	_target("v_doll", doll_head.global_position + Vector3(0, 0.04, 0), "BR_DOLL", 0.45, 2.0)
	floor_doll = _make_doll()
	L.add_child(floor_doll)
	floor_doll.visible = false


func _make_doll() -> Node3D:
	var d := _glb("res://models/bedroom/vera_doll.glb")
	d.scale = Vector3.ONE * DOLL_SCALE
	return d


## Платяной шкаф у восточной стены, дверцы — в комнату (на запад). Заперт, пока кукла не «посмотрит».
func _place_wardrobe() -> void:
	ward = _glb("res://models/bedroom/vera_wardrobe.glb")
	L.add_child(ward)
	ward.global_position = Vector3(WARD_XZ.x, _top(WARD_XZ.x, WARD_XZ.y, 0.3), WARD_XZ.y)
	ward.rotation.y = -PI / 2
	_box_body(ward, Vector3(1.14, 2.0, 0.6), Vector3(0, 1.0, 0))
	for n in ["Door0", "Door1"]:
		var dn := ward.find_child(n, true, false) as Node3D
		if dn:
			ward_doors.append(dn)
	_target("v_ward", ward.global_position + Vector3(-0.35, 1.1, 0), "BR_WARD", 0.5, 2.2)
	# письмо Веры — на дне шкафа
	letter_node = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.15, 0.21)
	letter_node.mesh = q
	var lm := StandardMaterial3D.new()
	var ru := TranslationServer.get_locale().begins_with("ru")
	lm.albedo_texture = load("res://textures/letter/letter_%s.png" % ("ru" if ru else "en"))
	lm.roughness = 0.9
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	letter_node.material_override = lm
	ward.add_child(letter_node)
	letter_node.position = Vector3(0.08, 0.145, 0.02)
	letter_node.rotation = Vector3(-PI / 2, 0.4, 0)
	letter_node.visible = false
	# рядом с письмом — фотография в рамке, лицом вверх
	photo_node = _make_photo()
	ward.add_child(photo_node)
	photo_node.position = Vector3(-0.24, 0.16, 0.0)
	photo_node.rotation = Vector3(-PI / 2, -0.25, 0)
	photo_node.visible = false


## Невидимая коробка-столкновение для мебели (в локальных осях узла n).
func _box_body(n: Node3D, size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	n.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = center
	body.add_child(cs)


## Потайной ящичек в основании шкатулки — внутри неё, пока шкатулка не доиграет до конца.
func _place_secret() -> void:
	var bb := AABB()
	var first := true
	for mi in box.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var a: AABB = m.global_transform * m.get_aabb()
		bb = a if first else bb.merge(a)
		first = false
	secret = Node3D.new()
	box.add_child(secret)
	var lw := box.global_basis.inverse() * bb.size          # габариты шкатулки в её осях
	lw = lw.abs()
	var dr := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(lw.x * 0.62, lw.y * 0.16, lw.z * 0.7)
	dr.mesh = bm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.28, 0.15, 0.08)
	wm.roughness = 0.55
	dr.material_override = wm
	secret.add_child(dr)
	secret.global_position = Vector3(bb.get_center().x, bb.position.y + lw.y * 0.09, bb.get_center().z)
	secret.set_meta("h", lw.y * 0.16)
	secret.set_meta("d", lw.z)
	eye_item = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.011
	sm.height = 0.022
	eye_item.mesh = sm
	var em := ShaderMaterial.new()
	em.shader = preload("res://shaders/glass_eye.gdshader")
	eye_item.material_override = em
	secret.add_child(eye_item)
	eye_item.position = Vector3(0, lw.y * 0.08 + 0.011, 0)
	eye_item.rotation = Vector3(-0.9, 0.3, 0)
	eye_item.visible = false


## Верх изножья кровати — самая высокая точка в полосе у ног.
func _foot_top() -> float:
	var best := Y2 + 0.7
	for dz in [-0.12, -0.06, 0.0, 0.06]:
		for dx in [-0.3, 0.0, 0.3]:
			best = maxf(best, _top(BED_FOOT.x + dx, BED_FOOT.z + dz, 1.4))
	return best


func _cloth_mat(tint: Color, tile: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/linen_diff.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load("res://textures/linen_nor.jpg")
	m.normal_scale = 0.4
	m.roughness = 0.95
	m.uv1_scale = Vector3(1.0 / tile, 1.0 / tile, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _wool_mat() -> StandardMaterial3D:
	var m := _cloth_mat(Color(0.36, 0.07, 0.08), 0.08)
	m.normal_scale = 1.2
	return m


# ---------------------------------------------------------------- фотография из шкафа
## Фотография в тёмной деревянной рамке (лицом к +Z, центр — середина снимка).
func _make_photo() -> Node3D:
	var n := Node3D.new()
	n.name = "VeraPhoto"
	var pic := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(PHOTO_W, PHOTO_H)
	pic.mesh = q
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = load("res://textures/vera_photo.png")
	pm.roughness = 0.55
	pic.material_override = pm
	n.add_child(pic)
	pic.position.z = 0.012
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.16, 0.1, 0.06)
	wood.roughness = 0.6
	var fw := 0.03
	var bars := [[Vector3(0, PHOTO_H / 2 + fw / 2, 0), Vector3(PHOTO_W + fw * 2, fw, 0.03)],
		[Vector3(0, -PHOTO_H / 2 - fw / 2, 0), Vector3(PHOTO_W + fw * 2, fw, 0.03)],
		[Vector3(-PHOTO_W / 2 - fw / 2, 0, 0), Vector3(fw, PHOTO_H, 0.03)],
		[Vector3(PHOTO_W / 2 + fw / 2, 0, 0), Vector3(fw, PHOTO_H, 0.03)],
		[Vector3(0, 0, -0.006), Vector3(PHOTO_W, PHOTO_H, 0.012)]]
	for b in bars:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b[1]
		m.mesh = bm
		m.material_override = wood
		n.add_child(m)
		m.position = b[0]
	return n


## Пустое место на стене у входа: гвоздь и чуть светлее обои там, где раньше висела рама.
func _make_hang_spot() -> void:
	var sp: PhysicsDirectSpaceState3D = (L as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(HANG_FROM, HANG_FROM + Vector3(0, 0, -2.0))
	var hit: Dictionary = sp.intersect_ray(q)
	if hit.is_empty():
		push_warning("vera_room: стена для фотографии не найдена")
		return
	hang_n = hit.normal
	hang_pos = hit.position + hang_n * 0.018
	hang_mark = Node3D.new()
	L.add_child(hang_mark)
	hang_mark.global_position = hit.position + hang_n * 0.002
	hang_mark.look_at(hang_mark.global_position - hang_n, Vector3.UP)    # -Z узла — в стену
	var patch := MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2(PHOTO_W + 0.07, PHOTO_H + 0.07)
	patch.mesh = pq
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(1.0, 0.97, 0.86, 0.05)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	patch.material_override = pm
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hang_mark.add_child(patch)
	var nail := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.004
	cm.bottom_radius = 0.003
	cm.height = 0.025
	nail.mesh = cm
	var nm := StandardMaterial3D.new()
	nm.albedo_color = Color(0.25, 0.22, 0.2)
	nm.metallic = 0.8
	nm.roughness = 0.45
	nail.material_override = nm
	hang_mark.add_child(nail)
	nail.position = Vector3(0, PHOTO_H / 2 + 0.02, 0.0125)
	nail.rotation.x = PI / 2
	_target("v_hang", hang_pos, "BR_HANG", 0.45, 2.0)


## Повесить фотографию на гвоздь.
func _hang_photo() -> void:
	if photo_hung or hang_mark == null:
		return
	photo_hung = true
	L.inv.remove("v_photo")
	var ph := _make_photo()
	L.add_child(ph)
	ph.global_position = hang_pos
	ph.look_at(hang_pos + hang_n, Vector3.UP)
	ph.rotate_object_local(Vector3.UP, PI)        # лицом из стены (снимок смотрит в +Z узла)
	ph.rotate_object_local(Vector3.BACK, 0.03)    # чуть криво, как вешают в темноте
	(hang_mark.get_child(0) as Node3D).visible = false
	L._sfx3d("click", hang_pos, -8.0, 0.7, true)
	L._sfx3d("thump", hang_pos, -16.0, 1.2, true)
	_on_photo_hung()


## Фотография повешена. Что будет дальше — ещё придумаем.
func _on_photo_hung() -> void:
	pass


## Шкаф открылся — картины в коридоре (и вся живопись модели спальни) становятся жуткими:
## темнее, грязнее; на каждой фотографии и пейзаже в темноте стоит Аня, у старика выколоты глаза.
func _creepy_pictures() -> void:
	if pictures_creepy:
		return
	pictures_creepy = true
	var tex: Texture2D = load(CREEPY_PICTURES)
	if tex == null:
		return
	for mi in B.root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i)
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture \
					and (mat as BaseMaterial3D).albedo_texture.resource_path.ends_with("_Image_20.png"):
				var d := mat.duplicate() as BaseMaterial3D
				d.albedo_texture = tex
				m.set_surface_override_material(i, d)
	L._sfx3d("creak", Vector3(-7.5, Y2 + 1.6, -35.6), -10.0, 0.55, true)   # в коридоре что-то скрипнуло


# ---------------------------------------------------------------- зеркало над комодом
func _make_mirror() -> void:
	glass = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(GLASS_W, GLASS_H)
	glass.mesh = q
	L.add_child(glass)
	glass.global_position = GLASS_C
	glass.rotation.y = PI / 2
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp = SubViewport.new()
	vp.size = Vector2i(int(420 * GLASS_W / GLASS_H), 420)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.positional_shadow_atlas_size = 1024
	add_child(vp)
	mcam = Camera3D.new()
	mcam.projection = Camera3D.PROJECTION_FRUSTUM
	mcam.keep_aspect = Camera3D.KEEP_HEIGHT
	mcam.size = GLASS_H
	mcam.far = 20.0
	mcam.current = true
	# слой 2 (1 << 1) — тело игрока из mirror.gd: в этом зеркале Миша тоже отражается; слой 3 — призраки чердака
	mcam.cull_mask = (0xFFFFF | MIRROR_LAYER) & ~REAL_LAYER & ~HELD_LAYER & ~(1 << 2)
	vp.add_child(mcam)
	var we := L.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var env: Environment = we.environment.duplicate()
		env.volumetric_fog_enabled = false
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.ssr_enabled = false
		env.glow_enabled = false
		mcam.environment = env
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D refl : source_color, filter_linear;
uniform sampler2D spots : filter_linear, repeat_enable;
void fragment() {
	vec3 c = texture(refl, vec2(1.0 - UV.x, UV.y)).rgb * vec3(0.72, 0.72, 0.68);
	float n = texture(spots, UV * vec2(0.7, 1.0)).r;
	float e = min(min(UV.x, 1.0 - UV.x) * 2.2, min(UV.y, 1.0 - UV.y) * 1.6);
	float desil = smoothstep(0.8, 0.92, n) + (1.0 - smoothstep(0.0, 0.3, e)) * 0.6 * smoothstep(0.45, 0.7, n);
	c = mix(c, vec3(0.03, 0.028, 0.024), clamp(desil, 0.0, 0.9));
	c *= mix(0.5, 1.0, smoothstep(0.0, 0.45, e));
	ALBEDO = c;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("refl", vp.get_texture())
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.seed = 23
	fn.frequency = 0.025
	fn.fractal_octaves = 4
	nt.noise = fn
	m.set_shader_parameter("spots", nt)
	glass.material_override = m


func _mirror_active() -> bool:
	if not started:
		return false
	var cam: Camera3D = L.player.cam
	var to: Vector3 = glass.global_position - cam.global_position
	if to.length() > 8.0 or to.dot(glass.global_basis.z) > -0.02:
		return false
	return cam.is_position_in_frustum(glass.global_position) or to.length() < 1.5


func _place_mcam() -> void:
	var G := glass.global_transform.orthonormalized()
	var el: Vector3 = G.affine_inverse() * L.player.cam.global_position
	var d := el.z
	if d < 0.03:
		return
	mcam.global_transform = Transform3D(Basis(-G.basis.x, G.basis.y, -G.basis.z), G * Vector3(el.x, el.y, -d))
	mcam.near = d
	mcam.frustum_offset = Vector2(el.x, -el.y)


# ---------------------------------------------------------------- свет
## Дверь захлопнулась: гаснет всё, кроме первого светильника — он моргает. Дойдёшь до него — загорается
## следующий по пути, а позади гаснет. Из темноты (только оттуда) — звуки, будто там кто-то есть:
## шаги, дыхание, скрежет, шёпот; свет ушёл вперёд — звуки перебираются в темноту за спиной.
const PATH := [1, 0, 6, 2, 3, NIGHT_LAMP]    ## светильники по пути: коридор → угол → дверь спальни → ночник
const DARK_SFX := [["step0", -4.0, 0.7], ["step2", -4.0, 0.65], ["breath_dark", -6.0, 1.0], ["scratch", -6.0, 0.75],
	["whisper_old", -8.0, 0.8], ["drag", -6.0, 0.7], ["knock", -8.0, 0.6], ["creak", -6.0, 0.6]]
var path_i := -1                     ## какой светильник сейчас горит (индекс в PATH)
var _base := {}                      ## исходная яркость светильников
var _dark_t := 3.0
var _lamp_t := 0.0


func lights_out() -> void:
	started = true
	var mf := _refl()
	if mf and mf.torch:
		mf.torch.visible = false                 # фонарь погас насовсем — в отражении его тоже нет
	for i in B.lamps.size():
		_base[i] = (B.lamps[i] as OmniLight3D).light_energy
	await get_tree().create_timer(0.8).timeout
	# всё гаснет разом с хлопком, первый светильник остаётся и моргает
	for i in B.lamps.size():
		if i != PATH[0] and i != NIGHT_LAMP:            # ночник у кровати горит всегда
			(B.lamps[i] as OmniLight3D).light_energy = 0.0
	L._sfx3d("click", L.player.global_position + Vector3(0, 2.0, 0), -2.0, 0.6, true)
	path_i = 0
	_dark_t = 2.5
	_start_peek()
	L._set_objective("BR_OBJ2")


func _lamp(i: int) -> OmniLight3D:
	return B.lamps[PATH[i]]


## Свет идёт за игроком: горит тот светильник пути, у которого он сейчас стоит (ближайший), остальные
## погашены. Пошёл дальше — загорается следующий, позади гаснет; вернулся назад — так же назад.
## В погасшей темноте сразу кто-то есть. Как только зажжена свеча — свет больше не водит (остаётся
## только ночник); звуки из темноты — всегда.
const LEAD := 1.8                    ## на сколько вперёд по ходу «смотрит» свет
var _want := 0
var _want_t := 0.0


func _update_path(delta: float) -> void:
	if path_i < 0:
		return
	_lamp_t += delta
	var cur := _lamp(path_i)
	var night: bool = PATH[path_i] == NIGHT_LAMP
	# горящий светильник неровно моргает (ночник — спокойнее)
	var e: float = _base[PATH[path_i]]
	var f := 1.0
	if not night:
		f = 0.0 if randf() < 0.06 else randf_range(0.65, 1.05)
		if fmod(_lamp_t, 3.7) < 0.25:
			f *= randf_range(0.0, 0.4)
	cur.light_energy = e * f
	if lit:
		return
	# ближайший светильник пути — к точке чуть впереди по ходу движения (не взгляда):
	# идёшь к светильнику — он загорается заранее, а не когда упёрся в него
	var p: Vector3 = L.player.global_position
	var v: Vector3 = L.player.velocity
	v.y = 0.0
	if v.length() > 0.3:
		p += v.normalized() * LEAD
	var best := path_i
	var best_d := INF
	var cur_d := INF
	for k in PATH.size():
		var lp := _lamp(k).global_position
		var d := Vector2(p.x - lp.x, p.z - lp.z).length()
		if k == path_i:
			cur_d = d
		if d < best_d:
			best_d = d
			best = k
	# переключаем, только если другой заметно ближе и игрок задержался — без дребезга на границе
	var want := best if best_d < cur_d - 0.3 else path_i
	if want != _want:
		_want = want
		_want_t = 0.0
	_want_t += delta
	if want != path_i and _want_t > 0.2:
		_switch_to(want)


## Переключить свет на светильник пути i: он загорается с треском, прежний через миг гаснет,
## и в его темноте сразу кто-то есть.
func _switch_to(i: int) -> void:
	if i == path_i:
		return
	var old := _lamp(path_i)
	path_i = i
	_lamp_t = 0.0
	var nxt := _lamp(i)
	var target: float = _base[PATH[i]]
	if PATH[i] == NIGHT_LAMP:
		nxt.light_energy = target                       # ночник и так горит — без треска
	else:
		L._sfx3d("click", nxt.global_position, -8.0, 1.2, true)
		var tw := create_tween()
		nxt.light_energy = 0.0
		for k in 3:
			tw.tween_property(nxt, "light_energy", target * 0.8, 0.05)
			tw.tween_property(nxt, "light_energy", 0.0, 0.07)
		tw.tween_property(nxt, "light_energy", target, 0.3)
	get_tree().create_timer(0.7).timeout.connect(func():
		if _lamp(path_i) == old or old == B.lamps[NIGHT_LAMP]:   # вернулся / ночник не гаснет
			return                                      # уже снова горит (вернулся)
		old.light_energy = 0.0
		L._sfx3d("click", old.global_position, -10.0, 0.7, true)
		get_tree().create_timer(1.2).timeout.connect(func():
			if lit:
				return
			var s: Array = DARK_SFX.pick_random()
			L._sfx3d(s[0], old.global_position + Vector3(randf_range(-0.8, 0.8), -0.6, randf_range(-0.8, 0.8)), s[1], s[2], true)))


## Свеча зажжена: свет больше не водит — гаснет всё, кроме ночника.
func _path_stop() -> void:
	for i in PATH.size():
		if PATH[i] != NIGHT_LAMP:
			_lamp(i).light_energy = 0.0
	path_i = PATH.size() - 1


## Где темно — там и звуки: точка подальше от горящего света, лучше за спиной у игрока.
func _dark_sounds(delta: float) -> void:
	if path_i < 0:
		return
	_dark_t -= delta
	if _dark_t > 0.0:
		return
	_dark_t = randf_range(2.5, 5.5) if not lit else randf_range(3.5, 7.0)   # и со свечой не стихают
	var p: Vector3 = L.player.global_position
	var lit_pos := _lamp(path_i).global_position
	var back: Vector3 = -L.player.forward()
	back.y = 0.0
	var best := Vector3.ZERO
	var best_s := -INF
	for k in 12:
		var a := randf() * TAU
		var r := randf_range(2.5, 6.0)
		var c := p + Vector3(cos(a), 0, sin(a)) * r
		c.x = clampf(c.x, -16.2, -5.7)                    # внутри спальни и её коридора
		c.z = clampf(c.z, -36.2, -27.8)
		c.y = Y2 + randf_range(0.2, 1.6)
		var dl := Vector2(c.x - lit_pos.x, c.z - lit_pos.z).length()
		if dl < 2.4 or (lit and Vector2(c.x - p.x, c.z - p.z).length() < 4.0):
			continue                                      # на свету (и рядом со свечой) никого нет
		var score := dl + (c - p).normalized().dot(back.normalized()) * 2.0 + randf()
		if score > best_s:
			best_s = score
			best = c
	if best_s == -INF:
		return
	var s: Array = DARK_SFX.pick_random()
	L._sfx3d(s[0], best, s[1], s[2] * randf_range(0.9, 1.1), true)
	if s[0].begins_with("step"):                         # шаги — несколько подряд, кто-то ходит
		for k in randi_range(2, 4):
			var q := best + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4)) * (k + 1)
			get_tree().create_timer(0.7 * (k + 1)).timeout.connect(func(): L._sfx3d("step%d" % (randi() % 4), q, -5.0, 0.7, true))


var floor_flame: MeshInstance3D
var floor_light: OmniLight3D
var peek: Node3D
var peek_gone := false


## Дверь захлопнулась — свеча на полу горит, а за ней в темноте стоит Вера.
func _start_peek() -> void:
	floor_flame.visible = true
	floor_light.visible = true
	floor_light.light_energy = 1.1
	peek.visible = true
	peek.play("idle", 0.35, 0.0)
	peek.pose.target = {"LeftForeArm": Vector3(0, 0, 1.0), "LeftHand": Vector3(0, 0, 0.2),
		"Spine": Vector3(0, 0, -0.3), "Spine1": Vector3(0, 0, -0.15), "Head": Vector3(0, 0, 0.35)}
	peek.pose.snap()
	for mi in peek.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as ShaderMaterial
		if m:
			m.set_shader_parameter("tint", Color(0.3, 0.29, 0.29))   # тёмный силуэт
			m.set_shader_parameter("rim", 0.0)                       # без ореола по краю


## Пока она есть: медленно поворачивается к игроку. Перешёл за свечу (в её сторону), подошёл,
## или взял свечу — исчезает, мигнув.
func _update_peek(delta: float) -> void:
	if peek_gone or not peek.visible:
		return
	var pp: Vector3 = L.player.global_position
	var d := pp - peek.global_position
	peek.rotation.y = lerp_angle(peek.rotation.y, atan2(d.x, d.z), minf(1.0, delta * 1.2))
	# пока игрок в коридоре (дверь захлопнулась у входа — это восточнее свечи), не проверяем:
	# иначе он «уже за свечой» и она исчезала, не успев показаться
	if not (pp.x > -14.1 and pp.z > -34.4):
		return
	var c := Vector3(CANDLE_XZ.x, 0, CANDLE_XZ.y)
	var dir := Vector3(PEEK_XZ.x, 0, PEEK_XZ.y) - c
	dir = dir.normalized()
	var past := Vector3(pp.x - c.x, 0, pp.z - c.z).dot(dir) > 0.1
	if past or Vector2(d.x, d.z).length() < 1.5 or lit:
		_peek_vanish()


func _peek_vanish() -> void:
	peek_gone = true
	L._sfx3d("whoosh", peek.global_position + Vector3(0, 1.4, 0), -12.0, 0.6, true)
	gutter_out(0.5)
	for k in 5:
		peek.visible = k % 2 == 1
		await get_tree().create_timer(randf_range(0.05, 0.12)).timeout
	peek.visible = false
	peek.queue_free()


## Взял горящую свечу с пола — она в руке.
func _take_candle() -> void:
	L.busy = true
	L._sfx("pickup", -6.0, 1.0, true)
	candle.visible = false
	floor_light.visible = false
	_make_held()
	lit = true
	_path_stop()
	gutter = 0.4
	await get_tree().create_timer(0.4).timeout
	L.busy = false
	L._set_objective("BR_OBJ3")


func _light_candle() -> void:
	L.busy = true
	L._sfx("match_strike", -4.0, 1.0, true)
	await get_tree().create_timer(0.35).timeout
	L.inv.remove("candle")
	L.inv.remove("matches")
	_make_held()
	lit = true
	_path_stop()
	gutter = 0.6
	await get_tree().create_timer(0.6).timeout
	L.busy = false
	L._set_objective("BR_OBJ3")


## Свеча в руке: справа внизу кадра, маленький тёплый дрожащий свет с тенями.
func _make_held() -> void:
	held = _glb("res://models/bedroom/vera_candle.glb")
	L.player.cam.add_child(held)
	held.position = HELD_POS
	held.rotation = Vector3(0.15, 0.4, 0)
	held.scale = Vector3.ONE * 0.75
	for v in held.find_children("*", "GeometryInstance3D", true, false):
		(v as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_set_layers(held, HELD_LAYER)
	flame = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.022, 0.05)
	flame.mesh = q
	var fm := ShaderMaterial.new()
	fm.shader = preload("res://shaders/candle_flame.gdshader")
	flame.material_override = fm
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.layers = HELD_LAYER
	held.add_child(flame)
	flame.position = Vector3(0, 0.19, 0)
	flame_light = OmniLight3D.new()
	flame_light.light_color = Color(1.0, 0.68, 0.38)
	flame_light.omni_range = 5.5
	flame_light.omni_attenuation = 1.6
	flame_light.shadow_enabled = true
	flame_light.shadow_bias = 0.05
	held.add_child(flame_light)
	flame_light.position = Vector3(0, 0.22, 0.02)
	_make_refl_candle()


## Тело игрока в отражении (из mirror.gd чердака — оно всегда при игроке, видно только зеркалам).
func _refl() -> Node:
	var a = L.get("attic")
	if a == null:
		return null
	var mf = a.get("mirror_fx")
	if mf == null or mf.get("body") == null or mf.get("sk") == null:
		return null
	return mf


## Свеча в правой руке отражения — как настоящая в руке у игрока.
func _make_refl_candle() -> void:
	var mf := _refl()
	if mf == null:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = "mixamorig_RightHand"
	(mf.sk as Skeleton3D).add_child(ba)
	refl_candle = _glb("res://models/bedroom/vera_candle.glb")
	ba.add_child(refl_candle)
	var k: float = (mf.body as Node3D).scale.x
	refl_candle.scale = Vector3.ONE * 0.75 / maxf(k, 0.01)
	refl_candle.position = Vector3(0, 0.06, 0.05) / maxf(k, 0.01)
	for v in refl_candle.find_children("*", "GeometryInstance3D", true, false):
		(v as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_set_layers(refl_candle, 1 << 1)
	refl_flame = flame.duplicate() as MeshInstance3D
	refl_flame.layers = 1 << 1
	refl_candle.add_child(refl_flame)
	refl_flame.position = flame.position


func _update_flame(delta: float) -> void:
	if held == null:
		return
	_ft += delta
	gutter = maxf(gutter - delta, 0.0)
	# вытянуть свечу вперёд (держишь Q / ПКМ)
	if push_hold and (L.player.frozen or not held.visible):
		push_hold = false
	_push = move_toward(_push, 1.0 if push_hold else 0.0, delta * 4.0)
	var e := _push * _push * (3.0 - 2.0 * _push)
	held.position = HELD_POS.lerp(HELD_FWD, e)
	held.rotation.y = lerpf(0.4, 0.25, e)
	var f := 0.82 + 0.1 * sin(_ft * 11.0) * sin(_ft * 7.3 + 1.0) + randf() * 0.08
	var g := 1.0 - smoothstep(0.0, 0.35, gutter) * 0.85
	flame_light.light_energy = 1.5 * f * g
	flame.scale = Vector3(1.0, (0.85 + 0.2 * f) * maxf(g, 0.2), 1.0)
	flame.visible = g > 0.1
	if refl_candle:
		refl_candle.visible = held.visible
		refl_flame.scale = flame.scale
		refl_flame.visible = flame.visible


## Q / правая кнопка — пока держишь, свеча вытянута вперёд (когда осколка уже нет).
func _unhandled_input(e: InputEvent) -> void:
	if held == null or not started or L.hallp.has_shard:
		return
	var pressed := -1
	if e is InputEventKey and e.physical_keycode == KEY_Q and not e.echo:
		pressed = 1 if e.pressed else 0
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT:
		pressed = 1 if e.pressed else 0
	if pressed < 0:
		return
	push_hold = pressed == 1 and not L.player.frozen


## Пламя на миг почти гаснет (испуг, сквозняк).
func gutter_out(sec: float) -> void:
	gutter = maxf(gutter, sec)


# ---------------------------------------------------------------- взаимодействие
func target_ok(id: String) -> bool:
	if not started or L.busy:
		return false
	match id:
		"v_candle": return candle.visible
		"v_matches": return matches.visible
		"v_box": return not box_done and not box_busy
		"v_eye": return eye_item.visible
		"v_doll": return doll_state == "chair" and not doll_eye.visible
		"v_ward": return not ward_open
		"v_letter": return letter_node.visible
		"v_photo": return photo_node.visible
		"v_hang": return not photo_hung and L.inv.has("v_photo") and hang_mark != null
	if id.begins_with("v_tooth"):
		return teeth[int(id.right(1)) - 1].visible
	return false


func interact(id: String) -> void:
	if not id.begins_with("v_"):
		return
	match id:
		"v_candle":
			_take_candle()
		"v_matches":
			if L.inv.add("matches", matches):
				matches.visible = false
				L._sfx("pickup", -6.0, 1.1, true)
				if L.inv.has("candle"):
					_light_candle()
		"v_box":
			_open_box()
		"v_eye":
			if L.inv.add("dolleye", eye_item):
				eye_item.visible = false
				L._sfx("pickup", -8.0, 1.4, true)
		"v_doll":
			if L.inv.has("dolleye"):
				_insert_eye()
			else:
				L._say("BR_DOLL_MISS", 2.6)
				_doll_twitch()
		"v_ward":
			if ward_unlocked:
				_open_wardrobe()
			else:
				L._sfx3d("click", ward.global_position + Vector3(0, 1.1, 0), -6.0, 0.8, true)
				L._sfx3d("thump", ward.global_position + Vector3(0, 1.1, 0), -12.0, 1.3, true)
				L._say("BR_WARD_LOCK", 2.0)
		"v_letter":
			letter_node.visible = false
			L._show_note("VL_NOTE")
			doll_state = "armed"
		"v_photo":
			if L.inv.add("v_photo", photo_node):
				photo_node.visible = false
				L._sfx("pickup", -6.0, 0.9, true)
		"v_hang":
			_hang_photo()
	if id.begins_with("v_tooth"):
		var t: Node3D = teeth[int(id.right(1)) - 1]
		if L.inv.add(id, t):
			t.visible = false
			L._sfx("pickup", -8.0, 1.3, true)


func _teeth_count() -> int:
	var n := 0
	for i in 3:
		if L.inv.has("v_tooth%d" % (i + 1)):
			n += 1
	return n


## Шкатулка: со всеми зубцами — играет до конца; без них — ошибка и испуг.
func _open_box() -> void:
	box_busy = true
	var full := _teeth_count() == 3
	if full:
		for i in 3:
			L.inv.remove("v_tooth%d" % (i + 1))
		L._sfx3d("click", box.global_position, -6.0, 1.4, true)
		await get_tree().create_timer(0.5).timeout
	create_tween().tween_property(box_lid, "rotation:x", -1.75, 0.7).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.5).timeout
	if full:
		L._sfx3d("vera_mb_full", box.global_position, -2.0, 1.0, true)
		var tw := create_tween()
		tw.tween_property(ballerina_pivot, "rotation:y", TAU * 9.0, 21.0)
		await get_tree().create_timer(21.0).timeout
		box_done = true
		box_busy = false
		_open_secret()
		return
	# ошибка: мелодия ломается на пустом зубце, свеча гаснет, шёпот за спиной
	L._sfx3d("vera_mb_broken", box.global_position, -2.0, 1.0, true)
	create_tween().tween_property(ballerina_pivot, "rotation:y", ballerina_pivot.rotation.y + 2.2, 2.2)
	await get_tree().create_timer(2.5).timeout
	gutter_out(1.6)
	var p = L.player
	L._sfx3d("whisper_harsh", p.cam.global_position - p.forward() * 0.6, -2.0, 0.8, true)
	p.shake = 0.5
	await get_tree().create_timer(0.8).timeout
	create_tween().tween_property(box_lid, "rotation:x", 0.0, 0.25).set_trans(Tween.TRANS_QUAD)
	L._sfx3d("click", box.global_position, -2.0, 0.6, true)
	L._say("BR_MB_MISS", 3.5)
	box_busy = false


# ---------------------------------------------------------------- кадр
func _process(delta: float) -> void:
	if not started:
		return
	_update_flame(delta)
	_update_peek(delta)
	_update_path(delta)
	_dark_sounds(delta)
	# подсказка у шкатулки: со всеми зубцами — «вставить»
	L.extra_hints["v_box"] = "BR_MB_FIX" if _teeth_count() == 3 else "BR_MB"
	# зеркало: отражение через кадр, только когда на него смотрят
	if _mirror_active():
		_mframe += 1
		if _mframe % 2 == 0:
			_place_mcam()
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	else:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_check_bed(delta)
	_update_doll(delta)
	L.extra_hints["v_doll"] = "BR_DOLL_EYE" if L.inv.has("dolleye") else "BR_DOLL"


## Под одеялом кто-то лежит. Подошёл со свечой и смотришь — одеяло опадает: пусто.
func _check_bed(delta: float) -> void:
	if bed_done or not lit or L.busy:
		return
	var p = L.player
	var head := BED_C + Vector3(0, 0.15, -0.6)
	var to: Vector3 = head - p.cam.global_position
	if to.length() < 2.3 and p.forward().angle_to(to) < 0.5:
		bed_near_t += delta
	else:
		bed_near_t = 0.0
	if bed_near_t < 0.6:
		return
	bed_done = true
	var k := blanket.find_blend_shape_by_name("Flat")
	create_tween().tween_method(func(v: float): blanket.set_blend_shape_value(k, v), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	L._sfx3d("sheet_rustle", BED_C, 0.0, 0.7, true)
	L._sfx3d("whoosh", BED_C + Vector3(0, 0.4, 0), -6.0, 0.6, true)
	gutter_out(0.5)
	p.shake = 0.35
	await get_tree().create_timer(0.45).timeout
	L._sfx3d("thump", BED_C, -6.0, 0.5, true)


# ---------------------------------------------------------------- шкатулка → глаз → кукла → шкаф
## Шкатулка доиграла: щелчок, из основания выдвигается потайной ящичек, в нём стеклянный глаз.
func _open_secret() -> void:
	await get_tree().create_timer(0.6).timeout
	L._sfx3d("click", box.global_position, -4.0, 1.6, true)
	eye_item.visible = true
	var fw: Vector3 = box.global_basis.z.normalized()
	var to: Vector3 = secret.global_position + fw * float(secret.get_meta("d")) * 0.55
	L._sfx3d("drawer", box.global_position, -8.0, 1.6, true)
	var tw := create_tween()
	tw.tween_property(secret, "global_position", to, 0.5).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_target("v_eye", eye_item.global_position + Vector3(0, 0.02, 0), "LVL_44", 0.35, 1.8)


## Без глаза: кукла чуть дёргает головой (на миг — и обратно).
func _doll_twitch() -> void:
	var y0 := doll_head.rotation.y
	var tw := create_tween()
	tw.tween_property(doll_head, "rotation:y", y0 + 0.12, 0.06)
	tw.tween_property(doll_head, "rotation:y", y0, 0.5).set_trans(Tween.TRANS_SINE)
	L._sfx3d("creak", doll_head.global_position, -16.0, 1.9, true)


## Угол головы куклы (в осях кресла), чтобы она смотрела на точку p.
func _head_yaw_to(p: Vector3) -> float:
	var d: Vector3 = p - doll_head.global_position
	var yaw := wrapf(atan2(d.x, d.z) - chair.global_rotation.y, -PI, PI)
	return clampf(yaw, -1.7, 1.7)


## Вставил глаз: кукла медленно поворачивает голову к шкафу — и дверца шкафа приоткрывается сама.
func _insert_eye() -> void:
	L.busy = true
	L.inv.remove("dolleye")
	doll_eye.visible = true
	L._sfx3d("click", doll_head.global_position, -8.0, 1.8, true)
	await get_tree().create_timer(1.0).timeout
	L.busy = false
	L._sfx3d("creak", doll_head.global_position, -6.0, 1.7, true)           # фарфор скрежещет о фарфор
	gutter_out(0.6)
	var tw := create_tween()
	tw.tween_property(doll_head, "rotation:y", _head_yaw_to(ward.global_position + Vector3(0, 1.0, 0)), 2.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await get_tree().create_timer(0.9).timeout
	ward_unlocked = true
	if ward_doors.size() > 1:
		L._sfx3d("creak", ward.global_position + Vector3(0, 1.1, 0), -4.0, 0.75, true)
		create_tween().tween_property(ward_doors[1], "rotation:y", 0.35, 2.2).set_trans(Tween.TRANS_SINE)


func _open_wardrobe() -> void:
	ward_open = true
	L._sfx3d("creak", ward.global_position + Vector3(0, 1.1, 0), -4.0, 0.9, true)
	if ward_doors.size() > 1:
		create_tween().tween_property(ward_doors[0], "rotation:y", -1.9, 1.1).set_trans(Tween.TRANS_SINE)
		create_tween().tween_property(ward_doors[1], "rotation:y", 1.9, 1.0).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.9).timeout
	letter_node.visible = true
	_target("v_letter", letter_node.global_position + Vector3(0, 0.03, 0), "BR_LETTER", 0.4, 2.2)
	photo_node.visible = true
	_target("v_photo", photo_node.global_position + Vector3(0, 0.03, 0), "BR_PHOTO", 0.4, 2.2)
	_creepy_pictures()


## Кукла после письма: на полу за спиной → посмотрел — пропала → снова в кресле и следит за тобой.
func _update_doll(delta: float) -> void:
	var p = L.player
	match doll_state:
		"armed":
			if L.busy or L.note_panel.visible:
				return
			_doll_t += delta
			if _doll_t < 0.8:
				return
			var back: Vector3 = -p.forward()
			back.y = 0.0
			back = back.normalized()
			var from: Vector3 = p.global_position + Vector3(0, 0.5, 0)
			var dist := 1.0
			var q := PhysicsRayQueryParameters3D.create(from, from + back * 1.4)
			q.exclude = [p.get_rid()]
			var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				dist = clampf(from.distance_to(hit["position"]) - 0.35, 0.6, 1.0)
			var at: Vector3 = Vector3(p.global_position.x, Y2, p.global_position.z) + back * dist
			floor_doll.global_position = Vector3(at.x, _top(at.x, at.z, 0.3), at.z)
			var d: Vector3 = p.global_position - at
			floor_doll.rotation.y = atan2(d.x, d.z)
			var fh := floor_doll.find_child("Head", true, false) as Node3D
			if fh:
				fh.rotation = Vector3(-0.25, 0.0, 0.35)              # смотрит снизу вверх, голова набок
			floor_doll.visible = true
			doll.visible = false
			L._sfx3d("giggle", at + Vector3(0, 0.4, 0), -14.0, 0.85, true)
			L._sfx("heartbeat", -10.0, 1.0, true)
			doll_state = "floor"
			_doll_t = 0.0
		"floor":
			var to: Vector3 = floor_doll.global_position + Vector3(0, 0.25, 0) - p.cam.global_position
			if to.length() < 4.5 and p.forward().angle_to(to) < 0.5:
				_doll_t += delta
			if _doll_t > 0.6:
				doll_state = "vanish"
				_doll_vanish()
		"back":
			var y := _head_yaw_to(p.cam.global_position)
			doll_head.rotation.y = lerp_angle(doll_head.rotation.y, y, minf(1.0, delta * 0.8))


func _doll_vanish() -> void:
	L._sfx3d("whoosh", floor_doll.global_position + Vector3(0, 0.3, 0), -10.0, 1.3, true)
	gutter_out(0.5)
	for k in 5:
		floor_doll.visible = k % 2 == 1
		await get_tree().create_timer(randf_range(0.05, 0.11)).timeout
	floor_doll.visible = false
	doll.visible = true
	doll_state = "back"
