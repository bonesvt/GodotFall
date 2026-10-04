extends RefCounted
## Mom's bed made soft: a rounded mattress in linen, puffy pillows, and a
## patchwork quilt that drapes over the mattress edges, or over whoever is in
## the bed (family_scene.gd lays one over Eco and Mom from their posed bones).
## Textures are painted here at runtime: a stitched patchwork and a plain
## linen, so the bed reads as fabric instead of blocks.

const Art := preload("res://scripts/ps2/ps2_assets.gd")

const MATTRESS := Vector3(1.5, 0.2, 1.95)
## Quilt colours, warm and faded, like the rest of her room.
const PATCHES := [Color(0.8, 0.45, 0.35), Color(0.55, 0.65, 0.5), Color(0.9, 0.75, 0.45),
	Color(0.5, 0.55, 0.7), Color(0.85, 0.6, 0.55), Color(0.93, 0.88, 0.76)]
## The quilt's grid step (m) and how far it hangs over the sides.
const STEP := 0.035
const OVERHANG := 0.2
## Body parts the quilt drapes over: [from bone, to bone, radius].
const BODY := [
	["J_Bip_C_Hips", "J_Bip_C_Spine", 0.19], ["J_Bip_L_UpperLeg", "J_Bip_R_UpperLeg", 0.15], ["J_Bip_C_Spine", "J_Bip_C_UpperChest", 0.15],
	["J_Bip_L_UpperLeg", "J_Bip_L_LowerLeg", 0.095], ["J_Bip_R_UpperLeg", "J_Bip_R_LowerLeg", 0.095],
	["J_Bip_L_LowerLeg", "J_Bip_L_Foot", 0.08], ["J_Bip_R_LowerLeg", "J_Bip_R_Foot", 0.08],
	["J_Bip_L_Foot", "J_Bip_L_ToeBase", 0.08], ["J_Bip_R_Foot", "J_Bip_R_ToeBase", 0.08],
]
const ARMS := [
	["J_Bip_L_UpperArm", "J_Bip_L_LowerArm", 0.07], ["J_Bip_R_UpperArm", "J_Bip_R_LowerArm", 0.07],
	["J_Bip_L_LowerArm", "J_Bip_L_Hand", 0.065], ["J_Bip_R_LowerArm", "J_Bip_R_Hand", 0.065],
	["J_Bip_L_Hand", "J_Bip_L_Middle3", 0.065], ["J_Bip_R_Hand", "J_Bip_R_Middle3", 0.065],
	["J_Bip_L_Thumb1", "J_Bip_L_Thumb3", 0.05], ["J_Bip_R_Thumb1", "J_Bip_R_Thumb3", 0.05],
]

static var _quilt_mat: Material
static var _linen_mat: Material
static var _ticking_mat: Material


## The soft parts of the bed whose frame sits at `bed` (floor level, middle of
## the bed, head end toward +Z). Returns the quilt, named "MomQuilt".
static func dress(root: Node3D, bed: Vector3) -> MeshInstance3D:
	var top := bed.y + 0.38 + MATTRESS.y
	var mattress := MeshInstance3D.new()
	mattress.name = "MomMattress"
	mattress.mesh = soft_box(MATTRESS, 0.07)
	mattress.material_override = ticking()
	mattress.position = bed + Vector3(0, 0.38 + MATTRESS.y / 2.0, -0.05)
	root.add_child(mattress)
	for dx in [-0.37, 0.37]:
		var pillow := MeshInstance3D.new()
		pillow.mesh = soft_box(Vector3(0.62, 0.15, 0.38), 0.07, 0.35)
		pillow.material_override = linen()
		pillow.position = Vector3(bed.x + dx, top + 0.075, bed.z + 0.74)
		pillow.rotation_degrees = Vector3(-8, dx * 8.0, 0)
		root.add_child(pillow)
	var quilt := drape(bed, bed.z + 0.5, [])
	quilt.name = "MomQuilt"
	root.add_child(quilt)
	return quilt


## Top of the mattress for the bed at `bed`.
static func mattress_top(bed: Vector3) -> float:
	return bed.y + 0.38 + MATTRESS.y


