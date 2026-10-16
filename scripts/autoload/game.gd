extends Node
## Globaler Spielzustand: Budget, Empoerung ("Weltoeffentlichkeit"), Faehigkeiten, Statistik, Siegbedingungen.

signal news_posted(text: String, kind: String)
signal message_posted(text: String, kind: String, team: int)
signal alert(pos: Vector3, kind: String)
signal outrage_changed(value: float)
signal level_changed(level: int)
signal match_ended(result: Dictionary)
signal ability_used(id: String, team: int)

var world: World = null
var player_team := 0
var demo_mode := false
var running := false
var ended := false
var time := 0.0
var difficulty := 1       # 0 leicht, 1 normal, 2 schwer

# --- Ressourcen
var budget: Array = [0.0, 0.0]
var outrage := 0.0
var footage := 0.0        # unveroeffentlichtes Videomaterial
var evidence := 0.0       # gesammelte Beweise (ADF)
var level := 0
var cooldowns: Array = [{}, {}]
var peak_outrage := 0.0

# --- Statistik
var stats := {}

var _civ_events: Array = []     # {pos, n, cause, by, t, direct}
var _civ_flush_t := 0.0
var _income_t := 0.0
var _news_t := 20.0
var _decay_t := 0.0
var _last_event_t := -99.0
var _rng := RandomNumberGenerator.new()
var _launch_alert_t := 0.0
var _evidence_cd_t := 0.0
var _hub_total := 0
var _end_check_t := 0.0
var _upload_hint_t := 0.0
var fire_clusters: Array = []     # Feuergefechte der eigenen Seite: {pos, t, alert_t}
var jam_t := 0.0                  # Stoersender der Hadar-Front aktiv
var briefing_t := 0.0             # Presse-Briefing aktiv: neue Empoerung wirkt abgeschwaecht
var timeline: Array = []          # Ereignisprotokoll: {t, kind, text, pos, o}
var outrage_samples := PackedFloat32Array()   # Empoerung im 2-s-Takt
var anger_samples := PackedFloat32Array()     # Summe Wut aller Viertel im 2-s-Takt
var attrib: Dictionary = {}       # Ursache -> Empoerung (nur Zuwachs)
var footage_src: Dictionary = {}  # Ursache -> unveroeffentlichtes Material
var _sample_t := 0.0
var _aid_news_t := -99.0

func start(side: int, diff: int, demo: bool) -> void:
	player_team = side
	difficulty = diff
	demo_mode = demo
	running = true
	ended = false
	time = 0.0
	budget = [4500.0, 2800.0]
	if difficulty == 0:
		budget[side] += 800.0
	outrage = 0.0
	footage = 0.0
	evidence = 0.0
	level = 0
	peak_outrage = 0.0
	cooldowns = [{}, {}]
	_civ_events.clear()
	fire_clusters.clear()
	_civ_flush_t = 0.0
	_income_t = 0.0
	_news_t = 25.0
	_last_event_t = -99.0
	_launch_alert_t = 0.0
	_upload_hint_t = 0.0
	_decay_t = 0.0
	_end_check_t = 0.0
	briefing_t = 0.0
	jam_t = 0.0
	timeline.clear()
	outrage_samples = PackedFloat32Array()
	anger_samples = PackedFloat32Array()
	attrib.clear()
	footage_src.clear()
	_sample_t = 0.0
	_aid_news_t = -99.0
	_rng.randomize()
	stats = {
		"civ_killed": 0, "civ_by_adf": 0, "civ_by_reb": 0, "adf_lost": 0, "reb_lost": 0,
		"hubs_destroyed": 0, "hubs_total": 0, "buildings_destroyed": 0, "uploads": 0, "launches": 0,
		"evidence_published": 0, "shots_warned": 0, "tunnel_trips": 0, "recruits": 0, "aid_delivered": 0, "strikes": 0,
	}
	outrage_changed.emit(outrage)
	level_changed.emit(level)

