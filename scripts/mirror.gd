extends Node
## Настоящее зеркало на чердаке + тело игрока, которое видно только в отражении.
##
## Как работает отражение: вторая камера стоит «за стеклом» — зеркально к камере игрока —
## и смотрит сквозь стекло косой пирамидой (frustum), ровно по краям рамы. Её картинка
## (SubViewport) выводится на стекло, отражённая по горизонтали. Тело игрока (Remy, Mixamo)
## лежит на слое отрисовки 2: камера игрока этот слой не видит, камера зеркала — видит.

const GW := 0.56            ## ширина стекла, м
const GH := 1.5             ## высота стекла, м
const EYE := 3.47           ## высота глаз модели Remy в её единицах
const BODY_LAYER := 2       ## слой «тело игрока»
const REFL_H := 900         ## разрешение отражения по высоте (ширина — по пропорции)

var L: Node                 ## level.gd
var glass: MeshInstance3D
var vp: SubViewport
var mcam: Camera3D
var body: Node3D
var sk: Skeleton3D
var ap: AnimationPlayer
var bones := {}
var open := false           ## простыня снята — зеркало работает
var _anim := ""
var _speed := 0.0


func setup(level: Node, mirror: Node3D) -> void:
	L = level
	# стекло: плоскость поверх старого «бокса»
	var old: Node3D = mirror.get_node("Glass")
	glass = MeshInstance3D.new()
	glass.name = "Reflection"
	var q := QuadMesh.new()
	q.size = Vector2(GW, GH)
	glass.mesh = q
	glass.position = old.position + Vector3(0, 0, 0.0065)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mirror.add_child(glass)
	# вьюпорт с камерой отражения (мир — общий с основной сценой)
	vp = SubViewport.new()
	vp.size = Vector2i(int(REFL_H * GW / GH), REFL_H)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(vp)
	mcam = Camera3D.new()
	mcam.projection = Camera3D.PROJECTION_FRUSTUM
	mcam.keep_aspect = Camera3D.KEEP_HEIGHT
	mcam.size = GH
	mcam.far = 30.0
	mcam.current = true
	vp.add_child(mcam)
	# материал старого зеркала: отражение темнее, с пятнами облезлой амальгамы и тёмными краями
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D refl : source_color, filter_linear;
uniform sampler2D spots : filter_linear, repeat_enable;
void fragment() {
	vec3 c = texture(refl, vec2(1.0 - UV.x, UV.y)).rgb * vec3(0.70, 0.71, 0.66);
	float n = texture(spots, UV * vec2(0.55, 1.4)).r;
	float e = min(min(UV.x, 1.0 - UV.x) * 2.6, min(UV.y, 1.0 - UV.y) * 1.2);
	float desil = smoothstep(0.66, 0.8, n) + (1.0 - smoothstep(0.0, 0.35, e)) * 0.55 * smoothstep(0.45, 0.7, n);
	c = mix(c, vec3(0.035, 0.03, 0.025), clamp(desil, 0.0, 0.92));
	c *= mix(0.45, 1.0, smoothstep(0.0, 0.5, e));
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
	fn.seed = 9
	fn.frequency = 0.02
	fn.fractal_octaves = 4
	nt.noise = fn
	m.set_shader_parameter("spots", nt)
	glass.material_override = m
	_setup_body()


func _setup_body() -> void:
	var p: Node3D = L.player
	body = load("res://models/player/remy.fbx").instantiate()
	body.name = "MirrorBody"
	var k: float = (p.head.position.y) / EYE
	body.scale = Vector3(k, k, k)
	body.rotation.y = PI                       # Mixamo смотрит в +Z, игрок — в −Z
	p.add_child(body)
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = 1 << (BODY_LAYER - 1)
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # фонарь светит «из головы»
	p.cam.cull_mask &= ~(1 << (BODY_LAYER - 1))
	# свет фонаря «отражается» на самом игроке — мягкая подсветка, которая освещает только тело
	var spill := OmniLight3D.new()
	spill.light_color = Color(1.0, 0.9, 0.75)
	spill.light_energy = 0.9
	spill.omni_range = 1.8
	spill.light_cull_mask = 1 << (BODY_LAYER - 1)
	spill.shadow_enabled = false
	spill.position = Vector3(0, 1.25, -0.55)
	p.add_child(spill)
	sk = body.get_node("Skeleton3D")
	for i in sk.get_bone_count():
		bones[sk.get_bone_name(i).trim_prefix("mixamorig_")] = i
	ap = body.get_node("AnimationPlayer")
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var lib := AnimationLibrary.new()
	var idle: Animation = ap.get_animation("mixamo_com").duplicate()
	idle.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation("idle", idle)
	for pair in [["back", "anim_back"], ["left", "anim_left"], ["right", "anim_right"]]:
		var src: Node = load("res://models/player/%s.fbx" % pair[1]).instantiate()
		var a: Animation = (src.get_node("AnimationPlayer") as AnimationPlayer).get_animation("mixamo_com").duplicate()
		a.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(pair[0], a)
		src.free()
	ap.add_animation_library("m", lib)
	ap.play("m/idle")
	# фонарик в правой руке (виден только в отражении)
	var ba := BoneAttachment3D.new()
	ba.bone_name = "mixamorig_RightHand"
	sk.add_child(ba)
	var torch := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.05
	cyl.height = 0.42
	torch.mesh = cyl
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.08, 0.08, 0.09)
	tm.metallic = 0.7
	tm.roughness = 0.4
	tm.emission_enabled = true
	tm.emission = Color(0.02, 0.02, 0.02)
	torch.material_override = tm
	torch.layers = 1 << (BODY_LAYER - 1)
	torch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	torch.position = Vector3(0, 0.18, 0.06)
	ba.add_child(torch)


