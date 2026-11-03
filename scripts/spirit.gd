extends Node3D
## Призрак девочки (Blood Stained Spirit, adhamasalah, CC BY; риг и анимации — Mixamo).
## Меш с запечёнными масками (tools/bake_spirit.gd) + шейдер shaders/spirit.gdshader:
## рукава провисают под весом, волосы и подол колышутся, кровь проступает по команде.
##
## Анимации: idle — стоит как призрак, zidle — жуткое покачивание, walk — медленный шаг,
## run — бег, reach — тянет руку.

const HEIGHT := 1.7          ## рост, м (один для всех появлений призрака)
const EYE_OFS := Vector3(0.017, 0.098, 0.1)   ## глаза от кости головы (м): в стороны, вверх, вперёд (старая модель)
## Новая модель Ани (MakeHuman, tools: mpfb/ghost/make_ghost.py): лицо, карточки волос.
## В игре пока — старая модель; новая — только там, где задано new_model = true до добавления в сцену
## (пробный скример scripts/test_grab.gd).
var new_model := false
const NEW_DIR := "res://models/spirit2/"
## Из make_ghost.py (anya_ghost.json), координаты Blender: глаза, рот, кость головы; рост до макушки.
const NEW_INFO := {"eye_l": [0.025338, -0.100612, 1.389180], "mouth": [-0.000000, -0.142592, 1.350613], "head": [-0.001301, -0.014884, 1.307164], "height": 1.508432}
var eye_ofs := EYE_OFS
var hair_mat: ShaderMaterial       ## волосы новой модели (тот же шейдер, с альфой карточек)
var _r0 := Basis.IDENTITY          ## поза покоя головы — оси «лица» для шейдера
const ANIMS := ["idle", "zidle", "walk", "run", "reach"]

var model: Node3D
var sk: Skeleton3D
var ap: AnimationPlayer
var mat: ShaderMaterial
var float_h := 0.0           ## на сколько парит над полом (плавно)
var _float := 0.0
var _t := 0.0
var _arms := {}
var life: SkeletonModifier3D      ## подёргивания головы, дыхание, дрожь (spirit_life.gd)
var eyes: Array[MeshInstance3D] = []   ## еле видные блики глаз сквозь волосы

## Мимика (челюсть, уголки рта) — через шейдер, без новых костей.
## Откатить: FACE = false — лицо снова неподвижное, всё остальное как раньше.
const FACE := true
var mouth := 0.0             ## 0..1: рот раскрыт (крик); анимировать через set_mouth/scream
var grimace := 0.0           ## 0..1: уголки рта вниз (злость, плач)
var murmur := true           ## сама по себе иногда беззвучно шевелит губами
var _head_b := -1
var _mur := 0.0
var _mur_next := 3.0
var _mur_to := 0.0


## Старая Аня «не пластик» (рельеф кожи/прядей/ткани, матовость). 0.0 — вернуть как было.
const REALISM := 1.0

## «Живая» Аня: следит за тобой головой, моргает, дышит ртом, губы дрожат, волосы и подол
## отстают по инерции, кожа просвечивает, мокрые пряди. false — всё как было до этого
## (бэкап файлов: backup/anya_before_alive, метка в git: anya-before-alive).
const ALIVE := true
var watch := true            ## следить головой за камерой игрока (можно выключить для отдельной сцены)
const WATCH_DIST := 9.0      ## дальше — не замечает
var _blink := 0.0            ## 0..1 — веки
var _blink_next := 4.0
var _blink_t := -1.0         ## идёт моргание: время от начала
var _blink_len := 0.14
var _mi: MeshInstance3D      ## тело (для перевода инерции в оси меша)
var _hair_x := Vector3.ZERO  ## пружины инерции: смещение и скорость (мир)
var _hair_v := Vector3.ZERO
var _hem_x := Vector3.ZERO
var _hem_v := Vector3.ZERO
var _prev_head := Vector3.ZERO
var _prev_hips := Vector3.ZERO
var _prev_hb := Basis.IDENTITY
var _hips_b := -1
var _inert_ready := false


