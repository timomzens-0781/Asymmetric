extends RefCounted
## Test-Szenario: beobachtet ein KI-Spiel, Kamera folgt dem Geschehen, Screenshots zu festen Zeiten.

static func run(m: Node) -> void:
	var w: World = m.world
	var rig: RtsCamera = m.rig
	var shots := [70.0, 130.0, 190.0, 250.0, 310.0, 370.0]
	var si := 0
	var focus := Vector3(-30, 0, 20)
	while si < shots.size():
		await m.get_tree().create_timer(1.5).timeout
		# Brennpunkt: Schwerpunkt der ADF-Bodentruppen, die schon weit vorgerueckt sind
		var c := Vector3.ZERO
		var n := 0
		for u in w.units:
			if u.alive and u.team == 0 and not u.is_civ and u.layer != "air" and u.position.x > -45.0:
				c += u.position
				n += 1
		if n > 0:
			focus = c / n
		rig.focus_on(focus)
		rig.target_dist = 44.0
		if Game.time >= shots[si]:
			m._take_shot_now("w%d" % si)
			si += 1
	m.get_tree().quit()
