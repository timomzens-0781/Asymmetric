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

func start(side: int, diff: int, demo: bool) -> void:
	player_team = side
	difficulty = diff
	demo_mode = demo
	running = true
	ended = false
	time = 0.0
	budget = [4500.0, 2200.0]
	if difficulty == 0:
		budget[side] += 800.0
	outrage = 0.0
	footage = 0.0
	evidence = 0.0
	level = 0
	peak_outrage = 0.0
	cooldowns = [{}, {}]
	_civ_events.clear()
	_civ_flush_t = 0.0
	_income_t = 0.0
	_news_t = 25.0
	_last_event_t = -99.0
	_rng.randomize()
	stats = {
		"civ_killed": 0, "civ_by_adf": 0, "civ_by_reb": 0, "adf_lost": 0, "reb_lost": 0,
		"hubs_destroyed": 0, "hubs_total": 0, "buildings_destroyed": 0, "uploads": 0, "launches": 0,
		"evidence_published": 0, "shots_warned": 0,
	}
	outrage_changed.emit(outrage)
	level_changed.emit(level)

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
	return 3.2 * hubs * (1.0 + outrage / 80.0) * mult

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
func add_outrage(v: float, silent: bool = false) -> void:
	var old := outrage
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

func report_civilian_deaths(pos: Vector3, n: float, by_team: int, cause: String, direct: bool = false) -> void:
	if n <= 0.0:
		return
	_civ_events.append({"pos": pos, "n": n, "cause": cause, "by": by_team, "direct": direct})
	stats.civ_killed += int(ceil(n))
	if by_team == U.TEAM_ADF:
		stats.civ_by_adf += int(ceil(n))
	elif by_team == U.TEAM_REB:
		stats.civ_by_reb += int(ceil(n))

func report_event_outrage(pos: Vector3, amount: float, headline: String = "") -> void:
	## Direkte Empoerung (z.B. Klinik getroffen, Journalisten getoetet)
	var vis := footage_visibility(pos)
	var gain := amount * (0.6 + 0.6 * vis)
	footage += gain * 0.5
	add_outrage(gain * 0.5)
	if headline != "":
		news_posted.emit(headline, "bad")
	alert.emit(pos, "outrage")

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
			var vis := footage_visibility(g.pos)
			var raw: float = g.n * 1.0 * sev
			var cam: float = 1.0 if vis >= 0.99 else 0.55
			var gain := raw * (0.45 + vis * 0.9)
			# Rebellen-Seite: Material wird hochgeladen (Medien-Team) oder sickert durch
			if media_alive() > 0 or demo_mode:
				footage += gain
				if _is_ai_rebel():
					_ai_upload()
			else:
				add_outrage(gain * 0.55)
				footage += gain * 0.35
			alert.emit(g.pos, "casualties")
			var n := int(round(g.n))
			var pool: Array = Data.HEADLINES_CIV_DIRECT if g.direct else Data.HEADLINES_CIV_STRIKE
			var line: String = pool[_rng.randi() % pool.size()]
			if line.contains("%d"):
				line = line % maxi(n, 1)
			if g.cause == "ambiguous":
				line = "Unklarer Vorfall: Mann auf Straße erschossen – war er bewaffnet?"
			news_posted.emit("%s: %s" % [Data.OUTLETS[_rng.randi() % Data.OUTLETS.size()], line], "bad")
			_last_event_t = time
		elif g.by == U.TEAM_REB:
			evidence += g.n * 0.8
			add_outrage(-g.n * 0.25, true)
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
	footage = 0.0
	stats.uploads += 1
	add_outrage(gain)
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
		report_civilian_deaths(u.position, 1.0, by, "direct" if direct else "strike", direct)
		return
	if u.press:
		# Getoetete Journalisten: grosse Empoerung, wenn ADF verantwortlich
		if attacker != null and attacker.team == U.TEAM_ADF:
			report_event_outrage(u.position, 9.0, Data.HEADLINES_PRESS_KILLED[0])
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

func structure_destroyed(s: Structure, attacker: Entity) -> void:
	stats.buildings_destroyed += 1
	if s.kind_class in ["hospital", "school"] and attacker != null and attacker.team == U.TEAM_ADF:
		var h: Array = Data.HEADLINES_SENSITIVE
		report_event_outrage(s.position, 14.0, h[0] if s.kind_class == "hospital" else h[1])

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
	if id == "upload" and (footage < 0.5 or media_alive() <= 0):
		return false
	if id == "donate" and outrage < 12.0:
		return false
	return true

func use_ability(team: int, id: String, pos: Vector3 = Vector3.ZERO) -> bool:
	if not ability_ready(team, id):
		return false
	var d: Dictionary = Data.ABILITIES[id]
	budget[team] -= d.cost
	cooldowns[team][id] = d.cd
	ability_used.emit(id, team)
	match id:
		"airstrike", "precision", "salvo", "warning", "scan":
			if world != null:
				world.support.execute(id, team, pos)
		"evidence":
			var gain := evidence * 3.2
			evidence = 0.0
			stats.evidence_published += 1
			add_outrage(-gain, true)
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
