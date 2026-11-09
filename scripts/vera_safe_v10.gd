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
## ARMS_ENDING (сейчас включено) — вместо скримера выше финал главы: руки из тайника затаскивают Мишу внутрь.
## MIDPICK_SCARE (сейчас включено) — как именно:
##   * пока ковыряешь замок — изнутри тихие звуки (скрежет, дыхание), дверцы иногда чуть выгибаются;
##   * первый штифт открылся — обманка: тишина, изнутри удар всем телом, дверцы выгибаются, замок держит;
##     потом медленно когтями по дверце. Второй штифт;
##   * посреди второго штифта, в случайный миг (или через несколько секунд, если тянешь), замок сам щёлкает
##     изнутри — и дверцы настежь, маска прямо в лицо, крик, кадр-вспышка. Миша отшатывается, маска за ним,
##     руки из темноты — в плечи; Миша хватается за них, дважды пытается отодрать — рывок, маска в лицо,
##     чернота, шёпот у уха, название игры.
##   false — прежний финал: после первого штифта, Мишу отбрасывает на пол, руки тащат с пола (_arms_ending_old).
## Всё для финала грузится в фоне заранее и один раз рисуется под чёрной шторкой в начале мини-игры (_prewarm) —
## в скримере ничего не подгружается.

const PINS := 2
const TOL := 0.1            ## «нужное место» шпильки: ± рад — открывается полностью
const SOFT := 0.6           ## дальше этого от нужного места замок не поворачивается совсем
const TURN := 1.3           ## на сколько поворачивается личинка, рад
const ARMS_ENDING := true   ## false — прежний скример (Вера бросается в лицо) и мини-игра до конца
const MIDPICK_SCARE := true ## true — обманка после 1-го штифта и скример посреди 2-го; false — прежний финал (после 1-го)
const FLASH_TEX := "res://textures/flash_vera.png"
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
var arms_vera: Node3D
var arms_mod: SkeletonModifier3D


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
	cam.cull_mask = _old_cam.cull_mask & ~(1 << 12)  # как у игрока (тело для зеркал не видно) и без свечи в руке — она у игрока, не тут
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
	_turn = 0.0
	_ang = 0.0
	_new_sweet()
	if ARMS_ENDING and not _scared:
		await _prewarm()                              # пока экран чёрный — финал рисуется один раз заранее
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
		return                                        # вырывается сам — ввод не нужен
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
	if _warm and _prep_step < 4 and (not _on or _busy) and not _scared:
		if ResourceLoader.load_threaded_get_status(REMY) == ResourceLoader.THREAD_LOAD_LOADED \
				and ResourceLoader.load_threaded_get_status(MASK) == ResourceLoader.THREAD_LOAD_LOADED:
			_prep_next()
	_tt += delta
	if _cam_live and is_instance_valid(cam):
		_cam_at()
		if arms_mod:                                   # её ладони — к Мише (вниз и к камере), когти — в него
			var cb := cam.global_basis
			arms_mod.set("palm_down", (-cb.y * 0.6 + cb.z * 0.8).normalized())
	if _twitch:
		_twitch_t -= delta
		if _twitch_t <= 0.0:
			_twitch_t = randf_range(0.2, 0.7)
			_mask_tilt_to = Vector2(randf_range(-0.5, 0.5), randf_range(-0.25, 0.25))
		_mask_tilt = _mask_tilt.move_toward(_mask_tilt_to, delta * 14.0)
	if _mask_live and is_instance_valid(mask):
		_place_mask(_mask_out)
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
	if ARMS_ENDING and MIDPICK_SCARE and not _scared:
		_dread(delta)
		if _armed:
			_late_t -= delta
			if (_hold and _turn >= _scare_at) or _late_t <= 0.0:
				_armed = false
				_scared = true
				_busy = true
				_hold = false
				_arms_ending()
				return
	if _turn >= 0.999:
		_pin_done()


func _pin_done() -> void:
	_busy = true
	_hold = false
	_pins_done += 1
	L._sfx3d("click", plate_pos(), -2.0, 0.9, true)
	if ARMS_ENDING and MIDPICK_SCARE and not _scared:
		if _pins_done == 1:
			_fakeout()
		else:                                         # на всякий случай: второй штифт не должен успеть открыться
			_scared = true
			_arms_ending()
		return
	if _pins_done >= PINS:
		_open()
		return
	if not _scared:
		_scared = true
		if ARMS_ENDING:
			_arms_ending_old()
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
const SOUNDS := ["door", "scream_cabinet", "cabinet_riser", "cabinet_final", "sting", "attic_thud", "breath_dark", "scratch", "whisper_harsh",
	"thump", "scream", "drag", "drone", "giggle", "cabinet_strain", "cabinet_bang", "heartbeat", "whisper_old", "creak", "click"]
