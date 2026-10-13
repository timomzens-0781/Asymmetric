class_name Hud
extends CanvasLayer
## Das Spiel-HUD: Kopfleiste (Budget, Empoerung, Zeit), Nachrichtenticker, Meldungen, Minikarte,
## Auswahlinfo, Command-Card, Faehigkeitsleiste, Tooltips, Banner.

signal pause_clicked
signal speed_changed(mult: float)

const C_PANEL := Color(0.075, 0.07, 0.065, 0.94)
const C_EDGE := Color(0.85, 0.64, 0.25)
const C_TEXT := Color(0.93, 0.9, 0.82)

var world: World
var player: PlayerController
var rig: RtsCamera
var team := 0

var root: Control
var overlay: WorldOverlay
var topbar: Panel
var bottom: Panel
var minimap: Minimap
var info: InfoPanel
var card: GridContainer
var abil: VBoxContainer
var abil_panel: Panel
var meter: OutrageMeter
var lbl_money: Label
var lbl_income: Label
var lbl_pop: Label
var lbl_time: Label
var lbl_extra: Label
var lbl_level: Label
var ticker_panel: Panel
var ticker_label: Label
var ticker_tag: Label
var feed: VBoxContainer
var tip_panel: Panel
var tip_title: Label
var tip_text: Label
var banner: Label
var banner_sub: Label
var vignette: TextureRect
var speed_btns: Array = []
var roe_btn: CmdButton

var _ticker_queue: Array = []
var _ticker_t := 0.0
var _ticker_idle := 6.0
var _card_sig := ""
var _card_items: Array = []
var _card_buttons: Array = []
var _abil_buttons: Dictionary = {}
var _refresh_t := 0.0
var _banner_t := 0.0
var _feed_items: Array = []
var _hover_btn: CmdButton = null
var _speed := 1.0
var shown := false

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Game.news_posted.connect(_on_news)
	Game.message_posted.connect(_on_message)
	Game.level_changed.connect(_on_level)
	get_viewport().size_changed.connect(_layout)

# ============================================================================= Aufbau
func _style(bg: Color, edge: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	return s

func _panel(parent: Control, bg: Color = C_PANEL, edge: Color = C_EDGE, bw: int = 1) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _style(bg, edge, bw, 4))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(p)
	return p

func _label(parent: Control, text: String, fs: int = 14, col: Color = C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	overlay = WorldOverlay.new()
	root.add_child(overlay)
	# Vignette
	vignette = TextureRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.55)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 0.95)
	gt.width = 256
	gt.height = 256
	vignette.texture = gt
	root.add_child(vignette)
	_build_topbar()
	_build_ticker()
	_build_feed()
	_build_bottom()
	_build_abilities()
	_build_tooltip()
	_build_banner()
	_layout()

func _build_topbar() -> void:
	topbar = _panel(root)
	lbl_money = _label(topbar, "$0", 24, Color(0.6, 0.95, 0.5))
	lbl_income = _label(topbar, "+0/s", 12, Color(0.7, 0.8, 0.6))
	lbl_pop = _label(topbar, "Truppen 0/0", 13, C_TEXT)
	lbl_extra = _label(topbar, "", 12, Color(1.0, 0.9, 0.5))
	meter = OutrageMeter.new()
	topbar.add_child(meter)
	lbl_level = _label(topbar, "", 12, Color(1.0, 0.45, 0.35))
	lbl_time = _label(topbar, "00:00", 20, C_TEXT)
	for i in range(3):
		var b := CmdButton.new()
		b.custom_minimum_size = Vector2(30, 24)
		b.size = Vector2(30, 24)
		b.label = ["1×", "2×", "3×"][i]
		b.center_text = true
		topbar.add_child(b)
		b.pressed.connect(_set_speed.bind([1.0, 2.0, 3.0][i]))
		speed_btns.append(b)
	var pb := CmdButton.new()
	pb.size = Vector2(40, 30)
	pb.icon = "pause"
	pb.tip_title = "Pause / Menü (Esc)"
	topbar.add_child(pb)
	pb.pressed.connect(func(): pause_clicked.emit())
	pb.hover_changed.connect(_on_btn_hover)
	speed_btns.append(pb)

