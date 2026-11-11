extends Node
## Мысли Миши (внутренний голос): немного, только самые важные — по паре на комнату.
## Миша реагирует на то, что творится в доме, и понемногу вспоминает, что случилось с Аней.
## Ключи MT_* в lang/strings.csv; озвучка — res://voice/en/MT_xxx.ogg, подхватится сама (settings.voice).
## Показываются в строке субтитров, но иначе: наклонным шрифтом, холодным цветом, без кавычек.
##
## Чтобы не налезать на сценки, скримеры и чужие реплики, мысль ждёт: строка субтитров свободна,
## нет записки и инвентаря, не идёт сценка (L.busy, игрок заморожен), никто не говорит (озвучка),
## и последние QUIET секунд было тихо — без крика, скримера и призрака (L.quiet_for).
## Не дождалась удобного момента за MAX_WAIT — пропадает.
##
##   зал        MT_NOTE1 (закрыл записку бабушки), MT_PHONE (после звонка)
##   коридор    MT_LIGHT (горит лампочка, хотя пробки выбило), MT_FUNERAL (свечи зажжены)
##   детская    MT_NURSERY (вошёл), MT_HIDE (после «Теперь ты водишь, Миша»)
##   чердак     MT_ATTIC (очнулся там), MT_TURN (манекены повернулись)
##   2 этаж     MT_ANYA_DOOR (дверь Ани заперта)
##   ванная     MT_MIRROR (цифры задом наперёд), MT_HAIR (волосы в ванне)
##   спальня    MT_LETTER (письмо бабушки), MT_SAFE (увидел тайник, шпилька уже в кармане)
const ENABLED := true               ## false — мыслей нет совсем
const MAX_WAIT := 20.0
const QUIET := 2.5                  ## столько секунд до мысли — без крика, скримера, призрака
const COL := Color(0.74, 0.8, 0.88)  ## цвет мыслей (обычные субтитры — тёплые)

## реплика → [мысль, через сколько секунд]
const AFTER := {
	"NUR_24": ["MT_HIDE", 0.5],             # «Теперь ты водишь, Миша»
	"LVL_37": ["MT_ATTIC", 3.0],            # очнулся на чердаке (после воспоминания)
	"LVL_72": ["MT_ANYA_DOOR", 0.3],        # комната Ани заперта
	"B_MIRROR1": ["MT_MIRROR", 0.5],        # цифры задом наперёд
	"B_SHARD_TUB": ["MT_HAIR", 0.5],        # волосы на дне ванны
	"VL_09": ["MT_LETTER", 3.5],            # письмо Веры
}

var L: Node
var done := {}
var queue := []                     ## [ключ, когда можно, до какого времени ждать]
var _t := 0.0
var _poll_t := 0.0
var _flags := {}
var _note_text := ""
var _italic: Font
var _showing := false


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
	var i := 0
	while i < queue.size():
		if _t > queue[i][2]:
			queue.remove_at(i)                # не дождалась — момент упущен
			continue
		i += 1
	for k in queue.size():
		var q: Array = queue[k]
		if _t >= q[1]:
			if _free():
				queue.remove_at(k)
				_show(q[0])
			return


## Можно ли сейчас говорить: никто не говорит, нет записки/инвентаря/сценки, вокруг тихо.
func _free() -> bool:
	if L.msg_timer > 0.2:
		return false
	if L.note_panel and L.note_panel.visible:
		return false
	if L.inv and L.inv.get("is_open"):
		return false
	if L.busy or (L.player and L.player.frozen):
		return false
	if L.voice_player and L.voice_player.playing:
		return false
	if not L.quiet_for(QUIET):
		return false
	return true


func _show(key: String) -> void:
	done[key] = true
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
	# зал: записка бабушки (закрыл — мысль), после звонка
	if L.note_panel:
		if L.note_panel.visible:
			_note_text = L.note_label.text
		elif _note_text != "":
			if _note_text == tr("LVL_01"):
				think("MT_NOTE1", 0.6)
			_note_text = ""
	var hd = L.haunts.get("done") if L.get("haunts") else null
	if hd is Dictionary and (hd as Dictionary).has("phone") and _once("phone"):
		think("MT_PHONE", 1.5)
	# коридор: пробки выбило, а лампочка горит; свечи зажжены
	if ph == "corridor":
		if not done.has("MT_LIGHT") and L.bulb.light_energy > 0.1 and _sees(L.bulb.global_position, 7.0, 0.4):
			think("MT_LIGHT")
		if L.exit_unlocked and _once("exit"):
			think("MT_FUNERAL", 3.0)
	# детская
	if ph == "nursery" and _once("nursery"):
		think("MT_NURSERY", 5.0)
	# чердак: манекены повернулись
	var at = L.get("attic")
	if at and at.get("solved") and _once("asolved"):
		think("MT_TURN", 4.0)
	# спальня: тайник за картиной — когда шпилька уже у тебя (зов Веры позади, в доме тихо)
	var bd = L.get("bedroom")
	var vr = bd.get("vroom") if bd else null
	if vr and L.inv and L.inv.has("v_hairpin"):
		var sf = vr.get("safe")
		if sf and is_instance_valid(sf) and sf.visible and not done.has("MT_SAFE") and not sf.get("_on") \
				and _sees(sf.global_position, 3.5, 0.4):
			think("MT_SAFE")
