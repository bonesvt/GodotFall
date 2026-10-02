extends RefCounted
## Shared helpers for building run levels out of boxes, signs and markers.

static var _checker: ImageTexture


static func box(parent: Node, pos: Vector3, size: Vector3, color: Color, rot_deg := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot_deg
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = checker()
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	parent.add_child(body)
	return body


## A flat glowing disc, used for objective rings and slam telegraphs.
static func disc(parent: Node, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.06
	mesh.material = glow(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


static func glow(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	return mat


static func label(parent: Node, pos: Vector3, text: String, font_size := 96) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = font_size
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 16
	parent.add_child(l)
	return l


static func checker() -> ImageTexture:
	if _checker == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
		for y in 64:
			for x in 64:
				var light := ((x >> 5) + (y >> 5)) % 2 == 0
				img.set_pixel(x, y, Color(1, 1, 1) if light else Color(0.82, 0.82, 0.82))
		img.generate_mipmaps()
		_checker = ImageTexture.create_from_image(img)
	return _checker


static func environment(parent: Node, top: Color, horizon: Color) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_bottom_color = horizon.darkened(0.6)
	sky_mat.ground_horizon_color = horizon
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = horizon
	env.fog_density = 0.004
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	parent.add_child(sun)