func _ready() -> void:
	if new_model:
		_load_new()
	else:
		_load_old()
	for s_ in ["Left", "Right"]:
		_arms[s_] = [sk.find_bone("mixamorig_%sArm" % s_), sk.find_bone("mixamorig_%sForeArm" % s_), sk.find_bone("mixamorig_%sHand" % s_)]
	life = preload("res://scripts/spirit_life.gd").new()
	sk.add_child(life)
	_make_eyes()
	_head_b = sk.find_bone("mixamorig_Head")
	_r0 = sk.get_bone_global_rest(_head_b).basis.orthonormalized() if new_model else Basis.IDENTITY
	_p("head_k", model.scale.x)
	sk.skeleton_updated.connect(_head_to_shader)
	_hips_b = sk.find_bone("mixamorig_Hips")
	_p("alive", 1.0 if ALIVE else 0.0)
	_blink_next = randf_range(2.0, 6.0)
	play("idle")


func _load_old() -> void:
	model = load("res://models/spirit/spirit.fbx").instantiate()
	add_child(model)
	model.scale = Vector3.ONE * (HEIGHT / 0.98)
	sk = model.get_node("Skeleton3D")
	ap = model.get_node("AnimationPlayer")
	var lib := AnimationLibrary.new()
	for n in ANIMS:
		lib.add_animation(n, load("res://models/spirit/anim_%s.res" % n))
	ap.add_animation_library("g", lib)
	var mi: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	mi.mesh = load("res://models/spirit/spirit_mesh.res")
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/spirit.gdshader")
	mat.set_shader_parameter("albedo_tex", load("res://models/spirit/spirit_albedo.png"))
	mat.set_shader_parameter("realism", REALISM)
	mi.material_override = mat
	_mi = mi


## Новая модель: тело (кожа, рубашка, глаза — одна текстура) и волосы-карточки, свои анимации
## (перенесены со старой: tools/retarget_ghost.gd). Глаза и рот — из anya_ghost.json.
func _load_new() -> void:
	model = load("res://models/spirit2/anya_ghost.glb").instantiate()
	add_child(model)
	var info := NEW_INFO
	model.scale = Vector3.ONE * (HEIGHT / float(info.height))
	sk = model.find_children("*", "Skeleton3D", true, false)[0]
	ap = AnimationPlayer.new()
	model.add_child(ap)
	var lib := AnimationLibrary.new()
	for n in ANIMS:
		lib.add_animation(n, load("res://models/spirit2/anim_%s.res" % n))
	ap.add_animation_library("g", lib)
	# Blender (x, y, z) → Godot (x, z, -y); всё от кости головы, в метрах модели
	var bg := func(a: Array) -> Vector3: return Vector3(a[0], a[2], -a[1])
	var head: Vector3 = bg.call(info.head)
	var e: Vector3 = (bg.call(info.eye_l) as Vector3) - head
	var m: Vector3 = (bg.call(info.mouth) as Vector3) - head
	eye_ofs = Vector3(absf(e.x), e.y, e.z) * model.scale.x
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		var src := g.get_active_material(0) as BaseMaterial3D
		var sm := ShaderMaterial.new()
		var is_hair := String(g.name).begins_with("Hair")
		sm.shader = hair_shader() if is_hair else load("res://shaders/spirit.gdshader")
		if src and src.albedo_texture:
			sm.set_shader_parameter("albedo_tex", src.albedo_texture)
		sm.set_shader_parameter("flip_v", false)
		sm.set_shader_parameter("obj_noise", true)
		sm.set_shader_parameter("skin_mask", true)
		sm.set_shader_parameter("sag", 0.0)
		sm.set_shader_parameter("eye_at", eye_ofs)
		sm.set_shader_parameter("eye_r", 0.0105 * model.scale.x)
		sm.set_shader_parameter("mouth_at", m * model.scale.x)
		g.material_override = sm
		if is_hair:
			hair_mat = sm
		else:
			mat = sm
			_mi = g


## Параметр шейдера — и телу, и волосам.
func _p(name_: String, v: Variant) -> void:
	mat.set_shader_parameter(name_, v)
	if hair_mat:
		hair_mat.set_shader_parameter(name_, v)


static var _hair_shader: Shader
## Волосы: тот же шейдер, двусторонний, с вырезом по альфе текстуры прядей.
static func hair_shader() -> Shader:
	if _hair_shader == null:
		var code: String = (load("res://shaders/spirit.gdshader") as Shader).code
		code = code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode cull_disabled;\n#define HAIR")
		_hair_shader = Shader.new()
		_hair_shader.code = code
	return _hair_shader