func _build_ticker() -> void:
	ticker_panel = _panel(root, Color(0.05, 0.05, 0.05, 0.88), Color(0.5, 0.1, 0.1), 1)
	ticker_panel.clip_contents = true
	ticker_label = _label(ticker_panel, "", 14, Color(0.95, 0.93, 0.85))
	ticker_tag = _label(ticker_panel, " LIVE ", 13, Color(1, 1, 1))
	ticker_tag.add_theme_stylebox_override("normal", _style(Color(0.75, 0.1, 0.1)))

func _build_feed() -> void:
	feed = VBoxContainer.new()
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed.add_theme_constant_override("separation", 2)
	root.add_child(feed)

func _build_bottom() -> void:
	bottom = _panel(root, Color(0.06, 0.055, 0.05, 0.96), C_EDGE, 2)
	minimap = Minimap.new()
	bottom.add_child(minimap)
	info = InfoPanel.new()
	bottom.add_child(info)
	info.pick_unit.connect(func(e): player.select_list([e]))
	info.cancel_queue.connect(func(s, idx): s.cancel_unit(idx))
	card = GridContainer.new()
	card.columns = 4
	card.add_theme_constant_override("h_separation", 5)
	card.add_theme_constant_override("v_separation", 5)
	bottom.add_child(card)

func _build_abilities() -> void:
	abil_panel = _panel(root, Color(0.07, 0.065, 0.06, 0.88), C_EDGE, 1)
	abil = VBoxContainer.new()
	abil.add_theme_constant_override("separation", 5)
	abil_panel.add_child(abil)

func _build_tooltip() -> void:
	tip_panel = _panel(root, Color(0.04, 0.04, 0.04, 0.96), C_EDGE, 1)
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.visible = false
	tip_title = _label(tip_panel, "", 15, C_EDGE)
	tip_text = _label(tip_panel, "", 12, C_TEXT)
	tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_banner() -> void:
	banner = _label(root, "", 34, Color(1, 0.9, 0.9))
	banner.add_theme_stylebox_override("normal", _style(Color(0.7, 0.05, 0.05, 0.92), Color(1, 0.7, 0.7), 2, 3))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.visible = false
	banner_sub = _label(root, "", 15, Color(1, 0.95, 0.9))
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.visible = false

func _layout() -> void:
	if root == null:
		return
	var sz := get_viewport().get_visible_rect().size
	var W := sz.x
	var H := sz.y
	topbar.position = Vector2(0, 0)
	topbar.size = Vector2(W, 62)
	lbl_money.position = Vector2(14, 4)
	lbl_income.position = Vector2(16, 36)
	lbl_pop.position = Vector2(150, 3)
	lbl_extra.position = Vector2(150, 23)
	var mw := clampf(W * 0.38, 420.0, 640.0)
	meter.size = Vector2(mw, 50)
	meter.position = Vector2((W - mw) * 0.5, 4)
	lbl_level.position = Vector2(150, 41)
	lbl_time.position = Vector2(W - 150, 6)
	for i in range(3):
		(speed_btns[i] as Control).position = Vector2(W - 150 + i * 34, 34)
	(speed_btns[3] as Control).position = Vector2(W - 52, 14)
	(speed_btns[3] as Control).position = Vector2(W - 54, 6)
	ticker_panel.position = Vector2(0, 62)
	ticker_panel.size = Vector2(W, 28)
	ticker_tag.position = Vector2(6, 3)
	feed.position = Vector2(12, 100)
	feed.size = Vector2(520, 160)
	var bh := 214.0
	bottom.position = Vector2(0, H - bh)
	bottom.size = Vector2(W, bh)
	minimap.position = Vector2(10, 8)
	info.position = Vector2(226, 8)
	info.size = Vector2(minf(W - 226 - 340, 700), bh - 16)
	card.position = Vector2(W - 4 * 71 - 12, 8)
	var n_ab := 6 if team == U.TEAM_ADF else 2
	abil_panel.size = Vector2(80, n_ab * 71 + (41 if team == U.TEAM_ADF else 0) + 12)
	abil_panel.position = Vector2(W - 92, 100)
	abil.position = Vector2(6, 6)
	banner.size = Vector2(minf(W * 0.8, 920), 62)
	banner.position = Vector2((W - banner.size.x) * 0.5, 140)
	banner_sub.size = Vector2(banner.size.x, 30)
	banner_sub.position = Vector2(banner.position.x, 206)

