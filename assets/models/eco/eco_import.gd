@tool
extends EditorScenePostImport
## Import script for eco.glb (set in eco.glb.import). Swaps the placeholder
## materials exported from Blender (eco_*) for the game's PS2 materials in
## assets/materials/eco/, and makes her animations loop.

const MATERIALS := "res://assets/materials/eco/"


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
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		for anim_name in player.get_animation_list():
			player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	return scene
