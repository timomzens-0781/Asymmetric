class_name Screens
extends CanvasLayer
## Titelbild, Briefing, Pausenmenue und Endbildschirm.

signal start_requested(side: int, difficulty: int)
signal begin_requested
signal restart_requested
signal menu_requested
signal resume_requested

const C_EDGE := Color(0.85, 0.64, 0.25)
const C_TEXT := Color(0.93, 0.9, 0.82)

var title_root: Control
var brief_root: Control
var pause_root: Control
var end_root: Control
var _difficulty := 1
var _diff_btns: Array = []
var _brief_side := 0
var _brief_title: Label
var _brief_text: Label
var _brief_obj: Label
var _end_title: Label
var _end_text: Label
var _end_stats: Label
var _end_rate: Label
var _sound_btns: Array = []

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_title()
	_build_brief()
	_build_pause()
	_build_end()
	hide_all()
	get_viewport().size_changed.connect(_layout)
	_layout()

func hide_all() -> void:
	title_root.visible = false
	brief_root.visible = false
	pause_root.visible = false
	end_root.visible = false

func is_open() -> bool:
	return title_root.visible or brief_root.visible or pause_root.visible or end_root.visible

# ----------------------------------------------------------------------------- Helfer
func _style(bg: Color, edge: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	return s

func _lbl(parent: Control, text: String, fs: int, col: Color = C_TEXT, outline: int = 3) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _button(parent: Control, text: String, size_v: Vector2, cb: Callable, accent: Color = C_EDGE) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size_v
	b.size = size_v
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_stylebox_override("normal", _style(Color(0.12, 0.11, 0.1, 0.95), Color(accent.r, accent.g, accent.b, 0.55), 2))
	b.add_theme_stylebox_override("hover", _style(Color(0.2, 0.17, 0.12, 0.98), accent, 2))
	b.add_theme_stylebox_override("pressed", _style(Color(0.3, 0.22, 0.1, 1.0), accent, 2))
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.pressed.connect(func():
		Sfx.play_ui("click")
		cb.call())
	parent.add_child(b)
	return b

func _dim(parent: Control, a: float) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0, 0, 0, a)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(c)
	return c

func _new_root() -> Control:
	var r := Control.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r

# ----------------------------------------------------------------------------- Titel
var _title_lbl: Label
var _tag_lbl: Label
var _card_a: ChoiceCard
var _card_b: ChoiceCard
var _diff_row: Control
var _bottom_row: Control
var _ver: Label
var _diff_lbl: Label

func _build_title() -> void:
	title_root = _new_root()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(dim)
	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 0.5)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.size = Vector2(0, 250)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(top)
	_title_lbl = _lbl(title_root, "ASYMMETRIC", 92, Color(0.95, 0.76, 0.32), 8)
	_tag_lbl = _lbl(title_root, "Den Krieg gewinnt nicht, wer die meisten Panzer hat.", 22, Color(0.92, 0.88, 0.78), 5)
	_card_a = ChoiceCard.new()
	_card_a.title = "AURELISCHE STREITKRÄFTE"
	_card_a.subtitle = "Die Hightech-Supermacht"
	_card_a.body = "Panzer, Drohnen, Kampfhubschrauber, Präzisionsschläge: Jedes Gefecht kannst du gewinnen. Doch der Feind versteckt sich unter Zivilisten – und jedes Bild eines Fehlschlags geht um die Welt."
	_card_a.icons = ["tank", "drone", "heli"]
	_card_a.accent = Color(0.3, 0.55, 0.95)
	_card_a.details = ["Ressource: Budget & Weltöffentlichkeit", "Verhindere Sanktionen, Flugverbot, Intervention", "Sieg: Tunnelnetz zerschlagen"]
	title_root.add_child(_card_a)
	_card_a.chosen.connect(func(): start_requested.emit(U.TEAM_ADF, _difficulty))
	_card_b = ChoiceCard.new()
	_card_b.title = "HADAR-FRONT"
	_card_b.subtitle = "Die Guerilla"
	_card_b.body = "Du hast keine Chance auf dem Schlachtfeld – aber im Netz. Tarne dich unter dem Volk, lege Hinterhalte, provoziere den Giganten und lass die Kameras laufen."
	_card_b.icons = ["rpg", "launcher", "camera"]
	_card_b.accent = Color(0.95, 0.5, 0.12)
	_card_b.details = ["Ressource: Spenden, die mit der Empörung wachsen", "Medien-Teams filmen, Upload macht Eindruck", "Sieg: Empörung auf 100% treiben"]
	title_root.add_child(_card_b)
	_card_b.chosen.connect(func(): start_requested.emit(U.TEAM_REB, _difficulty))
	_diff_lbl = _lbl(title_root, "Schwierigkeit:", 16, Color(0.85, 0.82, 0.74))
	_diff_row = Control.new()
	_diff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(_diff_row)
	for i in range(3):
		var b := _button(_diff_row, ["Leicht", "Normal", "Schwer"][i], Vector2(110, 36), _set_diff.bind(i))
		b.position = Vector2(i * 118, 0)
		_diff_btns.append(b)
	_bottom_row = Control.new()
	_bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(_bottom_row)
	var sb := _button(_bottom_row, "Sound: an", Vector2(150, 36), func():
		Sfx.sfx_on = not Sfx.sfx_on
		Sfx.music_on = Sfx.sfx_on
		_refresh_sound())
	sb.position = Vector2(0, 0)
	_sound_btns.append(sb)
	var qb := _button(_bottom_row, "Beenden", Vector2(120, 36), func(): get_tree().quit())
	qb.position = Vector2(160, 0)
	_ver = _lbl(title_root, "Prototyp · Godot 4 · Fiktives Szenario: Qadira, Hadar", 12, Color(0.65, 0.62, 0.55), 2)
	_set_diff(1)
	_refresh_sound()