# ============================================================================= Binden
func bind(w: World, p: PlayerController, r: RtsCamera, t: int) -> void:
	world = w
	player = p
	rig = r
	team = t
	overlay.world = w
	overlay.player = p
	overlay.rig = r
	info.player = p
	info.world = w
	minimap.bind(w, p, r)
	meter.team = t
	_build_ability_buttons()
	if not player.selection_changed.is_connected(_on_selection_changed):
		player.selection_changed.connect(_on_selection_changed)
	if not player.mode_changed.is_connected(_on_mode_changed):
		player.mode_changed.connect(_on_mode_changed)
	_layout()
	_card_sig = ""
	_refresh_card(true)
	for c in feed.get_children():
		c.queue_free()
	_feed_items.clear()
	_ticker_queue.clear()
	ticker_label.text = ""
	set_shown(true)

func set_shown(v: bool) -> void:
	shown = v
	root.visible = v

func _on_selection_changed() -> void:
	_refresh_card(true)

func _on_mode_changed() -> void:
	for id in _abil_buttons.keys():
		var b: CmdButton = _abil_buttons[id]
		b.active = player.mode == "ability" and player.ability_id == id
		b.queue_redraw()
	_refresh_card(true)

func _build_ability_buttons() -> void:
	for c in abil.get_children():
		c.queue_free()
	_abil_buttons.clear()
	var ids: Array = player.ability_order()
	var i := 0
	for id in ids:
		var d: Dictionary = Data.ABILITIES[id]
		var b := CmdButton.new()
		b.icon = d.icon
		b.hotkey = "F%d" % (i + 1)
		b.cost = d.cost
		b.label = ""
		b.tip_title = "%s  [F%d]" % [d.name, i + 1]
		b.tip_text = d.desc + ("\nKosten: %s · Abklingzeit %ds" % [U.fmt_money(d.cost), int(d.cd)])
		b.accent = U.team_color(team)
		abil.add_child(b)
		b.pressed.connect(player.begin_ability.bind(id))
		b.hover_changed.connect(_on_btn_hover)
		_abil_buttons[id] = b
		i += 1
	if team == U.TEAM_ADF:
		roe_btn = CmdButton.new()
		roe_btn.custom_minimum_size = Vector2(66, 36)
		roe_btn.size = Vector2(66, 36)
		roe_btn.icon = "roe"
		roe_btn.hotkey = "R"
		roe_btn.tip_title = "Einsatzregeln [R]"
		roe_btn.tip_text = "Streng: Einheiten feuern nur auf identifizierte Feinde.\nFrei: Zivile Gebäude, aus denen geschossen wird, werden automatisch beschossen – mit Kollateralrisiko."
		abil.add_child(roe_btn)
		roe_btn.pressed.connect(func():
			world.roe_free[0] = not world.roe_free[0]
			Sfx.play_ui("click"))
		roe_btn.hover_changed.connect(_on_btn_hover)
	else:
		roe_btn = null