## A quilt over the bed at `bed`, from its foot to `head_z`, laid over the
## capsules [[a, b, radius], ...] (world space) of whoever is under it.
static func drape(bed: Vector3, head_z: float, capsules: Array) -> MeshInstance3D:
	var top := mattress_top(bed) + 0.025
	var half := MATTRESS.x / 2.0
	var foot := bed.z - 0.05 - MATTRESS.z / 2.0
	var x0 := bed.x - half - OVERHANG
	var nx := int(ceil((MATTRESS.x + OVERHANG * 2.0) / STEP)) + 1
	var z0 := foot - OVERHANG
	var nz := int(ceil((head_z - z0) / STEP)) + 1
	var h := PackedFloat32Array()
	h.resize(nx * nz)
	var body := PackedFloat32Array()
	body.resize(nx * nz)
	for j in nz:
		var z := minf(z0 + j * STEP, head_z)
		for i in nx:
			var x := x0 + i * STEP
			# Flat on the mattress, rolling over the edges and hanging down.
			var out := maxf(absf(x - bed.x) - half, 0.0)
			out = Vector2(out, maxf(foot - z, 0.0)).length()
			var y := top - 0.06 * smoothstep(0.0, 0.06, out) - 2.2 * maxf(out - 0.03, 0.0)
			# Soft folds, more where it hangs.
			y += (0.006 + 0.03 * smoothstep(0.0, OVERHANG, out)) * sin(x * 23.0 + z * 7.0) * sin(z * 17.0 - x * 5.0)
			var b := -INF
			for c in capsules:
				b = maxf(b, _capsule_top(c, x, z))
			h[j * nx + i] = y
			body[j * nx + i] = b
	# Bodies lift it, and the cloth spreads the lift out around them: it
	# slopes away from each body, then relaxes into soft rolls, never sinking
	# back into whoever is underneath.
	var floor_ := body.duplicate()
	for n in h.size():
		floor_[n] = body[n] + 0.05
	for k in 6:
		var next := body.duplicate()
		for j in range(1, nz - 1):
			for i in range(1, nx - 1):
				var m := body[j * nx + i]
				for d in [-1, 1, -nx, nx]:
					m = maxf(m, body[j * nx + i + d] - STEP * 0.75)
				next[j * nx + i] = m
		body = next
	for n in h.size():
		h[n] = maxf(h[n], body[n] + 0.05)
	for k in 12:
		var next := h.duplicate()
		for j in range(1, nz - 1):
			for i in range(1, nx - 1):
				var n := j * nx + i
				var avg := (h[n] * 4.0 + h[n - 1] + h[n + 1] + h[n - nx] + h[n + nx]) / 8.0
				next[n] = maxf(avg, floor_[n])
		h = next
	return _grid_mesh(x0, z0, nx, nz, h, head_z)


## Capsules for the posed skeleton `skel`, for drape(). `arms` adds the arms.
static func capsules(skel: Skeleton3D, arms := false) -> Array:
	var out := []
	for part in BODY + (ARMS if arms else []):
		var a := skel.find_bone(part[0])
		var b := skel.find_bone(part[1])
		if a < 0 or b < 0:
			continue
		out.append([skel.global_transform * skel.get_bone_global_pose(a).origin,
			skel.global_transform * skel.get_bone_global_pose(b).origin, part[2]])
	return out


