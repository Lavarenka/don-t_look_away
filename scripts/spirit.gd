extends Node3D
## Призрак девочки — Аня.
## Сейчас в игре — Аня v3 (ANYA_V3): своя модель на основе MakeHuman (CC0), сборка — tools/anya3;
## анимации перенесены со старой (tools/retarget_anya3.gd).
## Прежняя: Blood Stained Spirit (adhamasalah, CC BY; риг и анимации — Mixamo), меш с запечёнными масками
## (tools/bake_spirit.gd) + шейдер shaders/spirit.gdshader: рукава провисают под весом, волосы и подол колышутся,
## кровь проступает по команде.
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

## ===== Аня v3 =====
## Новое тело с настоящим лицом: кости челюсти, губ, век, бровей и глаз (мимика — scripts/spirit3_face.gd), пальцы,
## 5 костей спины и 3 — шеи; волосы — пряди на 13 цепочках костей с физикой (SpringBoneSimulator3D): висят по тяжести,
## отстают в движении, ложатся на плечи; ночная рубашка — отдельной сеткой.
## Откатить на прежнюю Аню: ANYA_V3 = false (файлы прежней на месте; бэкап скриптов — backup/anya_before_v3,
## метка в git — before-anya-v3).
const ANYA_V3 := true
## Файлы v3 — полными путями (по ним tools/git_used.py понимает, что они нужны игре).
const V3_MODEL := "res://models/spirit3/anya.glb"
const V3_HAIR := "res://models/spirit3/anya_hair.json"       # цепочки костей волос
const V3_EYE := "res://models/spirit3/anya_eye.json"         # где на текстуре глаз радужки
const V3_TEX := {
	"skin_head": ["res://models/spirit3/tex/skin_head_albedo.png", "res://models/spirit3/tex/skin_head_normal.png", "res://models/spirit3/tex/skin_head_mask.png"],
	"skin_body": ["res://models/spirit3/tex/skin_body_albedo.png", "res://models/spirit3/tex/skin_body_normal.png", "res://models/spirit3/tex/skin_body_mask.png"],
	"gown": ["res://models/spirit3/tex/gown_albedo.png", "res://models/spirit3/tex/gown_normal.png", "res://models/spirit3/tex/gown_mask.png"],
	"hair": "res://models/spirit3/tex/hair_strands.png", "eyes": "res://models/spirit3/tex/eye_albedo.png", "lashes": "res://models/spirit3/tex/lashes.png",
	"pores": "res://models/spirit3/tex/detail_pores.png", "weave": "res://models/spirit3/tex/detail_weave.png"}
## Как кости прежнего рига (Mixamo) называются у v3 — чтобы сцены могли спрашивать кость одним именем: bone("Head").
const V3_BONES := {"Hips": "root", "Spine": "spine05", "Spine1": "spine04", "Spine2": "spine03", "Chest": "spine01", "Neck": "neck01", "Head": "head",
	"LeftShoulder": "clavicle_L", "RightShoulder": "clavicle_R", "LeftArm": "upperarm01_L", "RightArm": "upperarm01_R",
	"LeftForeArm": "lowerarm01_L", "RightForeArm": "lowerarm01_R", "LeftHand": "wrist_L", "RightHand": "wrist_R",
	"LeftUpLeg": "upperleg01_L", "RightUpLeg": "upperleg01_R", "LeftLeg": "lowerleg01_L", "RightLeg": "lowerleg01_R",
	"LeftFoot": "foot_L", "RightFoot": "foot_R"}