# ============================================================================= Command-Card
func _selection_sig() -> String:
	var s := "m:%s:%s|" % [player.mode, player.ability_id]
	for e in player.selected:
		if is_instance_valid(e):
			s += "%s,%d;" % [e.kind, e.get_instance_id()]
	return s

func _refresh_card(force: bool = false) -> void:
	if player == null:
		return
	var sig := _selection_sig()
	if sig == _card_sig and not force:
		return
	_card_sig = sig
	for c in card.get_children():
		c.queue_free()
	_card_buttons.clear()
	_card_items = _build_card_items()
	for it in _card_items:
		var b := CmdButton.new()
		b.icon = it.get("icon", "")
		b.label = it.get("label", "")
		b.hotkey = it.get("hotkey", "")
		b.cost = it.get("cost", -1.0)
		b.tip_title = it.get("tip_title", "")
		b.tip_text = it.get("tip", "")
		b.accent = U.team_color(team)
		card.add_child(b)
		b.pressed.connect(it.action)
		if it.has("right"):
			b.right_pressed.connect(it.right)
		b.hover_changed.connect(_on_btn_hover)
		_card_buttons.append(b)
	_update_card_states()

func _own_units() -> Array:
	return player._own_units()

func _build_card_items() -> Array:
	var items: Array = []
	var structs := player._own_structures()
	var units := _own_units()
	if not structs.is_empty() and units.is_empty():
		var s: Structure = structs[0]
		for k in s.produces:
			var d: Dictionary = Data.UNITS[k]
			items.append({
				"icon": d.icon, "label": d.get("short", d.name), "cost": d.cost,
				"tip_title": "%s  (%s)" % [d.name, U.fmt_money(d.cost)],
				"tip": d.desc + "\nAusbildungszeit: %ds · Truppenstärke: %d" % [int(d.time), d.pop] + "\nRechtsklick: letzte Bestellung stornieren",
				"action": func(): _produce(s, k),
				"right": func(): _unproduce(s, k),
				"kind": k, "struct": s,
			})
		if not s.produces.is_empty():
			items.append({
				"icon": "flag", "label": "Sammelpunkt",
				"tip_title": "Sammelpunkt", "tip": "Rechtsklick auf die Karte setzt den Sammelpunkt für neue Einheiten.",
				"action": func(): Game.message("Rechtsklick: Sammelpunkt setzen", "info", team),
			})
		if s.garrisoned.size() > 0 and s.team == team:
			items.append({
				"icon": "exit", "label": "Räumen", "hotkey": "V",
				"tip_title": "Gebäude räumen [V]", "tip": "Alle Besatzungen verlassen das Gebäude.",
				"action": func():
					for u in s.garrisoned.duplicate():
						(u as Unit).ungarrison(),
			})
		return items
	if units.is_empty():
		return items
	var any_weapons := units.any(func(u): return not u.weapons.is_empty())
	items.append({"icon": "stop", "label": "Stopp", "hotkey": "X", "tip_title": "Stopp [X]", "tip": "Alle Befehle abbrechen.",
		"action": func():
			for u in units:
				if is_instance_valid(u):
					u.cmd_stop()})
	if any_weapons:
		items.append({"icon": "attack_move", "label": "Angriff", "hotkey": "T", "tip_title": "Angriffsbewegung [T]", "tip": "Bewegt sich zum Ziel und bekämpft unterwegs alle erkannten Feinde.",
			"action": func(): player.set_mode("attack_move")})
		items.append({"icon": "hold", "label": "Halten", "hotkey": "H", "tip_title": "Feuer halten [H]", "tip": "Einheiten eröffnen nicht von selbst das Feuer. Hilft, Zwischenfälle mit Zivilisten zu vermeiden.",
			"action": func():
				for u in units:
					if is_instance_valid(u):
						u.hold = not u.hold
						if u.hold:
							u.target = null,
			"toggle": "hold"})
	if units.any(func(u): return u.manual_only):
		items.append({"icon": "fire_ground", "label": "Feuerbefehl", "hotkey": "F", "tip_title": "Feuerbefehl [F]", "tip": "Wählt ein Bodenziel für Artillerie bzw. Raketenwerfer.",
			"action": func(): player.set_mode("fire_ground")})
	if units.any(func(u): return u.can_conceal):
		items.append({"icon": "conceal", "label": "Tarnen", "hotkey": "G", "tip_title": "Zivile Tarnung [G]", "tip": "Kämpfer mischen sich unters Volk, bis sie das Feuer eröffnen. Automatisch nach 3s Ruhe.",
			"action": func():
				for u in units:
					if is_instance_valid(u):
						u.cmd_toggle_conceal(),
			"toggle": "conceal"})
		items.append({"icon": "exit", "label": "Verlassen", "hotkey": "V", "tip_title": "Gebäude verlassen [V]", "tip": "Rechtsklick auf ein Gebäude: Einheit bezieht Stellung. V: Besatzung verlässt das Gebäude.",
			"action": func():
				for u in units:
					if is_instance_valid(u) and u.garrison != null:
						u.ungarrison()})
	if units.any(func(u): return u.can_ied):
		items.append({"icon": "ied", "label": "Sprengfalle", "hotkey": "B", "cost": 50.0, "tip_title": "Sprengfalle legen [B]", "tip": "Versteckte Mine unter dem Fahrzeug des Gegners. Maximal 8 aktiv. Aufklärer entdecken sie.",
			"action": func():
				for u in units:
					if is_instance_valid(u) and u.can_ied:
						u.cmd_place_ied()})
	return items