var _prepared := false
var _warm := false
var _prep_step := 0
var arms_light: OmniLight3D
var mask_light: OmniLight3D
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
var _mask_out := 0.0             ## насколько маска вылезла из темноты (м)
var cold: OmniLight3D
# борьба и затягивание (всё — плавные величины; камера и руки ставятся по ним каждый кадр)
const ARM_DEPTH := 0.1           ## плечевые суставы её рук — на столько за стеной (м)
const GRIP_D := 0.11             ## Миша хватает её руку на столько выше её кисти (м)
var _pull := 0.0                 ## 0..1 — Миша отдирает её руки от себя
var _strain := 0.0               ## дрожь от усилия
var _e := 0.0                    ## путь затягивания: 0 — лежит на полу, 1 — у самых дверец
var _tilt := 0.0                 ## откидывает голову назад, когда тянет (рад)
var _me_reach := 0.0             ## 0 — его руки внизу, вне кадра; 1 — держат её руки
var _me_palm := 0.09             ## от запястья до костяшек, м
var _me_fp := [[Vector3.RIGHT, Vector3.DOWN], [Vector3.LEFT, Vector3.DOWN]]   ## [пальцы, ладонь] кистей Миши (мир)
var _cam_live := false           ## камера ставится по _e/_tilt каждый кадр
var _fall := Vector3.ZERO
var _ctrl := Vector3.ZERO
var _end := Vector3.ZERO
var _tt := 0.0
var _lunging := false
# скример посреди второго штифта
var _armed := false              ## второй штифт: скример ждёт своего мига
var _scare_at := 0.5             ## на каком повороте личинки (0..1) он случится
var _late_t := 6.0               ## …или через столько секунд работы с замком
var _dread_t := 4.0              ## тихие звуки изнутри, пока ковыряешь замок
var _breath_t := 2.0
var _twitch := false             ## маска дёргается: резкие наклоны, мелкая дрожь
var _mask_tilt := Vector2.ZERO
var _mask_tilt_to := Vector2.ZERO
var _twitch_t := 0.0
var _mask_live := false          ## маска ставится в проём каждый кадр (_mask_out)
var _roll0 := 0.4
var _back := Vector3.ZERO
var flash_rect: TextureRect
var _flash_tex: Texture2D
var _breathe_tw: Array[Tween] = []


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
			_flash_tex = load(FLASH_TEX)
		1:
			_spawn_arms(_hole)
		2:
			mask = (load(MASK) as PackedScene).instantiate()
			L.add_child(mask)
			mask.scale = Vector3.ONE * 1.3
			mask.visible = false
			for mi in mask.find_children("*", "MeshInstance3D", true, false):
				var m := mi as MeshInstance3D
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				for i in m.mesh.get_surface_count():
					var mat := m.get_active_material(i)
					if mat is BaseMaterial3D:
						var d := mat.duplicate() as BaseMaterial3D
						d.albedo_color = Color(0.8, 0.68, 0.58)       # нездоровая желтовато-серая кожа
						d.roughness = 0.45                             # чуть влажная
						m.set_surface_override_material(i, d)
			mask_light = OmniLight3D.new()                     # снизу — тусклый кроваво-красный
			mask_light.light_color = Color(0.8, 0.22, 0.15)
			mask_light.light_energy = 0.75
			mask_light.omni_range = 0.42
			mask_light.visible = false
			L.add_child(mask_light)
			mask_light.global_position = _hole + normal * 0.16 + Vector3.DOWN * 0.27
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
	if _twitch:                                      # дёргается: резкие наклоны головы, мелкая дрожь
		b = b * Basis(Vector3.BACK, _mask_tilt.x) * Basis(Vector3.UP, _mask_tilt.y)
		c += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.0025
	mask.global_transform = Transform3D(b.scaled(Vector3.ONE * 1.3), c)
	if mask_light:
		mask_light.global_position = c + normal * 0.12 + Vector3.DOWN * 0.1


