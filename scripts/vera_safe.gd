extends Node3D
## Тайник за картиной в спальне Веры: картина упала (vera_call.gd) — за ней в стене старый шкафчик:
## наличник с профилем, две филёнчатые дверцы на кованых петлях-стрелах, три накладки — и на каждой
## навесной замок. Модель — models/bedroom/vera_safe.glb (tools/blender/make_vera_safe.py).
##
## Мини-игра «поймай щелчок» (шпилькой-невидимкой, крупным планом):
##   мышь влево-вправо — шпилька ходит в скважине, как стрелка; где-то спрятано «нужное место».
##   Чем ближе к нему — тем чаще и громче тикают штифты и дрожит шпилька. Попал — отчётливый щелчок,
##   шпилька вздрагивает: жми ЛКМ (или E / пробел; есть ещё полсекунды) — личинка проворачивается,
##   дужка выскакивает, замок падает на пол, накладка откидывается — камера к следующему замку.
##   Нажал мимо — шпилька срывается с дребезгом, «нужное место» чуть сдвигается, а изнутри бьют
##   в дверцу. ПКМ — отойти (открытые замки так и остаются открытыми).
## Скример (ARMS_ENDING) — на втором щелчке: дужка выскочила, полсекунды облегчения — и изнутри
##   срывает третий замок вместе с пробоем, дверцы настежь: маска в лицо, руки из темноты затаскивают
##   Мишу внутрь (_arms_ending). Всё для финала грузится в фоне заранее и один раз рисуется под чёрной
##   шторкой в начале мини-игры (_prewarm) — в скримере ничего не подгружается.
## ARMS_ENDING = false — без скримера: три замка — и дверцы открываются (_open → _on_open).
## Прежний тайник (простые дверцы, «держи ЛКМ», обманка) — scripts/vera_safe_v10.gd,
## переключатель SAFE_V2 в vera_call.gd.

const ARMS_ENDING := true            ## false — без скримера: три замка — и тайник открыт
const SCARE_LOCK := 2                ## на каком по счёту открытом замке — финал
const WIN := [0.07, 0.06, 0.05]      ## «нужное место» шпильки у замков 1..3: ± рад
const GRACE := 0.5                   ## после щелчка столько секунд можно жать ЛКМ
const NEAR := 0.4                    ## ближе этого (рад) к нужному месту штифты тикают чаще и громче
const CAM_D := 0.15                  ## камера — на таком расстоянии от скважины
const LAMP_E := 0.75                 ## свеча у замка (крупный план)
const GLINT_LAYER := 1 << 17         ## замки, накладки, шпилька: их одних подсвечивает «блик» у камеры
const MODEL := "res://models/bedroom/vera_safe.glb"
const MODEL_SIZE := Vector2(0.4, 0.45)   ## проём модели (м)
const FLASH_TEX := "res://textures/flash_vera.png"
const MENU := "res://scenes/menu.tscn"
const VENEER := preload("res://shaders/veneer.gdshader")
const METAL := preload("res://shaders/old_metal.gdshader")

var L: Node
var R: Node
var normal := Vector3.BACK  ## из стены в комнату
var size := Vector2(0.3, 0.38)
var model: Node3D
var leaves: Array[Node3D] = []        ## петли дверец (крутятся по y); мета "sgn": −1 левая, +1 правая
var locks: Array[Dictionary] = []     ## замки сверху вниз: root, body, plug (личинка), shackle (дужка), hasp (накладка)
var pick_mesh: Node3D
var opened := false
var _lock := 0                        ## сколько замков уже открыто = какой сейчас (с нуля)
var _scared := false
var _target: Dictionary