## Eigene Einheit/Gebaeude wurde getroffen -> Feuergefecht-Markierung am Bildschirmrand
func entity_hit(e: Entity) -> void:
	if demo_mode or not running or e.team != player_team:
		return
	var pos := e.position
	for c in fire_clusters:
		if U.dist2d(c.pos, pos) < 26.0:
			c.pos = (c.pos as Vector3).lerp(pos, 0.35)
			c.t = time
			if time - c.alert_t > 9.0:
				c.alert_t = time
				alert.emit(c.pos, "combat")
			return
	fire_clusters.append({"pos": pos, "t": time, "alert_t": time})
	alert.emit(pos, "combat")
	Sfx.play_ui("alert", -12.0)

func stop() -> void:
	running = false

# ============================================================================= Okonomie
func can_afford(t: int, cost: float) -> bool:
	return budget[t] >= cost

func spend(t: int, cost: float) -> void:
	budget[t] -= cost

func refund(t: int, cost: float) -> void:
	budget[t] += cost

func pop_used(t: int) -> int:
	var n := 0
	if world == null:
		return 0
	for u in world.units:
		if u.alive and u.team == t and not u.is_civ:
			n += u.pop
	return n

func pop_cap(t: int) -> int:
	return 70 if t == U.TEAM_ADF else 90

func prod_speed(t: int) -> float:
	if t == U.TEAM_ADF:
		return 1.0
	return 1.0

func income_rate(t: int) -> float:
	# Schwierigkeit: Spieler bekommt auf "leicht" mehr, die KI auf "schwer" mehr
	var mult := 1.0
	if demo_mode:
		mult = 1.0
	elif t == player_team:
		mult = [1.25, 1.0, 0.9][difficulty]
	else:
		mult = [0.75, 1.0, 1.25][difficulty]
	if t == U.TEAM_ADF:
		var base := 24.0 * mult
		if level >= 1:
			base *= 0.6
		return base
	var hubs := alive_hubs()
	var donations := 0.012 * world.total_anger() if world != null else 0.0
	return (3.6 * hubs * (1.0 + outrage / 80.0) + 1.5 + donations) * mult

func alive_hubs() -> int:
	if world == null:
		return 0
	var n := 0
	for s in world.structures:
		if s.alive and s.hub:
			n += 1
	return n

func no_fly_zone() -> bool:
	return level >= 2

# ============================================================================= Sim
func _process(dt: float) -> void:
	if not running or world == null or world.paused:
		return
	dt = minf(dt, 0.2)
	time += dt
	# Einkommen
	_income_t += dt
	if _income_t >= 1.0:
		_income_t -= 1.0
		budget[0] += income_rate(0)
		budget[1] += income_rate(1)
	fire_clusters = fire_clusters.filter(func(c): return time - c.t < 8.0)
	if briefing_t > 0.0:
		briefing_t = maxf(0.0, briefing_t - dt)
	if jam_t > 0.0:
		jam_t = maxf(0.0, jam_t - dt)
		if jam_t <= 0.0:
			message_posted.emit("Störsender erloschen – Drohnen und Lenkwaffen wieder einsatzbereit", "info", U.TEAM_ADF)
		if outrage > 0.0:
			add_outrage(-0.05 * dt, true, "")
	_sample_t -= dt
	if _sample_t <= 0.0:
		_sample_t = 2.0
		outrage_samples.append(outrage)
		anger_samples.append(world.total_anger() if world != null else 0.0)
	# Abklingzeiten
	for t in range(2):
		var cd: Dictionary = cooldowns[t]
		for k in cd.keys():
			cd[k] = maxf(0.0, cd[k] - dt)
	# Zivile Ereignisse sammeln und buendeln
	_civ_flush_t -= dt
	if _civ_flush_t <= 0.0:
		_civ_flush_t = 1.1
		_flush_civ_events()
	# Videomaterial: ohne Medien-Team sickert es langsam ins Netz
	_decay_t += dt
	if footage > 0.0:
		var has_media := media_alive() > 0
		var leak := 0.012 if not has_media else 0.0
		if leak > 0.0:
			var amt := minf(footage, footage * leak * dt + 0.02 * dt)
			footage -= amt
			add_outrage(amt * 0.55)
	# Hinweis fuer den menschlichen Rebellen-Spieler: Material wartet auf Upload
	if player_team == U.TEAM_REB and not demo_mode and footage >= 5.0 and media_alive() > 0 and time - _upload_hint_t > 35.0:
		_upload_hint_t = time
		message_posted.emit("Videomaterial bereit – Upload mit F1 (+%.0f%% Empörung)" % (footage * 1.35), "good", U.TEAM_REB)
	# Natuerlicher Abbau der Empoerung
	if time - _last_event_t > 30.0 and outrage > 0.0:
		add_outrage(-0.03 * dt, true)
	# Nachrichtenticker
	_news_t -= dt
	if _news_t <= 0.0:
		_news_t = _rng.randf_range(24.0, 40.0)
		var arr: Array = Data.HEADLINES_QUIET
		news_posted.emit(arr[_rng.randi() % arr.size()], "info")
	_end_check_t -= dt
	if _end_check_t <= 0.0:
		_end_check_t = 0.5
		_check_end()

