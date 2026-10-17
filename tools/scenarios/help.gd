extends RefCounted
## Zeigt das Hilfemenue. Aufruf: autostart=0 scenario=help

static func run(m: Node) -> void:
	await m.get_tree().create_timer(0.8).timeout
	m.screens.show_help(2, "pause")
	await m.get_tree().create_timer(1.0).timeout
	m._take_shot_now("h2")
	await m.get_tree().create_timer(1.5).timeout
	m.get_tree().quit()