# мини-игра
var _on := false
var _busy := false          ## скример / переходы — ввод не принимается
var cam: Camera3D
var _old_cam: Camera3D
var _cam_base := Vector3.ZERO
var _cam_look := Vector3.ZERO
var pick: Node3D            ## шпилька: корень — в скважине текущего замка (крутится вместе с личинкой)
var pick_arm: Node3D        ## …а сама она — на _ang вокруг оси скважины
var _ang := 0.0             ## шпилька, рад (−1.3..1.3)
var _sweet := 0.0           ## нужное место
var _in_win := false
var _grace := 0.0
var _near := 0.0
var _jolt := 0.0
var _lockout := 0.0
var _tick_t := 0.0
var _fails := 0
var ui: CanvasLayer
var black: ColorRect
var help: Label
var lamp: OmniLight3D
var glint: OmniLight3D       ## блик на металле — только слой GLINT_LAYER (дерево от него не бликует)
# финал с руками
var _pull_on := false        ## идёт затягивание — ввод не принимается
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
	visible = false                                     # пока картина висит — шкафчика не видно (vera_call._fall)


func _build() -> void:
	model = (load(MODEL) as PackedScene).instantiate()
	add_child(model)
	model.scale = Vector3.ONE * minf(size.x / MODEL_SIZE.x, size.y / MODEL_SIZE.y)
	model.position = Vector3(0, 0, -0.003)              # задний край наличника — к самой стене
	_materials()
	for nm in ["HingeL", "HingeR"]:
		var h := model.find_child(nm, true, false) as Node3D
		h.set_meta("sgn", -1.0 if nm == "HingeL" else 1.0)
		leaves.append(h)
	for i in 3:
		var root := model.find_child("Lock%d" % (i + 1), true, false) as Node3D
		locks.append({
			"root": root,
			"body": root.find_child("Lock%dBody" % (i + 1), true, false),
			"plug": root.find_child("Lock%dPlug" % (i + 1), true, false),
			"shackle": root.find_child("Lock%dShackle" % (i + 1), true, false),
			"hasp": model.find_child("Hasp%d" % (i + 1), true, false),
		})
	pick_mesh = model.find_child("Pick", true, false) as Node3D
	pick_mesh.visible = false
	var shiny: Array[Node] = [pick_mesh]
	for lk in locks:
		shiny.append(lk["root"])
		shiny.append(lk["hasp"])
	for n in shiny:
		if n == null:
			continue
		for mi in [n] + n.find_children("*", "MeshInstance3D", true, false):
			if mi is MeshInstance3D:
				(mi as MeshInstance3D).layers |= GLINT_LAYER


## Материалы по именам из Blender: дерево — шпон под старым лаком (veneer.gdshader), железо, латунь,
## сталь, шпилька — old_metal.gdshader (потемнело, ржавчина/патина пятнами, рёбра затёрты до блеска).
func _materials() -> void:
	var wood := ShaderMaterial.new()
	wood.shader = VENEER
	wood.set_shader_parameter("wood_a", Color(0.2, 0.1, 0.05))
	wood.set_shader_parameter("wood_b", Color(0.07, 0.035, 0.018))
	wood.set_shader_parameter("grain_scale", 2.4)
	wood.set_shader_parameter("clearcoat_k", 0.35)          # лак старый, мутный
	wood.set_shader_parameter("rough_k", 1.8)
	wood.set_shader_parameter("age", 0.85)
	wood.set_shader_parameter("seed", 3.7)
	wood.set_shader_parameter("floor_y", -100.0)
	var M := {
		"Wood": wood,
		"Iron": _metal(Color(0.07, 0.066, 0.062), Color(0.3, 0.29, 0.28), Color(0.15, 0.065, 0.028), 0.8, 0.55, 0.35, 0.45, 110.0),
		"Brass": _metal(Color(0.3, 0.215, 0.085), Color(0.72, 0.55, 0.28), Color(0.065, 0.06, 0.035), 1.0, 0.4, 0.22, 0.7, 80.0),
		"Steel": _metal(Color(0.26, 0.26, 0.27), Color(0.58, 0.58, 0.6), Color(0.16, 0.075, 0.035), 1.0, 0.36, 0.2, 0.55, 140.0),
		"Pin": _metal(Color(0.03, 0.028, 0.026), Color(0.38, 0.38, 0.4), Color(0.15, 0.08, 0.04), 0.7, 0.32, 0.1, 0.85, 140.0),
	}
	var kh := StandardMaterial3D.new()
	kh.albedo_color = Color(0, 0, 0)
	kh.roughness = 1.0
	M["Keyhole"] = kh
	var vd := StandardMaterial3D.new()                  # темнота внутри — без света вообще
	vd.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vd.albedo_color = Color(0, 0, 0)
	M["Void"] = vd
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i)
			var nm := src.resource_name if src else ""
			if M.has(nm):
				m.set_surface_override_material(i, M[nm])


