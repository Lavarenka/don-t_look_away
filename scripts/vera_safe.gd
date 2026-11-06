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

const PINS := 2
const TOL := 0.1            ## «нужное место» шпильки: ± рад — открывается полностью
const SOFT := 0.6           ## дальше этого от нужного места замок не поворачивается совсем
const TURN := 1.3           ## на сколько поворачивается личинка, рад

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
