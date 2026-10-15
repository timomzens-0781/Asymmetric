class_name Atmosphere
extends RefCounted
## Himmel, Sonne, Nebel, Tonemapping, Bloom.

static func setup(parent: Node, golden: float = 0.0) -> Dictionary:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://scripts/gfx/shaders/sky.gdshader")
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.82
	env.tonemap_white = 7.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = 1.12
	env.fog_enabled = true
	env.fog_light_color = Color(0.86, 0.78, 0.65)
	env.fog_density = 0.0011
	env.fog_sun_scatter = 0.25
	env.fog_aerial_perspective = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 1.45
	sun.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 170.0
	sun.directional_shadow_split_1 = 0.28
	sun.light_angular_distance = 0.6
	parent.add_child(sun)
	return {"env": env, "sun": sun, "we": we, "sky": sm}

## k: 0 = Nachmittag, 1 = Daemmerung
static func apply_time(a: Dictionary, k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	var env: Environment = a.env
	var sun: DirectionalLight3D = a.sun
	var sm: ShaderMaterial = a.sky
	sun.rotation_degrees = Vector3(lerpf(-42.0, -13.0, k), lerpf(38.0, 58.0, k), 0.0)
	sun.light_color = Color(1.0, 0.93, 0.8).lerp(Color(1.0, 0.58, 0.3), k)
	sun.light_energy = lerpf(1.45, 1.05, k)
	var horizon := Color(0.86, 0.78, 0.64).lerp(Color(0.95, 0.52, 0.28), k)
	sm.set_shader_parameter("top_color", Color(0.32, 0.5, 0.78).lerp(Color(0.16, 0.24, 0.45), k))
	sm.set_shader_parameter("horizon_color", horizon)
	sm.set_shader_parameter("ground_color", Color(0.6, 0.52, 0.4).lerp(Color(0.35, 0.22, 0.17), k))
	sm.set_shader_parameter("sun_color", sun.light_color)
	sm.set_shader_parameter("cloud_light", Color(1.0, 0.98, 0.94).lerp(Color(1.0, 0.66, 0.45), k))
	sm.set_shader_parameter("cloud_dark", Color(0.55, 0.6, 0.68).lerp(Color(0.42, 0.28, 0.38), k))
	sm.set_shader_parameter("sun_dir", sun.global_transform.basis.z if sun.is_inside_tree() else Basis.from_euler(sun.rotation).z)
	env.ambient_light_energy = lerpf(0.6, 0.5, k)
	env.fog_light_color = Color(0.86, 0.78, 0.65).lerp(Color(0.85, 0.5, 0.35), k)
	env.tonemap_exposure = lerpf(0.82, 0.92, k)
