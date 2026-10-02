@tool
extends EditorScenePostImport
## Import script for smart_pistol.glb (set in its .import file). Swaps the
## placeholder materials exported from Blender (pistol_*) for the game's
## materials in assets/materials/pistol/. Viewmodel parts cast no shadows.

const MATERIALS := "res://assets/materials/pistol/"


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
				push_warning("smart_pistol.glb: no material for %s" % m.resource_name)
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return scene
