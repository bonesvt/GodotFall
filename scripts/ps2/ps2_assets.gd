extends RefCounted
## Lookup for the PS2-style art in assets/. Level code keeps building boxes by
## colour (level_kit.gd box()), and surface() turns that colour and size into
## the matching textured material, so level generators need no art changes:
##   low-saturation colour  -> concrete with a steel-plate top, tinted by the colour
##     (small pieces up to 2.5 m across become cover: low ones barriers, tall ones crates)
##   blue   -> wallrun panels       orange -> grapple anchor hazard stripes
##   green  -> military crates      red    -> lava

const SKY_SHADER := preload("res://assets/shaders/ps2_sky.gdshader")
const SKY_LAYERS := preload("res://assets/textures/sky.png")

const MATERIALS := {
	"concrete": preload("res://assets/materials/concrete.tres"),
	"wallrun": preload("res://assets/materials/wallrun.tres"),
	"anchor": preload("res://assets/materials/anchor.tres"),
	"cover": preload("res://assets/materials/cover.tres"),
	"barrier": preload("res://assets/materials/barrier.tres"),
	"lava": preload("res://assets/materials/lava.tres"),
}

const MODELS := {
	"pistol": preload("res://assets/models/pistol_p08.tscn"),
	"grunt": preload("res://assets/models/grunt.tscn"),
	"salvage_cache": preload("res://assets/models/salvage_cache.tscn"),
	"extract_beacon": preload("res://assets/models/extract_beacon.tscn"),
	"titan_atlas": preload("res://assets/models/titan_atlas.tscn"),
	"titan_ogre": preload("res://assets/models/titan_ogre.tscn"),
	"titan_stryder": preload("res://assets/models/titan_stryder.tscn"),
	"titan_scrap": preload("res://assets/models/titan_scrap.tscn"),
	"titan_enemy": preload("res://assets/models/titan_enemy.tscn"),
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


## A titan model for a chassis id ("atlas", "ogre", "stryder", "scrap", "enemy")
## holding the weapon for a weapon id ("xo16", "tracker", "splitter", "scrap").
static func titan(chassis: String, weapon: String) -> Node3D:
	var body := model("titan_" + chassis if MODELS.has("titan_" + chassis) else "titan_scrap")
	var gun := model("titan_weapon_" + weapon if MODELS.has("titan_weapon_" + weapon) else "titan_weapon_scrap")
	body.find_child("WeaponMount", true, false).add_child(gun)
	return body


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
		# The textures are mid grey, so brighten the tint to keep levels at their old brightness.
		var mat: ShaderMaterial = MATERIALS["concrete"].duplicate()
		var tint := Color(minf(color.r * 1.6, 1.0), minf(color.g * 1.6, 1.0), minf(color.b * 1.6, 1.0))
		mat.set_shader_parameter("albedo", tint)
		_cache[key] = mat
	return _cache[key]


## PS2-style sky, fog and light for a level: a painted gradient sky with
## mountains, thick distance fog, flat ambient light and crunchy shadows.
static func environment(parent: Node, top: Color, horizon: Color) -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", horizon)
	sky_mat.set_shader_parameter("layers", SKY_LAYERS)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = top.lerp(horizon, 0.5)
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = horizon
	env.fog_density = 0.0055
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	parent.add_child(sun)
