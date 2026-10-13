class_name Fx
extends Node3D
## Effekte: Explosionen, Rauch, Feuer, Muendungsfeuer, Leuchtspur, Schockwellen, Truemmerstaub.

var world: World
var _cache: Dictionary = {}
var _lights_active := 0
var _active_particles := 0
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

# ----------------------------------------------------------------------------- Ressourcen
func _grad_tex(key: String, stops: Array) -> GradientTexture1D:
	if _cache.has(key):
		return _cache[key]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s in stops:
		offs.append(s[0])
		cols.append(s[1])
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	_cache[key] = t
	return t

func _curve_tex(key: String, pts: Array) -> CurveTexture:
	if _cache.has(key):
		return _cache[key]
	var c := Curve.new()
	for p in pts:
		c.add_point(Vector2(p[0], p[1]))
	var t := CurveTexture.new()
	t.curve = c
	_cache[key] = t
	return t

func _billboard_mat(key: String, tex: Texture2D, additive: bool) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	_cache[key] = m
	return m

func _quad(key: String, mat: Material) -> QuadMesh:
	if _cache.has(key):
		return _cache[key]
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = mat
	_cache[key] = q
	return q

func _fire_mesh() -> QuadMesh:
	return _quad("q_fire", _billboard_mat("m_fire", Gfx.soft_circle(64, 0.1), true))

func _smoke_mesh() -> QuadMesh:
	return _quad("q_smoke", _billboard_mat("m_smoke", Gfx.smoke_tex(64), false))

func _dust_mesh() -> QuadMesh:
	return _quad("q_dust", _billboard_mat("m_dust", Gfx.smoke_tex(64), false))

func _spark_mesh() -> QuadMesh:
	return _quad("q_spark", _billboard_mat("m_spark", Gfx.soft_circle(32, 0.6), true))

func _debris_mesh() -> BoxMesh:
	if _cache.has("b_debris"):
		return _cache["b_debris"]
	var b := BoxMesh.new()
	b.size = Vector3(0.28, 0.2, 0.34)
	b.material = Gfx.flat_mat(Color(0.18, 0.16, 0.14), 1.0)
	_cache["b_debris"] = b
	return b

func _brick_mesh() -> BoxMesh:
	if _cache.has("b_brick"):
		return _cache["b_brick"]
	var b := BoxMesh.new()
	b.size = Vector3(0.5, 0.35, 0.5)
	b.material = Gfx.flat_mat(Color(0.62, 0.55, 0.45), 1.0)
	_cache["b_brick"] = b
	return b

func _emitter(pos: Vector3, amount: int, life: float, pm: ParticleProcessMaterial, mesh: Mesh, one_shot: bool = true, explos: float = 1.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = explos
	p.local_coords = false
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 50, 60))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = pos
	add_child(p)
	p.emitting = true
	if one_shot:
		get_tree().create_timer(life + 0.6).timeout.connect(p.queue_free)
	return p