func _set_diff(i: int) -> void:
	_difficulty = i
	for k in range(_diff_btns.size()):
		var b: Button = _diff_btns[k]
		var on := k == i
		b.add_theme_stylebox_override("normal", _style(Color(0.3, 0.22, 0.08, 0.98) if on else Color(0.12, 0.11, 0.1, 0.95), C_EDGE if on else Color(C_EDGE.r, C_EDGE.g, C_EDGE.b, 0.4), 2))

func _refresh_sound() -> void:
	for b in _sound_btns:
		(b as Button).text = "Sound: an" if Sfx.sfx_on else "Sound: aus"
	if Sfx.music_on:
		Sfx.start_music()

func show_title() -> void:
	hide_all()
	title_root.visible = true
	_layout()

# ----------------------------------------------------------------------------- Briefing
var _brief_panel: Panel
var _brief_btn: Button

func _build_brief() -> void:
	brief_root = _new_root()
	_dim(brief_root, 0.55)
	_brief_panel = Panel.new()
	_brief_panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.065, 0.06, 0.97), C_EDGE, 2, 4))
	brief_root.add_child(_brief_panel)
	_brief_title = _lbl(_brief_panel, "", 34, Color(0.95, 0.76, 0.32), 5)
	_brief_title.position = Vector2(30, 20)
	_brief_text = _lbl(_brief_panel, "", 16, C_TEXT, 2)
	_brief_text.position = Vector2(30, 80)
	_brief_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brief_obj = _lbl(_brief_panel, "", 15, Color(0.85, 0.82, 0.72), 2)
	_brief_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brief_btn = _button(_brief_panel, "EINSATZ BEGINNEN", Vector2(260, 48), func(): begin_requested.emit())

func show_briefing(side: int) -> void:
	hide_all()
	_brief_side = side
	if side == U.TEAM_ADF:
		_brief_title.text = "OPERATION STÄHLERNER SCHILD"
		_brief_text.text = "Qadira, Hadar. Seit Tagen schlagen Raketen in Ihrer Basis ein – abgefeuert aus dicht besiedelten Vierteln der Altstadt. Die Hadar-Front kämpft nicht um Gelände, sondern um Bilder: Ihre Kämpfer tragen Zivil, ihre Werfer stehen neben Schulen, und überall laufen Kameras.\n\nSie verfügen über die stärkste Armee der Region. Das Problem ist nicht, wie viel Feuerkraft Sie haben, sondern wie viel Sie sich leisten können."
		_brief_obj.text = "ZIELE\n▸ Entdecken und zerschlagen Sie alle sechs Tunnelknoten der Hadar-Front (getarnt in Wohnhäusern).\n▸ Halten Sie die Empörung unter 100%. Bei 35% drohen Sanktionen, bei 65% die Flugverbotszone, bei 100% greift eine Koalition ein.\n▸ Zivilisten und Presse sind keine Ziele. Nutzen Sie Aufklärung, Warnungen und Präzision.\n▸ Raketenabschüsse werden geortet – Beweise sammeln Sie für die Pressekonferenz."
		_brief_btn.add_theme_stylebox_override("normal", _style(Color(0.12, 0.2, 0.36, 0.98), Color(0.3, 0.55, 0.95), 2))
	else:
		_brief_title.text = "OPERATION LEUCHTFEUER"
		_brief_text.text = "Qadira, Hadar. Gegen Aurelias Armee können Sie keine einzige Schlacht gewinnen – das wissen Sie, und das weiß Ihr Gegner. Aber die Welt schaut zu, und die Verbündeten des Giganten haben schwache Nerven.\n\nIhre Waffen: Tarnung, Hinterhalt, die Rakete als Provokation – und das Smartphone. Wer das Bild beherrscht, beherrscht den Krieg."
		_brief_obj.text = "ZIELE\n▸ Treiben Sie die Weltöffentlichkeit auf 100% Empörung.\n▸ Medien-Teams filmen Ereignisse in ihrer Nähe. Aufnahmen sammeln sich an – veröffentlichen Sie sie mit F1 (Upload).\n▸ Verstecken Sie Kämpfer in Häusern (Rechtsklick) oder unter Zivilisten (G). Lassen Sie den Feind zuerst kommen.\n▸ Halten Sie mindestens einen Tunnelknoten am Leben: Ohne sie ist der Widerstand gebrochen."
		_brief_btn.add_theme_stylebox_override("normal", _style(Color(0.36, 0.18, 0.05, 0.98), Color(0.95, 0.5, 0.12), 2))
	brief_root.visible = true
	_layout()

