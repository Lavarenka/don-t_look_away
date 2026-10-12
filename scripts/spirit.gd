extends Node3D
## Призрак девочки (Blood Stained Spirit, adhamasalah, CC BY; риг и анимации — Mixamo).
## Меш с запечёнными масками (tools/bake_spirit.gd) + шейдер shaders/spirit.gdshader:
## рукава провисают под весом, волосы и подол колышутся, кровь проступает по команде.
##
## Анимации: idle — стоит как призрак, zidle — жуткое покачивание, walk — медленный шаг,
## run — бег, reach — тянет руку.

const HEIGHT := 1.7          ## рост, м (один для всех появлений призрака)
const EYE_OFS := Vector3(0.017, 0.098, 0.1)   ## глаза от кости головы (м): в стороны, вверх, вперёд
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


func _ready() -> void:
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
	mi.material_override = mat
	for s in ["Left", "Right"]:
		_arms[s] = [sk.find_bone("mixamorig_%sArm" % s), sk.find_bone("mixamorig_%sForeArm" % s), sk.find_bone("mixamorig_%sHand" % s)]
	life = preload("res://scripts/spirit_life.gd").new()
	sk.add_child(life)
	_make_eyes()
	_head_b = sk.find_bone("mixamorig_Head")
	mat.set_shader_parameter("head_k", model.scale.x)
	sk.skeleton_updated.connect(_head_to_shader)
	play("idle")


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
		var p := hp.origin + Vector3(sx * EYE_OFS.x, EYE_OFS.y, EYE_OFS.z) / model.scale.x
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
	mat.set_shader_parameter("blood", v)


func set_lift(v: float) -> void:
	mat.set_shader_parameter("lift", v)


## Полупрозрачная «призрачная» версия (0 — обычная, 1 — сильно просвечивает):
## сквозь неё виден фон, тело «дышит» пятнами плотности, по краю холодный ореол, ноги тают к полу.
## Шейдер — тот же spirit.gdshader с добавленной прозрачностью (собирается один раз).
static var _ghost_shader: Shader
func set_ghostly(v: float) -> void:
	if v <= 0.0:
		mat.shader = load("res://shaders/spirit.gdshader")
		return
	if _ghost_shader == null:
		var code: String = (load("res://shaders/spirit.gdshader") as Shader).code
		code = code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode depth_draw_always, cull_back;\nuniform float ghost = 0.5;\nvarying float v_h;")
		code = code.replace("void vertex() {", "void vertex() {\n\tv_h = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - NODE_POSITION_WORLD.y;")
		code = code.replace("\tif (debug == 1)", "\tfloat gfr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);\n" \
			+ "\tfloat breath = vnoise(UV * 5.0 + vec2(TIME * 0.21, -TIME * 0.17)) * 0.6 + vnoise(UV * 17.0 - TIME * 0.4) * 0.4;\n" \
			+ "\tfloat a = mix(0.72, 0.28, ghost) + breath * 0.3 + gfr * 0.35;\n" \
			+ "\ta *= smoothstep(0.0, 0.5, v_h);\n" \
			+ "\tALPHA = clamp(a, 0.0, 1.0);\n" \
			+ "\tEMISSION += vec3(0.4, 0.5, 0.65) * gfr * ghost * 0.35;\n" \
			+ "\tif (debug == 1)")
		_ghost_shader = Shader.new()
		_ghost_shader.code = code
	mat.shader = _ghost_shader
	mat.set_shader_parameter("ghost", v)
	for mi in find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Видна только на заданном слое отрисовки (например, только в зеркале).
func set_layer(mask: int) -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = mask
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_t += delta
	_update_face(delta)
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
		mat.set_shader_parameter(k + "0", p0)
		mat.set_shader_parameter(k + "1", p1)
		mat.set_shader_parameter(k + "2", p2)
		mat.set_shader_parameter("arm_up_" + k, up)


## Губы шевелятся сами: изредка чуть приоткрывает рот и беззвучно что-то шепчет, потом снова замирает.
func _update_face(delta: float) -> void:
	if not FACE:
		mat.set_shader_parameter("mouth", 0.0)
		mat.set_shader_parameter("grimace", 0.0)
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
	if mouth > 0.3:                  # в крике челюсть подрагивает
		m += sin(_t * 41.0) * 0.04 * mouth
	mat.set_shader_parameter("mouth", m)
	mat.set_shader_parameter("grimace", grimace)


## Поза головы — уже после «живости» (рывки головы), иначе рот съезжал бы при рывках.
func _head_to_shader() -> void:
	if not FACE:
		return
	var hp := sk.get_bone_global_pose(_head_b)
	mat.set_shader_parameter("head_inv", Projection(hp.affine_inverse()))
	mat.set_shader_parameter("head_rot", hp.basis.orthonormalized())