## Играть анимацию (имя из ANIMS).
func play(n: String, speed := 1.0, blend := 0.25) -> void:
	ap.play("g/" + n, blend)
	ap.speed_scale = speed


## Замереть в позе: анимация n на секунде t.
func freeze(n: String, t: float) -> void:
	ap.play("g/" + n, 0.0)
	ap.seek(t, true)
	ap.speed_scale = 0.0


## Играть анимацию n с секунды t — так призрак «живой» даже в короткие появления.
func play_from(n: String, t: float, speed := 0.8) -> void:
	ap.play("g/" + n, 0.0)
	ap.seek(t, true)
	ap.speed_scale = speed


func set_speed(s: float) -> void:
	ap.speed_scale = s


## Глаза: две светящиеся точки на лице (между прядями), жёлто-белые с багровым ореолом,
## мерцают; в крике вспыхивают ярче. Волосы перед лицом их перекрывают.
func _make_eyes() -> void:
	var head := sk.find_bone("mixamorig_Head")
	var ba := BoneAttachment3D.new()
	ba.bone_idx = head
	sk.add_child(ba)
	var hp := sk.get_bone_global_rest(head)
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	for sx in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		e.mesh = q
		var em := ShaderMaterial.new()
		em.shader = preload("res://shaders/spirit_eye.gdshader")
		em.set_shader_parameter("seed", randf() * 10.0)
		e.material_override = em
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ba.add_child(e)
		var p := hp.origin + Vector3(sx * eye_ofs.x, eye_ofs.y, eye_ofs.z) / model.scale.x
		e.position = hp.affine_inverse() * p
		eyes.append(e)
	set_eyes(0.45)


## Яркость глаз (0 — не видно).
var eye_power := 0.45
func set_eyes(v: float) -> void:
	eye_power = v
	for e in eyes:
		e.visible = v > 0.01
		(e.material_override as ShaderMaterial).set_shader_parameter("power", v)


## Дрожь (0..1) — например, перед броском.
func set_shiver(v: float) -> void:
	life.shiver = v


