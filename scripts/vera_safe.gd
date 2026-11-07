extends Node3D
## Тайник за картиной в спальне Веры: картина упала (vera_call.gd) — за ней в стене маленькие
## дверцы с замком, меньше рамы. Открыть — шпилькой (мини-игра крупным планом).
##
## Мини-игра «шпилька»:
##   мышь влево-вправо — поворачиваешь шпильку в скважине; удерживай ЛКМ (или D) — поворачиваешь
##   личинку замка. Чем ближе шпилька к «нужному месту», тем дальше личинка проворачивается;
##   мимо — замок упирается, дрожит и скрежещет. Довернул до конца — щелчок, следующий штифт.
##   Штифтов два. ПКМ — отойти (прогресс сохраняется только по уже открытым штифтам).
## Скример — после первого штифта: тишина, изнутри стук, шпильку кто-то дёргает изнутри — и дверцы
##   распахиваются: из темноты тайника прямо в лицо бросается Вера с распахнутым в крике ртом.
##   Чернота. Дверцы снова закрыты, шпилька в замке — второй штифт.
## Открыл — дверцы распахиваются, внутри темно (что там — дальше придумаем: _on_open()).
##
## ARMS_ENDING (сейчас включено) — вместо скримера выше финал главы: посреди мини-игры дверцы с грохотом
##   распахиваются, Мишу отбрасывает, он падает на пол. Из темноты тайника вытягиваются две страшно длинные
##   руки (руки Веры, тело — за стеной), хватают его и тащат в тайник. Можно сопротивляться (быстро жать
##   E / ЛКМ / пробел) — затягивает медленнее, но всё равно затягивает. Чернота — и заставка игры.

const PINS := 2
const TOL := 0.1            ## «нужное место» шпильки: ± рад — открывается полностью
const SOFT := 0.6           ## дальше этого от нужного места замок не поворачивается совсем
const TURN := 1.3           ## на сколько поворачивается личинка, рад
const ARMS_ENDING := true   ## false — прежний скример (Вера бросается в лицо) и мини-игра до конца
const MENU := "res://scenes/menu.tscn"

var L: Node
var R: Node
var normal := Vector3.BACK  ## из стены в комнату
var size := Vector2(0.3, 0.38)
var leaves: Array[Node3D] = []
var plate: Node3D           ## латунная накладка с личинкой
var core: Node3D            ## личинка (вращается)
var opened := false
var _pins_done := 0
var _scared := false
var _target: Dictionary

# мини-игра
var _on := false
var _busy := false          ## скример / переходы — ввод не принимается
var cam: Camera3D
var _old_cam: Camera3D
var pick: Node3D
var _ang := 0.0             ## шпилька, рад (−1.3..1.3)
var _sweet := 0.0
var _turn := 0.0            ## личинка 0..1
var _hold := false
var _rattle_t := 0.0
var _tick_t := 0.0
var ui: CanvasLayer
var black: ColorRect
var help: Label
var lamp: OmniLight3D
# финал с руками
var _pull_on := false        ## идёт затягивание — ввод: «вырываться»
var _resist := 0.0           ## накопленный рывок назад (м), гаснет со временем
var _pull_p := 0.0           ## 0 — лежит на полу, 1 — в тайнике
var arms_vera: Node3D
var arms_mod: SkeletonModifier3D
var mash: Label


## center — середина стены за картиной, n — нормаль из стены, s — размер картины (ш×в)
func setup(level: Node, room: Node, center: Vector3, n: Vector3, s: Vector2) -> void:
	L = level
	R = room
	normal = n.normalized()
	size = Vector2(clampf(s.x * 0.72, 0.18, 0.4), clampf(s.y * 0.72, 0.22, 0.45))
	L.add_child(self)
	global_position = center + normal * 0.004
	look_at(global_position + normal, Vector3.UP)      # -Z узла — из стены (в комнату)
	rotate_object_local(Vector3.UP, PI)                 # +Z — в комнату
	_build()


func _wood() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.17, 0.1, 0.06)
	m.roughness = 0.55
	return m


func _brass(dark := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.32, 0.15) if dark else Color(0.62, 0.48, 0.22)
	m.metallic = 0.9
	m.roughness = 0.38
	return m


