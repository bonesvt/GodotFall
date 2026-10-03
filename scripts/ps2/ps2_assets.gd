extends RefCounted
## Lookup for the stylized PS2 art in assets/. Level code keeps building boxes by
## colour (level_kit.gd box()), and surface() turns that colour and size into
## the matching textured material, so level generators need no art changes:
##   low-saturation colour  -> concrete with a steel-plate top, tinted by the colour
##     (small pieces up to 2.5 m across become cover: low ones barriers, tall ones crates)
##   blue   -> wallrun panels       orange -> grapple anchor hazard stripes
##   green  -> military crates      red    -> lava

const Look := preload("res://scripts/ps2/look.gd")
const SKY_SHADER := preload("res://assets/shaders/ps2_sky.gdshader")
const SKY_LAYERS := preload("res://assets/textures/sky.png")

const MATERIALS := {
	"concrete": preload("res://assets/materials/concrete.tres"),
	"wallrun": preload("res://assets/materials/wallrun.tres"),
	"anchor": preload("res://assets/materials/anchor.tres"),
	"cover": preload("res://assets/materials/cover.tres"),
	"barrier": preload("res://assets/materials/barrier.tres"),
	"lava": preload("res://assets/materials/lava.tres"),
	"temple_stone": preload("res://assets/materials/temple_stone.tres"),
	"temple_carving": preload("res://assets/materials/temple_carving.tres"),
	"timber": preload("res://assets/materials/timber.tres"),
	"timber_carving": preload("res://assets/materials/timber_carving.tres"),
	"alloy": preload("res://assets/materials/alloy.tres"),
	"alloy_inlay": preload("res://assets/materials/alloy_inlay.tres"),
	"moss": preload("res://assets/materials/moss.tres"),
	"wood": preload("res://assets/materials/wood.tres"),
	"grass": preload("res://assets/materials/grass.tres"),
	"dirt": preload("res://assets/materials/dirt.tres"),
	"canvas": preload("res://assets/materials/canvas.tres"),
	"titan_armor": preload("res://assets/materials/titan_armor.tres"),
	"gunmetal": preload("res://assets/materials/gunmetal.tres"),
	"fabric": preload("res://assets/materials/grunt_fabric.tres"),
	"light": preload("res://assets/materials/light.tres"),
}

const MODELS := {
	"pistol": preload("res://assets/models/smart_pistol.tscn"),
	# Eco's upgrades of the smart pistol, tiers 1-5 (pistol_model() picks one).
	"pistol_t1": preload("res://assets/models/smart_pistol_t1.tscn"),
	"pistol_t2": preload("res://assets/models/smart_pistol_t2.tscn"),
	"pistol_t3": preload("res://assets/models/smart_pistol_t3.tscn"),
	"pistol_t4": preload("res://assets/models/smart_pistol_t4.tscn"),
	"pistol_t5": preload("res://assets/models/smart_pistol_t5.tscn"),
	"rivet_cannon": preload("res://assets/models/rivet_cannon.tscn"),
	"machine_pistol": preload("res://assets/models/machine_pistol.tscn"),
	"eco": preload("res://assets/models/eco.tscn"),
	"grunt": preload("res://assets/models/grunt.tscn"),
	"salvage_cache": preload("res://assets/models/salvage_cache.tscn"),
	"extract_beacon": preload("res://assets/models/extract_beacon.tscn"),
	"titan_atlas": preload("res://assets/models/titan_atlas.tscn"),
	"titan_ogre": preload("res://assets/models/titan_ogre.tscn"),
	"titan_stryder": preload("res://assets/models/titan_stryder.tscn"),
	"titan_scrap": preload("res://assets/models/titan_scrap.tscn"),
	"titan_enemy": preload("res://assets/models/titan_enemy.tscn"),
	## Eco's dad's titan, wrecked, for the hub (same node names as the others).
	"titan_wreck": preload("res://assets/models/titan_wreck.tscn"),
	"titan_weapon_xo16": preload("res://assets/models/titan_weapon_xo16.tscn"),
	"titan_weapon_tracker": preload("res://assets/models/titan_weapon_tracker.tscn"),
	"titan_weapon_splitter": preload("res://assets/models/titan_weapon_splitter.tscn"),
	"titan_weapon_scrap": preload("res://assets/models/titan_weapon_scrap.tscn"),
}

