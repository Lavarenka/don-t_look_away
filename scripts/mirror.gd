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
const REFL_H := 560         ## разрешение отражения по высоте (ширина — по пропорции); старое стекло мутное — больше не нужно
const GHOST_LAYER := 3      ## слой «только в зеркале»: призрак и двойник
const STILL_T := 2.5        ## сколько стоять неподвижно перед зеркалом до испуга

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
## Испуги в зеркале: 0 — девочка за плечом, 1 — двойник бросается из зеркала, 2 — всё
var stage := 0
var still := 0.0
var cooldown := 0.0
var _lib: AnimationLibrary
var _frame := 0
var _spill: OmniLight3D      ## подсветка тела игрока для зеркала (только тело, не туман)


## Прогрев: один кадр отражения в темноте при входе на чердак — шейдеры тела и окружения
## компилируются заранее, а не в тот момент, когда простыня сползает.
func prewarm() -> void:
	# своё, облегчённое окружение для отражения: без объёмного тумана, SSAO/SSIL/SSR и свечения —
	# иначе сцена фактически рисуется дважды со всеми тяжёлыми эффектами
	var we := L.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var env: Environment = we.environment.duplicate()
		env.volumetric_fog_enabled = false
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.ssr_enabled = false
		env.sdfgi_enabled = false
		env.glow_enabled = false
		mcam.environment = env
	_place_camera()
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


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
	mcam.cull_mask &= ~(1 << 10)        # «отражённый» слой осколка в обычном зеркале не виден
	vp.add_child(mcam)
	vp.positional_shadow_atlas_size = 1024
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
	p.cam.cull_mask &= ~(1 << (GHOST_LAYER - 1))
	# свет фонаря «отражается» на самом игроке — мягкая подсветка, которая освещает только тело
	var spill := OmniLight3D.new()
	spill.light_color = Color(1.0, 0.9, 0.75)
	spill.light_energy = 0.9
	spill.omni_range = 1.8
	spill.light_cull_mask = (1 << (BODY_LAYER - 1)) | (1 << (GHOST_LAYER - 1))
	spill.shadow_enabled = false
	spill.light_volumetric_fog_energy = 0.0   # иначе в тумане перед глазами висит белое пятно, даже с выключенным фонарём
	spill.light_bake_mode = Light3D.BAKE_DISABLED
	spill.position = Vector3(0, 1.25, -0.55)
	p.add_child(spill)
	_spill = spill
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
	_lib = lib
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
	if _spill:
		_spill.visible = L.player.is_light_lit()      # фонарь выключен — и отсвета на теле нет
	if body == null:
		return
	_animate(delta)
	var active: bool = open and L.phase == "attic" and _in_view()
	# отражение обновляется через кадр (30 к/с при 60) — на глаз не заметно, а нагрузка вдвое меньше
	_frame += 1
	if active and _frame % 2 == 0:
		_place_camera()
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	elif not active:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_scares(delta, active)


# ---------------- испуги в зеркале ----------------
func _scares(delta: float, active: bool) -> void:
	cooldown -= delta
	if stage >= 2 or L.busy:
		return
	var p: CharacterBody3D = L.player
	var cam: Camera3D = p.cam
	var to: Vector3 = glass.global_position - cam.global_position
	var looking: bool = active and to.length() < 3.6 and p.forward().angle_to(to) < 0.42
	if looking and Vector2(p.velocity.x, p.velocity.z).length() < 0.15:
		still += delta
	else:
		still = 0.0
	if still < STILL_T or cooldown > 0.0:
		return
	still = 0.0
	if stage == 0:
		stage = 1
		cooldown = 22.0
		_scare_girl()
	else:
		stage = 2
		_scare_double()