func _box(sz: Vector3, at: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = sz
	mi.mesh = b
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = at
	return mi


func _build() -> void:
	var w := size.x
	var h := size.y
	var wood := _wood()
	# темнота внутри тайника (видна, когда дверцы открыты)
	var hole := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	hole.mesh = q
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.01, 0.008, 0.006)
	hm.roughness = 1.0
	hole.material_override = hm
	add_child(hole)
	hole.position = Vector3(0, 0, 0.001)
	# рамка
	var fw := 0.022
	_box(Vector3(w + fw * 2, fw, 0.018), Vector3(0, h / 2 + fw / 2, 0.009), wood)
	_box(Vector3(w + fw * 2, fw, 0.018), Vector3(0, -h / 2 - fw / 2, 0.009), wood)
	_box(Vector3(fw, h, 0.018), Vector3(-w / 2 - fw / 2, 0, 0.009), wood)
	_box(Vector3(fw, h, 0.018), Vector3(w / 2 + fw / 2, 0, 0.009), wood)
	# две дверцы на петлях по краям
	for sgn in [-1.0, 1.0]:
		var hinge := Node3D.new()
		add_child(hinge)
		hinge.position = Vector3(sgn * w / 2, 0, 0.014)
		var leaf := _box(Vector3(w / 2 - 0.002, h - 0.004, 0.012), Vector3(-sgn * (w / 4), 0, 0), wood, hinge)
		_box(Vector3(w / 2 - 0.03, h - 0.04, 0.004), Vector3(-sgn * (w / 4), 0, 0.007), wood, hinge)   # филёнка
		leaf.set_meta("sgn", sgn)
		leaves.append(hinge)
	# накладка замка — на стыке дверец, чуть выше середины; личинка вращается
	plate = Node3D.new()
	add_child(plate)
	plate.position = Vector3(0, h * 0.08, 0.022)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.024
	cm.bottom_radius = 0.026
	cm.height = 0.004
	disc.mesh = cm
	disc.material_override = _brass()
	disc.rotation.x = PI / 2
	plate.add_child(disc)
	core = Node3D.new()
	plate.add_child(core)
	core.position = Vector3(0, 0, 0.0025)
	var cd := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.012
	cc.bottom_radius = 0.012
	cc.height = 0.002
	cd.mesh = cc
	cd.material_override = _brass(true)
	cd.rotation.x = PI / 2
	core.add_child(cd)
	var slot := StandardMaterial3D.new()
	slot.albedo_color = Color(0.0, 0.0, 0.0)
	_box(Vector3(0.0035, 0.014, 0.002), Vector3(0, -0.002, 0.0012), slot, core)
	var dot := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.0035
	sm.height = 0.007
	dot.mesh = sm
	dot.material_override = slot
	core.add_child(dot)
	dot.position = Vector3(0, 0.004, 0.0012)


func plate_pos() -> Vector3:
	return plate.global_position


## Картина упала — тайник виден: цель для E.
func reveal() -> void:
	if ARMS_ENDING:                                   # модели финала грузятся в фоне, пока игрок идёт к замку
		for r in [REMY, MASK]:
			ResourceLoader.load_threaded_request(r)
		_warm = true
	R._target("v_safe", plate_pos(), "BR_SAFE", 0.35, 1.8)
	for t in L.targets:
		if t.get("id") == "v_safe":
			_target = t


func can_use() -> bool:
	return not opened and not _on


func interact() -> void:
	if opened or _on:
		return
	if not L.inv.has("v_hairpin"):
		L._sfx3d("click", plate_pos(), -8.0, 0.7, true)
		L._say("BR_SAFE_LOCK", 2.2)
		return
	_start()


# ---------------------------------------------------------------- мини-игра
func _start() -> void:
	_on = true
	_busy = true
	L.busy = true
	var p = L.player
	p.frozen = true
	_old_cam = p.cam
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.near = 0.01
	L.add_child(cam)
	var pp := plate_pos()
	cam.global_position = pp + normal * 0.2 + Vector3.DOWN * 0.03
	cam.look_at(pp, Vector3.UP)
	lamp = OmniLight3D.new()                       # тёплый свет свечи в руке — на замок
	lamp.light_color = Color(1.0, 0.68, 0.38)
	lamp.light_energy = 0.55
	lamp.omni_range = 1.2
	cam.add_child(lamp)
	lamp.position = Vector3(0.12, -0.08, 0.02)
	_make_ui()
	black.color.a = 1.0
	cam.make_current()
	_make_pick()
	_new_sweet()
	_turn = 0.0
	_ang = 0.0
	create_tween().tween_property(black, "color:a", 0.0, 0.35)
	L._sfx3d("click", pp, -6.0, 1.3, true)
	await get_tree().create_timer(0.35).timeout
	_busy = false


func _stop() -> void:
	_busy = true
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, 0.25)
	await tw.finished
	if is_instance_valid(pick):
		pick.queue_free()
	cam.queue_free()
	_old_cam.make_current()
	L.player.frozen = false
	L.busy = false
	_on = false
	var tw2 := create_tween()
	tw2.tween_property(black, "color:a", 0.0, 0.3)
	await tw2.finished
	ui.queue_free()


func _make_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 50
	L.add_child(ui)
	black = ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(black)
	help = Label.new()
	help.text = tr("LP_HELP")
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_top = -60
	help.offset_bottom = -24
	help.modulate = Color(0.85, 0.8, 0.7, 0.8)
	help.add_theme_font_size_override("font_size", 18)
	ui.add_child(help)


## Шпилька: из скважины наружу, к камере и вниз; крутится вокруг оси скважины.
func _make_pick() -> void:
	pick = Node3D.new()
	core.add_child(pick)
	pick.position = Vector3(0, -0.002, 0.002)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.095, 0.09)
	m.metallic = 0.85
	m.roughness = 0.3
	var arm := Node3D.new()                         # вращается на _ang вокруг оси скважины (Z)
	arm.name = "Arm"
	pick.add_child(arm)
	for seg in [[Vector3(0, 0, 0), Vector3(0, -0.012, 0.05)], [Vector3(0, -0.012, 0.05), Vector3(0, -0.06, 0.085)]]:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0016
		cm.bottom_radius = 0.0016
		cm.height = a.distance_to(b)
		cm.radial_segments = 6
		c.mesh = cm
		c.material_override = m
		arm.add_child(c)
		c.position = (a + b) * 0.5
		var d := (b - a).normalized()
		c.basis = Basis(Quaternion(Vector3.UP, d))
	var tip := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.0025
	tm.outer_radius = 0.006
	tip.mesh = tm
	tip.material_override = m
	arm.add_child(tip)
	tip.position = Vector3(0, -0.064, 0.088)