func _metal(base: Color, worn: Color, rust_c: Color, met: float, rough: float, rust: float, wear: float, sc: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = METAL
	m.set_shader_parameter("base_col", base)
	m.set_shader_parameter("worn_col", worn)
	m.set_shader_parameter("rust_col", rust_c)
	m.set_shader_parameter("metal", met)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("rust", rust)
	m.set_shader_parameter("wear", wear)
	m.set_shader_parameter("scale", sc)
	m.set_shader_parameter("seed", randf() * 50.0)
	return m


## Скважина текущего замка (звуки, камера).
func plate_pos() -> Vector3:
	return (locks[mini(_lock, locks.size() - 1)]["plug"] as Node3D).global_position


## Картина упала — тайник виден: цель для E.
func reveal() -> void:
	visible = true
	if ARMS_ENDING:                                   # модели финала грузятся в фоне, пока игрок идёт к замку
		for r in [REMY, MASK]:
			ResourceLoader.load_threaded_request(r)
		_warm = true
	R._target("v_safe", global_position + normal * 0.03, "BR_SAFE3", 0.35, 1.8)
	for t in L.targets:
		if t.get("id") == "v_safe":
			_target = t


func can_use() -> bool:
	return not opened and not _on


func interact() -> void:
	if opened or _on:
		return
	if not L.inv.has("v_hairpin"):
		L._sfx3d("lock_jam", plate_pos(), -10.0, 1.1, true)
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
	cam.cull_mask = _old_cam.cull_mask & ~(1 << 12)  # как у игрока (тело для зеркал не видно) и без свечи в руке
	L.add_child(cam)
	_cam_to(_lock)
	var held = R.get("held")
	if held is Node3D:
		(held as Node3D).visible = false              # свеча в руке — у самого замка: светит лампа ниже
	lamp = OmniLight3D.new()                       # тёплый свет свечи в руке — на замок, сбоку: видна фактура
	lamp.light_color = Color(1.0, 0.66, 0.36)
	lamp.light_energy = LAMP_E
	lamp.omni_range = 1.6
	lamp.omni_attenuation = 1.0
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.02
	cam.add_child(lamp)
	lamp.light_specular = 0.35
	lamp.position = Vector3(0.3, 0.1, 0.05)            # сбоку: блик лака — за краем кадра, видна фактура
	glint = OmniLight3D.new()                          # у самой камеры: металл блестит лицом к нам
	glint.light_color = Color(1.0, 0.75, 0.48)
	glint.light_energy = 0.03
	glint.light_specular = 2.5
	glint.omni_range = 0.8
	glint.light_cull_mask = GLINT_LAYER
	cam.add_child(glint)
	glint.position = Vector3(-0.05, 0.08, 0.08)
	_make_ui()
	black.color.a = 1.0
	cam.make_current()
	_make_pick()
	_attach_pick(_lock)
	_new_sweet()
	if ARMS_ENDING and not _scared:
		await _prewarm()                              # пока экран чёрный — финал рисуется один раз заранее
	create_tween().tween_property(black, "color:a", 0.0, 0.35)
	L._sfx3d("lock_tick", plate_pos(), -8.0, 0.8, true)
	await get_tree().create_timer(0.35).timeout
	_busy = false


func _stop() -> void:
	_busy = true
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, 0.25)
	await tw.finished
	if is_instance_valid(pick):
		pick.visible = false
	var held = R.get("held")
	if held is Node3D:
		(held as Node3D).visible = true
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
	help.text = tr("LP_HELP2")
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_top = -60
	help.offset_bottom = -24
	help.modulate = Color(0.85, 0.8, 0.7, 0.8)
	help.add_theme_font_size_override("font_size", 18)
	ui.add_child(help)


