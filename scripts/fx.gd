extends RefCounted
## Throwaway combat effects: bullet tracers and impact sparks.
## Everything is unshaded, fades out with a tween and frees itself.


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
