extends RefCounted
## The render settings that differ between the looks: Anime (default: the PS3
## settings with a few changes), PS3, and the old PS2 look, applied to a
## level's Environment and sun. Everything else about a level's sky, haze and
## light (colours, fog density, sun angle) is the level's own and all looks
## share it. The PS2 autoload re-applies these when F9 changes the look.


## true while the game is in the PS3 look: the PS2 autoload's state, or the
## project default when it isn't running (tool scripts).
static func is_ps3() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var ps2: Node = tree.root.get_node_or_null("PS2") if tree != null else null
	if ps2 != null:
		return not ps2.enabled
	return float(ProjectSettings.get_setting("shader_globals/ps3_look", {}).get("value", 1.0)) > 0.5


## true while the game is in the Anime look (built on the PS3 look).
static func is_anime() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var ps2: Node = tree.root.get_node_or_null("PS2") if tree != null else null
	if ps2 != null:
		return bool(ps2.anime) and not ps2.enabled
	return float(ProjectSettings.get_setting("shader_globals/anime_look", {}).get("value", 0.0)) > 0.5


static func apply_env(env: Environment, ps3: bool, anime := false) -> void:
	if ps3:
		# Light from the sky itself: ambient picks up the sky's colours and
		# smooth or metal surfaces reflect it.
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 0.6
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		if env.sky != null:
			env.sky.radiance_size = Sky.RADIANCE_SIZE_128
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 1.05
		env.tonemap_white = 6.0
		env.ssao_enabled = true
		env.ssao_radius = 1.4
		env.ssao_intensity = 2.2
		env.ssao_power = 1.6
		env.ssao_detail = 0.6
		env.ssao_horizon = 0.08
		env.ssao_light_affect = 0.15
		env.glow_intensity = 0.65
		env.glow_strength = 1.0
		env.glow_bloom = 0.06
		env.glow_hdr_threshold = 1.0
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		# Sun shafts through the haze, only where the level has haze at all.
		env.volumetric_fog_enabled = env.fog_enabled
		env.volumetric_fog_density = 0.004
		env.volumetric_fog_albedo = env.fog_light_color
		env.volumetric_fog_anisotropy = 0.6
		env.volumetric_fog_length = 80.0
		env.volumetric_fog_ambient_inject = 0.3
		env.volumetric_fog_sky_affect = 0.0
		if anime:
			# Flat painted light: no contact shadows, a brighter exposure so
			# roofed rooms don't go murky under the cel shading.
			env.ssao_enabled = false
			env.tonemap_exposure = 1.45
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		if env.sky != null:
			env.sky.radiance_size = Sky.RADIANCE_SIZE_32
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 0.95
		env.tonemap_white = 5.0
		env.ssao_enabled = false
		env.glow_intensity = 0.5
		env.glow_strength = 1.1
		env.glow_bloom = 0.12
		env.glow_hdr_threshold = 1.1
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		env.volumetric_fog_enabled = false


static func apply_sun(sun: DirectionalLight3D, ps3: bool) -> void:
	if not sun.shadow_enabled:
		return
	if not sun.has_meta("ps2_shadow_distance"):
		sun.set_meta("ps2_shadow_distance", sun.directional_shadow_max_distance)
	if ps3:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_blend_splits = true
		sun.directional_shadow_max_distance = maxf(sun.get_meta("ps2_shadow_distance"), 120.0)
		sun.shadow_blur = 1.5
		sun.shadow_bias = 0.05
		sun.shadow_normal_bias = 1.2
		sun.light_volumetric_fog_energy = 1.4
	else:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_blend_splits = false
		sun.directional_shadow_max_distance = sun.get_meta("ps2_shadow_distance")
		sun.shadow_blur = 1.0
		sun.shadow_bias = 0.1
		sun.shadow_normal_bias = 2.0
