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


func play(level: Node) -> void:
	L = level
	var path := "res://video/memory_1986.ogv"
	if not ResourceLoader.exists(path):
		return
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var vp := VideoStreamPlayer.new()
	vp.stream = load(path)
	vp.expand = true
	vp.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vp)
	var music: AudioStreamPlayer = null
	vp.play()
	var t0 := Time.get_ticks_msec()
	var ci := 0
	while vp.is_playing():
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		while ci < MEM_CUES.size() and t >= float(MEM_CUES[ci][0]):
			var c: Array = MEM_CUES[ci]
			match c[1]:
				"sfx":
					if c[2] == "vera_mb_full":
						music = AudioStreamPlayer.new()
						music.stream = load("res://audio/vera_mb_full.wav")
						music.volume_db = c[3]
						music.pitch_scale = c[4]
						add_child(music)
						music.play()
					else:
						L._sfx(c[2], c[3], c[4], true)
				"say":
					L._say(c[2], _vdur(c[2], c[3]))
				"stopmusic":
					if music:
						music.stop()
			ci += 1
		await get_tree().process_frame
	if music:
		music.queue_free()
	L._say("", 0.1)
	layer.queue_free()