func media_alive() -> int:
	if world == null:
		return 0
	var n := 0
	for u in world.units:
		if u.alive and u.press and u.team == U.TEAM_REB:
			n += 1
	return n

# ============================================================================= Empoerung
func add_outrage(v: float, silent: bool = false, cause: String = "other", attribute: bool = true) -> void:
	var old := outrage
	if v > 0.0 and briefing_t > 0.0:
		v *= 0.7
	if v > 0.0 and attribute and cause != "":
		attrib[cause] = float(attrib.get(cause, 0.0)) + v
	outrage = clampf(outrage + v, 0.0, 100.0)
	peak_outrage = maxf(peak_outrage, outrage)
	if not silent and v > 0.0:
		_last_event_t = time
	outrage_changed.emit(outrage)
	var nl := 0
	if outrage >= Data.OUTRAGE_L1:
		nl = 1
	if outrage >= Data.OUTRAGE_L2:
		nl = 2
	if outrage >= Data.OUTRAGE_L3 - 0.01:
		nl = 3
	if nl > level:
		level = nl
		level_changed.emit(level)
		match nl:
			1:
				news_posted.emit(Data.HEADLINES_L1[0], "bad")
				message_posted.emit("STUFE 1: Sanktionen – das Budget wird gekürzt", "bad", -1)
			2:
				news_posted.emit(Data.HEADLINES_L2[0], "bad")
				message_posted.emit("STUFE 2: Flugverbotszone – Luftunterstützung abgezogen", "bad", -1)
				if world != null:
					world.enforce_no_fly_zone()
			3:
				news_posted.emit(Data.HEADLINES_L3[0], "bad")
	elif nl < level and nl < level:
		# Rueckgang unter Schwelle (nur 0 -> 1 -> 2 moeglich, 3 ist final)
		if level < 3:
			level = nl
			level_changed.emit(level)
			message_posted.emit("Die Lage entspannt sich: Stufe %d" % level, "good", -1)

# ----------------------------------------------------------------------------- Videomaterial & Ursachen
const CAUSE_LABELS := {
	"strike": "Luft- & Artillerieschläge", "collapse": "Eingestürzte Wohnhäuser", "direct": "Beschuss von Zivilisten",
	"ambiguous": "Unklare Vorfälle (Getarnte erschossen)", "press": "Getötete Journalisten", "sensitive": "Klinik / Schule getroffen",
	"check": "Schikane bei Kontrollen", "shield": "Schutzschilde getroffen", "staged": "Inszenierte Bilder (Klinik / Schule)", "other": "Sonstiges",
}

func add_footage(amount: float, cause: String) -> void:
	footage += amount
	footage_src[cause] = float(footage_src.get(cause, 0.0)) + amount