func _produce(s: Structure, k: String) -> void:
	if s.queue_unit(k):
		Sfx.play_ui("click")
	else:
		Sfx.play_ui("error")

func _unproduce(s: Structure, k: String) -> void:
	for i in range(s.queue.size() - 1, -1, -1):
		if s.queue[i].kind == k:
			s.cancel_unit(i)
			return

func _update_card_states() -> void:
	for i in range(_card_buttons.size()):
		var b: CmdButton = _card_buttons[i]
		var it: Dictionary = _card_items[i]
		var en := true
		if it.has("kind"):
			var s: Structure = it.struct
			var d: Dictionary = Data.UNITS[it.kind]
			en = Game.can_afford(team, d.cost) and s.alive
			if it.kind == "adf_viper" and Game.no_fly_zone():
				en = false
			# Anzahl in Warteschlange als Abzeichen
			var n := 0
			for q in s.queue:
				if q.kind == it.kind:
					n += 1
			var nb := str(n) if n > 0 else ""
			if b.badge != nb:
				b.badge = nb
				b.queue_redraw()
		elif it.has("cost") and it.cost > 0:
			en = Game.can_afford(team, it.cost)
		var act := false
		if it.has("toggle"):
			var units := _own_units()
			if it.toggle == "hold":
				act = units.any(func(u): return is_instance_valid(u) and u.hold)
			elif it.toggle == "conceal":
				act = units.any(func(u): return is_instance_valid(u) and u.can_conceal and u.conceal_pref)
		if it.get("icon", "") == "attack_move":
			act = player.mode == "attack_move"
		if it.get("icon", "") == "fire_ground":
			act = player.mode == "fire_ground"
		if b.enabled != en or b.active != act:
			b.enabled = en
			b.active = act
			b.queue_redraw()

func _update_abilities() -> void:
	for id in _abil_buttons.keys():
		var b: CmdButton = _abil_buttons[id]
		var d: Dictionary = Data.ABILITIES[id]
		var cd: float = Game.cooldowns[team].get(id, 0.0)
		var ready := Game.ability_ready(team, id)
		b.set_state(ready, cd, d.cd)
		var nb := ""
		if id == "evidence":
			nb = str(int(Game.evidence)) if Game.evidence >= 1.0 else ""
		elif id == "upload":
			nb = str(int(Game.footage)) if Game.footage >= 1.0 else ""
		if b.badge != nb:
			b.badge = nb
			b.queue_redraw()
	if roe_btn != null:
		var act: bool = world.roe_free[0]
		if roe_btn.active != act:
			roe_btn.active = act
			roe_btn.queue_redraw()