var v3 := false                    ## эта Аня — v3 (выставляется в _ready)
var force_old := false             ## задать true до добавления в сцену — прежняя модель, даже если ANYA_V3
var face: SkeletonModifier3D       ## v3: мимика, взгляд глаз, пальцы (spirit3_face.gd)
var hair_sim: SpringBoneSimulator3D   ## v3: физика волос
var mats: Array[ShaderMaterial] = []  ## v3: все её материалы (оттенок, кровь, призрачность — всем сразу)
var eye_mat: ShaderMaterial
var _face_loc := Vector3.ZERO      ## точка между глаз в осях кости головы (face_point)
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
	v3 = ANYA_V3 and not new_model and not force_old
	if v3:
		_load_v3()
	elif new_model:
		_load_new()
	else:
		_load_old()
	for s_ in ["Left", "Right"]:
		_arms[s_] = [bone(s_ + "Arm"), bone(s_ + "ForeArm"), bone(s_ + "Hand")]
	life = preload("res://scripts/spirit_life.gd").new()
	if v3:
		life.bones = {"head": "head", "necks": ["neck01", "neck02", "neck03"], "sp1": "spine02", "sp2": "spine01", "sh": ["clavicle_L", "clavicle_R"]}
	sk.add_child(life)
	_head_b = bone("Head")
	_hips_b = bone("Hips")
	var hr := sk.get_bone_global_rest(_head_b)
	if v3:
		_setup_v3()
		var mid := (sk.get_bone_global_rest(sk.find_bone("eye_L")).origin + sk.get_bone_global_rest(sk.find_bone("eye_R")).origin) * 0.5
		_face_loc = hr.affine_inverse() * (mid + Vector3(0, 0, 0.02))
	else:
		_make_eyes()
		_r0 = hr.basis.orthonormalized() if new_model else Basis.IDENTITY
		_p("head_k", model.scale.x)
		sk.skeleton_updated.connect(_head_to_shader)
		_p("alive", 1.0 if ALIVE else 0.0)
		_face_loc = hr.affine_inverse() * (hr.origin + Vector3(0.0, 0.098, 0.1) / model.scale.x)
	_blink_next = randf_range(2.0, 6.0)
	play("idle")


## Имя кости этой модели по имени прежнего рига без приставки: "Head", "LeftArm", "Spine1"…
func bone_name(n: String) -> String:
	return String(V3_BONES.get(n, n)) if v3 else "mixamorig_" + n


## Номер кости по имени прежнего рига: bone("Head").
func bone(n: String) -> int:
	return sk.find_bone(bone_name(n))


## Точка между её глаз (мир) — в позе после всех надстроек над анимацией (наклон, взгляд, рывки головы):
## такая поза есть в скелете только во время его обновления, поэтому ждём пару кадров. Вызывать с await.
func face_point() -> Vector3:
	var res := [sk.global_transform * (sk.get_bone_global_pose(_head_b) * _face_loc)]
	var cb := func(): res[0] = sk.global_transform * (sk.get_bone_global_pose(_head_b) * _face_loc)
	sk.skeleton_updated.connect(cb)
	await get_tree().process_frame
	await get_tree().process_frame
	sk.skeleton_updated.disconnect(cb)
	return res[0]


## ---------- Аня v3 ----------
static var _v3_shaders := {}
## Шейдер v3 по имени файла; ghostly — «призрачная» версия (та же, с прозрачностью-зерном).
static func v3_shader(n: String, ghostly := false) -> Shader:
	var key := n + ("#g" if ghostly else "")
	if not _v3_shaders.has(key):
		var sh: Shader = load("res://shaders/%s.gdshader" % n)
		if ghostly:
			var g := Shader.new()
			g.code = sh.code.replace("shader_type spatial;", "shader_type spatial;\n#define GHOSTLY")
			sh = g
		_v3_shaders[key] = sh
	return _v3_shaders[key]