## Entnimmt Videomaterial anteilig nach Ursache; liefert {Ursache: Anteil}
func take_footage(amount: float) -> Dictionary:
	var out := {}
	var total := maxf(footage, 0.0001)
	var frac := clampf(amount / total, 0.0, 1.0)
	for c in footage_src.keys():
		var part: float = footage_src[c] * frac
		out[c] = part
		footage_src[c] = footage_src[c] - part
	footage = maxf(footage - amount, 0.0)
	return out

func _attribute_gain(gain: float, portions: Dictionary, amount: float) -> void:
	if amount <= 0.0001 or gain <= 0.0:
		return
	for c in portions.keys():
		attrib[c] = float(attrib.get(c, 0.0)) + gain * float(portions[c]) / amount

func log_event(kind: String, text: String, pos: Vector3 = Vector3.ZERO, weight: float = 0.0) -> void:
	if timeline.size() > 500:
		timeline.pop_front()
	timeline.append({"t": time, "kind": kind, "text": text, "pos": pos, "o": outrage, "w": weight})

func report_civilian_deaths(pos: Vector3, n: float, by_team: int, cause: String, direct: bool = false) -> void:
	if n <= 0.0:
		return
	_civ_events.append({"pos": pos, "n": n, "cause": cause, "by": by_team, "direct": direct})
	stats.civ_killed += int(ceil(n))
	if by_team == U.TEAM_ADF:
		stats.civ_by_adf += int(ceil(n))
		if world != null:
			world.add_anger(pos, n * (4.5 if direct else 3.2))
	elif by_team == U.TEAM_REB:
		stats.civ_by_reb += int(ceil(n))
		if world != null:
			world.add_anger(pos, -n * 2.0)

func report_event_outrage(pos: Vector3, amount: float, headline: String = "", cause: String = "other") -> void:
	## Direkte Empoerung (z.B. Klinik getroffen, Journalisten getoetet)
	var vis := footage_visibility(pos)
	var gain := amount * (0.6 + 0.6 * vis)
	add_footage(gain * 0.5, cause)
	add_outrage(gain * 0.5, false, cause)
	if headline != "":
		news_posted.emit(headline, "bad")
	alert.emit(pos, "outrage")
	log_event(cause, headline if headline != "" else "Empörung durch Zwischenfall", pos)
	if world != null:
		world.add_anger(pos, amount * 1.2)

func footage_visibility(pos: Vector3) -> float:
	## Wie gut ist das Ereignis dokumentiert? Medien-Teams in der Naehe verdoppeln die Wirkung.
	var vis := 0.4   # Handy-Kameras der Anwohner
	if world == null:
		return vis
	for u in world.units:
		if u.alive and u.press and u.team == U.TEAM_REB and U.dist2d(u.position, pos) < u.film_range:
			vis = 1.0
			break
	# Zeugen in der Naehe (ueberlebende Zivilisten)
	var witnesses := 0
	for o in world.dyn.query(pos, 22.0):
		if o is Civilian and o.alive and U.dist2d(o.position, pos) < 22.0:
			witnesses += 1
	vis += minf(witnesses * 0.03, 0.25)
	return vis