## Рот: 0 — закрыт, 1 — раскрыт. sec > 0 — плавно.
func set_mouth(v: float, sec := 0.0) -> void:
	if sec <= 0.0:
		mouth = v
	else:
		create_tween().tween_property(self, "mouth", v, sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Крик: рот резко распахивается, дрожит, потом медленно закрывается.
func scream(hold := 0.7) -> void:
	var tw := create_tween()
	tw.tween_property(self, "mouth", 1.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "grimace", 1.0, 0.1)
	tw.tween_interval(hold)
	tw.tween_property(self, "mouth", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "grimace", 0.0, 1.2)
	life.shiver = 1.0
	if eye_power > 0.01:
		var e0 := eye_power
		set_eyes(e0 * 2.4)
		get_tree().create_timer(hold + 0.3).timeout.connect(func(): set_eyes(e0))
	get_tree().create_timer(hold + 0.3).timeout.connect(func(): life.shiver = 0.0)


func set_blood(v: float) -> void:
	_p("blood", v)


func set_lift(v: float) -> void:
	_p("lift", v)


## Полупрозрачная «призрачная» версия (0 — обычная, 1 — сильно просвечивает):
## сквозь неё виден фон, тело «дышит» пятнами плотности, по краю холодный ореол, ноги тают к полу.
## Шейдер — тот же spirit.gdshader с добавленной прозрачностью (собирается один раз).
static var _ghost_shader: Shader
## Прозрачность — «alpha hash» (рассыпчатое зерно вместо смешивания): рисуется как непрозрачная,
## с предпроходом глубины, поэтому 200 тыс. треугольников волос не пересчитываются слоями — нет просадки FPS.
func set_ghostly(v: float) -> void:
	if v <= 0.0:
		if mat.shader == _ghost_shader:
			mat.shader = load("res://shaders/spirit.gdshader")
			if hair_mat:
				hair_mat.shader = hair_shader()
		return
	if mat.shader != ghost_shader():
		mat.shader = _ghost_shader
		if hair_mat:
			hair_mat.shader = ghost_shader(true)
		for mi in find_children("*", "GeometryInstance3D", true, false):
			(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_p("ghost", v)


static var _ghost_hair_shader: Shader
static func ghost_shader(hair := false) -> Shader:
	if hair and _ghost_hair_shader:
		return _ghost_hair_shader
	if not hair and _ghost_shader:
		return _ghost_shader
	if true:
		var code: String = (load("res://shaders/spirit.gdshader") as Shader).code
		code = code.replace("shader_type spatial;", ("shader_type spatial;\nrender_mode cull_disabled;\n#define HAIR\n#define GHOSTLY" if hair else "shader_type spatial;\nrender_mode cull_back;\n#define GHOSTLY") + "\nuniform float ghost = 0.5;\nvarying float v_h;")
		code = code.replace("void vertex() {", "void vertex() {\n\tv_h = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - NODE_POSITION_WORLD.y;")
		code = code.replace("\tif (debug == 1)", "\tfloat gfr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);\n" \
			+ "\tfloat breath = vnoise(UV * 5.0 + vec2(TIME * 0.21, -TIME * 0.17)) * 0.6 + vnoise(UV * 17.0 - TIME * 0.4) * 0.4;\n" \
			+ "\tfloat a = mix(0.72, 0.28, ghost) + breath * 0.3 + gfr * 0.35;\n" \
			+ "\ta *= smoothstep(0.0, 0.5, v_h);\n" \
			+ "\tALPHA = clamp(a, 0.0, 1.0);\n" \
			+ "\tALPHA_HASH_SCALE = 1.0;\n" \
			+ "\tEMISSION += vec3(0.4, 0.5, 0.65) * gfr * ghost * 0.35;\n" \
			+ "\tif (debug == 1)")
		var sh := Shader.new()
		sh.code = code
		if hair:
			_ghost_hair_shader = sh
		else:
			_ghost_shader = sh
		return sh
	return _ghost_shader


## Видна только на заданном слое отрисовки (например, только в зеркале).
func set_layer(mask: int) -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = mask
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_t += delta
	_update_face(delta)
	if ALIVE:
		_alive(delta)
	# парит: плавно поднимается и медленно покачивается вверх-вниз
	_float = move_toward(_float, float_h, delta * 0.6)
	model.position.y = _float + (sin(_t * 1.4) * 0.035 if _float > 0.01 else 0.0)
	# положение рук для шейдера: рукава висят на них под своим весом
	for s in ["Left", "Right"]:
		var b: Array = _arms[s]
		var p0 := sk.get_bone_global_pose(b[0]).origin
		var p1 := sk.get_bone_global_pose(b[1]).origin
		var p2 := sk.get_bone_global_pose(b[2]).origin
		var up := clampf(1.0 + (p2 - p0).normalized().y, 0.0, 1.0)
		var k := "l" if s == "Left" else "r"
		_p(k + "0", p0)
		_p(k + "1", p1)
		_p(k + "2", p2)
		_p("arm_up_" + k, up)


## Губы шевелятся сами: изредка чуть приоткрывает рот и беззвучно что-то шепчет, потом снова замирает.
func _update_face(delta: float) -> void:
	if not FACE:
		_p("mouth", 0.0)
		_p("grimace", 0.0)
		return
	if murmur:
		_mur_next -= delta
		if _mur_next <= 0.0:
			_mur_to = randf_range(0.08, 0.2) if _mur_to == 0.0 else 0.0
			_mur_next = randf_range(1.2, 2.5) if _mur_to > 0.0 else randf_range(3.0, 8.0)
		var tgt := _mur_to
		if _mur_to > 0.0:            # шепчет: губы мелко двигаются
			tgt *= 0.55 + 0.45 * absf(sin(_t * 7.3) * sin(_t * 3.1 + 1.0))
		_mur = move_toward(_mur, tgt, delta * 0.8)
	else:
		_mur = move_toward(_mur, 0.0, delta)
	var m := maxf(mouth, _mur)
	var gr := grimace
	if ALIVE:
		# дышит ртом: на вдохе губы чуть размыкаются (в такт груди, см. spirit_life.gd)
		var br := sin(_t * 1.05) * 0.5 + 0.5
		br = br * br * (0.7 + 0.3 * sin(_t * 0.37))
		m = maxf(m, 0.045 * br)
		# губы мелко дрожат — от холода или от сдерживаемого плача
		gr += 0.07 * sin(_t * 17.0) * sin(_t * 5.3 + 1.7) + 0.05
	if mouth > 0.3:                  # в крике челюсть подрагивает
		m += sin(_t * 41.0) * 0.04 * mouth
	_p("mouth", m)
	_p("grimace", gr)


## Взгляд, моргание, инерция волос и подола.
func _alive(delta: float) -> void:
	if life == null:
		return
	# --- взгляд за камерой
	var cam := get_viewport().get_camera_3d()
	var want := 0.0
	if watch and cam and visible:
		var dist := cam.global_position.distance_to(global_position)
		want = 1.0 - smoothstep(WATCH_DIST - 2.0, WATCH_DIST, dist)
		life.look_target = cam.global_position
	life.look_w = move_toward(life.look_w, want, delta * 0.8)
	life.fwd_world = global_basis.z
	# --- моргание: редко, иногда глаза надолго закрыты, иногда два раза подряд
	_blink_next -= delta
	if _blink_t < 0.0 and _blink_next <= 0.0:
		_blink_t = 0.0
		_blink_len = 0.13 if randf() < 0.8 else randf_range(0.6, 1.4)
		_blink_next = randf_range(0.25, 0.4) if randf() < 0.2 else randf_range(3.0, 9.0)
	if _blink_t >= 0.0:
		_blink_t += delta
		var cl := 0.06                                  # веки смыкаются быстро...
		var op := 0.12 if _blink_len < 0.3 else 0.35    # ...открываются медленнее
		if _blink_t < cl:
			_blink = _blink_t / cl
		elif _blink_t < cl + _blink_len:
			_blink = 1.0
		elif _blink_t < cl + _blink_len + op:
			_blink = 1.0 - (_blink_t - cl - _blink_len) / op
		else:
			_blink = 0.0
			_blink_t = -1.0
	for e in eyes:
		(e.material_override as ShaderMaterial).set_shader_parameter("lid", _blink)
	# --- инерция: кончики волос и подол отстают от движения головы/бёдер и качаются, как на пружине
	if delta <= 0.0 or _mi == null:
		return
	var skx := sk.global_transform
	var hb := skx * sk.get_bone_global_pose(_head_b)
	var hips := skx * sk.get_bone_global_pose(_hips_b).origin if _hips_b >= 0 else global_position
	if not _inert_ready:
		_prev_head = hb.origin
		_prev_hips = hips
		_prev_hb = hb.basis.orthonormalized()
		_inert_ready = true
		return
	var hv := (hb.origin - _prev_head) / delta
	# поворот головы: кончики (≈ на 30 см ниже) получают скорость от вращения
	var dq := (hb.basis.orthonormalized() * _prev_hb.inverse()).get_rotation_quaternion()
	var ang := dq.get_axis() * dq.get_angle() / delta if dq.get_angle() > 0.0001 else Vector3.ZERO
	var tip_v := hv + ang.cross(Vector3.DOWN * 0.3)
	var pv := (hips - _prev_hips) / delta
	_prev_head = hb.origin
	_prev_hips = hips
	_prev_hb = hb.basis.orthonormalized()
	# телепорт (появилась в другом месте) — не дёргать волосы через всю комнату
	if tip_v.length() > 12.0 or pv.length() > 12.0:
		_hair_x = Vector3.ZERO; _hair_v = Vector3.ZERO; _hem_x = Vector3.ZERO; _hem_v = Vector3.ZERO
		return
	var d := minf(delta, 0.05)
	_hair_v += ((-tip_v * 0.04).limit_length(0.14) - _hair_x) * 38.0 * d - _hair_v * 5.0 * d
	_hair_x += _hair_v * d
	_hem_v += ((-pv * 0.045).limit_length(0.12) - _hem_x) * 30.0 * d - _hem_v * 4.0 * d
	_hem_x += _hem_v * d
	var to_mesh := _mi.global_basis.inverse()
	_p("hair_drag", to_mesh * _hair_x)
	_p("hem_drag", to_mesh * _hem_x)


## Поза головы — уже после «живости» (рывки головы), иначе рот съезжал бы при рывках.
func _head_to_shader() -> void:
	if not FACE:
		return
	var hp := sk.get_bone_global_pose(_head_b)
	# оси «лица» = оси кости головы в покое (у новой модели они не совпадают с осями скелета)
	_p("head_inv", Projection(Transform3D(_r0, Vector3.ZERO) * hp.affine_inverse()))
	_p("head_rot", hp.basis.orthonormalized() * _r0.inverse())
