@tool
extends EditorScenePostImport
## Import script for grunt.glb (set in grunt.glb.import). Swaps the placeholder
## materials exported from Blender (grunt_*) for the game's PS2 materials in
## assets/materials/grunt/.

const MATERIALS := "res://assets/materials/grunt/"


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
				push_warning("grunt.glb: no material for %s" % m.resource_name)
	return scene