func _load_v3() -> void:
	model = load(V3_MODEL).instantiate()
	add_child(model)
	sk = model.find_children("*", "Skeleton3D", true, false)[0]
	ap = AnimationPlayer.new()
	model.add_child(ap)
	var lib := AnimationLibrary.new()
	for n in ANIMS:
		lib.add_animation(n, load("res://models/spirit3/anim_%s.res" % n))
	ap.add_animation_library("g", lib)
	var ej: Dictionary = (load(V3_EYE) as JSON).data
	for mi_ in model.find_children("*", "MeshInstance3D", true, false):
		var g := mi_ as MeshInstance3D
		for si in g.mesh.get_surface_count():
			var src := g.mesh.surface_get_material(si)
			var nm := String(src.resource_name) if src else ""
			var sm := ShaderMaterial.new()
			match nm:
				"skin_head", "skin_body":
					sm.shader = v3_shader("anya_skin")
					sm.set_shader_parameter("albedo_tex", load(V3_TEX[nm][0]))
					sm.set_shader_parameter("normal_tex", load(V3_TEX[nm][1]))
					sm.set_shader_parameter("mask_tex", load(V3_TEX[nm][2]))
					sm.set_shader_parameter("pore_tex", load(V3_TEX.pores))
					sm.set_shader_parameter("pore_scale", 90.0 if nm == "skin_head" else 130.0)
					sm.set_shader_parameter("pore_k", 0.55)
					if nm == "skin_head":
						mat = sm
				"gown":
					sm.shader = v3_shader("anya_cloth")
					sm.set_shader_parameter("albedo_tex", load(V3_TEX.gown[0]))
					sm.set_shader_parameter("normal_tex", load(V3_TEX.gown[1]))
					sm.set_shader_parameter("mask_tex", load(V3_TEX.gown[2]))
					sm.set_shader_parameter("weave_tex", load(V3_TEX.weave))
					_mi = g
				"hair":
					sm.shader = v3_shader("anya_hair")
					sm.set_shader_parameter("strand_tex", load(V3_TEX.hair))
					hair_mat = sm
				"eyes":
					sm.shader = v3_shader("anya_eye")
					sm.set_shader_parameter("albedo_tex", load(V3_TEX.eyes))
					sm.set_shader_parameter("iris_a", Vector2(ej.iris_a[0], ej.iris_a[1]))
					sm.set_shader_parameter("iris_b", Vector2(ej.iris_b[0], ej.iris_b[1]))
					sm.set_shader_parameter("iris_r", float(ej.iris_r))
					eye_mat = sm
				"lashes":
					sm.shader = v3_shader("anya_lash")
					sm.set_shader_parameter("lash_tex", load(V3_TEX.lashes))
				"teeth":
					sm.shader = v3_shader("anya_mouth")
					sm.set_shader_parameter("kind", 1)
				_:
					sm.shader = v3_shader("anya_mouth")
					sm.set_shader_parameter("kind", 0)
			sm.set_meta("v3", nm)
			g.set_surface_override_material(si, sm)
			mats.append(sm)
		if String(g.name).begins_with("Hair"):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## v3: мимика и физика волос (после «живости» — в скелете модификаторы идут по порядку).
func _setup_v3() -> void:
	face = preload("res://scripts/spirit3_face.gd").new()
	sk.add_child(face)
	var meta: Dictionary = (load(V3_HAIR) as JSON).data
	hair_sim = SpringBoneSimulator3D.new()
	hair_sim.name = "HairSim"
	sk.add_child(hair_sim)
	var chains: Dictionary = meta.chains
	hair_sim.setting_count = chains.size()
	var i := 0
	for nm in chains:
		var bl: Array = chains[nm].bones
		var front := absf(float(chains[nm].az)) < 60.0
		hair_sim.set_root_bone_name(i, bl[0])
		hair_sim.set_end_bone_name(i, bl[bl.size() - 1])
		hair_sim.set_extend_end_bone(i, true)
		hair_sim.set_end_bone_direction(i, SkeletonModifier3D.BONE_DIRECTION_FROM_PARENT)
		hair_sim.set_end_bone_length(i, float(chains[nm].end_len))
		hair_sim.set_radius(i, 0.022)
		hair_sim.set_drag(i, HAIR_DRAG)
		hair_sim.set_gravity_direction(i, Vector3.DOWN)
		hair_sim.set_enable_all_child_collisions(i, true)
		_hair_front.append(1.0 if front else 0.0)
		i += 1
	_hair_apply()
	# обо что волосы опираются: голова, лицо, шея, плечи, грудь и спина, руки (точки — в осях скелета, поза покоя)
	_hair_ball("head", Vector3(0, 1.607, 0.040), 0.108)
	_hair_ball("head", Vector3(0, 1.525, 0.085), 0.078)
	_hair_capsule("neck01", Vector3(0, 1.40, -0.005), Vector3(0, 1.53, 0.02), 0.058)
	_hair_capsule("spine01", Vector3(-0.15, 1.325, -0.01), Vector3(0.15, 1.325, -0.01), 0.085)
	_hair_capsule("spine02", Vector3(0, 1.02, 0.01), Vector3(0, 1.26, 0.0), 0.135)
	_hair_capsule("spine04", Vector3(0, 0.80, 0.0), Vector3(0, 0.98, 0.01), 0.15)
	for sd in ["L", "R"]:
		var a := sk.get_bone_global_rest(sk.find_bone("upperarm01_" + sd)).origin
		var b := sk.get_bone_global_rest(sk.find_bone("lowerarm01_" + sd)).origin
		_hair_capsule("upperarm01_" + sd, a, b, 0.062)


