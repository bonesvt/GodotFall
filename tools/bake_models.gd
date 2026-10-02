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
		for tier in 6:
			_smart_pistol(tier)
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

## Tier 0 is Dad's broken pistol; 1-5 are Eco's upgrades (build_pistol.py --tier).
func _smart_pistol(tier := 0) -> void:
	var suffix := "" if tier == 0 else "_t%d" % tier
	var r := _root("SmartPistol")
	var gun: Node3D = load("res://assets/models/smart_pistol/smart_pistol%s.glb" % suffix).instantiate()
	gun.name = "Gun"
	r.add_child(gun)
	# Eco's arm: fingerless glove round the grip, sleeve rolled up (sculpted in tools/eco/)
	var arm: Node3D = load("res://assets/models/eco/eco_fp_arm.glb").instantiate()
	arm.name = "Arm"
	r.add_child(arm)
	_save(r, "smart_pistol%s.tscn" % suffix)


# --- grunt -----------------------------------------------------------------
# The grunt is sculpted and assembled in Blender now (tools/grunt/), and
# assets/models/grunt.tscn wraps the exported grunt.glb; nothing to bake here.


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

