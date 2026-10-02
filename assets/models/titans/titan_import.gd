@tool
extends EditorScenePostImport
## Import script for the Blender titans (set in each titan_*.glb.import).
## Swaps the placeholder materials from tools/titans/build_titans.py for
## titan_paint ShaderMaterials: the colour comes from Blender, the finish
## (gloss, chips, grime) from the material's name prefix below.

const SHADER := preload("res://assets/shaders/titan_paint.gdshader")
const WEAR := preload("res://assets/textures/titans/paint_wear.png")

## prefix -> shader parameters. First match wins, so longer prefixes go first.
const FINISHES := [
	["wreck_", {"gloss": 0.3, "reflection": 0.15, "wear": 0.5, "grime": 0.7, "shininess": 24.0}],
	["paint_gun", {"gloss": 0.45, "reflection": 0.25, "wear": 0.35, "grime": 0.3}],
	["paint_", {"gloss": 0.7, "reflection": 0.4, "wear": 0.3, "grime": 0.25}],
	["stripe_", {"gloss": 0.7, "reflection": 0.4, "wear": 0.35, "grime": 0.2}],
	["trim_", {"gloss": 0.55, "reflection": 0.3, "wear": 0.3, "grime": 0.3}],
	["chrome", {"gloss": 1.0, "reflection": 0.85, "wear": 0.0, "grime": 0.15, "shininess": 110.0}],
	["metal", {"gloss": 0.7, "reflection": 0.45, "wear": 0.0, "grime": 0.3, "shininess": 70.0}],
	["brass", {"gloss": 0.8, "reflection": 0.5, "wear": 0.0, "grime": 0.3, "shininess": 70.0}],
	["dark", {"gloss": 0.35, "reflection": 0.15, "wear": 0.1, "grime": 0.2, "shininess": 32.0}],
	["rubber", {"gloss": 0.08, "reflection": 0.03, "wear": 0.0, "grime": 0.35, "shininess": 12.0}],
	["hose", {"gloss": 0.3, "reflection": 0.1, "wear": 0.0, "grime": 0.3}],
	["seat", {"gloss": 0.3, "reflection": 0.1, "wear": 0.35, "grime": 0.3, "chip_color": Color(0.2, 0.12, 0.08)}],
	["rust", {"gloss": 0.1, "reflection": 0.03, "wear": 0.55, "grime": 0.6, "chip_color": Color(0.2, 0.1, 0.05)}],
	["soot", {"gloss": 0.05, "reflection": 0.0, "wear": 0.0, "grime": 0.0, "ao_strength": 0.0}],
	["glass", {"gloss": 1.0, "reflection": 0.9, "wear": 0.0, "grime": 0.2, "shininess": 120.0}],
	["glow_dead", {"gloss": 0.9, "reflection": 0.6, "wear": 0.0, "grime": 0.5}],
	["glow", {"unshaded": true, "emission_energy": 2.0, "wear": 0.0, "grime": 0.0, "ao_strength": 0.0}],
]

var _made := {}


func _post_import(scene: Node) -> Object:
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m is BaseMaterial3D:
				mesh.surface_set_material(i, _material(m))
	return scene


func _material(src: BaseMaterial3D) -> ShaderMaterial:
	var key := src.resource_name
	if _made.has(key):
		return _made[key]
	var mat := ShaderMaterial.new()
	mat.resource_name = key
	mat.shader = SHADER
	mat.set_shader_parameter("wear_tex", WEAR)
	mat.set_shader_parameter("albedo", src.albedo_color)
	mat.set_shader_parameter("emission", src.albedo_color)
	for finish in FINISHES:
		if key.begins_with(finish[0]):
			for param in finish[1]:
				mat.set_shader_parameter(param, finish[1][param])
			break
	_made[key] = mat
	return mat