## Волосы. Пока она стоит прямо, пряди держат форму причёски (пробор, лицо видно между прядями) и только качаются;
## когда голова сильно наклонена (нагнулась над тобой, ползёт) — «отпускаются» и висят по тяжести.
const HAIR_STIFF := 1.7            ## упругость: насколько пряди держат форму (спереди — полностью, сзади — слабее)
const HAIR_STIFF_LOOSE := 0.04
const HAIR_GRAVITY := 0.3
const HAIR_GRAVITY_LOOSE := 1.7
const HAIR_DRAG := 0.42            ## вязкость: гасит качание
var hair_loose := -1.0             ## 0..1 — задать вручную («отпустить» волосы); -1 — само, по наклону головы
var _hair_front: Array[float] = []
var _loose := 0.0
var _lift := 0.0


func _hair_apply() -> void:
	var k := maxf(_loose, clampf(_lift * 1.6, 0.0, 1.0))
	for i in hair_sim.setting_count:
		var st := HAIR_STIFF * (1.0 if _hair_front[i] > 0.5 else 0.55)
		hair_sim.set_stiffness(i, lerpf(st, HAIR_STIFF_LOOSE, k))
		hair_sim.set_gravity(i, lerpf(HAIR_GRAVITY, HAIR_GRAVITY_LOOSE, k) * (1.0 - 1.9 * _lift))


## Скрыта — физика волос не считается; показалась (обычно уже в другом месте) — волосы начинают с позы покоя,
## а не хлещут через всю комнату.
## (Сам сброс — в следующем кадре, из _hair_tick: при выходе из игры узлы тоже получают это уведомление,
## и трогать физику в этот момент нельзя — движок зависал на выходе.)
var _vis_dirty := false
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and v3:
		_vis_dirty = true


## Каждый кадр: по наклону головы решить, держат ли волосы форму или висят.
func _hair_tick(delta: float) -> void:
	if _vis_dirty:
		_vis_dirty = false
		hair_sim.reset()
	var want := hair_loose
	if want < 0.0:
		var up := (sk.global_transform.basis * sk.get_bone_global_pose(_head_b).basis.y).normalized()   # ось головы (вверх в покое)
		want = smoothstep(0.30, 0.75, 1.0 - up.dot(Vector3.UP))
	var k := move_toward(_loose, want, delta * 2.5)
	if absf(k - _loose) > 0.001:
		_loose = k
		_hair_apply()


func _hair_ball(bone_: String, at: Vector3, r: float) -> void:
	var c := SpringBoneCollisionSphere3D.new()
	hair_sim.add_child(c)
	c.bone_name = bone_
	c.radius = r
	c.position_offset = sk.get_bone_global_rest(sk.find_bone(bone_)).affine_inverse() * at


func _hair_capsule(bone_: String, a: Vector3, b: Vector3, r: float) -> void:
	var c := SpringBoneCollisionCapsule3D.new()
	hair_sim.add_child(c)
	c.bone_name = bone_
	c.radius = r
	c.height = a.distance_to(b) + r * 2.0
	var rest := sk.get_bone_global_rest(sk.find_bone(bone_))
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var want := Basis(x, y, x.cross(y))
	c.position_offset = rest.affine_inverse() * ((a + b) * 0.5)
	c.rotation_offset = (rest.basis.orthonormalized().inverse() * want).get_rotation_quaternion()


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


