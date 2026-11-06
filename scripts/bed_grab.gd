extends Node
## Детская, под кроватью (катсцена «рука»). Игрок уже присел и смотрит под кровать (nursery._under_bed).
## Своя левая рука тянется к рисунку на полу; пальцы почти касаются листа — и из темноты под кроватью
## выскальзывает маленькая бледная рука, хватает за запястье и рывком тянет к себе. Игрок дёргается,
## вырывается, рука исчезает в темноте. Дальше — как было (встаёт, Аня перед ним, рисунок).
## Откатить: BED_GRAB = false в nursery.gd — прежние «глаза» под кроватью.

const ARM := preload("res://scripts/fp_arm.gd")
const BODY_LAYER := 1 << 19             ## своя рука — свой слой и свой мягкий свет (как в звонке)
const SPILL := 0.85                     ## ореол фонаря на своей руке
const FLASH_REF := 1.2                  ## ближе этого к рисунку фонарь приглушается…
const FLASH_MIN := 0.3                  ## …но не тусклее этой доли
const CHILD := 0.8                      ## детская рука: масштаб от взрослой
const LEAN_DROP := 0.1

var L: Node
var me: Node                            ## fp_arm.gd — своя рука
var she: Node                           ## fp_arm.gd — рука из-под кровати
var _mat: ShaderMaterial
var _spill: SpotLight3D
var _spill_k := 0.0
var _flash_mask := 0
var _flash_e0 := 5.0
var _dim := false
var _drawing: Node3D
var _into := Vector3.LEFT               ## под кровать (по горизонтали)
var _fwd := Vector3.FORWARD
var _right := Vector3.RIGHT
var _body0 := Vector3.ZERO
var _head0 := Vector3.ZERO
var _lean := 0.0
var _pull := Vector3.ZERO               ## насколько её рывок утащил запястье
var _my_goal := Callable()              ## если задана — своя цель пересчитывается каждый кадр
var _her_on := false                    ## её кисть держит запястье (цель — от моего запястья)
var _her_shoulder := Vector3.ZERO
var _look_pt := Vector3.ZERO
var _look_on := false


func _process(delta: float) -> void:
	var p = L.player if L else null
	if p == null:
		return
	if _dim:
		var fl: SpotLight3D = p.flash
		var d: float = fl.global_position.distance_to(_drawing.global_position)
		p.flash_energy = _flash_e0 * clampf(pow(d / FLASH_REF, fl.spot_attenuation), FLASH_MIN, 1.0)
		if is_instance_valid(_spill):
			_spill.light_energy = SPILL * _spill_k * clampf(fl.light_energy / maxf(p.flash_energy, 0.001), 0.0, 1.0)
	if _look_on:
		var aim: Vector3 = _look_pt - p.cam.global_position
		var want := clampf(atan2(aim.y, Vector2(aim.x, aim.z).length()), -1.35, 0.9)
		p.head.rotation.x = lerp_angle(p.head.rotation.x, want, 1.0 - exp(-6.0 * delta))
	if is_instance_valid(me) and me.body:
		if _my_goal.is_valid():
			var g: Transform3D = _my_goal.call()
			g.origin += _pull
			me.set_goal(g)
		me.pole.global_position = me.body.global_position + Vector3.UP * 0.9 - _right * 0.6 - _fwd * 0.3
	if _her_on and is_instance_valid(she) and she.body:
		_her_follow()
	if is_instance_valid(she) and she.body and _mat:
		_mat.set_shader_parameter("wrist", she.hand_now.origin if she.have else she.hand_goal.origin)


## Её кисть: ложится сверху на моё предплечье чуть выше запястья, пальцы обхватывают его сбоку;
## рука тянется из-под кровати слева-спереди (её плечо — под кроватью, у самого пола).
func _her_grip() -> Transform3D:
	var w: Vector3 = me.hand_goal.origin
	var a: Vector3 = (w - me.fore_now).normalized() if me.have else _into
	var g := w - a * 0.06
	var side := a.cross(Vector3.UP).normalized()            # поперёк предплечья, вправо от меня
	if side.dot(_right) < 0.0:
		side = -side
	var f := (side * 0.75 + Vector3.DOWN * 0.45 + a * 0.1)
	var pn := Vector3.DOWN - f * f.dot(Vector3.DOWN)
	var mcp := g + Vector3.UP * 0.04 + side * 0.01
	return she.grip_xf(f, pn, mcp)


## Ставит её кисть в xf, а тело (под полом и под кроватью) — так, чтобы рука дотягивалась.
func _her_place(xf: Transform3D) -> void:
	she.set_goal(xf)
	var dir := (_into * 0.8 - _right * 0.6).normalized()
	var want: Vector3 = xf.origin + dir * float(she.arm_len) * 0.8
	want.y = clampf(xf.origin.y, _drawing.global_position.y + 0.09, _drawing.global_position.y + 0.16)
	var sh: Vector3 = she.bone_pos("mixamorig_LeftArm")
	she.body.global_position += want - sh
	she.pole.global_position = (want + xf.origin) * 0.5 + Vector3.UP * 0.05 - _right * 0.35


