extends Node
## Далёкие жуткие звуки: «где-то рядом что-то происходит».
## Каждый звучит один раз за игру, в своём месте, и только когда вокруг тихо —
## не накладывается на скримеры, крики, удары и катсцены (см. level.gd: last_loud / quiet_for).

var L: Node
## имя звука, в какой части игры, откуда (позиция), через сколько секунд пребывания там
var events := [
	{"snd": "far_moan", "phases": ["key", "door"], "pos": Vector3(0.0, 1.5, -11.0), "after": 25.0},
	{"snd": "far_whisper", "phases": ["corridor"], "pos": Vector3(0.3, 1.3, -20.0), "after": 18.0},
	{"snd": "far_scream", "phases": ["floor2"], "pos": Vector3(7.5, -2.0, -35.5), "after": 30.0},
]
var _t := {}


func _process(delta: float) -> void:
	for e in events:
		if e.get("done", false) or not L.phase in e.phases:
			continue
		var k: String = e.snd
		_t[k] = _t.get(k, 0.0) + delta
		if _t[k] > e.after and L.quiet_for(7.0):
			e["done"] = true
			var p := AudioStreamPlayer3D.new()
			p.stream = L._stream(k)
			p.volume_db = 0.0
			p.unit_size = 9.0
			p.max_db = 0.0
			L.add_child(p)
			p.global_position = e.pos
			p.finished.connect(p.queue_free)
			p.play()
			L.last_loud = L.time_now      # пока он звучит, другие «далёкие» звуки ждут