## Параметр шейдера — и телу, и волосам (у v3 — всем её материалам: оттенок, кровь, ореол, near_cut…).
func _p(name_: String, v: Variant) -> void:
	if v3:
		for m in mats:
			m.set_shader_parameter(name_, v)
		return
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
	if v3:
		eye_mat.set_shader_parameter("glow", v)
		return
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
	if v3:                               # пальцы скрючиваются, зрачки сжимаются в точку
		var tc := create_tween()
		tc.tween_property(face, "claw", 1.0, 0.12)
		tc.tween_interval(hold)
		tc.tween_property(face, "claw", 0.0, 1.0)
		eye_mat.set_shader_parameter("pupil", 0.16)
		get_tree().create_timer(hold + 0.5).timeout.connect(func(): eye_mat.set_shader_parameter("pupil", 0.30))
	if eye_power > 0.01:
		var e0 := eye_power
		set_eyes(e0 * 2.4)
		get_tree().create_timer(hold + 0.3).timeout.connect(func(): set_eyes(e0))
	get_tree().create_timer(hold + 0.3).timeout.connect(func(): life.shiver = 0.0)


func set_blood(v: float) -> void:
	_p("blood", v)


## Волосы дыбом (0..1). У v3 — физикой: тяжесть слабеет и меняет знак, пряди всплывают.
func set_lift(v: float) -> void:
	_p("lift", v)
	if v3:
		_lift = v
		_hair_apply()


## Полупрозрачная «призрачная» версия (0 — обычная, 1 — сильно просвечивает):
## сквозь неё виден фон, тело «дышит» пятнами плотности, по краю холодный ореол, ноги тают к полу.
## Шейдер — тот же spirit.gdshader с добавленной прозрачностью (собирается один раз).
static var _ghost_shader: Shader
## Прозрачность — «alpha hash» (рассыпчатое зерно вместо смешивания): рисуется как непрозрачная,
## с предпроходом глубины, поэтому 200 тыс. треугольников волос не пересчитываются слоями — нет просадки FPS.
func set_ghostly(v: float) -> void:
	if v3:
		var on := v > 0.0
		if on != _ghost_on:
			_ghost_on = on
			for m in mats:
				var n := String(m.get_meta("v3"))
				var file := "anya_skin" if n.begins_with("skin") else ("anya_cloth" if n == "gown" else ("anya_hair" if n == "hair" else ("anya_eye" if n == "eyes" else ("anya_lash" if n == "lashes" else "anya_mouth"))))
				m.shader = v3_shader(file, on)
			if on:
				for mi in find_children("*", "GeometryInstance3D", true, false):
					(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_p("ghost", v)
		return
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


var _ghost_on := false
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
	if v3:
		_hair_tick(delta)
		return
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
	if not FACE and not v3:
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
	if v3:                           # у v3 рот — костями: крик — челюсть и губы, шёпот и дыхание — чуть приоткрытые губы
		face.jaw = mouth + (sin(_t * 41.0) * 0.04 * mouth if mouth > 0.3 else 0.0)
		face.murmur = maxf(m - mouth, 0.0) if mouth < 0.05 else 0.0
		face.grimace = clampf(gr, 0.0, 1.0)
		return
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
	if v3 and cam:                    # глаза находят тебя раньше, чем повернётся голова
		face.look_target = cam.global_position
		face.look_w = move_toward(face.look_w, 1.0 if (watch and visible) else 0.0, delta * 2.5)
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
	if v3:
		face.blink = _blink
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
		if v3:
			hair_sim.reset()
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
	if not FACE or v3:
		return
	var hp := sk.get_bone_global_pose(_head_b)
	# оси «лица» = оси кости головы в покое (у новой модели они не совпадают с осями скелета)
	_p("head_inv", Projection(Transform3D(_r0, Vector3.ZERO) * hp.affine_inverse()))
	_p("head_rot", hp.basis.orthonormalized() * _r0.inverse())
