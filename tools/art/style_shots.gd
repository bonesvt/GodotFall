extends SceneTree
## Art-style concept renders of the temple base. Each view is shot three ways:
##   current  the game as it looks today (PS3 look);
##   anime    "Anime Match": the set repainted to sit with the characters'
##            VRoid toon shading (flat painted colour, cel light, lavender
##            shadows, ink lines in Eco's ink colour);
##   bebop    "90s Session": a late-90s cel anime look (hard shadows, gouache
##            backgrounds, muted palette with warm accents, film grain).
## Nothing here changes the game: the styles are swapped in at render time
## (concept_*.gdshader on every set surface, concept_post.gdshader on screen).
##   xvfb-run -a godot --path . -s res://tools/art/style_shots.gd -- [out_dir] [--only=hall,camp] [--styles=anime,bebop] [--small]
## Writes <out_dir>/<view>_<style>.png.

const Art := preload("res://scripts/ps2/ps2_assets.gd")
const SURFACE := preload("res://assets/shaders/ps2_surface.gdshader")
const STYLE_SHADERS := {
	"anime": preload("res://tools/art/concept_anime.gdshader"),
	"bebop": preload("res://tools/art/concept_bebop.gdshader"),
}
const POST := preload("res://tools/art/concept_post.gdshader")

const F := 1.2
const UP := 5.7
const CULL := 50.0
## name: [eye (feet), look-at, Eco's spot (feet) or null, Eco's yaw (deg)]
const VIEWS := {
	"hall": [Vector3(1.5, F, 7.0), Vector3(-1.0, F + 2.2, -26), Vector3(0.2, F, 2.4), 165.0],
	"loft": [Vector3(-7.4, UP, -5.5), Vector3(-10.0, UP + 0.4, -14), Vector3(-8.0, UP, -8.6), 150.0],
	"camp": [Vector3(37.0, 0.05, 25.0), Vector3(33.0, 2.0, 3.0), Vector3(35.2, 0.0, 20.0), 170.0],
	"temple": [Vector3(2.0, 0.05, 31.0), Vector3(-9.0, 3.0, 13.0), Vector3(0.6, 0.0, 27.6), 130.0],
}

## Per style: environment, sun and screen-pass settings.
const LOOKS := {
	"anime": {
		"ambient": Color(0.78, 0.76, 0.95), "ambient_energy": 0.75,
		"sun": Color(1.0, 0.94, 0.82), "sun_energy": 1.5, "shadow_opacity": 0.9,
		"fog": Color(0.75, 0.82, 0.95), "fog_density": 0.003,
		"saturation_env": 1.05, "contrast_env": 1.0, "exposure": 1.05, "ssao": false,
		"post": {
			"paint_radius": 3, "ink": Color(0.25, 0.19, 0.23, 1.0), "ink_width": 1.4,
			"depth_edge": 0.06, "normal_edge": 0.3, "ink_far": 40.0,
			"saturation": 0.95, "contrast": 1.04, "split": 0.25,
			"shadow_tone": Color(0.47, 0.45, 0.62), "highlight_tone": Color(0.56, 0.52, 0.47),
			"black_lift": 0.03, "halation": 0.0, "vignette": 0.12, "grain": 0.0, "paper": 0.0,
		},
	},
	"bebop": {
		"ambient": Color(0.45, 0.55, 0.72), "ambient_energy": 0.8,
		"sun": Color(1.0, 0.78, 0.5), "sun_energy": 1.9, "shadow_opacity": 1.0,
		"fog": Color(0.62, 0.52, 0.42), "fog_density": 0.006,
		"saturation_env": 0.95, "contrast_env": 1.05, "exposure": 1.2, "ssao": true,
		"post": {
			"paint_radius": 5, "ink": Color(0.08, 0.06, 0.08, 1.0), "ink_width": 1.8,
			"depth_edge": 0.07, "normal_edge": 0.4, "ink_far": 30.0,
			"saturation": 0.82, "contrast": 1.12, "split": 0.4,
			"shadow_tone": Color(0.36, 0.46, 0.58), "highlight_tone": Color(0.64, 0.52, 0.36),
			"black_lift": 0.14, "halation": 0.5, "halation_color": Color(1.0, 0.4, 0.2),
			"vignette": 0.35, "grain": 0.035, "grain_size": 1.4, "paper": 0.12,
		},
	},
}

