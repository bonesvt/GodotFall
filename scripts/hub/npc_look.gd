@tool
extends RefCounted
## The hero look (the strinova-look model sheets) on an NPC's toon materials
## (assets/shaders/eco_toon.gdshaderinc): outlines coloured by the surface under
## them, the face's warm skin band, their clothes shading cooler than their
## skin (body_mask.png from tools/npc/build_npc_masks.py), and a sheen ring and
## lighter tips on their hair.
##
## npc_import.gd applies it when a glb is imported, and hub_npc.gd again when
## an NPC is made, so it reaches glbs imported before it existed.

## Each line takes the colour of the surface under it, darkened: warm brown on
## skin, near black on dark cloth, a deep shade of the hair on hair.
## Multipliers, written as colours (sRGB) for the outline shader's `ink`.
const INK := {
	"body": Color(0.62, 0.48, 0.48),
	"face": Color(0.64, 0.49, 0.49),
	"hair": Color(0.6, 0.51, 0.57),
	"boots": Color(0.54, 0.51, 0.54),
}
## The shade side of their clothes (body_mask.png G): cooler than skin's.
const CLOTH_TINT := Vector3(0.74, 0.64, 0.8)
## Hair: [sheen ring colour, tip colour, how far the tips lighten].
const HAIR := {
	"ophelia": [Color(0.78, 0.74, 1.0), Color(0.3, 0.2, 0.55), 0.55],
	"pip": [Color(1.0, 0.72, 0.78), Color(0.62, 0.2, 0.3), 0.45],
}
const HAIR_DEFAULT := [Color(1.0, 0.9, 0.9), Color(0, 0, 0), 0.0]
const HAIR_RING := 0.42


static func apply(model: Node, who: String) -> void:
	var top := _hair_top(model, who)
	var done := {}
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as ShaderMaterial
			if mat == null or done.has(mat):
				continue
			done[mat] = true
			style(mat, who, mat.resource_name.trim_prefix("npc_%s_" % who), top)


static func style(mat: ShaderMaterial, who: String, part: String, hair_top: float) -> void:
	var tex = mat.get_shader_parameter("albedo_tex")
	if part == "body":
		var mask_path := "res://assets/textures/npc/%s/body_mask.png" % who
		if mat.get_shader_parameter("mask_tex") == null and ResourceLoader.exists(mask_path):
			mat.set_shader_parameter("use_mask", true)
			mat.set_shader_parameter("mask_tex", load(mask_path))
		mat.set_shader_parameter("shade_tint_2", CLOTH_TINT)
	elif part == "cloth":
		# their real-cloth garments (<who>_cloth.glb): cloth all over
		mat.set_shader_parameter("shade_tint", CLOTH_TINT)
	elif part == "face":
		mat.set_shader_parameter("bare_skin", 1.0)
	elif part.begins_with("hair") and part != "hair_cap":
		var hair: Array = HAIR.get(who, HAIR_DEFAULT)
		mat.set_shader_parameter("hair_ring", HAIR_RING)
		mat.set_shader_parameter("hair_ring_color", hair[0])
		mat.set_shader_parameter("hair_tip", hair[1])
		mat.set_shader_parameter("hair_tip_amount", hair[2])
		if hair_top > -INF:
			mat.set_shader_parameter("hair_top", hair_top)
	var ink := mat.next_pass as ShaderMaterial
	if ink != null and tex != null:
		var kind := "hair" if part.begins_with("hair") or part == "beard" else part
		ink.set_shader_parameter("albedo_tex", tex)
		ink.set_shader_parameter("tint", 1.0)
		ink.set_shader_parameter("ink", INK.get(kind, INK["body"]))


## The crown's height: the top of the hair meshes, in their own space (the
## shader's v_obj), which places the sheen ring and where the tips lighten.
static func _hair_top(model: Node, who: String) -> float:
	var top := -INF
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m != null and m.resource_name.trim_prefix("npc_%s_" % who).begins_with("hair"):
				top = maxf(top, mesh.get_aabb().end.y)
	return top
