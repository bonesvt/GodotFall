extends SceneTree
## Writes Eco's body mesh (the eco_v_body surface of eco.glb, in her rest
## pose) for tools/ink/build_tattoos.py: positions, normals, UVs and triangle
## indices as raw little-endian arrays.
##   godot --headless --path . -s res://tools/ink/dump_body.gd -- <out_dir>


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if not args.is_empty() else "user://ink"
	DirAccess.make_dir_recursive_absolute(out)
	var eco: Node = load("res://assets/models/eco.tscn").instantiate()
	var body := eco.find_child("Body", true, false) as MeshInstance3D
	for s in body.mesh.get_surface_count():
		var m := body.mesh.surface_get_material(s)
		if m == null or m.resource_name != "eco_v_body":
			continue
		var a := body.mesh.surface_get_arrays(s)
		_write(out + "/pos.f32", (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).to_byte_array())
		_write(out + "/nrm.f32", (a[Mesh.ARRAY_NORMAL] as PackedVector3Array).to_byte_array())
		_write(out + "/uv.f32", (a[Mesh.ARRAY_TEX_UV] as PackedVector2Array).to_byte_array())
		_write(out + "/idx.i32", (a[Mesh.ARRAY_INDEX] as PackedInt32Array).to_byte_array())
		print("body: %d vertices, %d triangles" % [(a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3])
	eco.free()
	quit()


func _write(path: String, data: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(data)
	f.close()