func _flush_civ_events() -> void:
	if _civ_events.is_empty():
		return
	# Cluster nach Ort/Ursache zusammenfassen
	var groups: Array = []
	for e in _civ_events:
		var merged := false
		for g in groups:
			if U.dist2d(g.pos, e.pos) < 28.0 and g.by == e.by:
				g.n += e.n
				g.direct = g.direct or e.direct
				if e.cause == "collapse":
					g.cause = "collapse"
				elif e.cause == "shield" and g.cause != "collapse":
					g.cause = "shield"
				merged = true
				break
		if not merged:
			groups.append(e.duplicate())
	_civ_events.clear()
	for g in groups:
		if g.by == U.TEAM_ADF:
			var sev := 1.0
			if g.direct:
				sev = 1.5
			if g.cause == "ambiguous":
				sev = 0.45
			elif g.cause == "shield":
				sev = 1.6
			var vis := footage_visibility(g.pos)
			var raw: float = g.n * 1.0 * sev
			var gain := raw * (0.45 + vis * 0.9)
			var cause_key: String = "strike"
			if g.cause == "collapse":
				cause_key = "collapse"
			elif g.cause == "direct":
				cause_key = "direct"
			elif g.cause == "ambiguous":
				cause_key = "ambiguous"
			elif g.cause == "shield":
				cause_key = "shield"
			# Rebellen-Seite: Material wird hochgeladen (Medien-Team) oder sickert durch
			if media_alive() > 0 or demo_mode:
				add_footage(gain, cause_key)
				if _is_ai_rebel():
					_ai_upload()
			else:
				add_outrage(gain * 0.55, false, cause_key)
				add_footage(gain * 0.35, cause_key)
			log_event("casualties", "%d Zivilisten getötet (%s)" % [int(round(g.n)), CAUSE_LABELS.get(cause_key, "")], g.pos, g.n)
			alert.emit(g.pos, "casualties")
			var n := int(round(g.n))
			var pool: Array = Data.HEADLINES_CIV_DIRECT if g.direct else Data.HEADLINES_CIV_STRIKE
			var line: String = pool[_rng.randi() % pool.size()]
			if line.contains("%d"):
				line = line % maxi(n, 1)
			if g.cause == "shield":
				line = Data.HEADLINES_SHIELD[_rng.randi() % Data.HEADLINES_SHIELD.size()]
			if g.cause == "ambiguous":
				line = "Unklarer Vorfall: Mann auf Straße erschossen – war er bewaffnet?"
			news_posted.emit("%s: %s" % [Data.OUTLETS[_rng.randi() % Data.OUTLETS.size()], line], "bad")
			_last_event_t = time
		elif g.by == U.TEAM_REB:
			evidence += g.n * 0.8
			add_outrage(-g.n * 0.25, true, "")
			log_event("evidence", "%d Zivilisten durch Raketen der Hadar-Front getötet" % int(round(g.n)), g.pos)
			news_posted.emit("Zivilisten durch Raketen der Hadar-Front getötet – Aurelia sammelt Beweise", "info")

func _is_ai_rebel() -> bool:
	return player_team != U.TEAM_REB

func _ai_upload() -> void:
	# KI-Rebellen laden mit Verzoegerung hoch
	if footage > 5.0:
		upload_footage(true)

func upload_footage(auto: bool = false) -> bool:
	if footage < 0.5:
		return false
	if media_alive() <= 0 and not demo_mode:
		return false
	var gain := footage * 1.35
	var raw_amt := footage
	var portions := take_footage(footage)
	stats.uploads += 1
	_attribute_gain(gain, portions, raw_amt)
	add_outrage(gain, false, "", false)
	log_event("upload", "Videomaterial veröffentlicht (+%.0f%% Empörung)" % gain, Vector3.ZERO, gain)
	if not auto or true:
		message_posted.emit("Videomaterial veröffentlicht: Empörung +%.0f%%" % gain, "good" if player_team == U.TEAM_REB else "bad", -1)
	return true

# ============================================================================= Ereignisse
func unit_died(u: Unit, attacker: Entity, dtype: String) -> void:
	if u.is_civ:
		var by := attacker.team if attacker != null else U.TEAM_ADF
		var direct := dtype in ["bullet", "ap"] and attacker != null and not attacker.is_structure()
		if dtype == "he" or dtype == "missile":
			direct = false
		var ckey := "direct" if direct else "strike"
		if u.shield_t > 0.0 and by == U.TEAM_ADF:
			ckey = "shield"
		report_civilian_deaths(u.position, 1.0, by, ckey, direct)
		return
	if u.kind == "adf_aid":
		if attacker != null and attacker.team == U.TEAM_REB:
			evidence += 2.0
			add_outrage(-2.5, true, "")
			news_posted.emit(Data.HEADLINES_AID_ATTACKED[0], "good" if player_team == U.TEAM_ADF else "bad")
			log_event("aid_attacked", "Hilfskonvoi von der Hadar-Front beschossen", u.position)
			if world != null:
				world.add_anger(u.position, -8.0)
		return
	if u.press:
		# Getoetete Journalisten: grosse Empoerung, wenn ADF verantwortlich
		if attacker != null and attacker.team == U.TEAM_ADF:
			report_event_outrage(u.position, 9.0, Data.HEADLINES_PRESS_KILLED[0], "press")
	if u.team == U.TEAM_ADF:
		stats.adf_lost += 1
	elif u.team == U.TEAM_REB:
		stats.reb_lost += 1
		# Getarnter Kaempfer von ADF erschossen: Vorfall wirkt auf Kameras wie Toetung Unbewaffneter
		if u.concealed and u.exposed_t <= 0.0 and attacker != null and attacker.team == U.TEAM_ADF:
			report_civilian_deaths(u.position, 1.0, U.TEAM_ADF, "ambiguous", true)

