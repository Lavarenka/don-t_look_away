extends Node
## Ролик-воспоминание «1986» — между детской и чердаком: Аня поймала Мишу, он проваливается в сон
## и вспоминает. Видео без звука — звук и субтитры здесь по времени.
## Видео res://video/memory_1986.ogv, 31 с:
## коридор в 1986-м, бабушка ведёт Аню за руку; Аня оглядывается; бабушка, не оборачиваясь:
## «Отвернись, Мишенька. Не смотри». Миша отворачивается к стене — скрип двери, «Миша?» — тишина.
## Поворачивается обратно — коридор пуст. Белая вспышка.
const MEM_CUES := [
	[0.2, "sfx", "vera_mb_full", -16.0, 0.92],
	[8.6, "sfx", "giggle", -18.0, 1.15],
	[17.0, "sfx", "buzz", -22.0, 0.8],
	[18.0, "say", "MEM_01", 3.4],
	[18.1, "sfx", "whisper", -14.0, 0.9],
	[23.0, "sfx", "creak", -8.0, 0.7],
	[23.8, "stopmusic"],
	[23.9, "say", "MEM_02", 1.8],
	[24.8, "sfx", "thump", -10.0, 0.8],
	[27.0, "sfx", "tinnitus", -20.0, 1.0],
]

var L: Node


func _vdur(key: String, min_sec: float) -> float:
	var st: AudioStream = preload("res://scripts/settings.gd").voice(key)
	var d := min_sec
	if st:
		d = maxf(d, st.get_length() + 0.5)
	return d


func _snd(st: AudioStream, db: float, pitch: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	return p


func play(level: Node) -> void:
	L = level
	var path := "res://video/memory_1986.ogv"
	if not ResourceLoader.exists(path):
		return
	# игра на паузе: её звуки (дождь, гул дома, шаги, призраки) замирают, пока идёт воспоминание;
	# сам ролик, его звуки, голос и субтитры работают при паузе
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tree := get_tree()
	var was_paused := tree.paused
	tree.set_meta("no_pause", true)                 # Esc не открывает меню посреди ролика
	tree.paused = true
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var vp := VideoStreamPlayer.new()
	vp.stream = load(path)
	vp.expand = true
	vp.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vp)
	# субтитры: строка как в игре (тот же стиль), поверх ролика, с тёмной обводкой
	var sub: Label = null
	if L.get("msg_label"):
		sub = (L.msg_label as Label).duplicate() as Label
	else:
		sub = Label.new()
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		sub.position = Vector2(-400, -120)
		sub.size = Vector2(800, 80)
	layer.add_child(sub)
	sub.text = ""
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	sub.add_theme_constant_override("outline_size", 6)
	var sub_left := 0.0
	var music: AudioStreamPlayer = null
	var players: Array[AudioStreamPlayer] = []
	vp.play()
	var t0 := Time.get_ticks_msec()
	var last := 0.0
	var ci := 0
	while vp.is_playing():
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		var dt := t - last
		last = t
		while ci < MEM_CUES.size() and t >= float(MEM_CUES[ci][0]):
			var c: Array = MEM_CUES[ci]
			match c[1]:
				"sfx":
					if c[2] == "vera_mb_full":
						music = _snd(load("res://audio/vera_mb_full.wav"), c[3], c[4])
					elif L.has_method("_stream"):
						players.append(_snd(L._stream(c[2]), c[3], c[4]))
				"say":
					sub.text = tr(c[2])
					sub.modulate.a = 1.0
					sub_left = _vdur(c[2], c[3])
					var vs: AudioStream = preload("res://scripts/settings.gd").voice(c[2])
					if vs:
						players.append(_snd(vs, 0.0, 1.0))
				"stopmusic":
					if music:
						music.stop()
			ci += 1
		if sub_left > 0.0:
			sub_left -= dt
			sub.modulate.a = clampf(sub_left, 0.0, 1.0)
		await tree.process_frame
	for p in players:
		if is_instance_valid(p):
			p.queue_free()
	if music:
		music.queue_free()
	layer.queue_free()
	tree.paused = was_paused
	tree.remove_meta("no_pause")