## Новый финал (MIDPICK_SCARE): посреди второго штифта, в случайный миг, без предупреждения.
## Замок сам щёлкает изнутри — и в ту же долю секунды дверцы настежь, маска прямо в лицо (во весь кадр),
## крик, вспышка, кадр-вспышка с лицом Веры. Миша отшатывается — маска высовывается за ним; по бокам от
## неё из темноты — руки, прямо в плечи. Миша хватается за них, дважды пытается отодрать — и рывок к ней,
## маска бросается в лицо — чернота. Тишина. Шёпот у самого уха — и название игры.
func _arms_ending() -> void:
	_prepare_ending()
	var hole := _hole
	var pp := plate_pos()
	help.visible = false
	var held = R.get("held")
	if held is Node3D:
		(held as Node3D).visible = false                 # свеча Миши выпала — её свет тоже
	_kill_breathe()
	# 0) замок открывается изнутри сам: личинка щёлкает до упора, шпильку выталкивает наружу
	L._sfx3d("click", pp, 4.0, 0.55, true)
	var t0 := create_tween().set_parallel()
	t0.tween_property(core, "rotation:z", -TURN, 0.08).set_trans(Tween.TRANS_QUAD)
	t0.tween_property(pick, "position:z", 0.03, 0.08)
	t0.tween_property(self, "_ang", _ang - 0.9, 0.08)
	await get_tree().create_timer(0.2).timeout
	# 1) настежь — и она в лицо
	for lf in leaves:
		var sg: float = (lf.get_child(0) as Node3D).get_meta("sgn", 1.0)
		create_tween().tween_property(lf, "rotation:y", sg * 2.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pick.visible = false
	plate.visible = false
	lamp.light_energy = 0.0                            # свеча выпала из руки
	cold = OmniLight3D.new()                           # мертвенный холодный свет у лица
	cold.light_color = Color(0.62, 0.7, 0.9)
	cold.light_energy = 0.45
	cold.omni_range = 1.4
	cam.add_child(cold)
	cold.position = Vector3(0.0, 0.25, 0.1)
	_twitch = true
	_mask_out = 0.09                                   # лицо — в десяти сантиметрах от глаз
	_mask_live = true
	_place_mask(_mask_out)
	mask.visible = true
	mask_light.visible = true
	arms_light.visible = true
	L._sfx3d("door", pp, 6.0, 0.55, true)
	L._sfx("scream_cabinet", 6.0, 1.0, true)          # удар + многослойный крик — с первой миллисекунды
	L._sfx("cabinet_riser", 0.0, 1.15, true)          # под всем этим — гул и сердце всё чаще
	if L.get("red_flash"):
		L.red_flash.color = Color(1, 1, 1, 0.7)       # белая вспышка → кровавый
		var fl := create_tween()
		fl.tween_property(L.red_flash, "color", Color(0.6, 0, 0, 0.35), 0.06)
		fl.tween_property(L.red_flash, "color:a", 0.0, 0.8)
	cam.fov = 82.0                                     # удар по глазам: картинка «выпрыгивает»
	create_tween().tween_property(cam, "fov", 68.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_subliminal(2, 0.06)
	# 2) Миша отшатывается — а она высовывается за ним
	_roll0 = 0.16
	var c0 := cam.global_position
	_back = hole + normal * 0.78 + Vector3.DOWN * 0.32
	create_tween().tween_property(self, "_mask_out", 0.24, 0.38).set_trans(Tween.TRANS_SINE)
	var t := 0.0
	while t < 0.38:
		await get_tree().process_frame
		t += get_process_delta_time()
		var ek := 1.0 - pow(1.0 - minf(t / 0.38, 1.0), 3.0)
		cam.global_position = c0.lerp(_back, ek)
		_look(cam, hole + Vector3.DOWN * 0.05, _roll0 * ek)
	_subliminal(1, 0.0)
	# 3) по бокам от неё из темноты — руки, прямо в плечи
	_anchor_arms()
	var sv := normal.cross(Vector3.UP).normalized()       # из комнаты — влево в кадре
	var start_l: Vector3 = hole + normal * 0.12 + sv * 0.1
	var start_r: Vector3 = hole + normal * 0.12 - sv * 0.1
	arms_mod.set("target_l", start_l)
	arms_mod.set("target_r", start_r)
	arms_mod.set("grip", 0.0)
	L._sfx3d("scratch", hole, 4.0, 0.7, true)
	await get_tree().process_frame
	arms_vera.visible = true
	_fall = cam.global_position
	_ctrl = hole + normal * 0.42 + Vector3.DOWN * 0.12
	_end = hole + normal * 0.24
	_e = 0.0
	_cam_live = true
	create_tween().tween_property(self, "_mask_out", 0.07, 0.35).set_trans(Tween.TRANS_SINE)   # сама — обратно в темноту, между рук
	var gt := 0.0
	while gt < 0.16:
		await get_tree().process_frame
		gt += get_process_delta_time()
		var k := _ease_jerk(gt / 0.16)
		var g := _grab_points()
		arms_mod.set("target_l", start_l.lerp(g[0], k))
		arms_mod.set("target_r", start_r.lerp(g[1], k))
	arms_mod.set("follow", true)
	create_tween().tween_property(arms_mod, "grip", 1.0, 0.07)
	L._sfx("thump", 4.0, 0.7, true)
	L._sfx3d("giggle", hole, 0.0, 0.5, true)
	create_tween().tween_property(self, "_e", 0.08, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	L._say("VERA_PULL", 2.4)
	# 4) Миша хватается за её руки
	_me_on = true
	_update_me()
	me_body.visible = true
	_me_mod.set("grip", 0.1)
	L._sfx("breath_dark", 2.0, 1.4, true)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_me_reach", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_me_mod, "orient", 1.0, 0.18)
	tw.tween_property(_me_mod, "grip", 1.0, 0.1).set_delay(0.16)
	await tw.finished
	# 5) дважды отдирает её руки — и дважды она дёргает его ближе
	for i in 2:
		L._sfx("cabinet_strain", 3.0, 1.0 + 0.12 * i, true)
		var tp := create_tween().set_parallel()
		tp.tween_property(self, "_pull", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tp.tween_property(self, "_tilt", 0.08, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tp.tween_property(self, "_strain", 1.0, 0.12)
		await get_tree().create_timer(0.3).timeout
		L._sfx("thump", 3.0, 0.6 + 0.12 * i, true)
		L._sfx3d("whisper_harsh", hole, 0.0, 0.85, true)
		var ty := create_tween().set_parallel()
		ty.tween_property(self, "_pull", 0.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ty.tween_property(self, "_tilt", -0.04, 0.08)
		ty.tween_property(self, "_strain", 0.0, 0.08)
		ty.tween_property(self, "_e", _e + 0.13, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.14).timeout
		create_tween().tween_property(self, "_tilt", 0.0, 0.15)
	# 6) рывок — к ней, лицо во весь экран; и она бросается навстречу
	_pull_on = true
	L._sfx("drag", 6.0, 0.7, true)
	var e0 := _e
	var ft := 0.0
	while ft < 0.4:
		await get_tree().process_frame
		ft += get_process_delta_time()
		var k := minf(ft / 0.4, 1.0)
		_e = lerpf(e0, 1.0, k * k)                        # разгоняется
	_twitch = false
	_subliminal(2, 0.07)
	await _lunge()
	# 7) чернота; визг обрывается сам. тишина. шёпот у самого уха — и название игры
	_cam_live = false
	_mask_live = false
	black.color.a = 1.0
	L._say("", 0.1)
	var shriek: AudioStream = L._stream("cabinet_final")
	for a2 in L.find_children("*", "AudioStreamPlayer", true, false) + L.find_children("*", "AudioStreamPlayer3D", true, false):
		if a2.get("stream") != shriek:
			a2.stop()
	await get_tree().create_timer(2.2).timeout         # визг обрывается — и долгая тишина
	L._sfx("whisper_old", 4.0, 0.85, true)
	_end_line("VERA_END", 2.4)
	await get_tree().create_timer(3.2).timeout
	await _title_card()
	get_tree().change_scene_to_file(MENU)


## Обманка после первого штифта: тишина — и изнутри удар всем телом; дверцы выгибаются, замок держит.
## Потом тихо, когти медленно по дверце изнутри. Второй штифт — скример будет где-то посреди него.
func _fakeout() -> void:
	var pp := plate_pos()
	help.visible = false
	_kill_breathe()
	await get_tree().create_timer(0.55).timeout
	L._sfx3d("cabinet_bang", pp - normal * 0.1, 6.0, 1.0, true)
	for lf in leaves:
		var sg: float = (lf.get_child(0) as Node3D).get_meta("sgn", 1.0)
		var tl := create_tween()
		tl.tween_property(lf, "rotation:y", sg * 0.11, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tl.tween_property(lf, "rotation:y", 0.0, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var tj := create_tween().set_parallel()
	tj.tween_property(core, "rotation:z", 0.0, 0.07)
	tj.tween_property(self, "_ang", clampf(_ang + randf_range(-0.7, 0.7), -1.3, 1.3), 0.07)
	var c0 := cam.global_position
	var tb := create_tween()                               # отдёрнулся
	tb.tween_property(cam, "global_position", c0 + normal * 0.06, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tb.tween_property(cam, "global_position", c0, 0.45).set_trans(Tween.TRANS_SINE)
	await tb.finished
	await _shake(0.2, 0.006)
	await get_tree().create_timer(1.6).timeout
	L._sfx3d("scratch", pp - normal * 0.12 + Vector3.DOWN * 0.05, -9.0, 0.45, true)   # когти медленно по дверце изнутри
	await get_tree().create_timer(1.6).timeout
	# второй штифт
	_turn = 0.0
	core.rotation.z = 0.0
	_new_sweet()
	help.visible = true
	_armed = true
	_scare_at = randf_range(0.3, 0.72)
	_late_t = randf_range(5.0, 8.5)
	_breath_t = 0.8
	_dread_t = randf_range(2.0, 3.0)
	L._sfx("heartbeat", -10.0, 1.1, true)
	_busy = false


## Пока ковыряешь замок — изнутри тихие звуки; на втором штифте Миша дышит всё чаще.
func _dread(delta: float) -> void:
	_dread_t -= delta
	_breath_t -= delta
	if _armed and _breath_t <= 0.0:
		_breath_t = randf_range(1.6, 2.4)
		L._sfx("breath_dark", -17.0, 1.3, true)
	if _dread_t > 0.0:
		return
	_dread_t = randf_range(2.5, 4.5) if _armed else randf_range(3.5, 6.0)
	var sv := normal.cross(Vector3.UP).normalized()
	var inside: Vector3 = global_position - normal * 0.2 + sv * randf_range(-0.12, 0.12)
	match randi() % 3:
		0:
			L._sfx3d("scratch", inside, -20.0, randf_range(0.5, 0.65), true)
		1:
			L._sfx3d("breath_dark", inside, -22.0, 0.75, true)
		_:
			_doors_breathe()


## Дверцы чуть выгибаются наружу — будто изнутри на них навалились — и обратно.
func _doors_breathe() -> void:
	_kill_breathe()
	L._sfx3d("creak", plate_pos(), -18.0, 1.5, true)
	for lf in leaves:
		var sg: float = (lf.get_child(0) as Node3D).get_meta("sgn", 1.0)
		var tl := create_tween()
		_breathe_tw.append(tl)
		tl.tween_property(lf, "rotation:y", sg * 0.035, 0.3).set_trans(Tween.TRANS_SINE)
		tl.tween_property(lf, "rotation:y", 0.0, 0.45).set_trans(Tween.TRANS_SINE)


func _kill_breathe() -> void:
	for tw in _breathe_tw:
		if tw and tw.is_valid():
			tw.kill()
	_breathe_tw.clear()
	for lf in leaves:
		lf.rotation.y = 0.0


## Кадр-вспышка: лицо Веры (негатив, кроваво-красное) на frames кадров, через delay секунд.
func _subliminal(frames: int, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_instance_valid(flash_rect):
		return
	flash_rect.visible = true
	for i in frames:
		await RenderingServer.frame_post_draw
	flash_rect.visible = false


func _make_flash() -> void:
	if _flash_tex == null:
		_flash_tex = load(FLASH_TEX)
	flash_rect = TextureRect.new()
	flash_rect.texture = _flash_tex
	flash_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flash_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.visible = false
	ui.add_child(flash_rect)
	ui.move_child(flash_rect, 0)                           # под чёрной шторкой


## Строчка в темноте (поверх чёрного экрана).
func _end_line(key: String, sec: float) -> void:
	var l := Label.new()
	l.text = tr(key)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.offset_left = -520
	l.offset_right = 520
	l.offset_top = -150
	l.offset_bottom = -100
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(0.8, 0.76, 0.7))
	preload("res://scripts/fonts.gd").subtitle(l)
	l.modulate.a = 0.0
	ui.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.4)
	tw.tween_interval(sec)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


## Под чёрной шторкой (начало мини-игры): всё, что появится в финале, один раз рисуется перед камерой —
## шейдеры и текстуры собираются заранее, в скримере ничего не подгружается и не подтормаживает.
func _prewarm() -> void:
	_prepare_ending()
	if not is_instance_valid(flash_rect):
		_make_flash()
	var mt := mask.global_transform
	var bt := me_body.global_transform
	_mask_at(cam.global_position - cam.global_basis.z * 0.45)
	mask.visible = true
	mask_light.visible = true
	arms_light.visible = true
	arms_vera.visible = true
	_me_on = true
	_me_reach = 1.0
	_update_me()
	me_body.visible = true
	flash_rect.visible = true
	for i in 3:
		await RenderingServer.frame_post_draw
	flash_rect.visible = false
	mask.visible = false
	mask_light.visible = false
	arms_light.visible = false
	arms_vera.visible = false
	me_body.visible = false
	_me_on = false
	_me_reach = 0.0
	mask.global_transform = mt
	me_body.global_transform = bt


## Прежний финал (MIDPICK_SCARE = false): сразу после первого штифта, Мишу отбрасывает на пол, руки тащат с пола.
func _arms_ending_old() -> void:
	_prepare_ending()
	var hole := _hole
	var pp := plate_pos()
	help.visible = false
	var held = R.get("held")
	if held is Node3D:
		(held as Node3D).visible = false                 # свеча Миши выпала — её свет тоже
	# без паузы: дверцы — с грохотом настежь, всё сразу на полную
	for lf in leaves:
		var sg: float = (lf.get_child(0) as Node3D).get_meta("sgn", 1.0)
		create_tween().tween_property(lf, "rotation:y", sg * 2.0, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pick.visible = false
	plate.visible = false
	create_tween().tween_property(cam, "fov", 74.0, 0.4)
	L._sfx3d("door", pp, 6.0, 0.55, true)
	L._sfx("scream_cabinet", 6.0, 1.0, true)          # удар + многослойный крик — с первой миллисекунды
	if L.get("red_flash"):
		L.red_flash.color = Color(1, 1, 1, 0.9)       # белая вспышка → кровавый
		var fl := create_tween()
		fl.tween_property(L.red_flash, "color", Color(0.6, 0, 0, 0.55), 0.08)
		fl.tween_property(L.red_flash, "color:a", 0.0, 1.0)
	mask.visible = true
	# Мишу отбрасывает: камера летит назад и вниз, на пол, с завалом набок
	var sp: PhysicsDirectSpaceState3D = (L as Node3D).get_world_3d().direct_space_state
	var out := hole + normal * 2.4                     # отлетает далеко, почти к дивану
	var floor_y: float = L.player.global_position.y
	var hit: Dictionary = sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(out.x, floor_y + 0.5, out.z), Vector3(out.x, floor_y - 0.5, out.z)))
	if not hit.is_empty():
		floor_y = hit.position.y
	_fall = Vector3(out.x, floor_y + 0.3, out.z)
	_ctrl = hole + normal * 1.2 + Vector3.DOWN * 0.7
	_end = hole + normal * 0.06
	var c0 := cam.global_position
	var fall_t := 0.0
	while fall_t < 0.5:
		await get_tree().process_frame
		fall_t += get_process_delta_time()
		var k := minf(fall_t / 0.5, 1.0)
		var hk := 1.0 - pow(1.0 - k, 3.0)
		var vk := k * k
		cam.global_position = Vector3(lerpf(c0.x, _fall.x, hk), lerpf(c0.y, _fall.y, vk), lerpf(c0.z, _fall.z, hk))
		_look(cam, hole + Vector3.DOWN * 0.05, 0.4 * k)
		# пока падаешь — маска на кадр-два прямо перед глазами (вспышки, как сбой)
		var flash := (k > 0.12 and k < 0.2) or (k > 0.5 and k < 0.56)
		if flash:
			var bb := cam.global_basis
			_mask_at(cam.global_position - bb.z * 0.42 - bb.y * 0.12)
		else:
			_place_mask(-0.4)
	_cam_live = true
	L._sfx3d("attic_thud", _fall, 2.0, 0.7, true)
	L._sfx("breath_dark", 0.0, 1.15, true)
	L._sfx("cabinet_riser", 2.0, 1.0, true)           # гул ползёт вверх, сердце всё чаще — до самого конца
	lamp.light_energy = 0.0                            # свеча выпала из руки
	cold = OmniLight3D.new()                           # мертвенный холодный свет у лица
	cold.light_color = Color(0.62, 0.7, 0.9)
	cold.light_energy = 0.45
	cold.omni_range = 1.4
	cam.add_child(cold)
	cold.position = Vector3(0.0, 0.25, 0.1)
	await get_tree().create_timer(0.25).timeout
	# из темноты выплывает маска — и смотрит
	arms_light.visible = true
	mask_light.visible = true
	_place_mask(-0.12)
	L._sfx3d("whisper_harsh", hole, 0.0, 0.7, true)
	var mt := 0.0
	while mt < 0.8:
		await get_tree().process_frame
		mt += get_process_delta_time()
		_place_mask(lerpf(-0.12, 0.08, _smooth(minf(mt / 0.8, 1.0))))
	# руки — рывком из середины проёма, по бокам от лица, — прямо за плечи
	_anchor_arms()
	var sv := normal.cross(Vector3.UP).normalized()       # из комнаты — влево в кадре
	var start_l: Vector3 = hole + normal * 0.12 + sv * 0.1
	var start_r: Vector3 = hole + normal * 0.12 - sv * 0.1
	arms_mod.set("target_l", start_l)
	arms_mod.set("target_r", start_r)
	arms_mod.set("grip", 0.0)
	L._sfx3d("scratch", hole, 2.0, 0.7, true)
	await get_tree().process_frame
	arms_vera.visible = true
	var gt := 0.0
	while gt < 0.32:
		await get_tree().process_frame
		gt += get_process_delta_time()
		var k := _ease_jerk(gt / 0.32)
		var g := _grab_points()
		arms_mod.set("target_l", start_l.lerp(g[0], k))
		arms_mod.set("target_r", start_r.lerp(g[1], k))
	arms_mod.set("follow", true)
	create_tween().tween_property(arms_mod, "grip", 1.0, 0.08)
	L._sfx("thump", 2.0, 0.7, true)
	L._sfx("scream", -4.0, 0.55, true)
	L._sfx3d("giggle", hole, -2.0, 0.55, true)
	var jolt := create_tween()                             # схватили — и сразу дёрнули к себе
	jolt.tween_property(self, "_e", 0.06, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await jolt.finished
	L._say("VERA_PULL", 3.0)
	# Миша хватается за её руки
	_me_on = true
	_update_me()
	me_body.visible = true
	_me_mod.set("grip", 0.1)
	L._sfx("breath_dark", 2.0, 1.35, true)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_me_reach", 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_me_mod, "orient", 1.0, 0.22)
	tw.tween_property(_me_mod, "grip", 1.0, 0.12).set_delay(0.2)
	await tw.finished
	# борьба: дважды отдирает её руки от себя — и дважды она дёргает его ближе
	for i in 2:
		L._sfx("cabinet_strain", 2.0, 1.0 + 0.1 * i, true)
		var tp := create_tween().set_parallel()
		tp.tween_property(self, "_pull", 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tp.tween_property(self, "_tilt", 0.09, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tp.tween_property(self, "_strain", 1.0, 0.18)
		await tp.finished
		await get_tree().create_timer(0.12).timeout
		L._sfx("thump", 2.0, 0.6 + 0.12 * i, true)
		L._sfx3d("whisper_harsh", hole, 0.0, 0.85, true)
		var ty := create_tween().set_parallel()
		ty.tween_property(self, "_pull", 0.0, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ty.tween_property(self, "_tilt", -0.04, 0.09)
		ty.tween_property(self, "_strain", 0.0, 0.1)
		ty.tween_property(self, "_e", _e + 0.1, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await ty.finished
		create_tween().tween_property(self, "_tilt", 0.0, 0.2)
		await get_tree().create_timer(0.08).timeout
	# последний рывок — быстро, в темноту; он всё ещё держится за её руки
	_pull_on = true
	L._sfx("drag", 4.0, 0.7, true)
	L._sfx("scream", -2.0, 0.45, true)
	var e0 := _e
	var ft := 0.0
	var lunged := false
	while true:
		await get_tree().process_frame
		ft += get_process_delta_time()
		var k := minf(ft / 0.75, 1.0)
		_e = lerpf(e0, 0.92, k * k)                      # разгоняется
		if k > 0.55 and not lunged:
			lunged = true
			_lunge()
		if not lunged:
			_place_mask(0.09)
		elif not _lunging:
			break                                        # лицо вплотную — и всё
	# затянуло — чернота, тишина, заставка
	_cam_live = false
	black.color.a = 1.0
	L._say("", 0.1)
	for a2 in L.find_children("*", "AudioStreamPlayer", true, false) + L.find_children("*", "AudioStreamPlayer3D", true, false):
		a2.stop()
	await get_tree().create_timer(1.8).timeout
	await _title_card()
	get_tree().change_scene_to_file(MENU)


## Маска бросается в лицо с визгом: из проёма — вплотную к камере.
func _lunge() -> void:
	_lunging = true
	if _mask_live:
		L._sfx("cabinet_final", 8.0, 1.0, true)
		var d := (cam.global_position - _hole).dot(normal)
		var tw := create_tween()
		tw.tween_property(self, "_mask_out", d - 0.035, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		await get_tree().create_timer(0.05).timeout       # лицо во весь экран — и всё
		_lunging = false
		return
	L._sfx("cabinet_final", 8.0, 1.0, true)
	var m0 := mask.global_position
	var lt := 0.0
	while lt < 0.3:                                      # 0.2 с — бросок, 0.1 с — лицо во весь экран
		await get_tree().process_frame
		lt += get_process_delta_time()
		var b2 := cam.global_basis
		var tgt: Vector3 = cam.global_position - b2.z * 0.34 - b2.y * 0.15
		_mask_at(m0.lerp(tgt, _ease_jerk(lt / 0.2)))
	_lunging = false


## Маска в точке p, лицом к камере.
func _mask_at(p: Vector3) -> void:
	var to := (cam.global_position - p).normalized()
	mask.global_transform = Transform3D(Basis(Vector3.UP.cross(to).normalized(), Vector3.UP, to).orthonormalized().scaled(Vector3.ONE * 1.3), p)


## Камера по пути затягивания: с пола — к дверцам; откидывает голову, когда тянет.
func _cam_at() -> void:
	var e := _e
	cam.global_position = _fall.lerp(_ctrl, e).lerp(_ctrl.lerp(_end, e), e)
	_look(cam, _hole + Vector3.DOWN * 0.05, _roll0 * (1.0 - e))
	cam.rotate_object_local(Vector3.RIGHT, _tilt)


## Плечевые суставы её рук — сразу за стеной посередине проёма (измерено модификатором уже с ключицами).
func _anchor_arms() -> void:
	var r: Array = arms_mod.get("roots_w")
	var a: Vector3 = r[0]
	var b: Vector3 = r[1]
	if a == Vector3.ZERO and b == Vector3.ZERO:
		return
	arms_vera.global_position += (_hole - normal * ARM_DEPTH + Vector3.UP * 0.03) - (a + b) * 0.5


static func _smooth(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


static func _ease_jerk(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 4.0)


## Куда вцепились её руки: Мише в плечи и грудь — когти видны внизу, по краям кадра.
## Когда он их отдирает (_pull) — её кисти отходят наружу и от него; от усилия всё дрожит.
func _grab_points() -> Array:
	var b := cam.global_basis
	var o := cam.global_position
	var pl := _pull
	var tr := Vector3(sin(_tt * 41.0), sin(_tt * 37.0 + 1.0), 0.0) * 0.005 * _strain
	var zf := clampf((o - _hole).dot(normal) - 0.06, 0.1, 0.3)      # вплотную к проёму — не уходят в стену
	return [o + b * (Vector3(-0.23 - 0.07 * pl, -0.19 + 0.01 * pl, -zf - 0.05 * pl) + tr),
		o + b * (Vector3(0.23 + 0.07 * pl, -0.19 + 0.01 * pl, -zf - 0.05 * pl) - tr)]


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
	arms_mat.set_shader_parameter("hole_at", hole - normal * 0.04)    # у проёма — чернота, дальше — вся рука
	arms_mat.set_shader_parameter("hole_r", 0.3)
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
	arms_vera.global_position += (hole - normal * 0.25) - (ls + rs) * 0.5   # точнее — _anchor_arms() перед финалом
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
	arms_light.light_color = Color(0.55, 0.6, 0.75)
	arms_light.light_energy = 0.6
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
	var MS := me_sk.global_transform
	var hw: Vector3 = MS * me_sk.get_bone_global_rest(me_sk.find_bone("mixamorig_Head")).origin
	_me_head_local = me_body.global_transform.affine_inverse() * hw
	_me_palm = (MS * me_sk.get_bone_global_rest(me_sk.find_bone("mixamorig_LeftHandMiddle1")).origin
		- MS * me_sk.get_bone_global_rest(me_sk.find_bone("mixamorig_LeftHand")).origin).length()
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


## Каждый кадр: тело Миши — под камерой; его кисти обхватывают её руки сверху, чуть выше её кистей,
## пальцы — поперёк её руки, внутрь кадра. Пока руки поднимаются (_me_reach) — идут снизу, из-за кадра.
func _update_me() -> void:
	if not _me_on or not is_instance_valid(me_body) or not is_instance_valid(cam):
		return
	var b := cam.global_basis.orthonormalized()
	var bb := Basis(-b.x, b.y, -b.z) * Basis.from_scale(Vector3.ONE * _me_k)
	var want_head := cam.global_position + b * Vector3(0, -0.05, 0.02)
	me_body.global_transform = Transform3D(bb, want_head - bb * _me_head_local)
	var g := _grab_points()
	var roots: Array = arms_mod.get("roots_w")
	# левая кисть Миши (слева в кадре) — на её руке, что идёт к g[0]: это её правая рука (roots[1])
	var pairs := [[g[0], roots[1], 1.0], [g[1], roots[0], -1.0]]
	var fp := []
	for i in 2:
		var gp: Vector3 = pairs[i][0]
		var root: Vector3 = pairs[i][1]
		var sx: float = pairs[i][2]
		var A := (root - gp).normalized()
		var G := gp + A * GRIP_D
		var P := -b.y
		P = (P - A * A.dot(P)).normalized()                 # ладонь — на её руку сверху
		var F0: Vector3 = b.x * sx                          # пальцы — поперёк её руки, внутрь кадра
		var F := (F0 - A * A.dot(F0) - P * P.dot(F0)).normalized()
		var wrist := G - P * 0.032 - F * _me_palm * 0.45
		var low := cam.global_position + b * Vector3(-0.22 * sx, -0.6, -0.1)
		_me_t[i].global_position = low.lerp(wrist, _me_reach)
		_me_p[i].global_position = cam.global_position + b * Vector3(-0.5 * sx, -0.45, 0.0)
		fp.append([F, P])
	_me_fp = fp


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


## Руки Миши: голова скрыта; кисти повёрнуты так, как задал хозяин (_me_fp: пальцы и ладонь в мире),
## пальцы сжаты на её руках (grip), от усилия дрожат (_strain).
class _MeGrip extends SkeletonModifier3D:
	var owner_safe: Node
	var orient := 0.0
	var grip := 0.0
	var _hands := []             ## [кисть, предплечье, пальцы в осях кисти, ладонь в осях кисти]
	var _f := []                 ## [кость, фаланга (−1 — большой), знак сгиба]
	var _head := -1
	var _t := 0.0

	static func _frame(a: Vector3, b: Vector3) -> Basis:
		var x := a.normalized()
		var y := (b - x * x.dot(b)).normalized()
		return Basis(x, y, x.cross(y))

	func _setup(sk: Skeleton3D) -> void:
		_head = sk.find_bone("mixamorig_Head")
		for side in ["Left", "Right"]:
			var h := sk.find_bone("mixamorig_%sHand" % side)
			var hr := sk.get_bone_global_rest(h)
			var mr := sk.get_bone_global_rest(sk.find_bone("mixamorig_%sHandMiddle1" % side))
			var ir := sk.get_bone_global_rest(sk.find_bone("mixamorig_%sHandIndex1" % side))
			var pr := sk.get_bone_global_rest(sk.find_bone("mixamorig_%sHandPinky1" % side))
			var f_sk := (mr.origin - hr.origin).normalized()
			var l_sk := ir.origin - pr.origin
			l_sk = (l_sk - f_sk * f_sk.dot(l_sk)).normalized()
			var p_sk := f_sk.cross(l_sk).normalized()       # левая — из ладони; правая — из тыльной стороны
			if side == "Right":
				p_sk = -p_sk
			var hb := hr.basis.orthonormalized().inverse()
			_hands.append([h, sk.get_bone_parent(h), (hb * f_sk).normalized(), (hb * p_sk).normalized()])
			# в какую сторону крутить фаланги, чтобы пальцы сгибались к ладони
			for g in ["Index", "Middle", "Ring", "Pinky", "Thumb"]:
				for k in [1, 2, 3]:
					var fb := sk.find_bone("mixamorig_%sHand%s%d" % [side, g, k])
					var cb := sk.find_bone("mixamorig_%sHand%s%d" % [side, g, k + 1])
					if fb < 0 or cb < 0:
						continue
					var fg := sk.get_bone_global_rest(fb)
					var d := (sk.get_bone_global_rest(cb).origin - fg.origin).normalized()
					var xg := fg.basis.orthonormalized() * Vector3.RIGHT
					var sgn := 1.0 if xg.cross(d).dot(p_sk) >= 0.0 else -1.0
					_f.append([fb, -1 if g == "Thumb" else k - 1, sgn])

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk == null:
			return
		if _hands.is_empty():
			_setup(sk)
		_t += 1.0 / 60.0
		sk.set_bone_pose_scale(_head, Vector3.ONE * 0.001)
		if orient > 0.001 and owner_safe:
			var fp: Array = owner_safe.get("_me_fp")
			var Si := sk.global_transform.basis.orthonormalized().inverse()
			for i in 2:
				var h: Array = _hands[i]
				var want := _frame(Si * (fp[i][0] as Vector3), Si * (fp[i][1] as Vector3)) * _frame(h[2], h[3]).inverse()
				var cur := sk.get_bone_global_pose(h[0]).basis.orthonormalized()
				var tgt := Basis(Quaternion(cur).slerp(Quaternion(want.orthonormalized()), clampf(orient, 0.0, 1.0)))
				var fg := sk.get_bone_global_pose(h[1]).basis.orthonormalized()
				sk.set_bone_pose_rotation(h[0], Quaternion((fg.inverse() * tgt).orthonormalized()))
		var st: float = owner_safe.get("_strain") if owner_safe else 0.0
		for e in _f:
			var a: float = 0.55 if e[1] < 0 else [0.95, 1.15, 0.85][e[1]]
			a = a * lerpf(0.12, 1.0, grip) + sin(_t * 47.0 + e[0]) * 0.035 * st
			var r := sk.get_bone_pose_rotation(e[0])
			sk.set_bone_pose_rotation(e[0], r * Quaternion(Vector3.RIGHT, a * e[2]))


## Длинные руки: плечо смотрит на цель, предплечье и кисть — прямо, рука вытягивается до цели;
## тонкие (кость сужена), пальцы длинные и костлявые, подёргиваются. Кисть доворачивается ладонью вниз.
class _LongArms extends SkeletonModifier3D:
	var target_l := Vector3.ZERO
	var target_r := Vector3.ZERO
	var follow := false          ## держит: цели — за камерой
	var grip := 0.0
	var palm_down := Vector3.DOWN
	var owner_safe: Node
	var roots_w := [Vector3.ZERO, Vector3.ZERO]   ## плечевые суставы (мир): [левый, правый] — уже с ключицами
	var clav_ang := 0.85                         ## ключицы — вперёд к проёму (рад)
	var _b := {}
	var _t := 0.0
	var _ready_b := false
	var _collapse := []
	var _clav := []                              ## [кость, знак]
	var _up_s := Vector3.UP
	var _arm_b := []

	func _setup(sk: Skeleton3D) -> void:
		_ready_b = true
		for n in ["mixamorig_LeftUpLeg", "mixamorig_RightUpLeg", "mixamorig_Neck"]:
			var i := sk.find_bone(n)
			if i >= 0:
				_collapse.append(i)
		var head := sk.get_bone_global_rest(sk.find_bone("mixamorig_Head")).origin
		var hips := sk.get_bone_global_rest(sk.find_bone("mixamorig_Hips")).origin
		_up_s = (head - hips).normalized()
		var toe := sk.get_bone_global_rest(sk.find_bone("mixamorig_LeftToeBase")).origin
		var foot := sk.get_bone_global_rest(sk.find_bone("mixamorig_LeftFoot")).origin
		var fwd := toe - foot
		fwd = (fwd - _up_s * _up_s.dot(fwd)).normalized()
		for side in ["Left", "Right"]:
			var c := sk.find_bone("mixamorig_%sShoulder" % side)
			var a := sk.find_bone("mixamorig_%sArm" % side)
			_arm_b.append(a)
			var d: Vector3 = sk.get_bone_global_rest(a).origin - sk.get_bone_global_rest(c).origin
			var sgn := 1.0 if (Basis(_up_s, 0.5) * d).dot(fwd) > d.dot(fwd) else -1.0
			_clav.append([c, sgn])

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
		var Si := S.affine_inverse()
		var ug := sk.get_bone_global_pose(up)
		var sh: Vector3 = S * ug.origin
		# локоть: рука выходит из тайника вперёд над комодом и только потом опускается к Мише
		var E := target
		if owner_safe:
			E = sh.lerp(target, 0.5)                   # рука прямая: из проёма — к Мише (над комодом проходит)
		# плечо → локоть
		var fr := sk.get_bone_rest(fo)
		var hr := sk.get_bone_rest(ha)
		var to_e: Vector3 = Si.basis * (E - sh)
		if to_e.length() < 0.001:
			return
		var ub := ug.basis.orthonormalized()
		var len_u: float = (ub * fr.origin).length()
		var want_dir := to_e.normalized()
		var nb := Basis(Quaternion((ub * fr.origin).normalized(), want_dir)) * ub
		var palm_now: Vector3 = nb * (d[5] as Vector3)
		var palm_want: Vector3 = Si.basis * palm_down
		var a := palm_now - want_dir * want_dir.dot(palm_now)
		var b := palm_want - want_dir * want_dir.dot(palm_want)
		if a.length() > 0.001 and b.length() > 0.001:
			nb = Basis(want_dir, a.normalized().signed_angle_to(b.normalized(), want_dir)) * nb
		var par := sk.get_bone_parent(up)
		var pg := sk.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis()
		sk.set_bone_pose_rotation(up, Quaternion((pg.inverse() * nb).orthonormalized()))
		const THIN := 0.8
		var s1 := maxf(to_e.length() / maxf(len_u, 0.01), 0.05)
		sk.set_bone_pose_scale(up, Vector3(THIN, s1, THIN))
		# локоть → кисть (с учётом растянутого плеча)
		var fg := sk.get_bone_global_pose(fo)
		var P: Basis = sk.get_bone_global_pose(up).basis            # с масштабом
		var to_h: Vector3 = (Si * target) - fg.origin
		if to_h.length() < 0.001:
			return
		var want_l := (P.inverse() * to_h).normalized()
		var hdir := hr.origin.normalized()
		var R := Quaternion(hdir, want_l)
		sk.set_bone_pose_rotation(fo, R)
		var seg := (P * (R * hr.origin)).length()
		var s2 := maxf(to_h.length() / maxf(seg, 0.001), 0.05)
		const THIN_F := 0.72
		sk.set_bone_pose_scale(fo, Vector3(THIN_F, s2, THIN_F))
		# кисть: обычной длины, чуть тоньше (костлявая)
		# компенсируем сужение и растяжение, которые кисть унаследовала от плеча и предплечья
		var inh: Basis = sk.get_bone_global_pose(fo).basis * sk.get_bone_rest(ha).basis
		var sc := inh.get_scale()
		var want_k: float = 0.82 * (ub * fr.origin).length() / maxf(len_u, 0.001)
		sk.set_bone_pose_scale(ha, Vector3(0.82 / maxf(sc.x, 0.01), 1.0 / maxf(sc.y, 0.01), 0.82 / maxf(sc.z, 0.01)) * (ug.basis.get_scale().x))
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
		if not _ready_b:
			_setup(sk)
		for i in _collapse:
			sk.set_bone_pose_scale(i, Vector3.ONE * 0.001)       # ноги и голова — не нужны (могли бы торчать из стены)
		# ключицы — вперёд: плечевые суставы сходятся к середине и выходят вперёд груди
		for c in _clav:
			var cg := sk.get_bone_global_pose(c[0]).basis.orthonormalized()
			var nb := Basis(_up_s, float(c[1]) * clav_ang) * cg
			var par := sk.get_bone_parent(c[0])
			var pg := sk.get_bone_global_pose(par).basis.orthonormalized()
			sk.set_bone_pose_rotation(c[0], Quaternion((pg.inverse() * nb).orthonormalized()))
		var S := sk.global_transform
		roots_w = [S * sk.get_bone_global_pose(_arm_b[0]).origin, S * sk.get_bone_global_pose(_arm_b[1]).origin]
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