func _new_sweet() -> void:
	_sweet = randf_range(-1.0, 1.0)
	while absf(_sweet - _ang) < 0.35:
		_sweet = randf_range(-1.0, 1.0)


func _input(e: InputEvent) -> void:
	if not _on:
		return
	get_viewport().set_input_as_handled()
	if _pull_on:
		var hit: bool = (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_E, KEY_SPACE, KEY_F]) \
			or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT)
		if hit:
			_struggle()
		return
	if _busy:
		return
	if e is InputEventMouseMotion:
		if not _hold:
			var old := _ang
			_ang = clampf(_ang + e.relative.x * 0.004, -1.3, 1.3)
			_tick_t += absf(_ang - old)
			if _tick_t > 0.12:
				_tick_t = 0.0
				L._sfx3d("click", plate_pos(), -20.0, randf_range(2.2, 2.8), true)
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_hold = e.pressed
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			_hold = false
			_stop()
	elif e is InputEventKey and e.physical_keycode == KEY_D and not e.echo:
		_hold = e.pressed


func _process(delta: float) -> void:
	# фоновая подготовка финала: по одному куску за кадр, когда модели догрузились (не во время мини-игры)
	if _warm and _prep_step < 4 and not _on:
		if ResourceLoader.load_threaded_get_status(REMY) == ResourceLoader.THREAD_LOAD_LOADED \
				and ResourceLoader.load_threaded_get_status(MASK) == ResourceLoader.THREAD_LOAD_LOADED:
			_prep_next()
	if _me_on:
		_update_me()
	if not _on or not is_instance_valid(pick):
		return
	var arm := pick.get_node("Arm") as Node3D
	arm.rotation.z = _ang
	if _busy:
		return
	# насколько личинка может повернуться при этом положении шпильки
	var off := absf(_ang - _sweet)
	var can := 1.0 if off <= TOL else clampf(1.0 - (off - TOL) / (SOFT - TOL), 0.0, 1.0)
	var want := can if _hold else 0.0
	var stuck := _hold and _turn >= can - 0.01 and can < 1.0
	_turn = move_toward(_turn, want, delta * (1.6 if _hold else 3.0))
	var jit := randf_range(-0.03, 0.03) if stuck else 0.0
	core.rotation.z = -_turn * TURN + jit
	if stuck:
		_rattle_t -= delta
		if _rattle_t < 0.0:
			_rattle_t = 0.09
			L._sfx3d("click", plate_pos(), -14.0, randf_range(0.5, 0.75), true)
	if _turn >= 0.999:
		_pin_done()


func _pin_done() -> void:
	_busy = true
	_hold = false
	_pins_done += 1
	L._sfx3d("click", plate_pos(), -2.0, 0.9, true)
	if _pins_done >= PINS:
		_open()
		return
	if not _scared:
		_scared = true
		if ARMS_ENDING:
			_arms_ending()
		else:
			_scare()
		return
	await get_tree().create_timer(0.4).timeout
	_turn = 0.0
	core.rotation.z = 0.0
	_new_sweet()
	_busy = false


