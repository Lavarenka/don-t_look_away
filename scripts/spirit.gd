extends Node3D
## Призрак девочки (Blood Stained Spirit, adhamasalah, CC BY; риг и анимации — Mixamo).
## Меш с запечёнными масками (tools/bake_spirit.gd) + шейдер shaders/spirit.gdshader:
## рукава провисают под весом, волосы и подол колышутся, кровь проступает по команде.
##
## Анимации: idle — стоит как призрак, zidle — жуткое покачивание, walk — медленный шаг,
## run — бег, reach — тянет руку.

const HEIGHT := 1.7          ## рост, м (один для всех появлений призрака)
const EYE_OFS := Vector3(0.031, 0.095, 0.097)   ## глаза от кости головы (м): в стороны, вверх, вперёд
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


## Блики глаз: две крошечные холодные точки у головы — в темноте видно, что она смотрит.
func _make_eyes() -> void:
	var head := sk.find_bone("mixamorig_Head")
	var ba := BoneAttachment3D.new()
	ba.bone_idx = head
	sk.add_child(ba)
	var hp := sk.get_bone_global_rest(head)
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = Color(0.85, 0.9, 0.8)
	var sph := SphereMesh.new()
	sph.radius = 0.0045 / model.scale.x
	sph.height = sph.radius * 2.0
	sph.radial_segments = 8
	sph.rings = 4
	for sx in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		e.mesh = sph
		e.material_override = em
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ba.add_child(e)
		var p := hp.origin + Vector3(sx * EYE_OFS.x, EYE_OFS.y, EYE_OFS.z) / model.scale.x
		e.position = hp.affine_inverse() * p
		eyes.append(e)
	set_eyes(0.45)


## Яркость бликов глаз (0 — не видно).
func set_eyes(v: float) -> void:
	for e in eyes:
		e.visible = v > 0.01
		(e.material_override as StandardMaterial3D).albedo_color = Color(0.85, 0.9, 0.8) * v


## Дрожь (0..1) — например, перед броском.
func set_shiver(v: float) -> void:
	life.shiver = v


func set_blood(v: float) -> void:
	mat.set_shader_parameter("blood", v)


func set_lift(v: float) -> void:
	mat.set_shader_parameter("lift", v)


## Видна только на заданном слое отрисовки (например, только в зеркале).
func set_layer(mask: int) -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = mask
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_t += delta
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
