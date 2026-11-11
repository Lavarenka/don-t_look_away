extends Node
## Мысли Миши (внутренний голос) — по всей игре. Миша РЕАГИРУЕТ на то, что творится в доме:
## сначала не верит и ищет объяснение («сквозняк», «показалось»), потом боится, хочет уехать,
## под конец понимает, что сделала бабушка. Воспоминания — только те, от которых не по себе.
## Ключи MT_* в lang/strings.csv; озвучка (позже) — res://voice/en/MT_xxx.ogg, подхватится сама (settings.voice).
## Показываются в строке субтитров, но иначе: наклонным шрифтом, холодным цветом, без кавычек.
##
## Мысль не перебивает: ждёт, пока погаснет текущий субтитр, закроется записка/инвентарь и кончится
## сценка (L.busy, игрок заморожен). Между мыслями — не меньше GAP секунд (кроме продолжений CHAIN),
## чтобы Миша не болтал без умолку: из нескольких странностей подряд он отзовётся на главную.
## Реакция, не сказанная вовремя (INFO: сколько ждать), пропадает — поздно удивляться.
##
## Откуда берутся:
##   AFTER  — после реплики/надписи (ключ _say);
##   HAUNTS — после «живого дома» (haunts.gd: done[...]): граммофон, книги, часы, звонок…;
##   EVENTS — после призраков level.gd (events[...]): силуэт в проёме, женщина за креслом…;
##   _poll() — по состоянию: увидел свечу/лампочку/портрет, вошёл в комнату, ванная, спальня, кукла, тайник.
const ENABLED := true               ## false — мыслей нет совсем
const GAP := 9.0                    ## между мыслями не меньше, с
const GAP_BIG := 3.5                ## …а важные реакции (важность 2) — уже через столько
const COL := Color(0.74, 0.8, 0.88)  ## цвет мыслей (обычные субтитры — тёплые)

## мысль → [важность 0..2 (из нескольких готовых — важнейшая), сколько ждать удобного момента, с]
const INFO := {
	"MT_DARK": [1, 12.0], "MT_CANDLE": [1, 6.0], "MT_KNOCK": [2, 6.0], "MT_DOORWAY": [2, 6.0],
	"MT_GRAMOPHONE": [1, 6.0], "MT_BOOKS": [1, 5.0], "MT_NOTE1": [2, 15.0], "MT_CHAIR": [0, 6.0],
	"MT_TV": [1, 6.0], "MT_PEEK": [2, 6.0], "MT_ARMCHAIR": [1, 6.0], "MT_PHONE": [2, 15.0],
	"MT_RUNAWAY": [2, 8.0], "MT_CLOCK": [2, 10.0], "MT_CHANDELIER": [0, 5.0],
	"MT_LIGHT": [2, 10.0], "MT_LIGHT2": [2, 20.0], "MT_SLAM": [1, 5.0], "MT_FIGURE": [2, 6.0],
	"MT_BULB": [1, 4.0], "MT_PORTRAITS": [1, 8.0], "MT_FLASH": [1, 6.0], "MT_TURNED": [2, 6.0],
	"MT_WHISPER": [2, 6.0], "MT_SHARD": [1, 8.0], "MT_FUNERAL": [1, 15.0],
	"MT_NURSERY": [1, 12.0], "MT_STEPS": [2, 6.0], "MT_DANCE": [2, 8.0], "MT_HORSE": [0, 5.0],
	"MT_DOLL_MOVED": [1, 6.0], "MT_HIDE": [2, 10.0],
	"MT_ATTIC": [2, 15.0], "MT_MANNEQ": [1, 10.0], "MT_MANNEQ_BEHIND": [2, 8.0], "MT_SHEET": [0, 5.0],
	"MT_TURN": [2, 12.0],
	"MT_FLOOR2": [1, 12.0], "MT_STUDY": [0, 6.0], "MT_ANYA_DOOR": [2, 8.0],
	"MT_BATH_OPEN": [1, 6.0], "MT_PRINTS": [1, 8.0], "MT_MIRROR": [2, 8.0], "MT_MIRROR_GHOST": [2, 10.0],
	"MT_HAIR": [2, 8.0], "MT_BEDKEY": [1, 8.0], "MT_BATH_GHOST": [2, 12.0],
	"MT_BEDROOM": [1, 12.0], "MT_WINDOW": [1, 10.0], "MT_BED": [2, 8.0], "MT_DOLL_TURN": [1, 6.0],
	"MT_LETTER": [2, 15.0], "MT_DOLL_BIG": [2, 10.0], "MT_CEILING": [2, 8.0], "MT_HAIRPIN": [1, 12.0],
	"MT_SAFE": [1, 10.0], "MT_LOCKS": [1, 10.0],
}