func _only_mirror(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = 1 << (GHOST_LAYER - 1)
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## 1) Девочка стоит у тебя за плечом — только в отражении. Обернёшься или моргнёт свет — её нет.
func _scare_girl() -> void:
	var p: CharacterBody3D = L.player
	var g := Node3D.new()
	var sp: Node3D = preload("res://scripts/spirit.gd").new()
	g.add_child(sp)
	L.add_child(g)
	sp.play_from("idle", 1.5, 1.0)
	sp.set_blood(0.35)
	sp.float_h = 0.12
	sp.set_layer(1 << (GHOST_LAYER - 1))
	var right: Vector3 = p.global_basis.x
	var back: Vector3 = p.global_basis.z
	g.global_position = p.global_position + back * 0.85 + right * 0.32
	L._face(g, glass.global_position)
	var gl := OmniLight3D.new()                       # холодный свет только на неё (слой зеркала)
	gl.light_color = Color(0.6, 0.7, 1.0)
	gl.light_energy = 1.6
	gl.omni_range = 2.2
	gl.light_cull_mask = 1 << (GHOST_LAYER - 1)
	g.add_child(gl)
	gl.position = Vector3(0, 1.3, 0)
	gl.global_position = gl.global_position + (glass.global_position - g.global_position).normalized() * 0.7
	L._sfx("whisper_harsh", -8.0, 0.8)
	var t := 0.0
	while t < 1.6:
		await get_tree().process_frame
		t += get_process_delta_time()
		var to: Vector3 = glass.global_position - p.cam.global_position
		if p.forward().angle_to(to) > 0.7:          # отвернулся — её уже нет
			break
	L._sfx("sting", -12.0, 0.7)
	g.queue_free()


## 2) Отражение замирает, наклоняет голову… и бросается на тебя из зеркала.
func _scare_double() -> void:
	var p: CharacterBody3D = L.player
	var d: Node3D = load("res://models/player/remy.fbx").instantiate()
	d.scale = body.scale
	L.add_child(d)
	d.global_transform = body.global_transform
	_only_mirror(d)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0, 0, 0, 0.4)
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mi in d.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = dark
	var dap: AnimationPlayer = d.get_node("AnimationPlayer")
	dap.add_animation_library("m", _lib)
	dap.play("m/idle")
	dap.speed_scale = 0.0
	var dsk: Skeleton3D = d.get_node("Skeleton3D")
	# настоящее тело пропадает из отражения — в зеркале остаётся двойник, который больше не повторяет за тобой
	mcam.cull_mask &= ~(1 << (BODY_LAYER - 1))
	L.busy = true
	await get_tree().create_timer(0.9).timeout
	# медленно наклоняет голову набок
	var hb := dsk.find_bone("mixamorig_Head")
	var h0 := dsk.get_bone_pose_rotation(hb)
	L._sfx("tinnitus", -14.0)
	var t := 0.0
	while t < 1.1:
		await get_tree().process_frame
		t += get_process_delta_time()
		dsk.set_bone_pose_rotation(hb, h0 * Quaternion(Vector3.FORWARD, deg_to_rad(38.0) * minf(t / 1.1, 1.0)))
	await get_tree().create_timer(0.35).timeout
	# рывок к стеклу
	p.frozen = true
	dap.play("m/back", 0.0, -3.0, true)
	dap.speed_scale = 1.0
	L._sfx("scream", 1.0)
	var start: Vector3 = d.global_position
	var aim: Vector3 = glass.global_position - glass.global_basis.z * 0.0
	aim.y = start.y
	var dir: Vector3 = (aim - start)
	var end: Vector3 = start + dir.normalized() * maxf(dir.length() - 0.55, 0.0)
	t = 0.0
	while t < 0.38:
		await get_tree().process_frame
		t += get_process_delta_time()
		d.global_position = start.lerp(end, t / 0.38)
	# …и выскакивает: на долю секунды — прямо перед лицом
	for mi in d.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = 1
	var cam: Camera3D = p.cam
	var fw: Vector3 = -cam.global_basis.z
	fw.y = 0.0
	fw = fw.normalized()
	d.global_position = cam.global_position + fw * 0.45 - Vector3(0, body.scale.y * EYE, 0)
	L._face(d, cam.global_position)
	L.red_flash.color.a = 0.55
	p.shake = 1.0
	await get_tree().create_timer(0.28).timeout
	d.queue_free()
	L.fade.color.a = 1.0
	await get_tree().create_timer(0.35).timeout
	create_tween().tween_property(L.fade, "color:a", 0.0, 0.6)
	create_tween().tween_property(L.red_flash, "color:a", 0.0, 0.8)
	mcam.cull_mask |= 1 << (BODY_LAYER - 1)       # отражение снова твоё
	L._sfx("heartbeat", -6.0)
	p.frozen = false
	L.busy = false


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