# ============================================================================= Tooltip
func _on_btn_hover(b: CmdButton, h: bool) -> void:
	if h:
		_hover_btn = b
	elif _hover_btn == b:
		_hover_btn = null

func _update_tooltip() -> void:
	if _hover_btn == null or not is_instance_valid(_hover_btn) or _hover_btn.tip_title == "":
		tip_panel.visible = false
		return
	var b := _hover_btn
	tip_title.text = b.tip_title
	tip_text.text = b.tip_text
	var w := 300.0
	tip_title.position = Vector2(10, 6)
	tip_text.position = Vector2(10, 28)
	tip_text.size = Vector2(w - 20, 10)
	tip_text.custom_minimum_size = Vector2(w - 20, 0)
	var h := 36.0 + maxf(tip_text.get_minimum_size().y, 14.0)
	tip_panel.size = Vector2(w, h)
	var gp := b.global_position
	var sz := get_viewport().get_visible_rect().size
	var px := clampf(gp.x + b.size.x * 0.5 - w * 0.5, 4.0, sz.x - w - 4.0)
	var py := gp.y - h - 8.0
	if py < 100.0:
		py = gp.y + b.size.y + 8.0
		px = clampf(gp.x - w - 8.0, 4.0, sz.x - w - 4.0)
	tip_panel.position = Vector2(px, py)
	tip_panel.visible = true

# ============================================================================= Ticker / Meldungen
func _on_news(text: String, kind: String) -> void:
	_ticker_queue.append({"text": text, "kind": kind})
	if _ticker_queue.size() > 6:
		_ticker_queue.pop_front()
	if kind == "bad":
		Sfx.play_ui("news", -6.0)

func _on_message(text: String, kind: String, t: int) -> void:
	if t != -1 and t != team:
		return
	var l := _label(feed, text, 14, {"bad": Color(1.0, 0.45, 0.4), "warn": Color(1.0, 0.85, 0.4), "good": Color(0.55, 1.0, 0.6), "info": Color(0.9, 0.9, 0.85)}.get(kind, C_TEXT))
	_feed_items.append({"label": l, "t": 0.0})
	if _feed_items.size() > 6:
		var old: Dictionary = _feed_items.pop_front()
		old.label.queue_free()
	if kind == "bad" or kind == "warn":
		Sfx.play_ui("alert", -8.0)

func _on_level(lv: int) -> void:
	if lv <= 0:
		return
	var txt: String = {1: "SANKTIONEN", 2: "FLUGVERBOTSZONE", 3: "INTERVENTION DER KOALITION"}.get(lv, "")
	var sub: String = {
		1: "Die Verbündeten kürzen das Budget der Streitkräfte (−40%).",
		2: "Luftunterstützung abgezogen – keine Luftschläge, keine Hubschrauber, keine Drohnen.",
		3: "Aurelia ist politisch und militärisch isoliert.",
	}.get(lv, "")
	banner.text = "BREAKING NEWS · " + txt
	banner_sub.text = sub
	banner.visible = true
	banner_sub.visible = true
	_banner_t = 7.0
	Sfx.play_ui("level_up")

func _set_speed(m: float) -> void:
	_speed = m
	speed_changed.emit(m)
	Sfx.play_ui("click", -6.0)

