extends Node
## Атмосфера дома: свет и туман + мелкие тихие события (без скримеров).
##
## Свет и туман:
##  - стелющийся по полу туман (FogVolume с медленно плывущим шумом) на обоих этажах и на чердаке;
##  - пыль в воздухе: крошечные пылинки, видимые только в луче фонаря и у ламп;
##  - облака на луне: лунный свет из окон время от времени медленно меркнет и возвращается;
##  - лампы в соседних комнатах сами мигают, иногда гаснут на несколько секунд.
## Мелкие события (раз в 1–2 минуты, только когда тихо):
##  - тень проходит мимо открытой двери в конце коридора (далеко, без звука, не скример);
##  - над головой скрипят доски — с потолка сыплется пыль.
## На чердаке теней не бывает (там свои сценки).

const SPIRIT = preload("res://scripts/spirit.gd")

var L: Node
var dust: GPUParticles3D
var moons: Array[Light3D] = []
var moon_base := {}
var lamps: Array[Light3D] = []
var t := 0.0
var next_event := 70.0        ## первое событие — не сразу
var next_cloud := 25.0
var next_lamp := 20.0
var shadow_n := 0


func setup(level: Node) -> void:
	L = level
	_ground_fog()
	_dust()
	for n in ["MoonW", "MoonE", "MoonNW", "MoonNE", "AMoonN", "AMoonS"]:
		var m := L.get_node_or_null(n) as Light3D
		if m:
			moons.append(m)
			moon_base[m] = m.light_energy
	# лампы для мигания — только «декоративные», которыми не управляют загадки
	if L.bedroom:
		for o in L.bedroom.lamps:
			lamps.append(o)
	var g := L.get_node_or_null("Attic/ALamp/Glow") as Light3D
	if g:
		lamps.append(g)


