extends Node3D
## Призрак бабушки Веры («The Haggard Witch», Azura_SQ, CC BY; упрощена, скелет и веса — наши,
## сделаны из скелета Ани, поэтому все анимации Ани перенесены на неё: tools/retarget_vera.gd).
## Есть челюсть: set_mouth(0..1) — рот раскрывается (крик).
##
## Анимации: idle, zidle, walk, run, reach — как у Ани (spirit.gd).

const ANIMS := ["idle", "zidle", "walk", "run", "reach"]
const TINT := Color(0.78, 0.76, 0.76)      ## чуть темнее и холоднее, «в тени»

var model: Node3D
var sk: Skeleton3D
var ap: AnimationPlayer
var life: SkeletonModifier3D
var jaw: SkeletonModifier3D
var mats: Array[BaseMaterial3D] = []
var float_h := 0.0
var _float := 0.0
var _t := 0.0


func _ready() -> void:
	model = load("res://models/vera/vera.glb").instantiate()
	add_child(model)
	sk = model.find_children("*", "Skeleton3D", true, false)[0]
	ap = AnimationPlayer.new()
	sk.get_parent().add_child(ap)
	ap.root_node = ap.get_path_to(sk.get_parent())
	var lib := AnimationLibrary.new()
	for n in ANIMS:
		var a: Animation = load("res://models/vera/anim_%s.res" % n)
		a.loop_mode = Animation.LOOP_LINEAR if n != "reach" else Animation.LOOP_NONE
		lib.add_animation(n, a)
	ap.add_animation_library("g", lib)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).get_active_material(0)
		if m is BaseMaterial3D:
			var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
			d.albedo_color = TINT
			d.metallic = 0.0
			(mi as MeshInstance3D).material_override = d
			mats.append(d)
	life = preload("res://scripts/spirit_life.gd").new()
	sk.add_child(life)
	jaw = preload("res://scripts/jaw_open.gd").new()
	sk.add_child(jaw)
	play("idle")


func play(n: String, speed := 1.0, blend := 0.25) -> void:
	ap.play("g/" + n, blend)
	ap.speed_scale = speed


func freeze(n: String, t: float) -> void:
	ap.play("g/" + n, 0.0)
	ap.seek(t, true)
	ap.speed_scale = 0.0


func play_from(n: String, t: float, speed := 0.8) -> void:
	ap.play("g/" + n, 0.0)
	ap.seek(t, true)
	ap.speed_scale = speed


func set_speed(s: float) -> void:
	ap.speed_scale = s


## Рот: 0 — закрыт, 1 — раскрыт в крике. С анимацией (время — сек.).
func set_mouth(v: float, sec := 0.0) -> void:
	if sec <= 0.0:
		jaw.open = v
	else:
		create_tween().tween_property(jaw, "open", v, sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Крик: рот резко распахивается, голову чуть откидывает, потом медленно закрывается.
func scream(hold := 0.8) -> void:
	var tw := create_tween()
	tw.tween_property(jaw, "open", 0.8, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(jaw, "open", 0.15, 0.9).set_trans(Tween.TRANS_SINE)
	life.shiver = 1.0
	get_tree().create_timer(hold + 0.3).timeout.connect(func(): life.shiver = 0.0)


func set_layer(mask: int) -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = mask
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_t += delta
	_float = move_toward(_float, float_h, delta * 0.6)
	model.position.y = _float + (sin(_t * 1.4) * 0.035 if _float > 0.01 else 0.0)