# ============================================================================= Update
func _process(dt: float) -> void:
	if not shown or player == null or world == null:
		return
	_refresh_t -= dt
	if _refresh_t <= 0.0:
		_refresh_t = 0.2
		_update_card_states()
		_update_abilities()
	_update_top()
	_update_ticker(dt)
	_update_feed(dt)
	_update_tooltip()
	if _banner_t > 0.0:
		_banner_t -= dt
		var a := clampf(_banner_t / 1.2, 0.0, 1.0)
		banner.modulate.a = a
		banner_sub.modulate.a = a
		if _banner_t <= 0.0:
			banner.visible = false
			banner_sub.visible = false
	# UI-Hover fuer Spielersteuerung
	var mp := get_viewport().get_mouse_position()
	var over := false
	for c in [topbar, bottom, ticker_panel, abil_panel]:
		if (c as Control).get_global_rect().has_point(mp):
			over = true
	player.ui_hover = over
	for i in range(3):
		var b: CmdButton = speed_btns[i]
		var act := is_equal_approx(_speed, [1.0, 2.0, 3.0][i])
		if b.active != act:
			b.active = act
			b.queue_redraw()

func _update_top() -> void:
	lbl_money.text = U.fmt_money(Game.budget[team])
	var inc := Game.income_rate(team)
	lbl_income.text = "+%d/s" % int(round(inc))
	if team == U.TEAM_ADF and Game.level >= 1:
		lbl_income.text += "  (Sanktionen −40%)"
	lbl_pop.text = "Truppen %d/%d" % [Game.pop_used(team), Game.pop_cap(team)]
	lbl_time.text = U.fmt_time(Game.time)
	var ex := ""
	if team == U.TEAM_ADF:
		ex = "Beweise: %d" % int(Game.evidence)
		ex += "  ·  ROE: %s" % ("frei" if world.roe_free[0] else "streng")
	else:
		ex = "Videomaterial: %d" % int(Game.footage)
		var m := Game.media_alive()
		ex += "  ·  Medien-Teams: %d" % m
		ex += "  ·  Tunnelknoten: %d" % Game.alive_hubs()
		if m == 0:
			ex += "  (!)"
	lbl_extra.text = ex
	var lv_txt := ""
	match Game.level:
		0:
			lv_txt = "Lage: unter Kontrolle" if team == U.TEAM_ADF else "Weltöffentlichkeit: noch ruhig"
		1:
			lv_txt = "STUFE 1 – Sanktionen aktiv"
		2:
			lv_txt = "STUFE 2 – Flugverbotszone aktiv"
		3:
			lv_txt = "STUFE 3 – Intervention"
	lbl_level.text = lv_txt
	lbl_level.add_theme_color_override("font_color", [Color(0.7, 0.85, 0.7), Color(1.0, 0.8, 0.3), Color(1.0, 0.45, 0.25), Color(1, 0.2, 0.2)][Game.level])

func _update_ticker(dt: float) -> void:
	if _ticker_t > 0.0:
		_ticker_t -= dt
		ticker_label.position.x -= dt * 95.0
		if ticker_label.position.x + ticker_label.size.x < 0.0:
			_ticker_t = 0.0
		return
	_ticker_idle -= dt
	if not _ticker_queue.is_empty():
		var n: Dictionary = _ticker_queue.pop_front()
		ticker_label.text = "●  " + n.text
		ticker_label.add_theme_color_override("font_color", {"bad": Color(1.0, 0.7, 0.65), "good": Color(0.7, 1.0, 0.75)}.get(n.kind, Color(0.95, 0.93, 0.85)))
		ticker_label.position = Vector2(get_viewport().get_visible_rect().size.x, 4)
		_ticker_t = 60.0
	else:
		ticker_label.text = ""

func _update_feed(dt: float) -> void:
	for it in _feed_items.duplicate():
		it.t += dt
		var l: Label = it.label
		if not is_instance_valid(l):
			_feed_items.erase(it)
			continue
		if it.t > 7.0:
			l.modulate.a = clampf(1.0 - (it.t - 7.0) / 1.2, 0.0, 1.0)
			if it.t > 8.2:
				l.queue_free()
				_feed_items.erase(it)