func _process(delta: float) -> void:
	if body == null:
		return
	_animate(delta)
	var active: bool = open and L.phase == "attic" and _in_view()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if active:
		_place_camera()


## Видно ли зеркало игроку (близко и спереди) — иначе не тратим кадр на отражение.
func _in_view() -> bool:
	var cam: Camera3D = L.player.cam
	var to: Vector3 = glass.global_position - cam.global_position
	if to.length() > 9.0:
		return false
	if to.dot(glass.global_basis.z) > -0.02:      # стоим за зеркалом
		return false
	return cam.is_position_in_frustum(glass.global_position) or to.length() < 1.5


func _place_camera() -> void:
	var G := glass.global_transform.orthonormalized()
	var e: Vector3 = L.player.cam.global_position
	var el: Vector3 = G.affine_inverse() * e
	var d := el.z
	if d < 0.03:
		return
	var b := Basis(-G.basis.x, G.basis.y, -G.basis.z)
	mcam.global_transform = Transform3D(b, G * Vector3(el.x, el.y, -d))
	mcam.near = d
	mcam.frustum_offset = Vector2(el.x, -el.y)


## Анимация тела по скорости игрока + поднятая рука с фонарём + наклон головы.
func _animate(delta: float) -> void:
	var p: CharacterBody3D = L.player
	var v: Vector3 = p.global_basis.inverse() * p.velocity
	var sp := Vector2(v.x, v.z).length()
	var name := "m/idle"
	var spd := 1.0
	if sp > 0.25:
		if absf(v.z) >= absf(v.x):
			name = "m/back"
			spd = sp / 1.25 * (-1.0 if v.z < 0.0 else 1.0)      # вперёд — та же походка назад, проигранная наоборот
		else:
			name = "m/right" if v.x > 0.0 else "m/left"
			spd = sp / 1.3
	if name != _anim or absf(spd - _speed) > 0.15:
		if name != _anim:
			ap.play(name, 0.25, spd)
		else:
			ap.speed_scale = 1.0
			ap.play(name, -1, spd)
		_anim = name
		_speed = spd
	ap.advance(delta)
	# правая рука держит фонарь перед собой, голова — туда, куда смотрит камера
	_aim_bone("RightArm", "RightForeArm", Vector3(-0.12, -0.35, 1.0))
	_aim_bone("RightForeArm", "RightHand", Vector3(-0.05, 0.05, 1.0))
	var pitch: float = p.head.rotation.x
	_turn("Neck", Vector3.RIGHT, -pitch * 0.4)
	_turn("Head", Vector3.RIGHT, -pitch * 0.6)


## Повернуть кость так, чтобы направление «кость → дочерняя кость» смотрело в dir (пространство модели).
func _aim_bone(bone: String, child: String, dir: Vector3) -> void:
	var b: int = bones[bone]
	var c: int = bones[child]
	var gb := sk.get_bone_global_pose(b)
	var gc := sk.get_bone_global_pose(c)
	var cur := (gc.origin - gb.origin).normalized()
	var rot := Quaternion(cur, dir.normalized())
	var par := sk.get_bone_parent(b)
	var pg := sk.get_bone_global_pose(par).basis if par != -1 else Basis()
	var ng := Basis(rot) * gb.basis
	sk.set_bone_pose_rotation(b, (pg.inverse() * ng).orthonormalized().get_rotation_quaternion())


func _turn(bone: String, axis: Vector3, ang: float) -> void:
	var b: int = bones[bone]
	var par := sk.get_bone_parent(b)
	var pg := sk.get_bone_global_pose(par).basis
	var ng := Basis(axis, ang) * sk.get_bone_global_pose(b).basis
	sk.set_bone_pose_rotation(b, (pg.inverse() * ng).orthonormalized().get_rotation_quaternion())
