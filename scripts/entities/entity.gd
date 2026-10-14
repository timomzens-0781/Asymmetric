class_name Entity
extends Node3D
## Basisklasse fuer alles Anklick- und Beschiessbare (Einheiten, Gebaeude, Zivilisten).

var id := 0
var team := 2
var kind := ""
var def: Dictionary = {}
var max_hp := 100.0
var hp := 100.0
var alive := true
var radius := 1.0
var armor := "inf"
var vision := 20.0
var selected := false
var model: Node3D = null
var parts: Dictionary = {}
var world: World = null
var seen_mask := 0       # Bit je Team: physisch gesehen
var ident_mask := 0      # Bit je Team: als Feind identifiziert
var hit_flash := 0.0
var last_attacker: Entity = null
var _qstamp := 0
var sel_node: Node3D = null

func is_structure() -> bool:
	return false

func is_unit() -> bool:
	return false

func seen_by(t: int) -> bool:
	return t == team or ((seen_mask >> t) & 1) == 1

func identified_by(t: int) -> bool:
	return t == team or ((ident_mask >> t) & 1) == 1

func take_damage(amount: float, attacker: Entity, dtype: String, from_pos: Vector3 = Vector3.ZERO) -> void:
	if not alive:
		return
	var mult: float = Data.DMG_MULT.get(dtype, Data.DMG_MULT["bullet"]).get(armor, 1.0)
	var dmg := amount * mult
	if dmg <= 0.0:
		return
	hp -= dmg
	hit_flash = 0.12
	Game.entity_hit(self)
	if attacker != null:
		last_attacker = attacker
	_on_damaged(dmg, attacker, dtype)
	if hp <= 0.0:
		hp = 0.0
		die(attacker, dtype)

func _on_damaged(_dmg: float, _attacker: Entity, _dtype: String) -> void:
	pass

func die(_attacker: Entity, _dtype: String) -> void:
	alive = false

## Abstand zur Aussenkante (fuer Reichweitenpruefung)
func edge_dist(p: Vector3) -> float:
	return maxf(0.0, U.dist2d(position, p) - radius)

func set_selected(v: bool) -> void:
	selected = v
	if sel_node != null:
		sel_node.visible = v
	elif v:
		_make_selection_visual()
		sel_node.visible = true

func _make_selection_visual() -> void:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	var s := maxf(radius * 2.6, 2.4)
	q.size = Vector2(s, s)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = Gfx.ring_tex(128, 0.1)
	m.albedo_color = Color(0.45, 1.0, 0.5)
	m.no_depth_test = true
	m.render_priority = 5
	mi.material_override = m
	mi.position = Vector3(0, 0.12, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	sel_node = mi