func launch_detected(pos: Vector3, u: Unit) -> void:
	if u.team != U.TEAM_REB:
		return
	if _launch_alert_t > time:
		return
	_launch_alert_t = time + 3.0
	stats.launches += 1
	log_event("launch", "Raketenabschuss der Hadar-Front", pos)
	# Gegenbatterie-Radar ortet die Abschussposition
	if world != null and world.adf_has_radar():
		u.exposed_t = maxf(u.exposed_t, 14.0)
		u.reveal(14.0)
		u.ident_mask |= 1
		alert.emit(pos, "launch")
		message_posted.emit("Raketenabschuss geortet!", "warn", U.TEAM_ADF)
		evidence += 1.0
		if _rng.randf() < 0.6:
			news_posted.emit(Data.HEADLINES_REBEL_ATTACK[_rng.randi() % Data.HEADLINES_REBEL_ATTACK.size()], "info")
	else:
		alert.emit(pos, "launch")
	if world != null:
		world.on_launch(pos, u)

func base_under_attack(s: Structure) -> void:
	if _launch_alert_t > time:
		return
	alert.emit(s.position, "base")

func hub_destroyed(s: Structure) -> void:
	stats.hubs_destroyed += 1
	news_posted.emit(Data.HEADLINES_HUB[0], "good")
	log_event("hub", "Tunnelknoten zerstört (%d von %d)" % [stats.hubs_destroyed, World.HUB_COUNT], s.position)

func structure_destroyed(s: Structure, attacker: Entity) -> void:
	stats.buildings_destroyed += 1
	if s.kind_class in ["hospital", "school"] and attacker != null and attacker.team == U.TEAM_ADF:
		var h: Array = Data.HEADLINES_SENSITIVE
		if s.staged_t > 0.0:
			var hs: Array = Data.HEADLINES_STAGED
			report_event_outrage(s.position, 14.0 * 2.5, hs[_rng.randi() % hs.size()], "staged")
			stats.staged_hits = int(stats.get("staged_hits", 0)) + 1
		else:
			report_event_outrage(s.position, 14.0, h[0] if s.kind_class == "hospital" else h[1], "sensitive")
	elif s.team == U.TEAM_CIV and attacker != null and attacker.team == U.TEAM_ADF and world != null:
		world.add_anger(s.position, 4.0)
	if s.kind == "adf_fieldhosp" and attacker != null and attacker.team == U.TEAM_REB:
		evidence += 3.0
		add_outrage(-3.0, true, "")
		news_posted.emit(Data.HEADLINES_AID_ATTACKED[1], "good" if player_team == U.TEAM_ADF else "bad")
		log_event("aid_attacked", "Feldlazarett von der Hadar-Front zerstört", s.position)