# ----------------------------------------------------------------------------- Explosionen
## size ~ Wirkradius in Metern. big = grosse Detonation (Bombe/Haubitze)
func explosion(pos: Vector3, size: float, ground: bool = true) -> void:
	if _active_particles > 80:
		size *= 0.7
	var s := clampf(size, 1.0, 12.0)
	# Feuerball
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35 * s
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.6 * s
	pm.initial_velocity_max = 2.4 * s
	pm.gravity = Vector3(0, 1.5, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 0.9 * s
	pm.scale_max = 1.7 * s
	pm.scale_curve = _curve_tex("c_fire", [[0.0, 0.5], [0.25, 1.0], [1.0, 0.2]])
	pm.color_ramp = _grad_tex("g_fire", [[0.0, Color(1.0, 0.95, 0.7, 1.0)], [0.2, Color(1.0, 0.6, 0.15, 0.95)], [0.6, Color(0.7, 0.18, 0.05, 0.6)], [1.0, Color(0.1, 0.03, 0.0, 0.0)]])
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	_emitter(pos, int(10 + s * 2.5), 0.45 + s * 0.06, pm, _fire_mesh())
	# Gleissender Kern
	flash(pos, 2.4 * s, 0.12)
	# Rauch
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = 0.4 * s
	sm.direction = Vector3(0, 1, 0)
	sm.spread = 35.0
	sm.initial_velocity_min = 1.0 + 0.3 * s
	sm.initial_velocity_max = 2.5 + 0.8 * s
	sm.gravity = Vector3(0, 0.6, 0)
	sm.damping_min = 0.6
	sm.damping_max = 1.2
	sm.scale_min = 0.6 * s
	sm.scale_max = 1.25 * s
	sm.scale_curve = _curve_tex("c_smoke", [[0.0, 0.4], [0.4, 1.0], [1.0, 1.4]])
	sm.color_ramp = _grad_tex("g_smoke", [[0.0, Color(0.25, 0.2, 0.17, 0.0)], [0.12, Color(0.22, 0.2, 0.19, 0.7)], [0.6, Color(0.3, 0.29, 0.28, 0.4)], [1.0, Color(0.4, 0.4, 0.4, 0.0)]])
	sm.angle_min = -180.0
	sm.angle_max = 180.0
	sm.angular_velocity_min = -30.0
	sm.angular_velocity_max = 30.0
	_emitter(pos + Vector3(0, 0.3, 0), int(6 + s * 1.6), 2.2 + s * 0.35, sm, _smoke_mesh(), true, 0.9)
	# Truemmer
	var dm := ParticleProcessMaterial.new()
	dm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	dm.emission_sphere_radius = 0.3 * s
	dm.direction = Vector3(0, 1, 0)
	dm.spread = 60.0
	dm.initial_velocity_min = 5.0 + s
	dm.initial_velocity_max = 10.0 + 2.2 * s
	dm.gravity = Vector3(0, -22, 0)
	dm.scale_min = 0.5
	dm.scale_max = 1.6
	dm.angle_min = -180.0
	dm.angle_max = 180.0
	dm.angular_velocity_min = -400.0
	dm.angular_velocity_max = 400.0
	_emitter(pos, int(6 + s * 2.0), 1.3, dm, _debris_mesh(), true, 1.0)
	if s >= 2.5:
		shockwave(pos, s * 1.5)
		dust_cloud(pos, s * 0.6)
		if _lights_active < 3 and s >= 3.0:
			_flash_light(pos + Vector3(0, 2.0, 0), s)
	if ground:
		world.city.add_scorch(pos, s * 0.9, 1.0 if s > 3.0 else 0.6)

func dust_cloud(pos: Vector3, s: float, color: Color = Color(0.72, 0.64, 0.5)) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.2 * s
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 90.0
	pm.initial_velocity_min = 1.5 * s
	pm.initial_velocity_max = 5.0 * s
	pm.gravity = Vector3(0, -0.4, 0)
	pm.damping_min = 1.5
	pm.damping_max = 3.0
	pm.scale_min = 1.0 * s
	pm.scale_max = 1.9 * s
	pm.scale_curve = _curve_tex("c_dust", [[0.0, 0.5], [0.5, 1.0], [1.0, 1.3]])
	pm.color_ramp = _grad_tex("g_dust_%s" % color.to_html(), [[0.0, Color(color.r, color.g, color.b, 0.0)], [0.15, Color(color.r, color.g, color.b, 0.55)], [1.0, Color(color.r * 0.9, color.g * 0.9, color.b * 0.9, 0.0)]])
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	_emitter(pos + Vector3(0, 0.8, 0), int(12 + s * 4.0), 3.6, pm, _dust_mesh(), true, 0.8)

func shockwave(pos: Vector3, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = Gfx.ring_tex(128, 0.18)
	m.albedo_color = Color(1.0, 0.85, 0.6, 0.55)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.25, 0)
	mi.scale = Vector3(0.3, 1, 0.3)
	add_child(mi)
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(radius, 1, radius), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.tween_callback(mi.queue_free)

func flash(pos: Vector3, s: float, secs: float = 0.1) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _spark_mesh()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = Gfx.soft_circle(32, 0.5)
	m.albedo_color = Color(1.0, 0.9, 0.65, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	q.size = Vector2(s, s)
	q.material = m
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, secs)
	tw.tween_callback(mi.queue_free)

func _flash_light(pos: Vector3, s: float) -> void:
	_lights_active += 1
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 3.5
	l.omni_range = 10.0 + s * 3.0
	l.shadow_enabled = false
	l.position = pos
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.35)
	tw.tween_callback(func():
		_lights_active -= 1
		l.queue_free())