func _her_follow() -> void:
	_her_place(_her_grip())


func _set_lean(v: float) -> void:
	_lean = v
	var off := _fwd * v + Vector3.DOWN * v * LEAN_DROP
	if is_instance_valid(me) and me.body:
		me.body.global_position = _body0 + off
	L.player.head.position = _head0 + Vector3(0, -v * LEAN_DROP, -v)


static func _smooth(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


static func _bez(a: Vector3, c: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(c, t).lerp(c.lerp(b, t), t)


## stand_y — высота глаз стоя (до приседания): по ней масштаб тела.
func run(level: Node, drawing: Node3D, into: Vector3, stand_y: float) -> void:
	L = level
	_drawing = drawing
	_into = Vector3(into.x, 0.0, into.z).normalized()
	var p = L.player
	var cam: Camera3D = p.cam
	_flash_e0 = p.flash_energy
	_dim = true
	_fwd = -p.global_basis.z
	_fwd.y = 0.0
	_fwd = _fwd.normalized()
	_right = _fwd.cross(Vector3.UP).normalized()
	_head0 = p.head.position
	var k: float = stand_y / ARM.EYE
	# своё тело: глаза — у камеры (присел), чуть сзади неё
	me = ARM.new()
	add_child(me)
	_body0 = p.global_position - _fwd * 0.15 + Vector3.UP * (p.head.position.y - stand_y - 0.04)
	me.spawn(L, _body0, p.global_rotation.y, k, BODY_LAYER)
	cam.cull_mask |= BODY_LAYER
	var fl: SpotLight3D = p.flash
	_flash_mask = fl.light_cull_mask
	fl.light_cull_mask &= ~BODY_LAYER
	_spill = SpotLight3D.new()
	_spill.light_color = fl.light_color
	_spill.spot_angle = 50.0
	_spill.spot_angle_attenuation = 1.0
	_spill.spot_range = 1.6
	_spill.spot_attenuation = 0.5
	_spill.light_energy = 0.0
	_spill.light_specular = 0.25
	_spill.light_volumetric_fog_energy = 0.0
	_spill.light_bake_mode = Light3D.BAKE_DISABLED
	fl.add_child(_spill)
	create_tween().tween_property(self, "_spill_k", 1.0, 0.5)
	# её рука — пока спрятана глубоко под кроватью
	she = ARM.new()
	add_child(she)
	var hide_at: Vector3 = drawing.global_position + _into * 1.2 + Vector3.DOWN * 0.5
	she.spawn(L, hide_at, atan2(_into.x, _into.z), k * CHILD, 1 | BODY_LAYER)   # и фонарь, и его ореол
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/ghost_arm.gdshader")
	var tex: Texture2D = she.skin_texture()
	if tex:
		_mat.set_shader_parameter("skin", tex)
	she.set_material(_mat)
	she.body.visible = false
	# своя рука — сначала под камерой (вне кадра)
	var start: Vector3 = cam.global_position + Vector3.DOWN * 0.2 - _right * 0.12 + _fwd * 0.02
	me.set_goal(Transform3D(Basis(), start))
	await get_tree().process_frame
	await get_tree().process_frame
	# куда тянется: ладонь вниз, пальцы к кровати, костяшки — в ладони над листом
	var dp: Vector3 = drawing.global_position
	var reach_f := (_into + Vector3.DOWN * 0.35).normalized()
	var touch: Transform3D = me.grip_xf(reach_f, Vector3.DOWN, dp + Vector3.UP * 0.075 - _into * 0.02)
	var near: Transform3D = touch
	near.origin += Vector3.UP * 0.035 - _into * 0.03
	var sh0: Vector3 = me.bone_pos("mixamorig_LeftArm")
	var need := 0.0
	for i in 81:
		need = i * 0.01
		if (sh0 + _fwd * need + Vector3.DOWN * need * LEAN_DROP).distance_to(near.origin) <= me.arm_len * 0.9:
			break
	_look_pt = dp + _into * 0.1
	_look_on = true
	L._sfx("heartbeat", -10.0, 0.9)
	# 1) медленно тянется к рисунку (вперёд и вниз), сам подаётся вперёд
	var ctrl := start.lerp(near.origin, 0.5) + Vector3.UP * 0.04
	var t1 := create_tween().set_parallel()
	t1.tween_method(func(q: float):
		me.set_goal(Transform3D(near.basis, _bez(start, ctrl, near.origin, _smooth(q)))), 0.0, 1.0, 1.3)
	t1.tween_property(me, "hand_w", 1.0, 0.8).set_delay(0.15)
	t1.tween_property(me, "grip", 0.12, 0.8)
	t1.tween_method(_set_lean, 0.0, need, 1.3).set_trans(Tween.TRANS_SINE)
	await t1.finished
	# 2) почти касается — пальцы чуть подрагивают
	var t2 := create_tween().set_parallel()
	t2.tween_method(func(q: float): me.set_goal(Transform3D(near.basis, near.origin.lerp(touch.origin, _smooth(q)))), 0.0, 1.0, 0.7)
	t2.tween_property(me, "grip", 0.25, 0.7)
	await t2.finished
	await get_tree().create_timer(0.25).timeout
	# 3) хватает: из темноты к запястью — за долю секунды
	_my_goal = func() -> Transform3D: return touch
	var from: Vector3 = dp + (_into * 0.8 - _right * 0.6).normalized() * 0.45 + Vector3.UP * 0.12
	she.hand_w = 1.0
	she.grip = 0.0
	_her_place(Transform3D(_her_grip().basis, from))
	await get_tree().process_frame
	_her_place(Transform3D(_her_grip().basis, from))
	await get_tree().process_frame
	she.body.visible = true
	var t3 := create_tween()
	t3.tween_method(func(q: float):
		var g := _her_grip()
		g.origin = from.lerp(g.origin, q * q)
		_her_place(g), 0.0, 1.0, 0.16)
	await t3.finished
	_her_on = true
	create_tween().tween_property(she, "grip", 1.0, 0.07)
	L._sfx("sting", 0.0, 1.1)
	L._sfx("whisper", 0.0, 1.3)
	L._say("NUR_22", 2.5)
	p.shake = 0.6
	p.flicker = 0.08
	# 4) рывок под кровать: запястье и сам игрок — вперёд, вниз
	var t4 := create_tween().set_parallel()
	t4.tween_property(self, "_pull", _into * 0.2 + Vector3.DOWN * 0.03, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t4.tween_method(_set_lean, need, need + 0.14, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t4.tween_property(me, "grip", 0.9, 0.15)
	await t4.finished
	L._sfx("creak", -4.0, 0.7)
	# 5) борьба: дёргает к себе, тянет обратно
	for i in 3:
		p.shake = 0.5
		var tt := create_tween().set_parallel()
		var back := _into * (0.08 if i % 2 == 0 else 0.2) + Vector3.DOWN * 0.03
		tt.tween_property(self, "_pull", back, 0.16).set_trans(Tween.TRANS_SINE)
		tt.tween_method(_set_lean, _lean, need + (0.05 if i % 2 == 0 else 0.14), 0.16).set_trans(Tween.TRANS_SINE)
		await tt.finished
		if i == 1:
			p.flicker = 0.12
	# 6) вырывается: её пальцы срываются, рука — назад к себе; её рука исчезает в темноте
	_her_on = false
	var hold: Transform3D = she.hand_goal
	var gone := hold.origin + (_into * 0.8 - _right * 0.6).normalized() * 0.45 + Vector3.DOWN * 0.02
	var my_from: Transform3D = me.hand_goal
	_my_goal = Callable()
	_pull = Vector3.ZERO
	var t5 := create_tween().set_parallel()
	t5.tween_property(she, "grip", 0.3, 0.06)
	t5.tween_method(func(q: float):
		var g := hold
		g.origin = hold.origin.lerp(gone, _smooth(q))
		she.set_goal(g), 0.0, 1.0, 0.22).set_delay(0.04)
	t5.tween_method(func(q: float):
		var e := _smooth(q)
		var pos := my_from.origin.lerp(start + Vector3.DOWN * 0.12 + _fwd * 0.05, e)
		me.set_goal(Transform3D(my_from.basis, pos)), 0.0, 1.0, 0.3)
	t5.tween_method(_set_lean, _lean, 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t5.tween_property(me, "hand_w", 0.0, 0.3)
	t5.tween_property(me, "grip", 0.0, 0.3)
	L._sfx("whoosh", -6.0, 1.2)
	p.shake = 0.7
	await t5.finished
	she.body.visible = false
	p.flicker = 0.35
	_look_on = false
	await get_tree().create_timer(0.2).timeout
	_finish()


func _finish() -> void:
	var p = L.player
	if is_instance_valid(_spill):
		_spill.queue_free()
	if _flash_mask != 0:
		(p.flash as SpotLight3D).light_cull_mask = _flash_mask
	p.cam.cull_mask &= ~BODY_LAYER
	p.head.position = _head0
	_dim = false
	create_tween().tween_property(p, "flash_energy", _flash_e0, 1.0)
	if is_instance_valid(me):
		me.remove()
	if is_instance_valid(she):
		she.remove()
	me = null
	she = null