## реплика → [мысль, через сколько секунд]
const AFTER := {
	"LVL_32": ["MT_DARK", 3.5],             # выбило пробки
	"HAUNT_05": ["MT_RUNAWAY", 2.0],        # «Миша, ты опять убежишь?»
	"LVL_28": ["MT_WHISPER", 0.4],          # «Не оборачивайся.»
	"PZ_TURNED": ["MT_TURNED", 0.4],        # отвернулся — свечи погасли
	"PZ_SHARD_1": ["MT_SHARD", 0.5],        # в осколке — дом, но не совсем этот
	"NUR_24": ["MT_HIDE", 0.5],             # «Теперь ты водишь, Миша»
	"LVL_37": ["MT_ATTIC", 3.0],            # очнулся на чердаке (после воспоминания)
	"LVL_52": ["MT_MANNEQ", 1.0],           # фото примерочной
	"LVL_66": ["MT_FLOOR2", 2.0],           # второй этаж
	"LVL_71": ["MT_STUDY", 0.3],            # кабинет деда заперт
	"LVL_72": ["MT_ANYA_DOOR", 0.3],        # комната Ани заперта
	"B_MIRROR0": ["MT_PRINTS", 0.5],        # детские ладошки на зеркале
	"B_MIRROR1": ["MT_MIRROR", 0.5],        # цифры задом наперёд
	"B_SHARD_TUB": ["MT_HAIR", 0.5],        # волосы на дне ванны
	"B_KEY": ["MT_BEDKEY", 0.5],            # ключ от бабушкиной спальни
	"VL_09": ["MT_LETTER", 3.5],            # письмо Веры
}
## «живой дом» (haunts.gd, done) → [мысль, задержка]
const HAUNTS := {
	"front_knock": ["MT_KNOCK", 1.5],
	"gramophone": ["MT_GRAMOPHONE", 2.0],
	"books": ["MT_BOOKS", 1.2],
	"armchair": ["MT_ARMCHAIR", 1.5],
	"phone": ["MT_PHONE", 1.5],
	"clock_stop": ["MT_CLOCK", 3.0],
	"chandelier": ["MT_CHANDELIER", 1.5],
	"door_slam": ["MT_SLAM", 1.0],
	"bulb": ["MT_BULB", 0.8],
	"hall_behind": ["MT_STEPS", 2.0],
	"horse_rock": ["MT_HORSE", 1.5],
	"doll_door": ["MT_DOLL_MOVED", 1.5],
}
## призраки level.gd (events) → [мысль, задержка]
const EVENTS := {
	"doorway": ["MT_DOORWAY", 2.5],
	"peek": ["MT_PEEK", 2.0],
	"corridor": ["MT_FIGURE", 1.5],
	"candle_flash": ["MT_FLASH", 2.0],
}
## после этой мысли — сразу следующая
const CHAIN := {
	"MT_LIGHT": ["MT_LIGHT2", 1.0],
}
const BUSY_OK := ["MT_LOCKS"]       ## эти можно и во время мини-игры

var L: Node
var done := {}
var queue := []                     ## [ключ, когда можно, до какого времени ждать]
var _t := 0.0
var _poll_t := 0.0
var _flags := {}
var _note_text := ""
var _italic: Font
var _showing := false
var _last_end := -100.0             ## когда погасла прошлая мысль
var _next := ""                     ## продолжение мысли (CHAIN) — до него другие мысли ждут
var _next_until := 0.0


func setup(level: Node) -> void:
	L = level
	L.add_child(self)


## Вызывается из L._say(): после некоторых реплик — своя мысль.
func on_say(key: String) -> void:
	restore_style()
	if AFTER.has(key):
		var a: Array = AFTER[key]
		think(a[0], a[1])