# ---------------- туман по полу ----------------
func _ground_fog() -> void:
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.012
	fn.fractal_octaves = 3
	nt.noise = fn
	var sh := Shader.new()
	sh.code = """
shader_type fog;
uniform float density = 1.3;
uniform vec3 albedo : source_color = vec3(0.62, 0.66, 0.72);
uniform sampler2D noise_tex : repeat_enable, filter_linear;
void fog() {
	// гуще у самого пола, к колену сходит на нет; клочья медленно плывут
	float h = clamp(UVW.y, 0.0, 1.0);
	float fall = pow(1.0 - h, 2.2);
	vec2 p = WORLD_POSITION.xz * 0.11;
	float n = texture(noise_tex, p + TIME * vec2(0.006, 0.004)).r;
	float n2 = texture(noise_tex, p * 2.3 - TIME * vec2(0.004, 0.007)).r;
	float clump = smoothstep(0.28, 0.75, n * 0.65 + n2 * 0.35);
	DENSITY = density * fall * (0.25 + clump * 1.1);
	ALBEDO = albedo;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("noise_tex", nt)
	# [центр, размер]: первый этаж + чердак (пол на y=0), второй этаж со спальней (пол на y=-3.4)
	for b in [[Vector3(0, 0.42, -19.0), Vector3(9.0, 0.95, 54.0)], [Vector3(-6.5, -2.98, -34.5), Vector3(25.0, 0.95, 23.0)]]:
		var fv := FogVolume.new()
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		fv.size = b[1]
		fv.material = mat
		L.add_child(fv)
		fv.global_position = b[0]


# ---------------- пыль в воздухе ----------------
func _dust() -> void:
	dust = GPUParticles3D.new()
	dust.amount = 420
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.local_coords = false
	dust.visibility_aabb = AABB(Vector3(-6, -4, -9), Vector3(12, 8, 18))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.6, 1.3, 3.6)
	pm.gravity = Vector3(0, -0.004, 0)
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.03
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_noise_speed = Vector3(0.02, 0.01, 0.02)
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.06
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	var fade := Gradient.new()                     # пылинка плавно появляется и исчезает
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = fade
	pm.color_ramp = gt
	dust.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.007, 0.007)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX     # освещается: видна только в свете
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 0.95, 0.85, 0.75)
	m.disable_receive_shadows = true
	q.material = m
	dust.draw_pass_1 = q
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	L.add_child(dust)


func _process(delta: float) -> void:
	t += delta
	var p = L.player
	if dust and p:
		# облако пылинок держится перед глазами (сами пылинки остаются на месте в мире)
		dust.global_position = p.cam.global_position + p.forward() * 2.8
	next_cloud -= delta
	if next_cloud <= 0.0:
		next_cloud = randf_range(35.0, 70.0)
		_cloud()
	next_lamp -= delta
	if next_lamp <= 0.0:
		next_lamp = randf_range(18.0, 40.0)
		_lamp_flicker()
	next_event -= delta
	if next_event <= 0.0:
		next_event = 8.0                            # не вышло — попробуем чуть позже
		if _event():
			next_event = randf_range(60.0, 120.0)


# ---------------- облака на луне ----------------
func _cloud() -> void:
	var k := randf_range(0.2, 0.45)
	for m in moons:
		var tw := create_tween()
		tw.tween_property(m, "light_energy", moon_base[m] * k, randf_range(2.5, 4.0)).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(randf_range(3.0, 9.0))
		tw.tween_property(m, "light_energy", moon_base[m], randf_range(4.0, 6.0)).set_trans(Tween.TRANS_SINE)


# ---------------- лампы мигают ----------------
func _lamp_flicker() -> void:
	if L.busy or not L.quiet_for(4.0):
		return
	var pp: Vector3 = L.player.global_position
	var pool := []
	for o in lamps:
		if not is_instance_valid(o) or o.light_energy < 0.05:
			continue
		var d := o.global_position.distance_to(pp)
		if d > 2.5 and d < 16.0:
			pool.append(o)
	if pool.is_empty():
		return
	var o: Light3D = pool.pick_random()
	var base := o.light_energy
	var dies := randf() < 0.3
	var seq := []                      # [доля яркости, секунд]
	for i in randi_range(4, 9):
		seq.append([randf_range(0.0, 0.35), randf_range(0.03, 0.09)])
		seq.append([randf_range(0.7, 1.0), randf_range(0.04, 0.2)])
	if dies:
		seq.append([0.0, randf_range(3.0, 8.0)])
		seq.append([0.4, 0.06])
		seq.append([0.0, 0.25])
	L._sfx3d("click", o.global_position, -24.0, randf_range(1.6, 2.2))
	for s in seq:
		if not is_instance_valid(o):
			return
		var e: float = base * s[0]
		o.light_energy = e
		await get_tree().create_timer(s[1]).timeout
		if not is_instance_valid(o) or absf(o.light_energy - e) > 0.001:
			return                     # лампой занялся кто-то другой (сценка) — не мешаем
	o.light_energy = base


# ---------------- мелкие события ----------------
func _event() -> bool:
	if L.busy or L.phase in ["intro", "end", "attic"] or not L.quiet_for(15.0):
		return false
	if L.attic and L.attic.has_method("is_active") and L.attic.is_active():
		return false
	if randf() < 0.55 and _shadow_pass():
		return true
	return _ceiling_dust()


## Тень проходит мимо открытой двери вдалеке — только если игрок смотрит прямо туда.
func _shadow_pass() -> bool:
	var p = L.player
	var eye: Vector3 = p.cam.global_position
	var fwd: Vector3 = p.forward()
	var space: PhysicsDirectSpaceState3D = L.get_world_3d().direct_space_state
	for id in L.doors.doors:
		if not L.doors.is_open(id):
			continue
		var c: Vector3 = L.doors.doors[id].center
		var to := c - eye
		var dist := Vector2(to.x, to.z).length()
		if dist < 6.0 or dist > 15.0 or absf(c.y - eye.y) > 1.6:
			continue
		if fwd.angle_to(to) > 0.3:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, c)
		q.exclude = [p.get_rid()]
		if not space.intersect_ray(q).is_empty():
			continue                                   # проём не виден
		# пол под проёмом
		var dq := PhysicsRayQueryParameters3D.create(c, c + Vector3(0, -3, 0))
		var hit := space.intersect_ray(dq)
		if hit.is_empty():
			continue
		var floor_y: float = hit.position.y
		var away := Vector3(to.x, 0, to.z).normalized()
		var side := away.cross(Vector3.UP).normalized()
		var base := Vector3(c.x, floor_y, c.z) + away * 0.9      # сразу за проёмом
		var a := base - side * 1.0
		var b := base + side * 1.0
		if randf() < 0.5:
			var tmp := a
			a = b
			b = tmp
		var g := SPIRIT.new()
		L.add_child(g)
		g.global_position = a
		var d := b - a
		g.rotation.y = atan2(d.x, d.z)
		g.mat.set_shader_parameter("tint", Color(0.07, 0.065, 0.07))
		g.mat.set_shader_parameter("rim", 0.0)
		g.set_eyes(0.0)
		g.set_blood(0.0)
		for mi in g.find_children("*", "GeometryInstance3D", true, false):
			(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.play("walk", 1.25, 0.0)
		shadow_n += 1
		var tw := create_tween()
		tw.tween_property(g, "global_position", b, 1.4)
		tw.tween_callback(g.queue_free)
		get_tree().create_timer(0.9).timeout.connect(func(): L._sfx3d("step%d" % (randi() % 4), base, -16.0, 0.8))
		return true
	return false


## Над головой проходит кто-то тяжёлый: скрип досок и пыль с потолка перед игроком.
func _ceiling_dust() -> bool:
	var p = L.player
	var space: PhysicsDirectSpaceState3D = L.get_world_3d().direct_space_state
	var f: Vector3 = p.forward()
	f.y = 0.0
	var at: Vector3 = p.cam.global_position + f.normalized() * 1.3
	var q := PhysicsRayQueryParameters3D.create(at, at + Vector3(0, 3.5, 0))
	q.exclude = [p.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	var top: Vector3 = hit.position - Vector3(0, 0.03, 0)
	L._sfx3d("beam_creak", top + Vector3(0, 0.6, 0), -10.0, randf_range(0.8, 1.0))
	for k in 3:
		get_tree().create_timer(0.5 + k * 0.6).timeout.connect(func(): L._sfx3d("step%d" % (randi() % 4), top + Vector3(k * 0.4, 0.8, 0), -9.0, 0.75))
	get_tree().create_timer(0.35).timeout.connect(_spawn_dust.bind(top))
	return true


func _spawn_dust(top: Vector3) -> void:
	var ps := GPUParticles3D.new()
	ps.one_shot = true
	ps.amount = 90
	ps.lifetime = 2.6
	ps.explosiveness = 0.55
	ps.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.35, 0.01, 0.35)
	pm.gravity = Vector3(0, -0.9, 0)
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.15
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 25.0
	pm.damping_min = 0.4
	pm.damping_max = 0.9
	pm.scale_min = 0.6
	pm.scale_max = 1.8
	ps.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.012, 0.012)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.albedo_color = Color(0.75, 0.7, 0.62, 0.8)
	qm.material = m
	ps.draw_pass_1 = qm
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	L.add_child(ps)
	ps.global_position = top
	ps.emitting = true
	get_tree().create_timer(4.0).timeout.connect(ps.queue_free)
