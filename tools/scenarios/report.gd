extends RefCounted
## Zeigt den Endbildschirm mit Auswertung (Daten werden erfunden). Aufruf: scenario=report

static func run(m: Node) -> void:
	await m.get_tree().create_timer(0.5).timeout
	var o := 0.0
	var t := 0.0
	Game.outrage_samples = PackedFloat32Array()
	Game.anger_samples = PackedFloat32Array()
	Game.timeline.clear()
	Game.attrib = {"strike": 21.0, "collapse": 14.0, "direct": 6.0, "ambiguous": 4.0, "press": 9.0, "sensitive": 12.0, "check": 1.0}
	var script := [
		[40.0, "casualties", "6 Zivilisten getötet (Luft- & Artillerieschläge)", 6.0, 8.0],
		[95.0, "upload", "Videomaterial veröffentlicht (+11% Empörung)", 11.0, 11.0],
		[130.0, "evidence", "Beweise veröffentlicht (−9% Empörung)", 9.0, -9.0],
		[185.0, "hub", "Tunnelknoten zerstört (1 von 7)", 0.0, 0.0],
		[240.0, "casualties", "14 Zivilisten getötet (Eingestürzte Wohnhäuser)", 14.0, 20.0],
		[262.0, "level", "Stufe 1: Sanktionen", 0.0, 0.0],
		[300.0, "sensitive", "Klinik getroffen! Ärzte ohne Strom und Medikamente", 14.0, 14.0],
		[352.0, "upload", "Videomaterial veröffentlicht (+17% Empörung)", 17.0, 17.0],
		[372.0, "level", "Stufe 2: Flugverbotszone", 0.0, 0.0],
		[430.0, "aid", "Hilfskonvoi entsandt", 0.0, -3.0],
		[470.0, "recruit", "Freiwillige schließen sich in Planquadrat F3 der Front an", 0.0, 0.0],
		[520.0, "hub", "Tunnelknoten zerstört (2 von 7)", 0.0, 0.0],
	]
	var si := 0
	var tt := 0.0
	while tt < 560.0:
		while si < script.size() and script[si][0] <= tt:
			o = clampf(o + script[si][4], 0.0, 100.0)
			Game.time = script[si][0]
			Game.outrage = o
			Game.log_event(script[si][1], script[si][2], Vector3.ZERO, script[si][3])
			si += 1
		o = maxf(0.0, o - 0.02)
		Game.outrage_samples.append(o)
		Game.anger_samples.append(20.0 + 60.0 * sin(tt / 140.0) * sin(tt / 140.0) + tt * 0.05)
		tt += 2.0
	Game.time = 560.0
	var res := {"winner": 0, "reason": "hubs", "time": 560.0, "player_won": true, "peak": 74.0, "outrage": o,
		"stats": {"civ_killed": 31, "civ_by_adf": 28, "civ_by_reb": 3, "adf_lost": 14, "reb_lost": 63, "hubs_destroyed": 7, "hubs_total": 7,
			"buildings_destroyed": 19, "uploads": 4, "launches": 9, "evidence_published": 2, "shots_warned": 3, "tunnel_trips": 12, "recruits": 8, "aid_delivered": 3, "strikes": 6}}
	m.screens.show_end(res, 0)
	await m.get_tree().create_timer(1.0).timeout
	await m._take_shot_now("report")
	m.get_tree().quit()
