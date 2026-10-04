@tool
extends EditorScenePostImport
## Import script for the Choir and wildlife models (assets/models/threats/*.glb,
## exported by tools/threats/build_threats.py). Swaps the Blender materials for
## the game's toon materials in assets/materials/threats/ (Eco's two-tone
## shader) and gives every part an ink outline, the same way grunt_import.gd
## does for the grunt: an "Ink" child with normals smoothed across shared
## corners, drawn only with the outline shader. Glowing parts (eyes, slits,
## lures, crystals) get no ink so they read as light.

const MATERIALS := "res://assets/materials/threats/"
const INK := "res://assets/materials/threats/threat_ink.tres"


func _post_import(scene: Node) -> Object:
	var ink: Material = load(INK)
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		var glows := false
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m == null:
				continue
			var path := MATERIALS + m.resource_name + ".tres"
			if ResourceLoader.exists(path):
				var toon: ShaderMaterial = load(path)
				mesh.surface_set_material(i, toon)
				var energy = toon.get_shader_parameter("emission_energy")
				if energy != null and float(energy) > 1.0:
					glows = true
			else:
				push_warning("%s: no material for %s" % [scene.name, m.resource_name])
		if not glows:
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