var run_node
var out := "user://style_shots"
var only: Array[String] = []
var styles: Array[String] = ["current", "anime", "bebop"]
var small := false
var _parked: Array = []
var _mats: Array[ShaderMaterial] = []
var _env: Environment
var _env_orig := {}
var _sun: DirectionalLight3D
var _sun_orig := {}
var _post: MeshInstance3D
var _eco: Node3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only.assign(a.trim_prefix("--only=").split(","))
		elif a.begins_with("--styles="):
			styles.assign(a.trim_prefix("--styles=").split(","))
		elif a == "--small":
			small = true
		elif not a.begins_with("--"):
			out = a
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(960, 540) if small else Vector2i(1600, 900)
	preload("res://scripts/run/tutorial.gd").settings_path = "user://shots_settings.cfg"
	run_node = load("res://scenes/run.tscn").instantiate()
	run_node.run_seed = 1234
	root.add_child(run_node)
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	await _frames(2)
	run_node.tutorial.set_enabled(false)
	await _frames(18)
	for n in ["hud", "pilot_hud"]:
		if n in run_node and run_node.get(n) != null:
			run_node.get(n).visible = false
	var ps2 = root.get_node_or_null("PS2")
	var player = run_node.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var cam: Camera3D = player.get_node("Head/Camera3D")
	cam.fov = 68.0
	for child in cam.get_children():
		if child is Node3D:
			child.visible = false
	_post = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	_post.mesh = quad
	_post.extra_cull_margin = 16384.0
	_post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ShaderMaterial.new()
	pm.shader = POST
	_post.material_override = pm
	_post.visible = false
	cam.add_child(_post)
	_eco = Art.model("eco")
	run_node.add_child(_eco)

	for view in VIEWS:
		if not only.is_empty() and not view in only:
			continue
		var v: Array = VIEWS[view]
		var at: Vector3 = v[0]
		var look: Vector3 = v[1]
		await _cull(at, look, CULL)
		_collect()
		player.global_position = at
		var eye := at + Vector3(0, 1.6, 0)
		var d := look - eye
		player.rotation.y = atan2(-d.x, -d.z)
		player.get_node("Head").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		cam.far = 1200.0
		_eco.global_position = v[2]
		_eco.rotation_degrees.y = v[3]
		for style in styles:
			_apply(style, ps2)
			await _frames(40)
			_post.visible = style != "current"
			await _frames(3)
			root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [view, style]))
			print("shot ", view, " ", style)
			_post.visible = false
	quit()


## Every ShaderMaterial in the scene that uses the game's surface shader.
func _collect() -> void:
	var seen := {}
	for m in _mats:
		seen[m] = true
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mats: Array = []
		if n is GeometryInstance3D:
			mats.append(n.material_override)
		if n is MeshInstance3D and n.mesh != null:
			for i in n.mesh.get_surface_count():
				mats.append(n.get_surface_override_material(i))
				mats.append(n.mesh.surface_get_material(i))
		if n is MultiMeshInstance3D and n.multimesh != null and n.multimesh.mesh != null:
			for i in n.multimesh.mesh.get_surface_count():
				mats.append(n.multimesh.mesh.surface_get_material(i))
		if n is CSGShape3D:
			mats.append(n.get("material"))
		for m in mats:
			while m != null:
				if m is ShaderMaterial and not seen.has(m) and (m.shader == SURFACE or STYLE_SHADERS.values().has(m.shader)):
					seen[m] = true
					_mats.append(m)
				m = m.next_pass if m is Material else null
		if n is WorldEnvironment and _env == null:
			_env = n.environment
			for p in ["ambient_light_color", "ambient_light_energy", "fog_light_color", "fog_density", "adjustment_saturation", "adjustment_contrast", "tonemap_exposure", "ssao_enabled"]:
				_env_orig[p] = _env.get(p)
		if n is DirectionalLight3D and _sun == null:
			_sun = n
			for p in ["light_color", "light_energy", "shadow_opacity"]:
				_sun_orig[p] = _sun.get(p)


func _apply(style: String, ps2) -> void:
	for m in _mats:
		m.shader = STYLE_SHADERS.get(style, SURFACE)
	if ps2 != null and "_rect" in ps2:
		ps2._rect.visible = style == "current"
	if style == "current":
		for p in _env_orig:
			_env.set(p, _env_orig[p])
		for p in _sun_orig:
			_sun.set(p, _sun_orig[p])
		return
	var L: Dictionary = LOOKS[style]
	if _env != null:
		_env.ambient_light_color = L["ambient"]
		_env.ambient_light_energy = L["ambient_energy"]
		_env.fog_light_color = L["fog"]
		_env.fog_density = L["fog_density"]
		_env.adjustment_saturation = L["saturation_env"]
		_env.adjustment_contrast = L["contrast_env"]
		_env.tonemap_exposure = L["exposure"]
		_env.ssao_enabled = L["ssao"]
	if _sun != null:
		_sun.light_color = L["sun"]
		_sun.light_energy = L["sun_energy"]
		_sun.shadow_opacity = L["shadow_opacity"]
	var pm: ShaderMaterial = _post.material_override
	for k in L["post"]:
		pm.set_shader_parameter(k, L["post"][k])


## Same culling as tools/hub/base_shots.gd: a software renderer runs out of
## instance shader parameter slots on the whole hub, so keep only what's near.
func _cull(eye: Vector3, look: Vector3, reach: float) -> void:
	var zr: Node3D = run_node.zone_root
	for n in zr.get_children():
		zr.remove_child(n)
		_parked.append(n)
	await process_frame
	var keep := []
	for n in _parked:
		if not n is Node3D or n is WorldEnvironment or n is DirectionalLight3D or n is MultiMeshInstance3D:
			keep.append(n)
			continue
		var p: Vector3 = (n as Node3D).position
		var flat := Vector2(p.x, p.z)
		if flat.distance_to(Vector2(eye.x, eye.z)) < reach or flat.distance_to(Vector2(look.x, look.z)) < reach * 0.6:
			keep.append(n)
	for n in keep:
		_parked.erase(n)
		zr.add_child(n)
	await process_frame
	for n in keep:
		var stack: Array = [n]
		while not stack.is_empty():
			var g: Node = stack.pop_back()
			stack.append_array(g.get_children())
			if g is GeometryInstance3D:
				for prop in g.get_property_list():
					var pn: String = prop["name"]
					if pn.begins_with("instance_shader_parameters/"):
						var key := pn.substr(27)
						g.set_instance_shader_parameter(key, g.get_instance_shader_parameter(key))
