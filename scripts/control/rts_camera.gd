class_name RtsCamera
extends Node3D
## RTS-Kamera: Pan (WASD/Pfeile/Rand), Drehen (Q/E, Mitteltaste), Zoom (Mausrad), Shake, Orbit-Modus fuers Menue.

var cam: Camera3D
var focus := Vector3(-120, 0, 126)
var target_focus := Vector3(-120, 0, 126)
var yaw := 0.45
var target_yaw := 0.45
var dist := 46.0
var target_dist := 46.0
var enabled := true
var edge_scroll := true
var orbit_mode := false
var shake := 0.0
var _orbit_t := 0.0
var intro := 0.0
var _drag_rot := false
var _rng := RandomNumberGenerator.new()
const MIN_DIST := 14.0
const MAX_DIST := 165.0
const BOUND := 150.0

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 48.0
	cam.near = 0.5
	cam.far = 900.0
	add_child(cam)
	cam.current = true
	_rng.randomize()
	_apply(0.0)

func jump_to(p: Vector3) -> void:
	target_focus = Vector3(clampf(p.x, -BOUND, BOUND), 0, clampf(p.z, -BOUND, BOUND))
	focus = target_focus

func focus_on(p: Vector3) -> void:
	target_focus = Vector3(clampf(p.x, -BOUND, BOUND), 0, clampf(p.z, -BOUND, BOUND))

func add_shake(a: float) -> void:
	shake = minf(shake + a, 1.5)

func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	if orbit_mode:
		_orbit_t += dt
		target_yaw += dt * 0.04
		yaw = target_yaw
		focus = focus.lerp(target_focus, dt * 0.8)
	elif enabled:
		_input_pan(dt)
	_apply(dt)

func _input_pan(dt: float) -> void:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1.0
	if edge_scroll and get_viewport() != null:
		var vp := get_viewport()
		var m := vp.get_mouse_position()
		var sz := vp.get_visible_rect().size
		if DisplayServer.window_is_focused() and Rect2(Vector2.ZERO, sz).has_point(m):
			var e := 6.0
			if m.x < e:
				d.x -= 1.0
			elif m.x > sz.x - e:
				d.x += 1.0
			if m.y < e:
				d.y -= 1.0
			elif m.y > sz.y - e:
				d.y += 1.0
	if Input.is_key_pressed(KEY_Q):
		target_yaw += dt * 1.6
	if Input.is_key_pressed(KEY_E):
		target_yaw -= dt * 1.6
	if d != Vector2.ZERO:
		var speed := 38.0 + dist * 0.9
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= 1.8
		var dir := Vector3(d.x, 0, d.y).normalized().rotated(Vector3.UP, yaw)
		target_focus += dir * speed * dt
		target_focus.x = clampf(target_focus.x, -BOUND, BOUND)
		target_focus.z = clampf(target_focus.z, -BOUND, BOUND)

func _unhandled_input(ev: InputEvent) -> void:
	if not enabled or orbit_mode:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				target_dist = clampf(target_dist * 0.88, MIN_DIST, MAX_DIST)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_dist = clampf(target_dist * 1.14, MIN_DIST, MAX_DIST)
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag_rot = mb.pressed
	elif ev is InputEventMouseMotion and _drag_rot:
		var mm := ev as InputEventMouseMotion
		target_yaw -= mm.relative.x * 0.006

func _apply(dt: float) -> void:
	if dt > 0.0 and not orbit_mode:
		var k := 1.0 - exp(-dt * 10.0)
		focus = focus.lerp(target_focus, k)
		var dist_rate := 9.0
		if intro > 0.0:
			intro -= dt
			dist_rate = 1.5
		dist = lerpf(dist, target_dist, 1.0 - exp(-dt * dist_rate))
		yaw = lerp_angle(yaw, target_yaw, 1.0 - exp(-dt * 10.0))
	elif orbit_mode:
		dist = lerpf(dist, target_dist, 1.0 - exp(-dt * 2.0))
	var t := clampf((dist - MIN_DIST) / (MAX_DIST - MIN_DIST), 0.0, 1.0)
	var pitch := deg_to_rad(lerpf(36.0, 62.0, t))
	var off := Vector3(0, sin(pitch), cos(pitch)) * dist
	off = off.rotated(Vector3.UP, yaw)
	var sh := Vector3.ZERO
	if shake > 0.01:
		sh = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * shake * 0.5
		shake = maxf(0.0, shake - dt * 2.6)
	cam.global_position = focus + off + sh
	cam.look_at(focus + sh * 0.5, Vector3.UP)
	Sfx.listener = focus
	Sfx.listener_zoom = dist

func ground_point(screen_pos: Vector2) -> Vector3:
	var o := cam.project_ray_origin(screen_pos)
	var d := cam.project_ray_normal(screen_pos)
	if absf(d.y) < 0.0001:
		return focus
	var t := -o.y / d.y
	if t < 0.0:
		return focus
	return o + d * t

func on_shake(pos: Vector3, amount: float) -> void:
	var d := U.dist2d(pos, focus)
	var k := clampf(1.0 - d / 90.0, 0.0, 1.0)
	add_shake(amount * k * 0.6)
