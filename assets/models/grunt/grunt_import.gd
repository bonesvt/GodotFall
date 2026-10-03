@tool
extends EditorScenePostImport
## Import script for grunt.glb (set in grunt.glb.import). Swaps the placeholder
## materials exported from Blender (grunt_*) for the game's materials in
## assets/materials/grunt/ (Eco's two-tone toon shader), and gives every part
## an ink outline like hers.
##
## Eco's outline is a next pass on her materials, but the grunt's parts are
## faceted: pushing split face normals outward leaves no line round the
## silhouette. So each part gets an "Ink" child: the same mesh with its normals
## smoothed across shared corners, drawn only with the outline shader.

const MATERIALS := "res://assets/materials/grunt/"
## Ink line material (eco_outline.gdshader), shared by every part.
const INK := "res://assets/materials/grunt/grunt_ink.tres"
## LED face decals sit on the visor glass; inking them would draw boxes round the eyes.
const NO_INK := ["Visor"]


func _post_import(scene: Node) -> Object:
	var ink: Material = load(INK)
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
		if not NO_INK.any(func(p: String) -> bool: return mi.name.begins_with(p)):
			_add_ink(mi as MeshInstance3D, ink, scene)
	return scene


func _add_ink(mi: MeshInstance3D, ink: Material, owner: Node) -> void:
	var hull := ArrayMesh.new()
	for i in mi.mesh.get_surface_count():
		var arrays: Array = mi.mesh.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if verts.is_empty() or normals.size() != verts.size():
			continue
		# average the normals of every vertex that shares a position
		var sums := {}
		for v in verts.size():
			var key := verts[v].snapped(Vector3.ONE * 0.0005)
			sums[key] = sums.get(key, Vector3.ZERO) + normals[v]
		var smooth := PackedVector3Array()
		smooth.resize(verts.size())
		for v in verts.size():
			var n: Vector3 = sums[verts[v].snapped(Vector3.ONE * 0.0005)]
			smooth[v] = n.normalized() if n.length() > 0.0001 else normals[v]
		var out := []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = verts
		out[Mesh.ARRAY_NORMAL] = smooth
		out[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
		hull.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
		hull.surface_set_material(hull.get_surface_count() - 1, ink)
	if hull.get_surface_count() == 0:
		return
	var child := MeshInstance3D.new()
	child.name = "Ink"
	child.mesh = hull
	child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(child)
	child.owner = owner