## Biggest footprint (m) that still counts as a cover piece rather than a platform.
const COVER_MAX_WIDTH := 2.5
const BARRIER_MAX_HEIGHT := 1.6

static var _cache := {}


static func model(id: String) -> Node3D:
	return MODELS[id].instantiate()


## Model id of the smart pistol at an upgrade tier: 0 is Dad's broken pistol,
## 1-5 are Eco's upgrades. Out-of-range tiers clamp.
static func pistol_model(tier: int) -> String:
	tier = clampi(tier, 0, 5)
	return "pistol" if tier == 0 else "pistol_t%d" % tier


## A titan model for a chassis id ("atlas", "ogre", "stryder", "scrap", "enemy")
## holding the weapon for a weapon id ("xo16", "tracker", "splitter", "scrap").
static func titan(chassis: String, weapon: String) -> Node3D:
	var body := model("titan_" + chassis if MODELS.has("titan_" + chassis) else "titan_scrap")
	var gun := model("titan_weapon_" + weapon if MODELS.has("titan_weapon_" + weapon) else "titan_weapon_scrap")
	body.find_child("WeaponMount", true, false).add_child(gun)
	return body


## A named material from MATERIALS, tinted when `tint` isn't white (tints are cached).
static func material(kind: String, tint := Color.WHITE) -> Material:
	if tint == Color.WHITE:
		return MATERIALS[kind]
	var key := kind + tint.to_html()
	if not _cache.has(key):
		var mat: ShaderMaterial = MATERIALS[kind].duplicate()
		var base = mat.get_shader_parameter("albedo")
		mat.set_shader_parameter("albedo", tint * (base if base is Color else Color.WHITE))
		_cache[key] = mat
	return _cache[key]


static func surface_kind(color: Color, size: Vector3) -> String:
	if color.s < 0.3:
		if maxf(size.x, size.z) <= COVER_MAX_WIDTH and size.y <= 3.0:
			return "barrier" if size.y <= BARRIER_MAX_HEIGHT else "cover"
		return "concrete"
	var hue := color.h * 360.0
	if hue < 15.0 or hue >= 330.0:
		return "lava"
	if hue < 50.0:
		return "anchor"
	if hue < 170.0:
		return "cover"
	return "wallrun"


## Shared material for a level box of this colour and size.
static func surface(color: Color, size: Vector3) -> Material:
	var kind := surface_kind(color, size)
	if kind != "concrete":
		return MATERIALS[kind]
	var key := color.to_html(false)
	if not _cache.has(key):
		# The textures are light grey already, so the tint only needs a small lift.
		var mat: ShaderMaterial = MATERIALS["concrete"].duplicate()
		var tint := Color(minf(color.r * 1.15, 1.0), minf(color.g * 1.15, 1.0), minf(color.b * 1.15, 1.0))
		mat.set_shader_parameter("albedo", tint)
		_cache[key] = mat
	return _cache[key]


## Stylized sky, haze and light for a level, a blend of Jak and Daxter's warm
## painted colour and Shadow of the Colossus's haze and bloom: a painted sky with
## a haloed sun, distance haze fading into mist in the void below the platforms,
## warm low sun with cool ambient shadows, soft bloom and a light colour grade.
## look.gd then adds the PS3 look's sky light, SSAO, sun shafts and soft
## shadows (or keeps the old PS2 settings when F9 has switched back).
static func environment(parent: Node, top: Color, horizon: Color) -> void:
	var sun_color := Color(1.0, 0.9, 0.72)
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", horizon)
	sky_mat.set_shader_parameter("sun_color", sun_color)
	sky_mat.set_shader_parameter("layers", SKY_LAYERS)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = top.lerp(horizon, 0.45).lightened(0.1)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 5.0
	env.fog_enabled = true
	env.fog_light_color = horizon.lerp(sun_color, 0.2)
	env.fog_density = 0.0045
	env.fog_aerial_perspective = 0.2
	env.fog_sun_scatter = 0.25
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	for level in 7:
		env.set_glow_level(level, 1.0 if level >= 2 and level <= 5 else 0.0)
	env.glow_intensity = 0.5
	env.glow_strength = 1.1
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.12
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.light_color = sun_color
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.75
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	Look.apply_env(env, Look.is_ps3())
	Look.apply_sun(sun, Look.is_ps3())
	parent.add_child(sun)