func think(key: String, delay := 0.0) -> void:
	if not ENABLED or done.has(key):
		return
	for q in queue:
		if q[0] == key:
			return
	var wait: float = (INFO[key] as Array)[1] if INFO.has(key) else 8.0
	queue.append([key, _t + delay, _t + delay + wait])


func restore_style() -> void:
	if not _showing or L == null or L.msg_label == null:
		return
	_showing = false
	L.msg_label.remove_theme_font_override("font")
	L.msg_label.remove_theme_color_override("font_color")


func _prio(key: String) -> int:
	return (INFO[key] as Array)[0] if INFO.has(key) else 1


func _process(delta: float) -> void:
	if not ENABLED or L == null or L.msg_label == null:
		return
	_t += delta
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = 0.25
		_poll()
	if _showing and L.msg_timer <= 0.0:
		restore_style()
	if queue.is_empty():
		return
	var i := 0
	while i < queue.size():
		if _t > queue[i][2]:
			queue.remove_at(i)                # не дождалась — момент упущен
			continue
		i += 1
	if _next != "" and _t > _next_until:
		_next = ""
	# из готовых — важнейшая (продолжение мысли — вне очереди)
	var best := -1
	for k in queue.size():
		var q: Array = queue[k]
		if _t < q[1]:
			continue
		if _next != "" and q[0] != _next:
			continue
		if best < 0 or _prio(q[0]) > _prio(queue[best][0]):
			best = k
	if best < 0:
		return
	var key: String = queue[best][0]
	if key != _next and _t - _last_end < (GAP_BIG if _prio(key) >= 2 else GAP):
		return
	if not _free(key in BUSY_OK):
		return
	queue.remove_at(best)
	_show(key)


## Можно ли сейчас говорить: строка субтитров свободна, нет записки, инвентаря и сценки.
func _free(busy_ok: bool) -> bool:
	if L.msg_timer > 0.2:
		return false
	if L.note_panel and L.note_panel.visible:
		return false
	if L.inv and L.inv.get("is_open"):
		return false
	if not busy_ok:
		if L.busy or (L.player and L.player.frozen):
			return false
	return true


func _show(key: String) -> void:
	done[key] = true
	if key == _next:
		_next = ""
	var text := tr(key)
	var sec := clampf(1.6 + text.length() * 0.055, 3.0, 7.5)
	L.msg_label.text = text
	_style()
	L.msg_label.modulate.a = 1.0
	L._voice(key)
	var st: AudioStream = preload("res://scripts/settings.gd").voice(key)
	if st:
		sec = maxf(sec, st.get_length() + 0.3)
	L.msg_timer = sec
	_last_end = _t + sec
	if CHAIN.has(key):
		var c: Array = CHAIN[key]
		think(c[0], sec + c[1])
		_next = c[0]
		_next_until = _t + sec + c[1] + 20.0


func _style() -> void:
	if _italic == null:
		var base: Font = L.msg_label.get_theme_font("font")
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)   # наклон — «курсив»
		_italic = fv
	L.msg_label.add_theme_font_override("font", _italic)
	L.msg_label.add_theme_color_override("font_color", COL)
	_showing = true


## Видит ли игрок точку p (не дальше dist).
func _sees(p: Vector3, dist: float, ang := 0.45) -> bool:
	var pl = L.player
	if pl == null or pl.cam == null:
		return false
	if pl.cam.global_position.distance_to(p) > dist:
		return false
	return L._sees(p, ang, false)


func _once(flag: String) -> bool:
	if _flags.has(flag):
		return false
	_flags[flag] = true
	return true


