extends RefCounted
## Ground built from a grid of heights: one smooth-shaded mesh split into grass
## (gentle slopes) and rock (steep faces like cliffs and hillsides), and a
## matching trimesh collider, so what you see is what you stand on.

const Art := preload("res://scripts/ps2/ps2_assets.gd")
const HubProps := preload("res://scripts/hub/hub_props.gd")

## Faces steeper than this (normal.y below it) get the rock material.
const ROCK_SLOPE := 0.72


## `heights` is row-major: heights[iz * nx + ix] is the ground at
## (x0 + ix * cell, z0 + iz * cell). Returns the body.
static func build(parent: Node, heights: PackedFloat32Array, nx: int, nz: int, x0: float, z0: float, cell: float,
		grass_tint := Color.WHITE, rock_tint := Color.WHITE) -> StaticBody3D:
	var grass := SurfaceTool.new()
	var rock := SurfaceTool.new()
	grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var at := func(ix: int, iz: int) -> Vector3:
		return Vector3(x0 + ix * cell, heights[iz * nx + ix], z0 + iz * cell)
	for iz in nz - 1:
		for ix in nx - 1:
			var a: Vector3 = at.call(ix, iz)
			var b: Vector3 = at.call(ix + 1, iz)
			var c: Vector3 = at.call(ix, iz + 1)
			var d: Vector3 = at.call(ix + 1, iz + 1)
			# Split along the diagonal that keeps cliffs edges straight.
			var tris := [[a, b, d], [a, d, c]] if absf(a.y - d.y) < absf(b.y - c.y) else [[a, b, c], [b, d, c]]
			for t in tris:
				var n: Vector3 = (t[2] - t[0]).cross(t[1] - t[0]).normalized()
				if n.y < 0.0:
					t = [t[0], t[2], t[1]]
					n = -n
				var st: SurfaceTool = grass if n.y >= ROCK_SLOPE else rock
				for v in t:
					st.add_vertex(v)
				faces.append_array(PackedVector3Array([t[0], t[1], t[2]]))
	var mesh := ArrayMesh.new()
	for pair in [[grass, Art.material("grass", grass_tint)],
			[rock, HubProps.material("rock", rock_tint)]]:
		var st: SurfaceTool = pair[0]
		st.index()
		st.generate_normals()
		var arrays := st.commit_to_arrays()
		if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, pair[1])
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.set_meta("surface", "grass")  # footstep sounds (player.gd)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	return body
