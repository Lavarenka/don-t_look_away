extends Node
## ПРОБНЫЙ скример (новая модель Ани, MakeHuman): в начале игры, посередине прихожей — она вплотную,
## лицо на весь экран, кричит и трясётся, руками держит тебя за голову. Выключить: level.TEST_GRAB = false.
const SPIRIT = preload("res://scripts/spirit.gd")
const TRIGGER_Z := 3.0          ## прошёл прихожую до этой отметки — срабатывает (один раз)
const DIST := 0.1               ## лицо (глаза) — в 10 см от камеры: на весь экран
const HOLD := 1.9               ## сколько держит

var L: Node
var done := false
var g: Node3D
var grab: SkeletonModifier3D
var _t := 0.0
var _fe = null
var _keep: Array = []           ## загруженное заранее держим, чтобы не выгрузилось
var _hoff := Vector3(0, 1.45, 0.0)   ## центр головы в локальных осях призрака


const PRE := ["res://models/spirit2/anya_ghost.glb", "res://models/spirit2/anim_reach.res", "res://models/spirit2/anim_idle.res"]


func _ready() -> void:
	# модель грузится заранее в фоне — в момент скримера без подвисания на загрузке
	for f in PRE:
		ResourceLoader.load_threaded_request(f)
	# заранее собрать шейдеры новой модели (тело и волосы), пока до скримера далеко
	var sh: Shader = SPIRIT.hair_shader()
	_keep.append(sh)


func _process(delta: float) -> void:
	if done:
		if g and is_instance_valid(g):
			_t += delta
			_hold_frame()
		return
	var p = L.player
	if L.busy or p.frozen or p.global_position.z > TRIGGER_Z:
		return
	for f in PRE:
		if ResourceLoader.load_threaded_get_status(f) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return                                # ещё грузится — подождём
	for f in PRE:
		if ResourceLoader.load_threaded_get_status(f) == ResourceLoader.THREAD_LOAD_LOADED:
			_keep.append(ResourceLoader.load_threaded_get(f))   # в кэше: spirit.gd возьмёт мгновенно
	done = true
	_scare()


func _scare() -> void:
	var p = L.player
	L.busy = true
	p.frozen = true
	_failsafe()
	p.head.rotation.x = 0.0
	_fe = p.get("flash_energy")
	if _fe != null:
		p.flash_energy = 1.0                  # вплотную фонарь выжигает лицо — приглушить
	g = SPIRIT.new()
	g.new_model = true
	L.add_child(g)
	g.visible = false
	await get_tree().process_frame
	g.play_from("reach", 1.6, 0.0)
	g.set_speed(0.0)
	g.set_blood(0.5)
	g.set_eyes(1.0)
	g.set_shiver(0.35)                  # лёгкая дрожь — лицо должно читаться
	g.murmur = false
	await get_tree().process_frame
	var hb: int = g.sk.find_bone("mixamorig_Head")
	g.rotation = Vector3.ZERO
	_hoff = g.global_transform.affine_inverse() * (g.sk.global_transform * g.sk.get_bone_global_pose(hb).origin)
	for mi in g.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # тень волос во весь кадр — лишняя нагрузка
	g._p("near_cut", 0.075)                       # пряди прямо у объектива не рисуем — лицо видно, видеокарте легче
	grab = preload("res://scripts/grab_pose.gd").new()
	g.sk.add_child(grab)
	var face := OmniLight3D.new()
	face.light_color = Color(0.72, 0.8, 1.0)
	face.light_energy = 0.35
	face.omni_range = 1.2
	L.player.cam.add_child(face)
	face.position = Vector3(0, -0.12, 0.0)          # снизу — жутче
	g.set_meta("face_light", face)
	_hold_frame()
	g.visible = true
	g.scream(HOLD)
	L._sfx("sting", 4.0, 1.0, true)
	L._sfx("scream", 4.0, 1.05, true)
	L._sfx("scream", 0.0, 0.8, true)
	p.shake = 0.15
	L.red_flash.color.a = 0.2
	for k in 6:
		await get_tree().create_timer(HOLD / 6.0).timeout
		p.shake = 0.12
		L.red_flash.color.a = 0.16 if k % 2 else 0.05
	L.fade.color.a = 1.0
	L.red_flash.color.a = 0.0
	if is_instance_valid(face):
		face.queue_free()
	if g and is_instance_valid(g):
		g.queue_free()
	g = null
	await get_tree().create_timer(0.35).timeout
	L.fade.color.a = 0.0
	p.flicker = 0.4
	if _fe != null:
		p.flash_energy = _fe
	p.frozen = false
	L.busy = false


## Каждый кадр: лицо в DIST перед камерой, трясётся; руки держат за голову по бокам.
func _hold_frame() -> void:
	if g == null or not is_instance_valid(g):
		return
	var cam: Camera3D = L.player.cam
	var fwd: Vector3 = -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var jit := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.003
	g.rotation = Vector3(0.0, atan2(-fwd.x, -fwd.z), sin(_t * 23.0) * 0.01)
	# от кости головы до глаз: ~0.09 вверх и ~0.1 вперёд
	var want: Vector3 = cam.global_position + fwd * (DIST + 0.1) + Vector3(0, -0.1, 0) + jit
	g.global_position = want - g.global_basis * _hoff
	if grab:
		var c: Vector3 = cam.global_position + fwd * 0.12 + Vector3(0, -0.07, 0)
		grab.targets = {"Left": c + right * 0.15, "Right": c - right * 0.15}


## Что бы ни случилось — через несколько секунд игрок снова может двигаться.
func _failsafe() -> void:
	await get_tree().create_timer(HOLD + 4.0).timeout
	var p = L.player
	if p.frozen and L.busy:
		if g and is_instance_valid(g):
			g.queue_free()
		g = null
		L.fade.color.a = 0.0
		L.red_flash.color.a = 0.0
		if _fe != null:
			p.flash_energy = _fe
		p.frozen = false
		L.busy = false
