@tool
extends EditorScenePostImport
## Import script for the hub NPCs' glbs (mom, ophelia, biggie; built by
## tools/npc/build_npc.py). Gives every surface the same toon shading as Eco
## (assets/shaders/eco_toon*), built here from each Blender material's name
## (npc_<who>_<part>) and the textures in assets/textures/npc/<who>/, sets
## each character's resting face from its blend shapes, and loops the anims.

const TOON := preload("res://assets/shaders/eco_toon.gdshader")
const TWO_SIDE := preload("res://assets/shaders/eco_toon_2side.gdshader")
const OVERLAY := preload("res://assets/shaders/eco_toon_overlay.gdshader")
const OUTLINE := preload("res://assets/shaders/eco_outline.gdshader")
const HAIR_TINT := Vector3(0.62, 0.55, 0.7)

## part: [shader, shade tint, render priority, outline width (0 = none), alpha cut, rim, sheen]
const PARTS := {
	"body": [TOON, Vector3(0.88, 0.74, 0.78), 0, 1.6, 0.0, 0.22, 0.0],
	"face": [TWO_SIDE, Vector3(1.0, 0.93, 0.92), 0, 1.2, 0.0, 0.22, 0.0],
	"hair": [TWO_SIDE, HAIR_TINT, 0, 1.2, 0.5, 0.22, 0.0],
	"hair_fringe": [TWO_SIDE, HAIR_TINT, 0, 1.2, 0.5, 0.22, 0.0],
	"hair_streak": [TWO_SIDE, HAIR_TINT, 0, 1.2, 0.5, 0.22, 0.0],
	"hair_cap": [TOON, HAIR_TINT, 0, 1.2, 0.5, 0.22, 0.0],
	"beard": [TWO_SIDE, HAIR_TINT, 0, 1.4, 0.0, 0.18, 0.0],
	"beanie": [TOON, Vector3(0.55, 0.55, 0.7), 0, 1.2, 0.0, 0.18, 0.0],
	"metal": [TOON, Vector3(0.55, 0.55, 0.7), 0, 0.0, 0.0, 0.3, 0.6],
	"boots": [TWO_SIDE, Vector3(0.55, 0.55, 0.7), 0, 0.0, 0.5, 0.22, 0.3],
	"eye_white": [TOON, Vector3.ONE, 0, 0.0, 0.5, 0.0, 0.0],
	"mouth": [TOON, Vector3.ONE, 0, 0.0, 0.5, 0.0, 0.0],
	"iris": [OVERLAY, Vector3.ONE, 1, 0.0, 0.0, 0.0, 0.0],
	"brow": [OVERLAY, Vector3.ONE, 2, 0.0, 0.0, 0.0, 0.0],
	"eyeline": [OVERLAY, Vector3.ONE, 2, 0.0, 0.0, 0.0, 0.0],
	"lash": [OVERLAY, Vector3.ONE, 2, 0.0, 0.0, 0.0, 0.0],
	"eye_glint": [OVERLAY, Vector3.ONE, 3, 0.0, 0.0, 0.0, 0.0],
}
## Each character's resting face (the same blend shapes the concept renders used).
const FACES := {
	"mom": {"Fcl_BRW_Sorrow": 0.55, "Fcl_EYE_Natural": 0.2, "Fcl_MTH_Up": 0.15},
	"ophelia": {"Fcl_EYE_Sorrow": 0.3, "Fcl_BRW_Sorrow": 0.3, "Fcl_MTH_Down": 0.25},
	"biggie": {"Fcl_BRW_Joy": 0.6, "Fcl_EYE_Joy": 0.45, "Fcl_MTH_Fun": 0.3},
	# the people of Solace (tools/town/build_townsfolk.py)
	"town_pell": {"Fcl_BRW_Joy": 0.3, "Fcl_MTH_Fun": 0.25},
	"town_kit": {"Fcl_BRW_Angry": 0.2, "Fcl_MTH_Up": 0.2},
	"town_wren": {"Fcl_EYE_Natural": 0.3, "Fcl_MTH_Fun": 0.2},
	"town_mira": {"Fcl_EYE_Natural": 0.35, "Fcl_BRW_Sorrow": 0.15},
	"town_rosa": {"Fcl_BRW_Joy": 0.45, "Fcl_EYE_Joy": 0.3, "Fcl_MTH_Fun": 0.3},
	"town_tobin": {"Fcl_BRW_Sorrow": 0.3, "Fcl_EYE_Natural": 0.4, "Fcl_MTH_Up": 0.15},
	"town_dez": {"Fcl_BRW_Angry": 0.25, "Fcl_MTH_Down": 0.15},
	"town_harl": {"Fcl_BRW_Angry": 0.15, "Fcl_MTH_Fun": 0.15},
	"town_jun": {"Fcl_EYE_Joy": 0.2, "Fcl_MTH_Fun": 0.35},
	"town_bram": {"Fcl_EYE_Natural": 0.3},
}


func _post_import(scene: Node) -> Object:
	var who := get_source_file().get_file().get_basename()
	var made := {}
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m == null:
				continue
			var key := m.resource_name
			if not made.has(key):
				made[key] = make_material(who, key, m)
			mesh.surface_set_material(i, made[key])
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var face: Dictionary = FACES.get(who, {})
		for shape: String in face:
			var b := (mi as MeshInstance3D).find_blend_shape_by_name(shape)
			if b >= 0:
				(mi as MeshInstance3D).set_blend_shape_value(b, face[shape])
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		for anim_name in player.get_animation_list():
			player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	return scene


static func make_material(who: String, key: String, source: Material) -> Material:
	var part := key.trim_prefix("npc_%s_" % who)
	var spec: Array = PARTS.get(part, PARTS["body"])
	var mat := ShaderMaterial.new()
	mat.resource_name = key
	mat.shader = spec[0]
	mat.render_priority = spec[2]
	var tex_path := "res://assets/textures/npc/%s/%s.png" % [who, part]
	var tex: Texture2D = load(tex_path) if ResourceLoader.exists(tex_path) else null
	if tex != null:
		mat.set_shader_parameter("albedo_tex", tex)
	elif source is BaseMaterial3D:
		mat.set_shader_parameter("albedo", (source as BaseMaterial3D).albedo_color)
	mat.set_shader_parameter("shade_tint", spec[1])
	mat.set_shader_parameter("alpha_cut", spec[4])
	mat.set_shader_parameter("rim", spec[5])
	mat.set_shader_parameter("sheen", spec[6])
	if spec[3] > 0.0:
		var ink := ShaderMaterial.new()
		ink.shader = OUTLINE
		ink.set_shader_parameter("width", spec[3])
		if spec[4] > 0.0:
			ink.set_shader_parameter("albedo_tex", tex)
			ink.set_shader_parameter("alpha_cut", spec[4])
		if part.begins_with("hair"):
			# The plain brown-grey ink is unlit, so on dark hair it stood out as
			# light strand lines; take a darker shade of the hair itself instead.
			ink.set_shader_parameter("ink", Color(0.45, 0.45, 0.45))
			ink.set_shader_parameter("tint", 1.0)
		mat.next_pass = ink
	return mat