# ----------------------------------------------------------------------------- Pause
var _pause_panel: Panel
var _pause_sound: Button

func _build_pause() -> void:
	pause_root = _new_root()
	_dim(pause_root, 0.6)
	_pause_panel = Panel.new()
	_pause_panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.065, 0.06, 0.97), C_EDGE, 2, 4))
	pause_root.add_child(_pause_panel)
	var t := _lbl(_pause_panel, "PAUSE", 38, Color(0.95, 0.76, 0.32), 5)
	t.position = Vector2(40, 18)
	var y := 82.0
	var b1 := _button(_pause_panel, "Fortsetzen", Vector2(320, 44), func(): resume_requested.emit())
	b1.position = Vector2(40, y)
	var b2 := _button(_pause_panel, "Neustart", Vector2(320, 44), func(): restart_requested.emit())
	b2.position = Vector2(40, y + 52)
	_pause_sound = _button(_pause_panel, "Sound: an", Vector2(320, 44), func():
		Sfx.sfx_on = not Sfx.sfx_on
		Sfx.music_on = Sfx.sfx_on
		_refresh_sound()
		_pause_sound.text = "Sound: an" if Sfx.sfx_on else "Sound: aus")
	_pause_sound.position = Vector2(40, y + 104)
	_sound_btns.append(_pause_sound)
	var b3 := _button(_pause_panel, "Hauptmenü", Vector2(320, 44), func(): menu_requested.emit())
	b3.position = Vector2(40, y + 156)
	var ctrl := _lbl(_pause_panel, "Steuerung\nWASD/Pfeile/Rand: Kamera · Q/E/Mittelmaus: Drehen · Rad: Zoom\nLinksklick/Rahmen: Wählen · Rechtsklick: Befehl · Strg+Rechtsklick: Feuer erzwingen\nT: Angriffsbewegung · X: Stopp · H: Feuer halten · G: Tarnen · B: Sprengfalle\nF: Feuerbefehl · V: Gebäude räumen · R: Einsatzregeln · F1–F6: Unterstützung\nStrg+1–9: Gruppe speichern · 1–9: abrufen · Leertaste: letzter Alarm", 12, Color(0.75, 0.72, 0.64), 2)
	ctrl.position = Vector2(40, y + 214)

func show_pause() -> void:
	hide_all()
	pause_root.visible = true
	_pause_sound.text = "Sound: an" if Sfx.sfx_on else "Sound: aus"
	_layout()

# ----------------------------------------------------------------------------- Ende
var _end_panel: Panel

func _build_end() -> void:
	end_root = _new_root()
	_dim(end_root, 0.62)
	_end_panel = Panel.new()
	_end_panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.065, 0.06, 0.98), C_EDGE, 2, 4))
	end_root.add_child(_end_panel)
	_end_title = _lbl(_end_panel, "", 44, Color(0.95, 0.76, 0.32), 6)
	_end_title.position = Vector2(40, 18)
	_end_text = _lbl(_end_panel, "", 16, C_TEXT, 2)
	_end_text.position = Vector2(40, 84)
	_end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_stats = _lbl(_end_panel, "", 15, Color(0.88, 0.85, 0.76), 2)
	_end_stats.position = Vector2(40, 170)
	_end_rate = _lbl(_end_panel, "", 18, Color(1.0, 0.85, 0.4), 3)
	var b1 := _button(_end_panel, "Nochmal spielen", Vector2(250, 48), func(): restart_requested.emit())
	b1.name = "BtnAgain"
	var b2 := _button(_end_panel, "Hauptmenü", Vector2(220, 48), func(): menu_requested.emit())
	b2.name = "BtnMenu"

