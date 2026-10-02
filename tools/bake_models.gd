extends SceneTree
## Builds the PS2-style model scenes in assets/models/ out of low-poly primitives.
## Run after importing textures (opening the editor once does that):
##   godot --headless --import
##   godot -s res://tools/bake_models.gd
## (not --headless: the per-part shader parameters only save with a renderer;
## on a server use xvfb-run.)
## Re-running overwrites the .tscn files. You can also edit the saved scenes
## in the editor; every part is a plain MeshInstance3D with a primitive mesh.
## Models face -Z with their origin at the feet, like the gameplay nodes.
## Titans are not built here: see tools/titans/build_titans.py.
## Pass model names after "--" to rebuild only those, e.g.
##   godot -s res://tools/bake_models.gd -- smart_pistol grunt
## (Eco herself is sculpted in Blender: see tools/eco/.)

const MODEL_SCRIPT := preload("res://scripts/ps2/ps2_model.gd")
const OUT := "res://assets/models/"

var M := {}


func _init() -> void:
	for m in ["gunmetal", "glove", "pilot_suit", "grunt_fabric", "grunt_armor", "visor",
			"titan_armor", "titan_frame", "titan_glow", "light", "anchor", "cover",
			"skin", "canvas"]:
		M[m] = load("res://assets/materials/%s.tres" % m)
	var only := OS.get_cmdline_user_args()
	var want := func(id: String) -> bool: return only.is_empty() or only.has(id)
	if want.call("smart_pistol"):
		_smart_pistol()
	if want.call("grunt"):
		_grunt()
	if want.call("props"):
		_cache()
		_beacon()
	quit()


# --- helpers ---------------------------------------------------------------

func _root(name: String) -> Node3D:
	var root := Node3D.new()
	root.name = name
	root.set_script(MODEL_SCRIPT)
	return root