## Камера крупного плана — перед скважиной замка i, чуть снизу.
func _cam_spot(i: int) -> Array:
	var kh: Vector3 = (locks[i]["plug"] as Node3D).global_position
	return [kh + normal * CAM_D + Vector3.DOWN * 0.02, kh]


func _cam_to(i: int) -> void:
	var s := _cam_spot(i)
	_cam_base = s[0]
	_cam_look = s[1]
	cam.global_position = _cam_base
	cam.look_at(_cam_look, Vector3.UP)


## Камера плавно переезжает к замку i.
func _glide_to(i: int) -> void:
	var a0 := cam.global_position
	var l0 := _cam_look
	var s := _cam_spot(i)
	var t := 0.0
	while t < 0.6:
		await get_tree().process_frame
		t += get_process_delta_time()
		var k := _smooth(minf(t / 0.6, 1.0))
		cam.global_position = a0.lerp(s[0], k)
		cam.look_at(l0.lerp(s[1], k), Vector3.UP)
	_cam_base = s[0]
	_cam_look = s[1]


## Лёгкий толчок камеры (щелчок, срыв, удар изнутри) — и обратно.
func _nudge(amp: float) -> void:
	if not is_instance_valid(cam) or _cam_live:
		return
	cam.global_position = _cam_base + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-0.3, 1.0)) * amp
	create_tween().tween_property(cam, "global_position", _cam_base, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Шпилька (невидимка из модели): корень — в скважине, «рука» крутится вокруг оси скважины.
func _make_pick() -> void:
	if is_instance_valid(pick):
		return
	pick = Node3D.new()
	pick_arm = Node3D.new()
	pick.add_child(pick_arm)
	add_child(pick)
	pick_mesh.reparent(pick_arm, false)
	pick_mesh.transform = Transform3D.IDENTITY
	pick_mesh.visible = true


func _attach_pick(i: int) -> void:
	pick.reparent(locks[i]["plug"] as Node3D, false)
	pick.transform = Transform3D.IDENTITY
	pick.visible = true


func _new_sweet() -> void:
	_sweet = randf_range(-1.05, 1.05)
	while absf(_sweet - _ang) < 0.45:
		_sweet = randf_range(-1.05, 1.05)
	_in_win = false
	_grace = 0.0


func _input(e: InputEvent) -> void:
	if not _on:
		return
	get_viewport().set_input_as_handled()
	if _pull_on or _busy:
		return
	if e is InputEventMouseMotion:
		var old := _ang
		_ang = clampf(_ang + e.relative.x * 0.004, -1.3, 1.3)
		_moved(old, _ang)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_try()
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			_stop()
	elif e is InputEventKey and e.pressed and not e.echo and (e.physical_keycode == KEY_E or e.physical_keycode == KEY_SPACE):
		_try()


## Шпилька сдвинулась: тиканье штифтов (чем ближе к нужному месту — тем чаще и громче) и щелчок,
## когда попала (или проскочила его за одно движение).
func _moved(old: float, now: float) -> void:
	var w: float = WIN[mini(_lock, 2)]
	var d0 := old - _sweet
	var d1 := now - _sweet
	var near := clampf(1.0 - absf(d1) / NEAR, 0.0, 1.0)
	_tick_t += absf(now - old)
	if _tick_t > lerpf(0.11, 0.045, near):
		_tick_t = 0.0
		L._sfx3d("lock_tick", plate_pos(), lerpf(-26.0, -13.0, near), randf_range(0.92, 1.08) * lerpf(1.0, 1.22, near), true)
	if not _in_win and (absf(d1) <= w or (signf(d0) != signf(d1) and absf(d0) < 0.3)):
		_in_win = true
		_click()
	elif _in_win and absf(d1) > w * 2.2:
		_in_win = false


## Поймал: отчётливый щелчок, шпилька и личинка вздрагивают.
func _click() -> void:
	_grace = GRACE
	_jolt = 0.07
	L._sfx3d("lock_click", plate_pos(), -3.0, randf_range(0.95, 1.06), true)
	var pl := locks[_lock]["plug"] as Node3D
	var tw := create_tween()
	tw.tween_property(pl, "rotation:z", -0.07, 0.03)
	tw.tween_property(pl, "rotation:z", 0.0, 0.12)
	_nudge(0.0012)


func _try() -> void:
	if _lockout > 0.0:
		return
	if _grace > 0.0:
		_unlock()
	else:
		_jam()


## Нажал мимо: шпилька срывается с дребезгом, нужное место чуть сдвигается — и изнутри удар в дверцу.
func _jam() -> void:
	_lockout = 0.5
	_fails += 1
	_in_win = false
	L._sfx3d("lock_jam", plate_pos(), -4.0, randf_range(0.92, 1.08), true)
	var slip := randf_range(0.22, 0.38) * (1.0 if randf() < 0.5 else -1.0)
	create_tween().tween_property(self, "_ang", clampf(_ang + slip, -1.3, 1.3), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sweet = clampf(_sweet + randf_range(-0.15, 0.15), -1.1, 1.1)
	var pl := locks[_lock]["plug"] as Node3D
	var tw := create_tween()
	for k in 4:
		tw.tween_property(pl, "rotation:z", randf_range(-0.06, 0.06), 0.025)
	tw.tween_property(pl, "rotation:z", 0.0, 0.05)
	_nudge(0.002)
	if ARMS_ENDING and not _scared:
		_bang_inside()


## Изнутри — удар в дверцу (каждый третий раз — всем телом и шёпот); дверцы вздрагивают.
func _bang_inside() -> void:
	await get_tree().create_timer(0.18).timeout
	if _scared or not _on:
		return
	var at := global_position - normal * 0.05
	if _fails % 3 == 0:
		L._sfx3d("cabinet_bang", at, -2.0, randf_range(0.95, 1.1), true)
		L._sfx3d("whisper_harsh", at, -10.0, 0.9, true)
	else:
		L._sfx3d("thump", at, -3.0, randf_range(0.9, 1.15), true)
	_kill_breathe()
	for lf in leaves:
		var sg: float = lf.get_meta("sgn", 1.0)
		var tl := create_tween()
		_breathe_tw.append(tl)
		tl.tween_property(lf, "rotation:y", sg * 0.045, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tl.tween_property(lf, "rotation:y", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_nudge(0.006)


## Поймал и нажал: личинка проворачивается, дужка выскакивает. На SCARE_LOCK-м — финал.
func _unlock() -> void:
	_busy = true
	_in_win = false
	_grace = 0.0
	var i := _lock
	var lk: Dictionary = locks[i]
	var kh := plate_pos()
	var plug := lk["plug"] as Node3D
	var sh := lk["shackle"] as Node3D
	L._sfx3d("lock_turn", kh, -1.0, randf_range(0.95, 1.05), true)
	create_tween().tween_property(plug, "rotation:z", -PI / 2, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.03)
	await get_tree().create_timer(0.21).timeout
	L._sfx3d("lock_pop", kh, -3.0, randf_range(0.95, 1.05), true)
	create_tween().tween_property(sh, "position:y", sh.position.y + 0.011, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var root := lk["root"] as Node3D
	var tb := create_tween()                             # замок осел на пробое
	tb.tween_property(root, "position:y", root.position.y - 0.0025, 0.05)
	_nudge(0.0015)
	_lock += 1
	if ARMS_ENDING and not _scared and _lock >= SCARE_LOCK:
		_scared = true
		_take_off(i)                                     # всё как обычно: шпильку вынул, дужку откинул…
		await get_tree().create_timer(0.42).timeout      # полсекунды облегчения — «ещё один»
		_arms_ending()
		return
	if _lock == 1 and ARMS_ENDING:                       # тише и страшнее: сердце, дыхание чаще
		L._sfx("heartbeat", -12.0, 1.05, true)
		_breath_t = 0.8
		_dread_t = randf_range(1.5, 2.5)
	await get_tree().create_timer(0.2).timeout
	await _take_off(i)
	if _lock >= locks.size():
		_open()
		return
	await _glide_to(_lock)
	_attach_pick(_lock)
	pick.position.z = 0.025
	var ti := create_tween()
	ti.tween_property(pick, "position:z", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	L._sfx3d("lock_tick", plate_pos(), -10.0, 0.75, true)
	await ti.finished
	_new_sweet()
	_busy = false


## Открытый замок снимается: шпильку — из скважины, дужку — в сторону, замок соскальзывает с пробоя
## и падает на пол; накладка откидывается.
func _take_off(i: int) -> void:
	var lk: Dictionary = locks[i]
	var root := lk["root"] as Node3D
	var sh := lk["shackle"] as Node3D
	var hasp := lk["hasp"] as Node3D
	var tp := create_tween()
	tp.tween_property(pick, "position:z", 0.025, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tp.finished
	if lk.get("gone", false):
		return
	pick.visible = false
	create_tween().tween_property(sh, "rotation:y", 1.5, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.13).timeout
	if lk.get("gone", false):
		return
	_drop(lk)
	await get_tree().create_timer(0.12).timeout
	if hasp:
		L._sfx3d("creak", hasp.global_position, -14.0, 2.2, true)
		var th := create_tween()
		th.tween_property(hasp, "rotation:y", -1.95, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await th.finished


## Замок падает с пробоя: чуть вперёд и вниз, кувыркаясь; лёг на пол (или на тумбу) — звон.
func _drop(lk: Dictionary) -> void:
	lk["gone"] = true
	var root := lk["root"] as Node3D
	root.reparent(L, true)
	var p0 := root.global_position
	var b0 := root.global_basis
	var sc := b0.get_scale()
	var floor_y: float = L.player.global_position.y
	var q := PhysicsRayQueryParameters3D.create(p0 + normal * 0.06, p0 + normal * 0.06 + Vector3.DOWN * 4.0)
	q.exclude = [L.player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		floor_y = (hit["position"] as Vector3).y
	var h := maxf(p0.y - floor_y, 0.05)
	var sec := sqrt(2.0 * h / 9.8)
	var spin := Vector3(randf_range(4.0, 7.0), randf_range(-3.0, 3.0), randf_range(-5.0, 5.0))
	var t := 0.0
	while t < sec:
		await get_tree().process_frame
		if not is_instance_valid(root):
			return
		t = minf(t + get_process_delta_time(), sec)
		root.global_position = p0 + normal * (0.1 * t / sec) + Vector3.DOWN * 4.9 * t * t
		root.global_basis = b0 * Basis.from_euler(spin * t)
	L._sfx3d("lock_drop", root.global_position, -1.0, randf_range(0.92, 1.08), true)
	var rest := Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.RIGHT, -PI / 2)   # лёг на спину, скважиной вверх
	root.global_transform = Transform3D(rest.scaled(sc), Vector3(root.global_position.x, floor_y + 0.0075 * sc.x, root.global_position.z))


## Дверцы распахнулись — оставшиеся замки срывает с пробоев: летят в комнату; накладки болтаются.
func _burst_locks() -> void:
	for lk in locks:
		var hp := lk["hasp"] as Node3D
		if hp:
			create_tween().tween_property(hp, "rotation:y", randf_range(-2.4, -1.6), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if lk.get("gone", false):
			continue
		lk["gone"] = true
		var root := lk["root"] as Node3D
		root.reparent(L, true)
		var side := normal.cross(Vector3.UP).normalized()
		var v: Vector3 = normal * randf_range(1.1, 1.6) + Vector3.UP * randf_range(0.3, 0.9) + side * randf_range(-0.7, 0.7)
		_fling(root, v, Vector3(randf_range(-14, 14), randf_range(-14, 14), randf_range(-14, 14)), 0.7)


func _fling(n: Node3D, v: Vector3, spin: Vector3, sec: float) -> void:
	var p0 := n.global_position
	var b0 := n.global_basis
	var t := 0.0
	while t < sec:
		await get_tree().process_frame
		if not is_instance_valid(n):
			return
		t += get_process_delta_time()
		n.global_position = p0 + v * t + Vector3.DOWN * 4.9 * t * t
		n.global_basis = b0 * Basis.from_euler(spin * t)
	n.visible = false


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
	if not _on or not is_instance_valid(pick_arm):
		return
	if is_instance_valid(lamp) and not _scared:            # свеча в руке подрагивает
		lamp.light_energy = LAMP_E * (0.86 + 0.08 * sin(_tt * 11.0) * sin(_tt * 7.3 + 1.0) + randf() * 0.05)
	var off := absf(_ang - _sweet)
	_near = clampf(1.0 - off / NEAR, 0.0, 1.0)
	_jolt = move_toward(_jolt, 0.0, delta * 0.45)
	pick_arm.rotation.z = _ang + sin(_tt * 53.0) * 0.007 * _near * _near + _jolt * sin(_tt * 85.0)
	if _busy:
		return
	if _in_win and off <= WIN[mini(_lock, 2)]:
		_grace = GRACE
	else:
		_grace = maxf(_grace - delta, 0.0)
	_lockout = maxf(_lockout - delta, 0.0)
	if ARMS_ENDING and not _scared:
		_dread(delta)


# ---------------------------------------------------------------- финал: руки из тайника
## Всё тяжёлое (модели, звуки) готовится заранее — когда начинается мини-игра, за чёрной шторкой;
## руки, маска и свои руки Миши стоят «за стеной» и уже рисуются (материалы собраны) — в скримере
## они только переезжают на место, без подгрузок и рывков.
const REMY := "res://models/player/remy.fbx"
const MASK := "res://models/ghosts/ghost_mask.glb"
const SOUNDS := ["door", "scream_cabinet", "cabinet_riser", "cabinet_final", "sting", "attic_thud", "breath_dark", "scratch", "whisper_harsh",
	"thump", "scream", "drag", "drone", "giggle", "cabinet_strain", "cabinet_bang", "heartbeat", "whisper_old", "creak", "click",
	"lock_tick", "lock_click", "lock_turn", "lock_pop", "lock_drop", "lock_jam"]
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
# пока ковыряешь замки — тихие звуки изнутри
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


## Финал: второй замок открылся — и через полсекунды изнутри срывает третий вместе с пробоем:
## дверцы настежь, маска прямо в лицо (во весь кадр), крик, вспышка, кадр-вспышка с лицом Веры. Миша отшатывается — маска высовывается за ним; по бокам от
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
	# 1) удар изнутри — третий замок срывает вместе с пробоем, дверцы настежь — и она в лицо
	for lf in leaves:
		var sg: float = lf.get_meta("sgn", 1.0)
		create_tween().tween_property(lf, "rotation:y", sg * 2.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if is_instance_valid(pick):
		pick.visible = false
	_burst_locks()
	L._sfx3d("cabinet_bang", pp, 4.0, 0.8, true)
	lamp.light_energy = 0.0                            # свеча выпала из руки
	if is_instance_valid(glint):
		glint.visible = false
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


## Пока ковыряешь замки — изнутри тихие звуки; после первого замка Миша дышит всё чаще.
func _dread(delta: float) -> void:
	_dread_t -= delta
	_breath_t -= delta
	if _lock >= 1 and _breath_t <= 0.0:
		_breath_t = randf_range(1.6, 2.4)
		L._sfx("breath_dark", -17.0, 1.3, true)
	if _dread_t > 0.0:
		return
	_dread_t = randf_range(2.5, 4.5) if _lock >= 1 else randf_range(3.5, 6.0)
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
		var sg: float = lf.get_meta("sgn", 1.0)
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
## Все три замка открыты (без скримера, ARMS_ENDING = false): дверцы медленно открываются.
func _open() -> void:
	opened = true
	await get_tree().create_timer(0.4).timeout
	L.inv.remove("v_hairpin")
	L.targets.erase(_target)
	await _stop()
	L._sfx3d("creak", global_position, -6.0, 1.3, true)
	for lf in leaves:
		var sg: float = lf.get_meta("sgn", 1.0)
		create_tween().tween_property(lf, "rotation:y", sg * 1.7, 1.2).set_trans(Tween.TRANS_SINE)
	_on_open()


## Тайник открыт. Что внутри — дальше придумаем.
func _on_open() -> void:
	pass