# ---------------------------------------------------------------- скример
func _scare() -> void:
	var pp := plate_pos()
	help.visible = false
	# личинка медленно возвращается; тишина
	var tw := create_tween()
	tw.tween_property(core, "rotation:z", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1.1).timeout
	L._sfx3d("thump", pp - normal * 0.1, -14.0, 1.4, true)            # изнутри — стук
	await get_tree().create_timer(0.9).timeout
	L._sfx3d("thump", pp - normal * 0.1, -9.0, 1.2, true)
	await get_tree().create_timer(0.35).timeout
	# шпильку дёргают изнутри — она уходит в скважину
	var arm := pick.get_node("Arm") as Node3D
	var t2 := create_tween()
	t2.tween_property(pick, "position:z", -0.03, 0.08).set_trans(Tween.TRANS_QUAD)
	t2.parallel().tween_property(arm, "rotation:z", _ang + 0.5, 0.08)
	await t2.finished
	await get_tree().create_timer(0.45).timeout
	# дверцы распахиваются — и она в лицо
	var vera: Node3D = preload("res://scripts/vera.gd").new()
	L.add_child(vera)
	vera.play("idle", 0.0)
	var face_from := pp - normal * 0.05
	# отшатнулся: камера рывком отъезжает от стены, а она — уже перед лицом (в ~30 см)
	var cam_back: Vector3 = pp + normal * 0.95 + Vector3.DOWN * 0.03
	var face_to: Vector3 = cam_back - normal * 0.56 + Vector3.DOWN * 0.05   # кость головы: лицо с раскрытым ртом — во весь кадр
	var b := Basis(Vector3.UP.cross(normal).normalized(), Vector3.UP, normal)   # +Z модели — к камере
	var head_ofs := Vector3(0, 1.6, 0.37)
	vera.global_transform = Transform3D(b, face_from - b * head_ofs)
	var face_light := OmniLight3D.new()
	face_light.light_color = Color(0.75, 0.82, 1.0)
	face_light.light_energy = 0.35
	face_light.omni_range = 0.8
	cam.add_child(face_light)
	face_light.position = Vector3(0, 0.05, -0.02)
	for lf in leaves:
		var sg: float = (lf.get_child(0) as Node3D).get_meta("sgn", 1.0)
		create_tween().tween_property(lf, "rotation:y", sg * 1.9, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pick.visible = false
	vera.scream(0.6)
	L._sfx("scream", 2.0, 0.78, true)
	L._sfx("sting", 0.0, 0.7, true)
	var lunge := create_tween()
	lunge.tween_property(vera, "global_position", face_to - b * head_ofs, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(cam, "global_position", cam_back, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	L.player.shake = 1.0
	if L.get("red_flash"):
		L.red_flash.color.a = 0.55
		create_tween().tween_property(L.red_flash, "color:a", 0.0, 0.9)
	# камера крупного плана тоже трясётся
	await get_tree().create_timer(0.12).timeout
	var c0 := cam_back
	var st := 0.0
	while st < 0.75:
		await get_tree().process_frame
		st += get_process_delta_time()
		cam.global_position = c0 + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.006 * (1.0 - st / 0.75)
	cam.global_position = pp + normal * 0.2 + Vector3.DOWN * 0.03
	cam.look_at(pp, Vector3.UP)
	black.color.a = 1.0
	vera.queue_free()
	face_light.queue_free()
	for lf in leaves:
		lf.rotation.y = 0.0
	await get_tree().create_timer(1.4).timeout
	# снова тишина: дверцы закрыты, шпилька в замке — второй штифт
	pick.visible = true
	pick.position.z = 0.002
	_turn = 0.0
	core.rotation.z = 0.0
	_new_sweet()
	help.visible = true
	create_tween().tween_property(black, "color:a", 0.0, 0.6)
	await get_tree().create_timer(0.6).timeout
	_busy = false


# ---------------------------------------------------------------- финал: руки из тайника
## Всё тяжёлое (модели, звуки) готовится заранее — когда начинается мини-игра, за чёрной шторкой;
## руки, маска и свои руки Миши стоят «за стеной» и уже рисуются (материалы собраны) — в скримере
## они только переезжают на место, без подгрузок и рывков.
const REMY := "res://models/player/remy.fbx"
const MASK := "res://models/ghosts/ghost_mask.glb"
const SOUNDS := ["door", "scream_demon", "sting", "attic_thud", "breath_dark", "scratch", "whisper_harsh",
	"thump", "scream", "drag", "drone", "giggle"]
var _prepared := false
var _warm := false
var _prep_step := 0
var arms_light: OmniLight3D
var _hole := Vector3.ZERO
var mask: Node3D
var me_body: Node3D              ## руки Миши (Remy без головы)
var me_sk: Skeleton3D
var _me_head_local := Vector3.ZERO
var _me_k := 0.46
var _me_t: Array[Node3D] = []    ## цели кистей Миши: [левая, правая]
var _me_p: Array[Node3D] = []
var _me_mod: SkeletonModifier3D
var _me_on := false
var _yank := 0.0                 ## рывок «отдираю руки» — гаснет
var _mask_out := 0.0             ## насколько маска вылезла из темноты (м)
var cold: OmniLight3D


func _prepare_ending() -> void:
	while _prep_step < 4:
		_prep_next()


## Один шаг подготовки: звуки → руки → маска → свои руки. Всё спрятано до финала.
func _prep_next() -> void:
	_hole = global_position + normal * 0.01
	match _prep_step:
		0:
			for n in SOUNDS:
				L._stream(n)
		1:
			_spawn_arms(_hole)
		2:
			mask = (load(MASK) as PackedScene).instantiate()
			L.add_child(mask)
			mask.scale = Vector3.ONE * 1.3
			mask.visible = false
			for mi in mask.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_place_mask(-0.4)
		3:
			_spawn_me()
	_prep_step += 1
	_prepared = _prep_step >= 4


## Маска в проёме: лицом в комнату, out — на сколько лицо выступает из стены (м; меньше 0 — в темноте).
func _place_mask(out: float) -> void:
	var b := Basis(Vector3.UP.cross(normal).normalized(), Vector3.UP, normal)
	var c := _hole + Vector3.DOWN * 0.15 + normal * (out - 0.065 * 1.3)
	if is_instance_valid(cam):
		var to := (cam.global_position - c).normalized()
		to = (to + normal * 2.0).normalized()           # чуть доворачивается к тебе
		b = Basis(Vector3.UP.cross(to).normalized(), Vector3.UP, to).orthonormalized()
	mask.global_transform = Transform3D(b.scaled(Vector3.ONE * 1.3), c)


func _arms_ending() -> void:
	_prepare_ending()
	var hole := _hole
	var pp := plate_pos()
	help.visible = false
	await get_tree().create_timer(0.3).timeout
	# дверцы — с грохотом настежь
	for lf in leaves:
		var sg: float = (lf.get_child(0) as Node3D).get_meta("sgn", 1.0)
		create_tween().tween_property(lf, "rotation:y", sg * 2.0, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pick.visible = false
	plate.visible = false
	create_tween().tween_property(cam, "fov", 74.0, 0.4)
	L._sfx3d("door", pp, 4.0, 0.62, true)
	L._sfx("scream_demon", 0.0, 0.8, true)
	L._sfx("sting", 0.0, 0.65, true)
	if L.get("red_flash"):
		L.red_flash.color.a = 0.45
		create_tween().tween_property(L.red_flash, "color:a", 0.0, 1.0)
	# Мишу отбрасывает: камера летит назад и вниз, на пол, с завалом набок
	var sp: PhysicsDirectSpaceState3D = (L as Node3D).get_world_3d().direct_space_state
	var out := hole + normal * 1.2
	var hit: Dictionary = sp.intersect_ray(PhysicsRayQueryParameters3D.create(out, out + Vector3.DOWN * 3.0))
	var floor_y: float = hit.position.y if not hit.is_empty() else hole.y - 1.75
	var fall := Vector3(out.x, floor_y + 0.45, out.z)
	var c0 := cam.global_position
	var fall_t := 0.0
	while fall_t < 0.5:
		await get_tree().process_frame
		fall_t += get_process_delta_time()
		var k := minf(fall_t / 0.5, 1.0)
		var hk := 1.0 - pow(1.0 - k, 3.0)
		var vk := k * k
		cam.global_position = Vector3(lerpf(c0.x, fall.x, hk), lerpf(c0.y, fall.y, vk), lerpf(c0.z, fall.z, hk))
		_look(cam, hole, 0.4 * k)
	L._sfx3d("attic_thud", fall, 2.0, 0.7, true)
	L._sfx("breath_dark", -2.0, 1.15, true)
	lamp.light_energy = 0.0                            # свеча выпала из руки
	cold = OmniLight3D.new()                           # мертвенный холодный свет у лица
	cold.light_color = Color(0.62, 0.7, 0.9)
	cold.light_energy = 0.4
	cold.omni_range = 1.4
	cam.add_child(cold)
	cold.position = Vector3(0.0, 0.25, 0.1)
	await _shake(0.45, 0.025)
	# из темноты медленно выплывает маска — и смотрит
	arms_light.visible = true
	_place_mask(-0.12)
	mask.visible = true
	L._sfx3d("whisper_harsh", hole, 0.0, 0.7, true)
	var mt := 0.0
	while mt < 1.1:
		await get_tree().process_frame
		mt += get_process_delta_time()
		_place_mask(lerpf(-0.12, 0.08, _smooth(minf(mt / 1.1, 1.0))))
	# руки — рывком из темноты, прямо за плечи
	L._sfx3d("scratch", hole, 0.0, 0.7, true)
	var grab_t := 0.0
	var start_l: Vector3 = hole + normal * 0.15 + Vector3.LEFT * 0.08
	var start_r: Vector3 = hole + normal * 0.15 + Vector3.RIGHT * 0.08
	arms_mod.set("target_l", start_l)
	arms_mod.set("target_r", start_r)
	await get_tree().process_frame
	arms_vera.visible = true
	while grab_t < 0.42:
		await get_tree().process_frame
		grab_t += get_process_delta_time()
		var k := _ease_jerk(grab_t / 0.42)
		var g := _grab_points()
		arms_mod.set("target_l", start_l.lerp(g[0], k))
		arms_mod.set("target_r", start_r.lerp(g[1], k))
		arms_mod.set("grip", 0.0)
	arms_mod.set("follow", true)
	create_tween().tween_property(arms_mod, "grip", 1.0, 0.1)
	L._sfx("thump", 0.0, 0.8, true)
	L._sfx("scream", -6.0, 0.55, true)
	L._sfx3d("giggle", hole, -4.0, 0.55, true)
	# свои руки — вцепляются в её запястья и пытаются отодрать
	_me_on = true
	me_body.visible = true
	await _shake(0.3, 0.03)
	L._say("VERA_PULL", 3.0)
	_make_mash()
	_pull_on = true
	var t := 0.0
	var ctrl: Vector3 = hole + normal * 0.6 + Vector3.DOWN * 0.15
	var end: Vector3 = hole + normal * 0.06
	var drag_t := 0.0
	while _pull_p < 1.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		_pull_p = minf(_pull_p + (0.05 + 0.045 * t) * dt, 1.0)       # всё сильнее
		_resist = move_toward(_resist, 0.0, dt * 0.5)
		_yank = move_toward(_yank, 0.0, dt * 4.0)
		var e := _pull_p
		var pos := fall.lerp(ctrl, e).lerp(ctrl.lerp(end, e), e)
		pos += normal * _resist
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.005
		cam.global_position = pos
		_look(cam, hole + Vector3.DOWN * 0.05, 0.4 * (1.0 - e) + sin(t * 9.0) * 0.035)
		_place_mask(0.09 + 0.025 * sin(t * 2.3))
		mash.modulate.a = 0.55 + 0.45 * sin(t * 10.0)
		drag_t -= dt
		if drag_t < 0.0:
			drag_t = randf_range(0.5, 0.9)
			L._sfx3d("drag", cam.global_position, -4.0, randf_range(0.7, 0.9), true)
	# затянуло — чернота, тишина, заставка
	_pull_on = false
	mash.visible = false
	black.color.a = 1.0
	L._say("", 0.1)
	for a2 in L.find_children("*", "AudioStreamPlayer", true, false) + L.find_children("*", "AudioStreamPlayer3D", true, false):
		a2.stop()
	await get_tree().create_timer(1.8).timeout
	await _title_card()
	get_tree().change_scene_to_file(MENU)


static func _smooth(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


static func _ease_jerk(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 4.0)


## Куда хватают руки: за плечи Миши (кисти — у самых краёв кадра, внизу).
func _grab_points() -> Array:
	var b := cam.global_basis
	var o := cam.global_position
	var y := 0.02 * _yank
	return [o + b * Vector3(-0.16, -0.19 + y, -0.24), o + b * Vector3(0.16, -0.19 + y, -0.24)]


static func _look(c: Camera3D, at: Vector3, roll: float) -> void:
	c.look_at(at, Vector3.UP)
	c.rotate_object_local(Vector3.BACK, roll)


func _shake(sec: float, amp: float) -> void:
	var t := 0.0
	var base := cam.global_position
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()
		cam.global_position = base + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * amp * (1.0 - t / sec)
	cam.global_position = base


## Вырываешься: дёргаешь её руки от себя — затягивание на миг сбивается.
func _struggle() -> void:
	_pull_p = maxf(_pull_p - 0.03, 0.0)
	_resist = minf(_resist + 0.05, 0.18)
	_yank = 1.0
	L._sfx3d("thump", cam.global_position, -14.0, randf_range(1.2, 1.5), true)


func _make_mash() -> void:
	mash = Label.new()
	mash.text = tr("LP_MASH")
	mash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mash.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	mash.offset_left = -300
	mash.offset_right = 300
	mash.offset_top = -120
	mash.offset_bottom = -80
	mash.add_theme_font_size_override("font_size", 30)
	mash.add_theme_color_override("font_color", Color(0.85, 0.12, 0.08))
	mash.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	ui.add_child(mash)


## Руки из тайника: тело (Remy, мёртвая серая кожа) — за стеной, плечи — позади дверец.
## Видны только руки — тонкие, костлявые, страшно длинные; длинные пальцы с тёмными ногтями.
var arms_mat: ShaderMaterial
func _spawn_arms(hole: Vector3) -> void:
	arms_vera = (load(REMY) as PackedScene).instantiate()
	var k: float = L.player.head.position.y / 3.47 if L.player.head.position.y > 1.0 else 1.6 / 3.47
	_me_k = k
	arms_vera.scale = Vector3(k, k, k)
	L.add_child(arms_vera)
	var tex: Texture2D = null
	for mi in arms_vera.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if m.name in ["Hair", "Eyes", "Eyelashes", "Tops", "Bottoms", "Shoes"]:
			m.visible = false
		elif tex == null:
			var bm := m.get_active_material(0) as BaseMaterial3D
			if bm:
				tex = bm.albedo_texture
	arms_mat = ShaderMaterial.new()
	arms_mat.shader = preload("res://shaders/ghost_arm.gdshader")
	if tex:
		arms_mat.set_shader_parameter("skin", tex)
	arms_mat.set_shader_parameter("fade0", 0.5)
	arms_mat.set_shader_parameter("fade1", 1.9)
	arms_mat.set_shader_parameter("tint", Color(0.6, 0.62, 0.6))
	arms_mat.set_shader_parameter("dead", 1.0)
	for mi in arms_vera.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = arms_mat
	var ap: AnimationPlayer = arms_vera.get_node("AnimationPlayer")
	ap.play("mixamo_com")
	ap.seek(0.3, true)
	ap.pause()
	var sk: Skeleton3D = arms_vera.get_node("Skeleton3D")
	var b := Basis(Vector3.UP.cross(normal).normalized(), Vector3.UP, normal)      # лицом в комнату
	arms_vera.global_transform = Transform3D(b.scaled(Vector3(k, k, k)), hole)
	arms_vera.visible = false
	arms_mod = _LongArms.new()
	arms_mod.set("target_l", hole + normal * 0.15)
	arms_mod.set("target_r", hole + normal * 0.15)
	arms_mod.set("owner_safe", self)
	sk.add_child(arms_mod)
	var S := sk.global_transform
	var ls: Vector3 = S * sk.get_bone_global_rest(sk.find_bone("mixamorig_LeftArm")).origin
	var rs: Vector3 = S * sk.get_bone_global_rest(sk.find_bone("mixamorig_RightArm")).origin
	arms_vera.global_position += (hole - normal * 0.4 + Vector3.DOWN * 0.03) - (ls + rs) * 0.5
	# длинные тёмные ногти
	var nm := StandardMaterial3D.new()
	nm.albedo_color = Color(0.16, 0.13, 0.09)
	nm.roughness = 0.3
	nm.metallic = 0.1
	for side in ["Left", "Right"]:
		for g in ["Thumb", "Index", "Middle", "Ring", "Pinky"]:
			var bn := "mixamorig_%sHand%s4" % [side, g]
			if sk.find_bone(bn) < 0:
				continue
			var ba := BoneAttachment3D.new()
			ba.bone_name = bn
			sk.add_child(ba)
			var nail := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.0045 / k
			cm.height = 0.032 / k
			cm.radial_segments = 6
			nail.mesh = cm
			nail.material_override = nm
			nail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ba.add_child(nail)
			nail.position = Vector3(0, cm.height * 0.35, 0)
			nail.rotation.x = 0.35                     # загнуты, как когти
	# холодный отсвет из тайника — на руки и маску
	arms_light = OmniLight3D.new()
	arms_light.light_color = Color(0.6, 0.7, 1.0)
	arms_light.light_energy = 0.9
	arms_light.omni_range = 2.6
	arms_light.shadow_enabled = false
	arms_light.visible = false
	L.add_child(arms_light)
	arms_light.global_position = hole + normal * 0.35 + Vector3.DOWN * 0.3


## Свои руки Миши: Remy без головы, тело — за камерой; кисти вцепляются в её руки чуть выше запястий.
func _spawn_me() -> void:
	me_body = (load(REMY) as PackedScene).instantiate()
	me_body.visible = false
	L.add_child(me_body)
	me_body.scale = Vector3.ONE * _me_k
	for mi in me_body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if m.name in ["Hair", "Eyes", "Eyelashes", "Bottoms", "Shoes"]:
			m.visible = false
	var ap: AnimationPlayer = me_body.get_node("AnimationPlayer")
	ap.play("mixamo_com")
	ap.seek(0.3, true)
	ap.pause()
	me_sk = me_body.get_node("Skeleton3D")
	# где голова — в осях тела (тело переставляется за камерой каждый кадр)
	var hw: Vector3 = me_sk.global_transform * me_sk.get_bone_global_rest(me_sk.find_bone("mixamorig_Head")).origin
	_me_head_local = me_body.global_transform.affine_inverse() * hw
	me_body.global_position = _hole - normal * 1.5             # пока — за стеной (рисуется, но не видно)
	for side in ["Left", "Right"]:
		var t := Node3D.new()
		t.top_level = true
		L.add_child(t)
		t.global_position = _hole - normal * 1.0
		var po := Node3D.new()
		po.top_level = true
		L.add_child(po)
		var ik := TwoBoneIK3D.new()
		ik.setting_count = 1
		ik.set_root_bone_name(0, "mixamorig_%sArm" % side)
		ik.set_middle_bone_name(0, "mixamorig_%sForeArm" % side)
		ik.set_end_bone_name(0, "mixamorig_%sHand" % side)
		me_sk.add_child(ik)
		ik.set_target_node(0, ik.get_path_to(t))
		ik.set_pole_node(0, ik.get_path_to(po))
		_me_t.append(t)
		_me_p.append(po)
	_me_mod = _MeGrip.new()
	_me_mod.set("owner_safe", self)
	me_sk.add_child(_me_mod)


## Каждый кадр: тело Миши — под камерой, его кисти — на её предплечьях; рывок — к себе.
func _update_me() -> void:
	if not _me_on or not is_instance_valid(me_body) or not is_instance_valid(cam):
		return
	var b := cam.global_basis.orthonormalized()
	var bb := Basis(-b.x, b.y, -b.z) * Basis.from_scale(Vector3.ONE * _me_k)
	var want_head := cam.global_position + b * Vector3(0, -0.06, 0.12)
	me_body.global_transform = Transform3D(bb, want_head - bb * _me_head_local)
	var gsk: Skeleton3D = arms_vera.get_node("Skeleton3D")
	var S := gsk.global_transform
	# левая кисть Миши — на той её руке, что слева в кадре (её правая), и наоборот
	var pairs := [["Right", 0], ["Left", 1]]
	for pr in pairs:
		var hand: Vector3 = S * gsk.get_bone_global_pose(gsk.find_bone("mixamorig_%sHand" % pr[0])).origin
		var fore: Vector3 = S * gsk.get_bone_global_pose(gsk.find_bone("mixamorig_%sForeArm" % pr[0])).origin
		var p := hand.lerp(fore, 0.42)
		p += b.z * 0.05 * _yank                            # рывок — к себе
		_me_t[pr[1]].global_position = p
		var sx := -1.0 if pr[1] == 0 else 1.0
		_me_p[pr[1]].global_position = cam.global_position + b * Vector3(sx * 0.7, -0.45, 0.05)


## Чёрный экран — название игры, мерцает, гаснет.
func _title_card() -> void:
	var t := Label.new()
	t.text = tr("MENU_05")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.add_theme_font_size_override("font_size", 66)
	preload("res://scripts/flicker.gd").style(t)
	t.modulate.a = 0.0
	ui.add_child(t)
	L._sfx("drone", -10.0, 0.8, true)
	var tw := create_tween()
	tw.tween_property(t, "modulate:a", 1.0, 2.0)
	tw.tween_interval(3.0)
	tw.tween_property(t, "modulate:a", 0.0, 1.5)
	await tw.finished
	await get_tree().create_timer(0.5).timeout


## Руки Миши: голова скрыта, пальцы сжаты на её руках, при рывке — белеют от усилия (дрожат).
class _MeGrip extends SkeletonModifier3D:
	var owner_safe: Node
	var _f := []
	var _head := -1

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null:
			return
		if _head < 0:
			_head = sk.find_bone("mixamorig_Head")
			for side in ["Left", "Right"]:
				for g in ["Index", "Middle", "Ring", "Pinky"]:
					for k in [1, 2, 3]:
						var f := sk.find_bone("mixamorig_%sHand%s%d" % [side, g, k])
						if f >= 0:
							_f.append([f, k])
				for k in [1, 2, 3]:
					var f := sk.find_bone("mixamorig_%sHandThumb%d" % [side, k])
					if f >= 0:
						_f.append([f, 0])
		sk.set_bone_pose_scale(_head, Vector3.ONE * 0.001)
		var y: float = owner_safe.get("_yank") if owner_safe else 0.0
		for e in _f:
			var r := sk.get_bone_pose_rotation(e[0])
			var a: float = (0.45 if e[1] == 0 else 0.95) + randf_range(-0.04, 0.04) * (1.0 + y * 3.0)
			sk.set_bone_pose_rotation(e[0], r * Quaternion(Vector3.RIGHT, a))


## Длинные руки: плечо смотрит на цель, предплечье и кисть — прямо, рука вытягивается до цели;
## тонкие (кость сужена), пальцы длинные и костлявые, подёргиваются. Кисть доворачивается ладонью вниз.
class _LongArms extends SkeletonModifier3D:
	var target_l := Vector3.ZERO
	var target_r := Vector3.ZERO
	var follow := false          ## держит: цели — за камерой
	var grip := 0.0
	var palm_down := Vector3.DOWN
	var owner_safe: Node
	var _b := {}
	var _t := 0.0

	func _arm(sk: Skeleton3D, side: String, target: Vector3) -> void:
		if not _b.has(side):
			var up := sk.find_bone("mixamorig_%sArm" % side)
			var fo := sk.find_bone("mixamorig_%sForeArm" % side)
			var ha := sk.find_bone("mixamorig_%sHand" % side)
			var fingers := []
			var roots := []
			for g in ["Index", "Middle", "Ring", "Pinky", "Thumb"]:
				for k in [1, 2, 3]:
					var f := sk.find_bone("mixamorig_%sHand%s%d" % [side, g, k])
					if f >= 0:
						fingers.append(f)
						if k == 1:
							roots.append(f)
			var fr := sk.get_bone_rest(fo)
			var hr := sk.get_bone_rest(ha)
			var v := fr.origin + fr.basis * hr.origin
			var hg := sk.get_bone_global_rest(ha)
			var ug0 := sk.get_bone_global_rest(up)
			var mid1 := sk.get_bone_global_rest(sk.find_bone("mixamorig_%sHandMiddle1" % side)).origin
			var ind := sk.get_bone_global_rest(sk.find_bone("mixamorig_%sHandIndex1" % side)).origin
			var pin := sk.get_bone_global_rest(sk.find_bone("mixamorig_%sHandPinky1" % side)).origin
			var fdir := (mid1 - hg.origin).normalized()
			var lat := (ind - pin).normalized()
			var palm := fdir.cross(lat)
			var palm_up := (ug0.basis.orthonormalized().inverse() * palm).normalized()
			_b[side] = [up, fo, ha, fingers, v, palm_up, roots]
		var d: Array = _b[side]
		var up: int = d[0]
		var fo: int = d[1]
		var ha: int = d[2]
		var v: Vector3 = d[4]
		sk.set_bone_pose_rotation(fo, sk.get_bone_rest(fo).basis.get_rotation_quaternion())
		sk.set_bone_pose_rotation(ha, sk.get_bone_rest(ha).basis.get_rotation_quaternion())
		var S := sk.global_transform
		var ug := sk.get_bone_global_pose(up)
		var sh: Vector3 = S * ug.origin
		var to_s: Vector3 = S.affine_inverse().basis * (target - sh)
		var len0: float = (ug.basis.orthonormalized() * v).length()
		var cur_dir: Vector3 = (ug.basis.orthonormalized() * v).normalized()
		if to_s.length() < 0.001:
			return
		var want_dir := to_s.normalized()
		var nb := Basis(Quaternion(cur_dir, want_dir)) * ug.basis.orthonormalized()
		var palm_now: Vector3 = nb * (d[5] as Vector3)
		var palm_want: Vector3 = S.affine_inverse().basis * palm_down
		var a := palm_now - want_dir * want_dir.dot(palm_now)
		var b := palm_want - want_dir * want_dir.dot(palm_want)
		if a.length() > 0.001 and b.length() > 0.001:
			var ang := a.normalized().signed_angle_to(b.normalized(), want_dir)
			nb = Basis(want_dir, ang) * nb
		var par := sk.get_bone_parent(up)
		var pg := sk.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis()
		sk.set_bone_pose_rotation(up, Quaternion((pg.inverse() * nb).orthonormalized()))
		var s := maxf(to_s.length() / maxf(len0, 0.01), 0.6)
		const THIN := 0.74
		sk.set_bone_pose_scale(up, Vector3(THIN, s, THIN))
		# кисть: длина — как была, толщина — чуть тоньше обычной (костлявая)
		sk.set_bone_pose_scale(ha, Vector3(0.82 / THIN, 1.05 / s, 0.82 / THIN))
		for f in d[6]:
			sk.set_bone_pose_scale(f, Vector3(0.8, 1.4, 0.8))      # длинные тонкие пальцы
		for f in d[3]:
			var r := sk.get_bone_pose_rotation(f)
			var tw := sin(_t * 23.0 + f * 1.7) * 0.06              # подёргиваются
			sk.set_bone_pose_rotation(f, r * Quaternion(Vector3.RIGHT, 0.2 + 0.85 * grip + tw))

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null:
			return
		_t += 1.0 / 60.0
		if follow and owner_safe:
			var g: Array = owner_safe.call("_grab_points")
			target_l = g[0]
			target_r = g[1]
		_arm(sk, "Left", target_r)
		_arm(sk, "Right", target_l)
		if owner_safe and owner_safe.get("arms_mat"):
			var m: ShaderMaterial = owner_safe.get("arms_mat")
			m.set_shader_parameter("wrist", target_l)
			m.set_shader_parameter("wrist2", target_r)


# ---------------------------------------------------------------- открыто
func _open() -> void:
	opened = true
	L._sfx3d("click", plate_pos(), 0.0, 0.6, true)
	var tw := create_tween()
	tw.tween_property(core, "rotation:z", -TURN, 0.2)
	await get_tree().create_timer(0.5).timeout
	L.inv.remove("v_hairpin")
	L.targets.erase(_target)
	await _stop()
	L._sfx3d("creak", plate_pos(), -6.0, 1.3, true)
	for lf in leaves:
		var sg: float = (lf.get_child(0) as Node3D).get_meta("sgn", 1.0)
		create_tween().tween_property(lf, "rotation:y", sg * 1.7, 1.2).set_trans(Tween.TRANS_SINE)
	_on_open()


## Тайник открыт. Что внутри — дальше придумаем.
func _on_open() -> void:
	pass