## Highest point of capsule `c` above (x, z), or -INF if it doesn't reach.
static func _capsule_top(c: Array, x: float, z: float) -> float:
	var a: Vector3 = c[0]
	var b: Vector3 = c[1]
	var r: float = c[2]
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(x - a.x, z - a.z)
	var t := 0.0 if ab.length_squared() < 1e-6 else clampf(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
	var p := a.lerp(b, t)
	var d := Vector2(x - p.x, z - p.z).length()
	if d >= r:
		return -INF
	var y := maxf(a.y, b.y) if ab.length_squared() < 1e-6 else p.y
	return y + sqrt(r * r - d * d)


static func _grid_mesh(x0: float, z0: float, nx: int, nz: int, h: PackedFloat32Array, head_z: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz:
		for i in nx:
			var x := x0 + i * STEP
			var z := minf(z0 + j * STEP, head_z)
			st.set_uv(Vector2(x, z) * 1.25)
			st.add_vertex(Vector3(x, h[j * nx + i], z))
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + nx)
			st.add_index(a + 1)
			st.add_index(a + nx + 1)
			st.add_index(a + nx)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = quilt()
	return mi


## A box with rounded edges and corners (radius `r`), its top and bottom
## puffed out by `puff` of its height in the middle, like a pillow.
static func soft_box(size: Vector3, r: float, puff := 0.0) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = size
	box.subdivide_width = 12
	box.subdivide_height = 4
	box.subdivide_depth = 12
	var arrays := box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var half := size / 2.0
	var inner := (half - Vector3.ONE * r).max(Vector3.ZERO)
	for i in verts.size():
		var p := verts[i]
		var core := p.clamp(-inner, inner)
		var n := (p - core).normalized()
		p = core + n * r
		if puff > 0.0:
			var mid := (1.0 - absf(p.x) / half.x) * (1.0 - absf(p.z) / half.z)
			p.y *= 1.0 + puff * mid
		verts[i] = p
		normals[i] = n
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# --- Fabric ------------------------------------------------------------------

static func quilt() -> Material:
	if _quilt_mat == null:
		_quilt_mat = _fabric(_patchwork())
	return _quilt_mat


static func linen() -> Material:
	if _linen_mat == null:
		_linen_mat = _fabric(_linen())
	return _linen_mat


## The mattress cover: linen with faint stripes.
static func ticking() -> Material:
	if _ticking_mat == null:
		_ticking_mat = _fabric(_linen(true))
	return _ticking_mat


static func _fabric(tex: Texture2D) -> Material:
	var mat: ShaderMaterial = Art.material("canvas").duplicate()
	mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("normal_tex", null)
	mat.set_shader_parameter("use_uv", true)
	mat.set_shader_parameter("world_space", false)
	mat.set_shader_parameter("tex_scale", 1.0)
	mat.set_shader_parameter("albedo", Color.WHITE)
	return mat


## 4 x 4 patches, each its own colour and print (plain, dots, stripes,
## checks), stitched along every seam, with a soft weave.
static func _patchwork() -> ImageTexture:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var cell := n / 4
	var looks := []
	for k in 16:
		looks.append([PATCHES[rng.randi() % PATCHES.size()], rng.randi() % 4])
	for y in n:
		for x in n:
			var look: Array = looks[(y / cell) * 4 + x / cell]
			var c: Color = look[0]
			var u := x % cell
			var v := y % cell
			match look[1]:
				1:
					if (u % 16 - 8) * (u % 16 - 8) + (v % 16 - 8) * (v % 16 - 8) < 7:
						c = c.lightened(0.35)
				2:
					if (u / 6) % 2 == 0:
						c = c.darkened(0.12)
				3:
					if ((u / 8) + (v / 8)) % 2 == 0:
						c = c.lightened(0.15)
			# Stitches just inside each seam, and the seam itself a little shaded.
			var edge := mini(mini(u, cell - 1 - u), mini(v, cell - 1 - v))
			if edge == 0:
				c = c.darkened(0.3)
			elif edge == 3 and ((u + v) / 3) % 2 == 0:
				c = Color(0.96, 0.92, 0.84)
			# Weave: a faint cross-hatch so it reads as cloth up close.
			c = c.darkened(0.05 * float((x + y) % 2) + 0.04 * rng.randf())
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _linen(stripes := false) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in n:
		for x in n:
			# Ticking stripes (the mattress), faint blue-grey on cream.
			var c := Color(0.95, 0.92, 0.86)
			if stripes and x % 24 < 7:
				c = c.lerp(Color(0.42, 0.5, 0.64), 0.65)
			c = c.darkened(0.03 * float((x * 3 + y) % 4 == 0) + 0.035 * rng.randf())
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