# ============================================================================= Faehigkeiten
func ability_ready(team: int, id: String) -> bool:
	var d: Dictionary = Data.ABILITIES[id]
	var cd: float = cooldowns[team].get(id, 0.0)
	if cd > 0.0:
		return false
	if budget[team] < d.cost:
		return false
	if d.get("needs_air", false) and no_fly_zone():
		return false
	if id == "evidence" and evidence < 1.0:
		return false
	if team == U.TEAM_ADF and jam_t > 0.0 and id in ["precision", "scan"]:
		return false
	if id == "upload" and (footage < 0.5 or media_alive() <= 0):
		return false
	if id == "donate" and outrage < 12.0:
		return false
	if id == "fieldhosp" and world != null:
		var n := 0
		for st in world.structures:
			if st.alive and st.kind == "adf_fieldhosp":
				n += 1
		if n >= 2:
			return false
	return true

func use_ability(team: int, id: String, pos: Vector3 = Vector3.ZERO) -> bool:
	if not ability_ready(team, id):
		return false
	var d: Dictionary = Data.ABILITIES[id]
	budget[team] -= d.cost
	cooldowns[team][id] = d.cd
	ability_used.emit(id, team)
	if id in ["airstrike", "precision", "salvo"]:
		stats.strikes += 1
		log_event("strike", "%s angefordert" % d.name, pos)
	match id:
		"airstrike", "precision", "salvo", "warning", "scan", "convoy", "fieldhosp", "corridor", "shield", "staged", "smoke":
			if world != null:
				world.support.execute(id, team, pos)
		"jam":
			jam_t = 25.0
			stats.jams = int(stats.get("jams", 0)) + 1
			message_posted.emit("Störsender aktiv: Drohnen, Präzisionsschläge und Radar fallen 25 s aus", "bad" if team != player_team else "good", -1)
			log_event("jam", "Störsender eingeschaltet")
			if world != null:
				for u in world.units:
					if u.alive and u.team == U.TEAM_ADF and u.layer == "air":
						world.fx.ring_ping(u.position, 6.0, Color(1.0, 0.3, 0.3, 0.8), 1.5)
		"briefing":
			briefing_t = 60.0
			add_outrage(-2.5, true, "")
			news_posted.emit("Aurelia-Sprecher: 'Wir tun alles, um Zivilisten zu schützen.'", "info")
			message_posted.emit("Presse-Briefing: Empörung −2,5 %, neue Bilder wirken 60 s lang abgeschwächt", "good", team)
			log_event("briefing", "Presse-Briefing abgehalten")
		"evidence":
			var gain := evidence * 3.2
			evidence = 0.0
			stats.evidence_published += 1
			add_outrage(-gain, true, "")
			log_event("evidence", "Beweise veröffentlicht (−%.0f%% Empörung)" % gain, Vector3.ZERO, gain)
			news_posted.emit(Data.HEADLINES_EVIDENCE[_rng.randi() % Data.HEADLINES_EVIDENCE.size()], "good")
			message_posted.emit("Beweise veröffentlicht: Empörung −%.0f%%" % gain, "good", team)
		"upload":
			upload_footage(false)
		"donate":
			var amt := 150.0 + outrage * 9.0
			budget[team] += amt
			message_posted.emit("Spendenaufruf: +%s" % U.fmt_money(amt), "good", team)
	return true

# ============================================================================= Sieg / Niederlage
func _check_end() -> void:
	if ended or world == null or demo_mode:
		return
	if level >= 3 or outrage >= 99.9:
		_end(U.TEAM_REB, "outrage")
		return
	var hq_alive := false
	for s in world.structures:
		if s.alive and s.kind == "adf_hq":
			hq_alive = true
	if not hq_alive:
		_end(U.TEAM_REB, "hq")
		return
	if alive_hubs() == 0 and time > 5.0:
		_end(U.TEAM_ADF, "hubs")
		return

func _end(winner: int, reason: String) -> void:
	ended = true
	running = false
	var res := {
		"winner": winner, "reason": reason, "time": time, "player_won": winner == player_team,
		"stats": stats.duplicate(), "peak": peak_outrage, "outrage": outrage,
	}
	match_ended.emit(res)

func message(text: String, kind: String = "info", team: int = -1) -> void:
	message_posted.emit(text, kind, team)

func news(text: String, kind: String = "info") -> void:
	news_posted.emit(text, kind)