func _pivot(parent: Node3D, name: String, pos: Vector3, rot_deg := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	n.rotation_degrees = rot_deg
	parent.add_child(n)
	return n


## kind: "box" (size), "cyl" (x radius, y height, z segments), "cone" (x bottom
## radius, y height, z top radius), "sphere" (x radius), "hemi" (x radius),
## "capsule" (x radius, y height), "prism" (size).
func _part(parent: Node3D, name: String, kind: String, size: Vector3, pos: Vector3,
		mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh: PrimitiveMesh
	match kind:
		"box":
			mesh = BoxMesh.new()
			mesh.size = size
		"cyl", "cone":
			mesh = CylinderMesh.new()
			mesh.bottom_radius = size.x
			mesh.top_radius = size.x if kind == "cyl" else size.z
			mesh.height = size.y
			mesh.radial_segments = int(size.z) if kind == "cyl" and size.z >= 3.0 else 8
			mesh.rings = 0
		"sphere", "hemi":
			mesh = SphereMesh.new()
			mesh.radius = size.x
			mesh.height = size.x * (1.0 if kind == "hemi" else 2.0)
			mesh.is_hemisphere = kind == "hemi"
			mesh.radial_segments = 8
			mesh.rings = 3 if kind == "hemi" else 5
		"capsule":
			mesh = CapsuleMesh.new()
			mesh.radius = size.x
			mesh.height = size.y
			mesh.radial_segments = 8
			mesh.rings = 2
		"prism":
			mesh = PrismMesh.new()
			mesh.size = size
		"ell":  # smooth ellipsoid: x radius, scaled per axis by the node (see _ell)
			mesh = SphereMesh.new()
			mesh.radius = size.x
			mesh.height = size.x * 2.0
			mesh.radial_segments = 12
			mesh.rings = 7
		"torus":  # x inner radius, y outer radius
			mesh = TorusMesh.new()
			mesh.inner_radius = size.x
			mesh.outer_radius = size.y
			mesh.rings = 12
			mesh.ring_segments = 6
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


## Ellipsoid: a smooth sphere of radius r stretched by `stretch`.
func _ell(parent: Node3D, name: String, r: float, stretch: Vector3, pos: Vector3,
		mat: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := _part(parent, name, "ell", Vector3(r, 0, 0), pos, mat, rot_deg)
	mi.scale = stretch
	return mi


## Cone from `base` toward `dir`, tapering to a point (hair spikes, built along
## +Y so the hair shader can sway their tips).
func _spike(parent: Node3D, name: String, base: Vector3, dir: Vector3, length: float,
		radius: float, mat: Material) -> MeshInstance3D:
	dir = dir.normalized()
	var mi := _part(parent, name, "cone", Vector3(radius, length, 0.0), base + dir * length * 0.5, mat)
	mi.quaternion = Quaternion(Vector3.UP, dir)
	return mi


func _painted(mat_name: String, color: Color) -> ShaderMaterial:
	var m: ShaderMaterial = M[mat_name].duplicate()
	m.set_shader_parameter("albedo", color)
	return m


func _save(root: Node3D, file: String) -> void:
	get_root().add_child(root)  # instance shader parameters only stick inside the tree
	_own(root, root)
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, OUT + file)
	print("%s %s" % [file, "saved" if err == OK else "FAILED (%d)" % err])
	root.free()


func _own(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		if c.scene_file_path != "":
			continue  # an instanced scene keeps its own nodes
		if c is GeometryInstance3D:
			# Height of each vertex above the model's feet, for the shader's fake occlusion.
			var xf := Transform3D.IDENTITY
			var n: Node = c
			while n != owner_node:
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			var row := Vector4(xf.basis.x.y, xf.basis.y.y, xf.basis.z.y, xf.origin.y)
			(c as GeometryInstance3D).set_instance_shader_parameter("part_height_row", row)
		_own(c, owner_node)


# --- Eco's sidearm: her father's smart pistol (first-person viewmodel) -------
# The gun itself is modelled in Blender (tools/pistol/build_pistol.py ->
# assets/models/smart_pistol/smart_pistol.glb); this puts it in Eco's hand.

func _smart_pistol() -> void:
	var r := _root("SmartPistol")
	var gun: Node3D = load("res://assets/models/smart_pistol/smart_pistol.glb").instantiate()
	gun.name = "Gun"
	r.add_child(gun)
	# Eco's arm: fingerless glove round the grip, sleeve rolled up (sculpted in tools/eco/)
	var arm: Node3D = load("res://assets/models/eco/eco_fp_arm.glb").instantiate()
	arm.name = "Arm"
	r.add_child(arm)
	_save(r, "smart_pistol.tscn")


# --- grunt -----------------------------------------------------------------

func _grunt() -> void:
	var r := _root("Grunt")
	var cloth: Material = M["grunt_fabric"]
	var plate: Material = M["grunt_armor"]
	var g: Material = M["gunmetal"]
	var glove: Material = M["glove"]
	for side in [-1.0, 1.0]:
		var leg := _pivot(r, "LegL" if side < 0.0 else "LegR", Vector3(side * 0.11, 0.92, 0))
		_part(leg, "Thigh", "capsule", Vector3(0.09, 0.5, 0), Vector3(0, -0.22, 0), cloth)
		_part(leg, "Knee", "box", Vector3(0.13, 0.12, 0.07), Vector3(0, -0.46, -0.08), plate)
		_part(leg, "Shin", "capsule", Vector3(0.08, 0.44, 0), Vector3(0, -0.65, 0), cloth)
		_part(leg, "Boot", "box", Vector3(0.17, 0.15, 0.3), Vector3(0, -0.845, -0.05), glove)
	_part(r, "Pelvis", "box", Vector3(0.34, 0.16, 0.2), Vector3(0, 0.98, 0), cloth)
	_part(r, "Belly", "box", Vector3(0.32, 0.26, 0.2), Vector3(0, 1.15, 0), cloth)
	_part(r, "Belt", "box", Vector3(0.35, 0.05, 0.22), Vector3(0, 1.04, 0), glove)
	_part(r, "Vest", "box", Vector3(0.42, 0.36, 0.27), Vector3(0, 1.37, 0), plate)
	for x in [-0.11, 0.0, 0.11]:
		_part(r, "Pouch", "box", Vector3(0.09, 0.1, 0.05), Vector3(x, 1.26, -0.155), cloth)
	_part(r, "Pack", "box", Vector3(0.3, 0.32, 0.14), Vector3(0, 1.36, 0.2), cloth)
	_part(r, "Radio", "box", Vector3(0.1, 0.16, 0.08), Vector3(0.1, 1.5, 0.22), g)
	_part(r, "Antenna", "cyl", Vector3(0.008, 0.36, 4), Vector3(0.12, 1.75, 0.23), g)
	for side in [-1.0, 1.0]:
		_part(r, "Pad", "box", Vector3(0.14, 0.08, 0.17), Vector3(side * 0.26, 1.51, 0), plate, Vector3(0, 0, side * -15))
	# head: balaclava, helmet, glowing visor (grunt.gd tints the "Visor" nodes)
	_part(r, "Neck", "cyl", Vector3(0.06, 0.08, 6), Vector3(0, 1.56, 0), cloth)
	_part(r, "Head", "sphere", Vector3(0.13, 0, 0), Vector3(0, 1.65, 0), M["glove"])
	_part(r, "Helmet", "hemi", Vector3(0.17, 0, 0), Vector3(0, 1.67, 0.01), plate)
	_part(r, "HelmetRim", "cyl", Vector3(0.175, 0.035, 8), Vector3(0, 1.675, 0.01), plate)
	_part(r, "Visor", "box", Vector3(0.24, 0.06, 0.05), Vector3(0, 1.645, -0.125), M["visor"])
	_part(r, "Rebreather", "box", Vector3(0.08, 0.06, 0.06), Vector3(0, 1.575, -0.11), g)
	# rifle, held at the hip on the right (matches grunt.gd MUZZLE)
	var gun := _pivot(r, "Rifle", Vector3(0.22, 1.22, 0))
	_part(gun, "Body", "box", Vector3(0.07, 0.12, 0.48), Vector3(0, 0, -0.24), g)
	_part(gun, "Barrel", "cyl", Vector3(0.02, 0.18, 6), Vector3(0, 0.02, -0.56), g, Vector3(90, 0, 0))
	_part(gun, "Stock", "box", Vector3(0.05, 0.1, 0.22), Vector3(0, -0.03, 0.1), g)
	_part(gun, "Mag", "box", Vector3(0.05, 0.16, 0.07), Vector3(0, -0.12, -0.3), g, Vector3(15, 0, 0))
	_part(gun, "Sight", "box", Vector3(0.04, 0.05, 0.12), Vector3(0, 0.085, -0.18), g)
	# arms: right hand on the grip, left hand on the handguard
	_part(r, "ArmRUpper", "capsule", Vector3(0.065, 0.32, 0), Vector3(0.29, 1.32, 0.02), cloth, Vector3(10, 0, 0))
	_part(r, "ArmRLower", "box", Vector3(0.1, 0.1, 0.24), Vector3(0.27, 1.18, -0.05), cloth)
	_part(r, "HandR", "box", Vector3(0.1, 0.1, 0.1), Vector3(0.23, 1.16, -0.15), glove)
	_part(r, "ArmLUpper", "capsule", Vector3(0.065, 0.32, 0), Vector3(-0.26, 1.3, -0.06), cloth, Vector3(25, 0, 0))
	_part(r, "ArmLLower", "box", Vector3(0.1, 0.1, 0.46), Vector3(-0.03, 1.19, -0.27), cloth, Vector3(0, -51, 0))
	_part(r, "HandL", "box", Vector3(0.1, 0.1, 0.1), Vector3(0.16, 1.19, -0.42), glove)
	_save(r, "grunt.tscn")


# --- titans ----------------------------------------------------------------
# The titans and their weapons are built in Blender now: tools/titans/.


# --- salvage cache and extraction beacon ------------------------------------

func _cache() -> void:
	var r := _root("SalvageCache")
	_part(r, "Base", "box", Vector3(1.6, 0.7, 1.0), Vector3(0, 0.35, 0), M["titan_frame"])
	_part(r, "Lid", "box", Vector3(1.7, 0.24, 1.1), Vector3(0, 0.82, 0), M["anchor"])
	for z in [-0.51, 0.51]:
		_part(r, "Light", "box", Vector3(1.4, 0.08, 0.04), Vector3(0, 0.55, z), M["light"])
	for x in [-0.86, 0.86]:
		_part(r, "Handle", "box", Vector3(0.08, 0.1, 0.5), Vector3(x, 0.5, 0), M["gunmetal"])
	_part(r, "Mast", "cyl", Vector3(0.03, 0.9, 4), Vector3(0.62, 1.35, 0.32), M["gunmetal"])
	_part(r, "LightTip", "sphere", Vector3(0.07, 0, 0), Vector3(0.62, 1.82, 0.32), M["light"])
	_save(r, "salvage_cache.tscn")


func _beacon() -> void:
	var r := _root("ExtractBeacon")
	_part(r, "Base", "cyl", Vector3(0.9, 0.25, 8), Vector3(0, 0.125, 0), M["gunmetal"])
	_part(r, "Tier", "cyl", Vector3(0.6, 0.3, 8), Vector3(0, 0.4, 0), M["titan_frame"])
	for i in 3:
		var a := TAU * i / 3.0
		_part(r, "Strut", "box", Vector3(0.2, 0.25, 0.7), Vector3(cos(a) * 0.95, 0.12, sin(a) * 0.95), M["anchor"], Vector3(0, -rad_to_deg(a) + 90.0, 0))
	_part(r, "Pole", "cyl", Vector3(0.1, 2.2, 6), Vector3(0, 1.65, 0), M["gunmetal"])
	_part(r, "Light", "sphere", Vector3(0.25, 0, 0), Vector3(0, 2.9, 0), M["light"])
	_part(r, "LightRing", "cyl", Vector3(0.4, 0.08, 8), Vector3(0, 2.6, 0), M["light"])
	_save(r, "extract_beacon.tscn")