# ----------------------------------------------------------------------------- Gefecht
func tracer(from: Vector3, to: Vector3, heavy: bool = false) -> void:
	var d := to - from
	var l := d.length()
	if l < 0.3:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var w := 0.09 if heavy else 0.05
	bm.size = Vector3(w, w, minf(l, 6.0))
	mi.mesh = bm
	var key := "tr_%s" % heavy
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.85, 0.35) if heavy else Color(1.0, 0.95, 0.6)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_cache[key] = m
	mi.material_override = _cache[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = from + d.normalized() * minf(l, 6.0) * 0.5
	mi.look_at(to, Vector3.UP)
	# Leuchtspur fliegt zum Ziel
	var tw := create_tween()
	var dur := clampf(l / 160.0, 0.05, 0.25)
	tw.tween_property(mi, "global_position", to - d.normalized() * minf(l, 6.0) * 0.5, dur)
	tw.tween_callback(mi.queue_free)

func muzzle_flash(pos: Vector3, s: float = 1.0) -> void:
	flash(pos, 0.9 * s, 0.06)

func spark(pos: Vector3) -> void:
	if _active_particles > 60:
		return
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -12, 0)
	pm.scale_min = 0.12
	pm.scale_max = 0.3
	pm.color_ramp = _grad_tex("g_spark", [[0.0, Color(1, 0.9, 0.5, 1)], [1.0, Color(1, 0.3, 0.0, 0.0)]])
	_emitter(pos, 4, 0.35, pm, _spark_mesh())

# ----------------------------------------------------------------------------- Dauer-Effekte
func attach_smoke(e: Node3D, size: float = 1.5, secs: float = 25.0) -> Node3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5 * size
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0.6, 0.9, 0.2)
	pm.damping_min = 0.4
	pm.damping_max = 0.8
	pm.scale_min = 0.9 * size
	pm.scale_max = 1.5 * size
	pm.scale_curve = _curve_tex("c_smoke2", [[0.0, 0.5], [1.0, 1.6]])
	pm.color_ramp = _grad_tex("g_smoke2", [[0.0, Color(0.1, 0.09, 0.08, 0.0)], [0.15, Color(0.12, 0.11, 0.1, 0.8)], [1.0, Color(0.35, 0.34, 0.33, 0.0)]])
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	var p := GPUParticles3D.new()
	p.amount = 12
	p.lifetime = 4.0
	p.local_coords = false
	p.process_material = pm
	p.draw_pass_1 = _smoke_mesh()
	p.visibility_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 50, 40))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var top := 1.4
	if e is Structure:
		top = (e as Structure).size.y * 0.8
	p.position = Vector3(0, top, 0)
	e.add_child(p)
	p.emitting = true
	if secs < 500.0:
		var tm := Timer.new()
		tm.one_shot = true
		tm.wait_time = secs
		p.add_child(tm)
		tm.timeout.connect(_stop_emitter.bind(p))
		tm.start()
	return p

func _stop_emitter(p: GPUParticles3D) -> void:
	if not is_instance_valid(p):
		return
	p.emitting = false
	var tm := Timer.new()
	tm.one_shot = true
	tm.wait_time = 5.0
	p.add_child(tm)
	tm.timeout.connect(p.queue_free)
	tm.start()

