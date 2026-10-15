class_name Projectile
extends Node3D
## Geschosse: Panzergranate, Rakete/Lenkwaffe (zielsuchend) und ballistische Artillerie/Raketen.

var world: World
var shooter: Entity
var team := 0
var w: Dictionary = {}
var target: Entity = null
var dest := Vector3.ZERO
var start := Vector3.ZERO
var mode := "direct"      # direct | ballistic | bomb
var speed := 60.0
var t := 0.0
var total := 1.0
var arc_h := 0.0
var _trail: GPUParticles3D = null
var _done := false
var _prev := Vector3.ZERO

func launch(wd: Dictionary, shooter_e: Entity, from: Vector3, tgt: Entity, tgt_pos: Vector3, wld: World) -> void:
	world = wld
	shooter = shooter_e
	team = shooter_e.team if shooter_e != null else U.TEAM_ADF
	w = wd
	start = from
	position = from
	_prev = from
	speed = wd.get("speed", 60.0)
	var proj: String = wd.get("proj", "shell")
	target = tgt
	if proj == "arty":
		mode = "ballistic"
		var sp: float = wd.get("spread", 0.0)
		dest = tgt_pos + U.rand_in_circle(world.rng, sp)
		dest.y = 0.0
		var dist := from.distance_to(dest)
		total = maxf(dist / speed, 0.5)
		arc_h = clampf(dist * 0.42, 6.0, 60.0)
	elif proj == "bomb":
		mode = "bomb"
		dest = tgt_pos
		total = maxf((from.y) / 28.0, 0.3)
	else:
		mode = "direct"
		dest = tgt_pos
	_build_visual(proj)

func _build_visual(proj: String) -> void:
	var mb := MeshBuilder.new()
	match proj:
		"shell":
			mb.cyl(Vector3.ZERO, 0.12, 0.12, 0.9, Color(1.0, 0.85, 0.4), 6, 2)
			var m := Gfx.unshaded_mat(Color(1.0, 0.8, 0.3), true)
			var mi := MeshInstance3D.new()
			mi.mesh = mb.build(m)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			mi.material_override = m
		"rocket", "missile":
			mb.cyl(Vector3.ZERO, 0.11, 0.11, 1.5, Color(0.7, 0.7, 0.68), 6, 2)
			mb.cyl(Vector3(0, 0, 0.85), 0.11, 0.0, 0.3, Color(0.6, 0.2, 0.1), 6, 2)
			mb.box(Vector3(0, 0, -0.6), Vector3(0.5, 0.05, 0.3), Color(0.3, 0.3, 0.3))
			mb.box(Vector3(0, 0, -0.6), Vector3(0.05, 0.5, 0.3), Color(0.3, 0.3, 0.3))
			var mi2 := MeshInstance3D.new()
			mi2.mesh = mb.build(Gfx.vcol_mat(0.5, 0.3))
			add_child(mi2)
			_trail = world.fx.rocket_trail(self, 1.1)
		"arty":
			mb.cyl(Vector3.ZERO, 0.2, 0.2, 1.1, Color(0.2, 0.2, 0.2), 6, 2)
			mb.cyl(Vector3(0, 0, 0.65), 0.2, 0.0, 0.3, Color(0.35, 0.3, 0.15), 6, 2)
			var mi3 := MeshInstance3D.new()
			mi3.mesh = mb.build(Gfx.vcol_mat(0.5, 0.3))
			add_child(mi3)
			if w.get("burst", 1) > 1:
				_trail = world.fx.rocket_trail(self, 1.0)
		"bomb":
			mb.cyl(Vector3.ZERO, 0.35, 0.35, 1.7, Color(0.25, 0.27, 0.22), 8, 0)
			mb.cyl(Vector3(0, 0.95, 0), 0.35, 0.0, 0.4, Color(0.25, 0.27, 0.22), 8, 0)
			mb.box(Vector3(0, -0.9, 0), Vector3(0.9, 0.06, 0.06), Color(0.2, 0.2, 0.2))
			mb.box(Vector3(0, -0.9, 0), Vector3(0.06, 0.06, 0.9), Color(0.2, 0.2, 0.2))
			var mi4 := MeshInstance3D.new()
			mi4.mesh = mb.build(Gfx.vcol_mat(0.5, 0.4))
			add_child(mi4)

func _process(dt: float) -> void:
	if _done or world == null or world.paused:
		return
	dt = minf(dt, 0.1)
	match mode:
		"direct":
			var tp := dest
			if target != null and target.alive:
				tp = target.position
				if target is Unit:
					tp.y = (target as Unit).air_h + 1.0 if (target as Unit).layer == "air" else 1.0
				elif target is Structure:
					tp.y = minf((target as Structure).size.y * 0.5, 3.0)
				else:
					tp.y = 1.0
			else:
				tp.y = maxf(tp.y, 0.8)
			var to := tp - position
			var d := to.length()
			var step := speed * dt
			if d <= step + 0.4:
				position = tp
				_impact()
				return
			_face(position, to)   # Spitze liegt auf +Z
			position += to.normalized() * step
		"ballistic":
			t += dt
			var k := clampf(t / total, 0.0, 1.0)
			var flat := start.lerp(dest, k)
			var y := lerpf(start.y, 0.0, k) + sin(k * PI) * arc_h
			var np := Vector3(flat.x, y, flat.z)
			if np.distance_to(position) > 0.01:
				_face(np, np - position)
			position = np
			if k >= 1.0:
				_impact()
		"bomb":
			t += dt
			var fall := 28.0 * t
			position.y = maxf(start.y - 0.5 * 0.0 - fall, 0.0)
			rotation.x = 0.0
			if position.y <= 0.6:
				position.y = 0.0
				_impact()

func _impact() -> void:
	if _done:
		return
	_done = true
	var splash: float = w.get("splash", 2.0)
	var dtype: String = w.get("type", "he")
	var shooter_ok: Entity = shooter if (shooter != null and is_instance_valid(shooter)) else null   # Schuetze kann inzwischen gefallen und freigegeben sein
	world.explode(position, splash, w.get("damage", 50.0), dtype, team, shooter_ok, {"proj": w.get("proj", "")})
	if _trail != null and is_instance_valid(_trail):
		_trail.emitting = false
		# Spur bleibt kurz stehen, dann freigeben
		_trail.reparent(world.fx)
		get_tree().create_timer(1.2).timeout.connect(_trail.queue_free)
	queue_free()

## Richtet das Geschoss entlang der Flugrichtung aus (Spitze = +Z); robust gegen senkrechte Flugbahnen.
func _face(from: Vector3, dir: Vector3) -> void:
	if dir.length() < 0.001:
		return
	var up := Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.RIGHT
	look_at_from_position(from, from - dir, up)
