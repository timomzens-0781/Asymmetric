class_name Civilian
extends Unit
## Zivilist: wandert, fluechtet bei Gefechten, verschwindet in Haeusern.

var variant := 0

func setup_civ(w: World, v: int) -> void:
	world = w
	variant = v
	kind = "civilian"
	team = U.TEAM_CIV
	is_civ = true
	max_hp = 45.0
	hp = max_hp
	spd = 3.6
	turn = 8.0
	layer = "foot"
	grid = "foot"
	radius = 0.7
	armor = "civ"
	vision = 10.0
	pop = 0
	name = "Civ_%d" % id
	model = Models.build_unit("civilian", U.TEAM_CIV, v)
	add_child(model)
	parts = model.get_meta("parts", {})
	spd *= randf_range(0.85, 1.2)
	_civ_wait = randf_range(0.0, 4.0)
	heading = randf() * TAU

func set_selected(v: bool) -> void:
	# Zivilisten sind nur zur Info anklickbar
	selected = v
	if sel_node != null:
		sel_node.visible = v
	elif v:
		_make_selection_visual()
		sel_node.visible = true