func attach_fire(e: Node3D) -> Node3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.5, 0.2, 1.5)
	if e is Structure:
		var st := e as Structure
		pm.emission_box_extents = Vector3(st.hx * 0.6, 0.2, st.hz * 0.6)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 15.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, 2.0, 0)
	pm.scale_min = 1.0
	pm.scale_max = 2.0
	pm.scale_curve = _curve_tex("c_fire2", [[0.0, 1.0], [1.0, 0.1]])
	pm.color_ramp = _grad_tex("g_fire2", [[0.0, Color(1.0, 0.8, 0.3, 0.9)], [0.5, Color(1.0, 0.35, 0.05, 0.6)], [1.0, Color(0.3, 0.05, 0.0, 0.0)]])
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.9
	p.local_coords = false
	p.process_material = pm
	p.draw_pass_1 = _fire_mesh()
	p.visibility_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 30, 40))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var top := 1.0
	if e is Structure:
		top = (e as Structure).size.y * 0.95
	p.position = Vector3(0, top, 0)
	e.add_child(p)
	p.emitting = true
	return p

func rocket_trail(parent: Node3D, thick: float = 1.0) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, 0.5, 0)
	pm.scale_min = 0.5 * thick
	pm.scale_max = 0.9 * thick
	pm.scale_curve = _curve_tex("c_trail", [[0.0, 0.5], [1.0, 1.6]])
	pm.color_ramp = _grad_tex("g_trail", [[0.0, Color(1.0, 0.85, 0.5, 0.9)], [0.12, Color(0.85, 0.85, 0.82, 0.6)], [1.0, Color(0.6, 0.6, 0.6, 0.0)]])
	var p := GPUParticles3D.new()
	p.amount = 22
	p.lifetime = 1.0
	p.local_coords = false
	p.process_material = pm
	p.draw_pass_1 = _smoke_mesh()
	p.visibility_aabb = AABB(Vector3(-60, -10, -60), Vector3(120, 60, 120))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.emitting = true
	return p

func crash(u: Unit) -> void:
	# Hubschrauber/Drohne stuerzt brennend ab und detoniert am Boden
	var wreck := Node3D.new()
	wreck.position = Vector3(u.position.x, u.air_h, u.position.z)
	add_child(wreck)
	var model := u.model
	u.remove_child(model)
	wreck.add_child(model)
	model.position = Vector3.ZERO
	var charred := Gfx.flat_mat(Color(0.08, 0.075, 0.07), 1.0)
	u._apply_override(model, charred)
	attach_smoke(wreck, 2.0, 5.0)
	attach_fire(wreck)
	var land := Vector3(u.position.x + randf_range(-4, 4), 0.0, u.position.z + randf_range(-4, 4))
	var tw := create_tween()
	tw.tween_property(wreck, "position", Vector3(land.x, 0.5, land.z), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(wreck, "rotation:z", 2.5, 1.4)
	tw.tween_callback(func():
		explosion(Vector3(land.x, 0.5, land.z), 4.5)
		Sfx.play_at("explosion_m", land)
		world.shake_at(land, 0.8)
		world.explode(land, 6.0, 90.0, "he", U.TEAM_CIV, null, {"silent": true, "no_fx": true}))
	tw.tween_interval(14.0)
	tw.tween_callback(wreck.queue_free)

## Kreis-Markierung am Boden (z.B. Ping)
func ring_ping(pos: Vector3, radius: float, color: Color, secs: float = 1.2) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = Gfx.ring_tex(128, 0.08)
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.3, 0)
	mi.scale = Vector3(radius * 0.3, 1, radius * 0.3)
	add_child(mi)
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(radius, 1, radius), secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, secs)
	tw.tween_callback(mi.queue_free)

## Einsturz eines Gebaeudes: Staubwolke, Ziegel, Truemmerhaufen
func collapse(pos: Vector3, size: Vector3) -> void:
	var s := clampf(maxf(size.x, size.z) * 0.45, 2.0, 9.0)
	dust_cloud(pos + Vector3(0, size.y * 0.4, 0), s * 1.4)
	dust_cloud(pos, s * 1.0, Color(0.6, 0.55, 0.48))
	explosion(pos + Vector3(0, size.y * 0.3, 0), s, true)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(size.x * 0.4, size.y * 0.3, size.z * 0.4)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 12.0
	pm.gravity = Vector3(0, -24, 0)
	pm.scale_min = 0.5
	pm.scale_max = 2.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -300.0
	pm.angular_velocity_max = 300.0
	_emitter(pos + Vector3(0, size.y * 0.6, 0), 40, 1.6, pm, _brick_mesh(), true, 0.9)
