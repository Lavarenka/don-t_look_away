extends Node
## ТЕСТ: Вера стоит в спальне бабушки и меняет позы — чтобы посмотреть на неё в игре.
## Включается в bedroom.gd (VERA_TEST). Для настоящей главы — убрать.
## Каждые 5–8 с: стоит / жутко покачивается / тянет левую руку / кричит (рот раскрывается, лампы мигают);
## всё время медленно поворачивается к игроку.

const SPOT := Vector3(-9.3, -3.4, -30.3)      ## у кровати, лицом к входу в комнату

var L: Node
var vera: Node3D
var t := 2.0
var last := ""


func setup(level: Node) -> void:
	L = level
	vera = preload("res://scripts/vera.gd").new()
	L.add_child(vera)
	vera.global_position = SPOT
	_face(Vector3(-14.1, -3.4, -28.43), 1.0)


func _face(p: Vector3, k: float) -> void:
	var d := p - vera.global_position
	var want := atan2(d.x, d.z)
	vera.rotation.y = lerp_angle(vera.rotation.y, want, k)


func _process(delta: float) -> void:
	if vera == null:
		return
	var pp: Vector3 = L.player.global_position
	if pp.distance_to(vera.global_position) < 12.0:
		_face(pp, delta * 0.8)                      # медленно поворачивается к игроку
	t -= delta
	if t > 0.0:
		return
	t = randf_range(5.0, 8.0)
	var opts := ["idle", "zidle", "reach", "scream"]
	opts.erase(last)
	var o: String = opts.pick_random()
	last = o
	match o:
		"idle":
			vera.play("idle", 0.8, 0.6)
		"zidle":
			vera.play("zidle", 0.7, 0.6)
		"reach":
			vera.play("idle", 0.8, 0.5)
			vera.reach(true)
			get_tree().create_timer(3.0).timeout.connect(func(): vera.reach(false))
		"scream":
			vera.play("idle", 0.5, 0.4)
			vera.scream(1.0)
			L._sfx3d("scream", vera.global_position + Vector3(0, 1.6, 0), -10.0, 0.75)
			if L.bedroom:
				for lamp in L.bedroom.lamps:
					var e: float = lamp.light_energy
					var tw := create_tween()
					for i in 6:
						tw.tween_property(lamp, "light_energy", e * randf_range(0.0, 0.3), 0.05)
						tw.tween_property(lamp, "light_energy", e, 0.07)