func show_end(res: Dictionary, player_team: int) -> void:
	hide_all()
	var won: bool = res.player_won
	_end_title.text = "SIEG" if won else "NIEDERLAGE"
	_end_title.add_theme_color_override("font_color", Color(0.5, 0.95, 0.55) if won else Color(1.0, 0.4, 0.35))
	var texts := {
		"outrage": ["Die Weltöffentlichkeit hat gesprochen: Eine internationale Koalition greift ein. Aurelia hat den Krieg der Bilder verloren – trotz überlegener Waffen.",
			"Die Welt schaut hin, und die Verbündeten Aurelias wenden sich ab. Eine Koalition greift ein. Die Bilder haben gesiegt."],
		"hq": ["Die Kommandozentrale wurde zerstört. Der Einsatz ist gescheitert.",
			"Die Kommandozentrale des Giganten brennt. Die Hadar-Front feiert einen Triumph, der Qadira lange im Gedächtnis bleiben wird."],
		"hubs": ["Das Tunnelnetzwerk der Hadar-Front ist zerschlagen. Die Stadt ist gesichert – die Frage ist nur, zu welchem Preis.",
			"Der letzte Tunnelknoten ist gefallen. Ohne Nachschub und Rückzugsorte bricht der Widerstand zusammen."],
	}
	_end_text.text = (texts[res.reason][0] if player_team == U.TEAM_ADF else texts[res.reason][1])
	var st: Dictionary = res.stats
	var t := "Einsatzdauer: %s\n" % U.fmt_time(res.time)
	t += "Höchste Empörung: %d%%\n" % int(round(res.peak))
	t += "Zivile Opfer gesamt: %d  (davon durch Aurelia: %d · durch die Hadar-Front: %d)\n" % [st.civ_killed, st.civ_by_adf, st.civ_by_reb]
	t += "Tunnelknoten zerstört: %d von 6\n" % st.hubs_destroyed
	t += "Verluste – Aurelia: %d · Hadar-Front: %d\n" % [st.adf_lost, st.reb_lost]
	t += "Raketenabschüsse: %d · Veröffentlichungen: %d · Warnungen: %d · Beweise vorgelegt: %d" % [st.launches, st.uploads, st.shots_warned, st.evidence_published]
	_end_stats.text = t
	var rate := ""
	if player_team == U.TEAM_ADF:
		if won:
			if st.civ_by_adf <= 8 and res.peak < 40.0:
				rate = "Wertung: Chirurgischer Sieg – kaum Kollateralschäden."
			elif res.peak < 65.0:
				rate = "Wertung: Sieg mit Narben – die Bilder bleiben."
			else:
				rate = "Wertung: Pyrrhussieg – ein Sieg, der kaum noch einer war."
		else:
			rate = "Wertung: Gewonnene Gefechte, verlorener Krieg."
	else:
		if won:
			rate = "Wertung: Der Krieg der Bilder ist gewonnen."
		else:
			rate = "Wertung: Das Tunnelnetz ist gefallen – ohne Rückhalt keine Bilder."
	_end_rate.text = rate
	end_root.visible = true
	_layout()

# ----------------------------------------------------------------------------- Layout
func _layout() -> void:
	if title_root == null:
		return
	var sz := get_viewport().get_visible_rect().size
	var W := sz.x
	var H := sz.y
	_title_lbl.position = Vector2(60, 24)
	_tag_lbl.position = Vector2(66, 142)
	var cw := minf(520.0, (W - 160.0) * 0.5)
	var ch := minf(470.0, H - 330.0)
	var cy := 235.0
	_card_a.position = Vector2(60, cy)
	_card_a.size = Vector2(cw, ch)
	_card_b.position = Vector2(60 + cw + 30, cy)
	_card_b.size = Vector2(cw, ch)
	_diff_lbl.position = Vector2(60, cy + ch + 20)
	_diff_row.position = Vector2(180, cy + ch + 14)
	_bottom_row.position = Vector2(60 + 2 * cw + 30 - 280, cy + ch + 14)
	_ver.position = Vector2(60, H - 28)
	var bw := minf(900.0, W - 80.0)
	_brief_panel.size = Vector2(bw, 560)
	_brief_panel.position = Vector2((W - bw) * 0.5, (H - 560) * 0.5)
	_brief_text.size = Vector2(bw - 60, 120)
	_brief_obj.position = Vector2(30, 290)
	_brief_obj.size = Vector2(bw - 60, 200)
	_brief_btn.position = Vector2(bw - 290, 490)
	_pause_panel.size = Vector2(min(760.0, W - 40.0), 560)
	_pause_panel.position = Vector2((W - _pause_panel.size.x) * 0.5, (H - 560) * 0.5)
	_end_panel.size = Vector2(minf(860.0, W - 40.0), 470)
	_end_panel.position = Vector2((W - _end_panel.size.x) * 0.5, (H - 470) * 0.5)
	_end_text.size = Vector2(_end_panel.size.x - 80, 80)
	_end_rate.position = Vector2(40, 330)
	_end_panel.get_node("BtnAgain").position = Vector2(40, 395)
	_end_panel.get_node("BtnMenu").position = Vector2(310, 395)
