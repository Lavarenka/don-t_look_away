extends Node
## Мысли и воспоминания Миши (внутренний голос) — по всей игре.
## Ключи MT_* в lang/strings.csv; озвучка (позже) — res://voice/en/MT_xxx.ogg, подхватится сама (settings.voice).
## Показываются в той же строке субтитров, но иначе: курсивом и холоднее цветом, без кавычек.
## Мысль не перебивает: ждёт, пока погаснет текущий субтитр, закроется записка/инвентарь
## и кончится сценка (L.busy, игрок заморожен). Каждая — один раз за игру. Не дождалась за MAX_WAIT — пропадает.
##
## Откуда берутся:
##   AFTER — сразу после определённой реплики/надписи (ключ _say → мысль, задержка);
##   _poll() — по состоянию игры: увидел свечу/кресло/лампочку, вошёл в комнату, взял шпильку и т. п.
const ENABLED := true               ## false — мыслей нет совсем
const MAX_WAIT := 25.0
const COL := Color(0.74, 0.8, 0.88)  ## цвет мыслей (обычные субтитры — тёплые)

## реплика → [мысль, через сколько секунд]
const AFTER := {
	"LVL_32": ["MT_HOUSE", 4.0],            # выбило пробки
	"LVL_37": ["MT_ATTIC", 3.0],            # очнулся на чердаке (после воспоминания)
	"LVL_52": ["MT_MANNEQ", 1.0],           # фото примерочной
	"LVL_66": ["MT_FLOOR2", 2.0],           # второй этаж
	"LVL_71": ["MT_STUDY", 0.3],            # кабинет деда заперт
	"LVL_72": ["MT_ANYA_DOOR", 0.3],        # комната Ани заперта
	"NUR_24": ["MT_HIDE", 0.5],             # «Теперь ты водишь, Миша»
	"HAUNT_05": ["MT_RUNAWAY", 2.0],        # «Миша, ты опять убежишь?»
	"B_KEY": ["MT_BEDKEY", 0.5],            # ключ от бабушкиной спальни
	"B_MIRROR1": ["MT_MIRROR", 0.5],        # цифры задом наперёд
	"B_SHARD_TUB": ["MT_HAIR", 0.5],        # волосы на дне ванны
	"VL_09": ["MT_LETTER", 3.5],            # письмо Веры
}
## после этой мысли — следующая
const CHAIN := {
	"MT_LIGHT": ["MT_LIGHT2", 1.2],
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
	queue.append([key, _t + delay, _t + delay + MAX_WAIT])


func restore_style() -> void:
	if not _showing or L == null or L.msg_label == null:
		return
	_showing = false
	L.msg_label.remove_theme_font_override("font")
	L.msg_label.remove_theme_color_override("font_color")


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
		var q: Array = queue[i]
		if _t > q[2]:
			queue.remove_at(i)                # не дождалась — момент упущен
			continue
		i += 1
	if queue.is_empty():
		return
	if _next != "" and _t > _next_until:
		_next = ""
	for k in queue.size():                    # первая, чьё время пришло
		var q0: Array = queue[k]
		if _next != "" and q0[0] != _next:
			continue
		if _t >= q0[1]:
			if _free(q0[0] in BUSY_OK):
				queue.remove_at(k)
				_show(q0[0])
			return


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
	if CHAIN.has(key):
		var c: Array = CHAIN[key]
		think(c[0], sec + c[1])
		_next = c[0]
		_next_until = _t + sec + c[1] + MAX_WAIT


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
	# записки: закрыл — мысль о прочитанном
	if L.note_panel:
		if L.note_panel.visible:
			_note_text = L.note_label.text
		elif _note_text != "":
			if _note_text == tr("LVL_01"):
				think("MT_NOTE1", 0.6)
			elif _note_text == tr("LVL_02"):
				think("MT_NOTE2", 0.6)
			_note_text = ""
	# дом, зал: свеча горит сама, кресло Гостя, сервант, телевизор
	if L.lamp_done and ph in ["intro", "hall", "door", "key"]:
		if not done.has("MT_CANDLE") and _sees(L.candle_light.global_position, 5.0, 0.35):
			think("MT_CANDLE")
		if not done.has("MT_CHAIR") and _sees(Vector3(-0.3, 1.0, -3.0), 3.5, 0.3):
			think("MT_CHAIR")
		if not done.has("MT_SERVANT") and _sees(L.servant_door.global_position + Vector3(0, 0.2, 0), 2.8, 0.35):
			think("MT_SERVANT")
		if L.tv_on and _once("tv"):
			think("MT_TV", 2.0)
	# коридор: пробки выбило, а лампочка горит; портреты
	if ph == "corridor":
		if not done.has("MT_LIGHT") and L.bulb.light_energy > 0.1 and _sees(L.bulb.global_position, 7.0, 0.4):
			think("MT_LIGHT")
		var p3 := L.get_node_or_null("Portrait3") as Node3D
		if p3 and not done.has("MT_PORTRAITS") and _sees(p3.global_position, 3.0, 0.4):
			think("MT_PORTRAITS")
		if L.exit_unlocked and _once("exit"):
			think("MT_FUNERAL", 3.0)
	if ph == "nursery" and _once("nursery"):
		think("MT_NURSERY", 5.0)
	# спальня Веры
	var bd = L.get("bedroom")
	if bd and bd.get("sealed") and _once("bedroom"):
		think("MT_BEDROOM", 4.0)
	var vr = bd.get("vroom") if bd else null
	if vr:
		if vr.get("lit") and _once("lit"):
			think("MT_WINDOW", 2.5)
		var sf = vr.get("safe")
		if sf and is_instance_valid(sf):
			if sf.visible and not done.has("MT_SAFE") and not sf.get("_on") and _sees(sf.global_position, 3.5, 0.4):
				think("MT_SAFE")
			if sf.get("_on") and not sf.get("_busy") and int(sf.get("_lock")) == 0 and _once("locks"):
				think("MT_LOCKS", 1.0)
	if L.inv and L.inv.has("v_hairpin") and _once("pin"):
		think("MT_HAIRPIN", 3.0)
