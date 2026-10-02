extends RefCounted
## Throwaway combat effects: tracers, sparks, muzzle stars, smoke puffs,
## flying debris, shell casings and blasts. The look is chunky and graphic
## (hard-edged stars and blobs, saturated colours) to match the painted PS2
## art. Everything is unshaded, animates with a tween and frees itself.


static func tracer(parent: Node, from: Vector3, to: Vector3, color: Color, width := 0.02, life := 0.08) -> void:
	var dir := to - from
	var length := dir.length()
	if length < 0.05:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, 1.0)
	var mat := _material(color)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var up := Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.FORWARD
	var b := Basis.looking_at(dir, up)
	mi.global_transform = Transform3D(Basis(b.x, b.y, b.z * length), from + dir * 0.5)
	_fade(mi, mat, life)


static func spark(parent: Node, pos: Vector3, color: Color, size := 0.12, life := 0.15) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := _material(color)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	_fade(mi, mat, life)


## A flat, spiky star facing the camera: muzzle flashes and hit flares.
static func star(parent: Node, pos: Vector3, color: Color, size := 0.3, life := 0.05, points := 5) -> MeshInstance3D:
	var mat := _material(color)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = _star_mesh(points, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * size
	mi.rotation.z = randf() * TAU
	var tween := mi.create_tween().set_parallel()
	tween.tween_property(mi, "scale", Vector3.ONE * size * 1.6, life)
	tween.tween_property(mat, "albedo_color:a", 0.0, life)
	tween.chain().tween_callback(mi.queue_free)
	return mi


## A soft blob that swells and drifts up as it fades: gun smoke, dust.
static func puff(parent: Node, pos: Vector3, color: Color, size := 0.25, life := 0.5, drift := Vector3(0, 0.6, 0)) -> void:
	var mi := _blob(parent, pos, color, size)
	var mat: StandardMaterial3D = mi.mesh.material
	var tween := mi.create_tween().set_parallel()
	tween.tween_property(mi, "scale", Vector3.ONE * 2.2, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(mi, "global_position", pos + drift * life, life)
	tween.tween_property(mat, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(mi.queue_free)


## A handful of chunky bits thrown along `normal` that arc down under gravity.
static func debris(parent: Node, pos: Vector3, normal: Vector3, color: Color, count := 4, speed := 4.0, size := 0.05, life := 0.45) -> void:
	for i in count:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * size * randf_range(0.6, 1.4)
		mesh.material = _material(color.darkened(randf() * 0.35))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		mi.global_position = pos
		var v := (normal + Vector3(randf_range(-0.8, 0.8), randf_range(-0.2, 0.9), randf_range(-0.8, 0.8))).normalized() * speed * randf_range(0.6, 1.2)
		_throw(mi, pos, v, life)


## A brass casing flipped out of the ejection port, tumbling.
static func casing(parent: Node, pos: Vector3, velocity: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.008
	mesh.bottom_radius = 0.008
	mesh.height = 0.03
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh.material = _material(Color(1.0, 0.78, 0.3))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	_throw(mi, pos, velocity, 0.5, 9.0)


## An expanding fireball with a shock ring: titan shells, kill pops.
static func blast(parent: Node, pos: Vector3, color: Color, radius := 2.0, life := 0.35) -> void:
	var core := _blob(parent, pos, Color(1.0, 0.95, 0.75), radius * 0.35)
	var core_mat: StandardMaterial3D = core.mesh.material
	var t1 := core.create_tween().set_parallel()
	t1.tween_property(core, "scale", Vector3.ONE * 2.8, life * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t1.tween_property(core_mat, "albedo_color", Color(color, 0.0), life * 0.6)
	t1.chain().tween_callback(core.queue_free)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 16
	torus.ring_segments = 4
	var ring_mat := _material(color)
	torus.material = ring_mat
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = pos
	ring.scale = Vector3.ONE * radius * 0.2
	var t2 := ring.create_tween().set_parallel()
	t2.tween_property(ring, "scale", Vector3(radius, radius * 0.3, radius), life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t2.tween_property(ring_mat, "albedo_color:a", 0.0, life)
	t2.chain().tween_callback(ring.queue_free)
	puff(parent, pos, Color(0.25, 0.22, 0.2, 0.7), radius * 0.4, life * 3.0, Vector3(0, 1.2, 0))


## A thin ring of light that snaps outward around `axis`: the suppressor's
## pressure pop at the muzzle.
static func shock_ring(parent: Node, pos: Vector3, axis: Vector3, color: Color, radius := 0.05, life := 0.09) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 16
	torus.ring_segments = 3
	var mat := _material(color)
	torus.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var up := axis.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.99 else Vector3.RIGHT).normalized()
	mi.global_transform = Transform3D(Basis(side, up, side.cross(up)), pos)
	mi.scale = Vector3(radius * 0.3, radius * 0.1, radius * 0.3)
	var tween := mi.create_tween().set_parallel()
	tween.tween_property(mi, "scale", Vector3(radius, radius * 0.25, radius), life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(mat, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(mi.queue_free)


## A solid piece thrown off and tumbling away: an ejected magazine.
static func chunk(parent: Node, pos: Vector3, size: Vector3, color: Color, velocity: Vector3, life := 0.7) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	_throw(mi, pos, velocity, life, 12.0)


## A brief point light: muzzle flashes light up the walls around you.
static func light(parent: Node, pos: Vector3, color: Color, energy := 2.0, range_m := 4.0, life := 0.05) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = pos
	var tween := l.create_tween()
	tween.tween_property(l, "light_energy", 0.0, life)
	tween.tween_callback(l.queue_free)


static func _blob(parent: Node, pos: Vector3, color: Color, size: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = _material(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	return mi


## Ballistic arc, done as a tweened method so nothing needs a physics body.
static func _throw(mi: Node3D, pos: Vector3, v: Vector3, life: float, gravity := 14.0) -> void:
	var spin := Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20))
	var tween := mi.create_tween()
	tween.tween_method(func(t: float):
		if is_instance_valid(mi):
			mi.global_position = pos + v * t + Vector3.DOWN * 0.5 * gravity * t * t
			mi.rotation = spin * t
			mi.scale = Vector3.ONE * clampf((life - t) / (life * 0.3), 0.0, 1.0)
	, 0.0, life, life)
	tween.tween_callback(mi.queue_free)


static func _star_mesh(points: int, mat: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	for i in points:
		var a0 := TAU * i / points
		var a1 := TAU * (i + 0.5) / points
		var a2 := TAU * (i + 1) / points
		var long := 1.0 if i % 2 == 0 else 0.7
		verts.append(Vector3.ZERO)
		verts.append(Vector3(cos(a0), sin(a0), 0) * 0.28)
		verts.append(Vector3(cos(a1), sin(a1), 0) * long)
		verts.append(Vector3.ZERO)
		verts.append(Vector3(cos(a1), sin(a1), 0) * long)
		verts.append(Vector3(cos(a2), sin(a2), 0) * 0.28)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	return mesh


static func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	return mat


static func _fade(node: Node, mat: StandardMaterial3D, life: float) -> void:
	var tween := node.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, life)
	tween.tween_callback(node.queue_free)
