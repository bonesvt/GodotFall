@tool
extends EditorScenePostImport
## Import script for eco.glb (set in eco.glb.import). Swaps the placeholder
## materials exported from Blender (eco_v_*) for the game's toon materials in
## assets/materials/eco/, sets her fierce expression from the face's blend
## shapes, and makes her animations loop.

const MATERIALS := "res://assets/materials/eco/"
## Face blend shapes (from the VRoid preset) that make her default expression:
## angry brows, narrowed eyes, the corners of the mouth turned down a touch.
const EXPRESSION := {"Fcl_BRW_Angry": 1.0, "Fcl_EYE_Angry": 0.55, "Fcl_MTH_Down": 0.1}


func _post_import(scene: Node) -> Object:
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m == null:
				continue
			var path := MATERIALS + m.resource_name + ".tres"
			if ResourceLoader.exists(path):
				mesh.surface_set_material(i, load(path))
			else:
				push_warning("eco.glb: no material for %s" % m.resource_name)
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for shape: String in EXPRESSION:
			var b := (mi as MeshInstance3D).find_blend_shape_by_name(shape)
			if b >= 0:
				(mi as MeshInstance3D).set_blend_shape_value(b, EXPRESSION[shape])
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		for anim_name in player.get_animation_list():
			player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	return scene