func _poll() -> void:
	var ph: String = L.phase
	# «живой дом» и призраки
	var hd = L.haunts.get("done") if L.get("haunts") else null
	if hd is Dictionary:
		for k in HAUNTS:
			if (hd as Dictionary).has(k) and _once("h_" + k):
				think(HAUNTS[k][0], HAUNTS[k][1])
	var ev = L.get("events")
	if ev is Dictionary:
		for k in EVENTS:
			if (ev as Dictionary).has(k) and _once("e_" + k):
				think(EVENTS[k][0], EVENTS[k][1])
	# записка бабушки: закрыл — мысль о прочитанном
	if L.note_panel:
		if L.note_panel.visible:
			_note_text = L.note_label.text
		elif _note_text != "":
			if _note_text == tr("LVL_01"):
				think("MT_NOTE1", 0.6)
			_note_text = ""
	# зал: свеча горит сама, кресло, телевизор работает без света
	if L.lamp_done and ph in ["intro", "hall", "door", "key"]:
		if not done.has("MT_CANDLE") and _sees(L.candle_light.global_position, 5.0, 0.35):
			think("MT_CANDLE")
		if not done.has("MT_CHAIR") and _sees(Vector3(-0.3, 1.0, -3.0), 3.5, 0.3):
			think("MT_CHAIR")
		if L.tv_on and _once("tv"):
			think("MT_TV", 1.5)
	# коридор: пробки выбило, а лампочка горит; портреты
	if ph == "corridor":
		if not done.has("MT_LIGHT") and L.bulb.light_energy > 0.1 and _sees(L.bulb.global_position, 7.0, 0.4):
			think("MT_LIGHT")
		var p3 := L.get_node_or_null("Portrait3") as Node3D
		if p3 and not done.has("MT_PORTRAITS") and _sees(p3.global_position, 3.0, 0.4):
			think("MT_PORTRAITS")
		if L.exit_unlocked and _once("exit"):
			think("MT_FUNERAL", 3.0)
	# детская
	var nu = L.get("nursery")
	if ph == "nursery" and _once("nursery"):
		think("MT_NURSERY", 5.0)
	if nu and float(nu.get("dance_seen")) > 1.2 and _once("dance"):
		think("MT_DANCE", 0.5)
	# чердак
	var at = L.get("attic")
	if at:
		if at.get("_behind_done") and _once("mbehind"):
			think("MT_MANNEQ_BEHIND", 3.0)
		if at.get("sheet_down") and _once("sheet"):
			think("MT_SHEET", 1.5)
		if at.get("solved") and _once("asolved"):
			think("MT_TURN", 4.0)
	# ванная
	var ba = L.get("bath")
	if ba and ph == "floor2":
		if ba.get("unlocked") and _once("bopen"):
			think("MT_BATH_OPEN", 1.5)
		if ba.get("ghost_done") and _once("bghost"):
			think("MT_MIRROR_GHOST", 3.0)
		if int(ba.get("exit_scare")) == 3 and _once("bexit"):
			think("MT_BATH_GHOST", 4.0)
	# спальня Веры
	var bd = L.get("bedroom")
	if bd and bd.get("sealed") and _once("bedroom"):
		think("MT_BEDROOM", 4.0)
	var vr = bd.get("vroom") if bd else null
	if vr:
		if vr.get("lit") and _once("lit"):
			think("MT_WINDOW", 2.5)
		if vr.get("bed_done") and _once("bed"):
			think("MT_BED", 2.0)
		var eye = vr.get("doll_eye")
		if eye is Node3D and (eye as Node3D).visible and _once("dolleye"):
			think("MT_DOLL_TURN", 2.0)
		if str(vr.get("doll_state")) == "back" and _once("dollback"):
			think("MT_DOLL_BIG", 1.5)
		var cs = vr.get("call_seq")
		if cs and is_instance_valid(cs) and not done.has("MT_CEILING") and int(cs.get("stage")) == 0:
			var ve = cs.get("spider")                            # Вера на потолке (vera_ceiling.gd)
			if ve is Node3D and is_instance_valid(ve) and (ve as Node3D).visible and _sees((ve as Node3D).global_position, 10.0, 0.6):
				think("MT_CEILING", 0.8)
		var sf = vr.get("safe")
		if sf and is_instance_valid(sf):
			if sf.visible and not done.has("MT_SAFE") and not sf.get("_on") and _sees(sf.global_position, 3.5, 0.4):
				think("MT_SAFE")
			if sf.get("_on") and not sf.get("_busy") and int(sf.get("_lock")) == 0 and _once("locks"):
				think("MT_LOCKS", 1.0)
	if L.inv and L.inv.has("v_hairpin") and _once("pin"):
		think("MT_HAIRPIN", 3.0)
