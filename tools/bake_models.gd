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
	if want.call("titans"):
		for id in TITANS:
			_titan(id, TITANS[id])
		for id in ["xo16", "tracker", "splitter", "scrap"]:
			_titan_weapon(id)
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

## Chassis proportions: w/d/h torso, leg thickness, leg spread, shoulder scale,
## hip height, paint, and a weapon for the enemy variant.
const TITANS := {
	"atlas": {"w": 2.6, "d": 1.8, "h": 2.0, "leg": 0.8, "spread": 0.75, "sh": 1.0, "hip": 3.0,
		"paint": Color(0.62, 0.7, 0.8)},
	"ogre": {"w": 3.2, "d": 2.2, "h": 2.2, "leg": 1.0, "spread": 0.95, "sh": 1.3, "hip": 2.9,
		"paint": Color(0.8, 0.72, 0.52)},
	"stryder": {"w": 2.0, "d": 1.4, "h": 1.6, "leg": 0.55, "spread": 0.6, "sh": 0.8, "hip": 3.4,
		"paint": Color(0.9, 0.9, 0.92), "accent": Color(1.0, 0.55, 0.15)},
	"scrap": {"w": 2.5, "d": 1.8, "h": 1.9, "leg": 0.75, "spread": 0.75, "sh": 1.0, "hip": 3.0,
		"paint": Color(0.62, 0.45, 0.34), "scrap": true},
	"enemy": {"w": 3.2, "d": 2.2, "h": 2.2, "leg": 1.0, "spread": 0.95, "sh": 1.3, "hip": 2.9,
		"paint": Color(0.75, 0.22, 0.18), "accent": Color(0.2, 0.2, 0.22)},
}


func _titan(id: String, p: Dictionary) -> void:
	var r := _root("Titan_" + id)
	r.set("stride", 4.5)
	r.set("swing_degrees", 22.0)
	var armor := _painted("titan_armor", p["paint"])
	var accent := _painted("titan_armor", p.get("accent", Color(p["paint"]).darkened(0.25)))
	var frame: Material = M["titan_frame"]
	var glow: Material = M["titan_glow"]
	var scrap: bool = p.get("scrap", false)
	var w: float = p["w"]
	var d: float = p["d"]
	var h: float = p["h"]
	var lw: float = p["leg"]
	var hip: float = p["hip"]
	var sh: float = p["sh"]

	_part(r, "Pelvis", "box", Vector3(w * 0.58, 0.6, d * 0.55), Vector3(0, hip, 0), frame)
	for side in [-1.0, 1.0]:
		var leg := _pivot(r, "LegL" if side < 0.0 else "LegR", Vector3(side * (w * 0.29 + lw * 0.45), hip, 0))
		var thigh_mat: Material = M["cover"] if scrap and side > 0.0 else armor
		_part(leg, "Hip", "cyl", Vector3(lw * 0.45, lw + 0.1, 8), Vector3(0, 0, 0), frame, Vector3(0, 0, 90))
		_part(leg, "Thigh", "box", Vector3(lw, hip * 0.46, lw + 0.1), Vector3(0, -hip * 0.25, 0), thigh_mat)
		_part(leg, "Knee", "cyl", Vector3(lw * 0.42, lw + 0.12, 8), Vector3(0, -hip * 0.5, 0), frame, Vector3(0, 0, 90))
		_part(leg, "KneePlate", "box", Vector3(lw * 0.8, lw * 0.7, 0.2), Vector3(0, -hip * 0.5, -lw * 0.55), accent, Vector3(-10, 0, 0))
		_part(leg, "Shin", "box", Vector3(lw + 0.1, hip * 0.4, lw + 0.25), Vector3(0, -hip * 0.72, 0.04), armor)
		_part(leg, "Foot", "box", Vector3(lw + 0.3, hip * 0.11, lw + 1.0), Vector3(0, -hip * 0.945, -0.25), frame)
		_part(leg, "Toe", "prism", Vector3(lw + 0.3, 0.3, 0.5), Vector3(0, -hip * 0.97, -0.25 - (lw + 1.0) * 0.5 - 0.2), frame, Vector3(-90, 0, 0))
	_part(r, "Waist", "cyl", Vector3(w * 0.22, 0.6, 8), Vector3(0, hip + 0.5, 0), frame)
	var ty := hip + 0.75 + h * 0.5
	var torso := _part(r, "Torso", "box", Vector3(w, h, d), Vector3(0, ty, 0), armor)
	if scrap:
		torso.rotation_degrees.z = 2.0
	_part(r, "ChestLower", "prism", Vector3(w * 0.9, 0.5, d), Vector3(0, ty - h * 0.5 - 0.2, 0), armor, Vector3(180, 0, 0))
	_part(r, "Hatch", "box", Vector3(w * 0.55, h * 0.62, 0.14), Vector3(0, ty - h * 0.05, -d * 0.5 - 0.05), accent)
	for side in [-1.0, 1.0]:
		_part(r, "HatchHinge", "box", Vector3(0.12, h * 0.5, 0.18), Vector3(side * w * 0.3, ty - h * 0.05, -d * 0.5 - 0.05), frame)
	_part(r, "Eye", "box", Vector3(w * 0.34, 0.16, 0.12), Vector3(0, ty + h * 0.34, -d * 0.5 - 0.04), glow)
	_part(r, "Brow", "box", Vector3(w * 0.5, 0.14, 0.3), Vector3(0, ty + h * 0.45, -d * 0.5 - 0.05), accent)
	_part(r, "Back", "box", Vector3(w * 0.7, h * 0.75, 0.8), Vector3(0, ty - 0.05, d * 0.5 + 0.35), frame)
	for side in [-1.0, 1.0]:
		_part(r, "Vent", "cyl", Vector3(0.18, 0.6, 6), Vector3(side * w * 0.2, ty + h * 0.35, d * 0.5 + 0.55), frame)
	_part(r, "Core", "box", Vector3(w * 0.3, 0.3, 0.12), Vector3(0, ty - h * 0.2, d * 0.5 + 0.77), glow)

	for side in [-1.0, 1.0]:
		var arm := _pivot(r, "ArmL" if side < 0.0 else "ArmR", Vector3(side * (w * 0.5 + 0.35 * sh), ty + h * 0.3, 0))
		if not (scrap and side < 0.0):
			_part(arm, "Pad", "box", Vector3(0.95, 0.75, 1.25) * sh, Vector3(side * 0.1, 0.1, 0), accent if side > 0.0 else armor, Vector3(0, 0, side * -10))
		_part(arm, "Shoulder", "sphere", Vector3(0.42 * sh, 0, 0), Vector3.ZERO, frame)
		_part(arm, "Upper", "box", Vector3(0.5, 1.1, 0.5) * Vector3(sh, 1, sh), Vector3(0, -0.75, 0), frame)
		_part(arm, "Elbow", "cyl", Vector3(0.3 * sh, 0.6 * sh, 8), Vector3(0, -1.4, 0), frame, Vector3(0, 0, 90))
		_part(arm, "Forearm", "box", Vector3(0.7, 0.7, 1.5) * sh, Vector3(0, -1.45, -0.55 * sh), armor)
		if side < 0.0:
			_part(arm, "Fist", "box", Vector3(0.55, 0.55, 0.5) * sh, Vector3(0, -1.45, -1.45 * sh), frame)
		else:
			_pivot(arm, "WeaponMount", Vector3(0, -1.45, -1.2 * sh))
	if scrap:
		_part(r, "Patch", "box", Vector3(0.8, 0.6, 0.06), Vector3(-w * 0.3, ty + h * 0.15, -d * 0.5 - 0.03), M["cover"], Vector3(0, 0, 12))
	_save(r, "titan_%s.tscn" % id)


func _titan_weapon(id: String) -> void:
	var r := _root("TitanWeapon_" + id)
	var frame: Material = M["titan_frame"]
	var steel := _painted("titan_armor", Color(0.5, 0.52, 0.55))
	match id:
		"xo16":
			_part(r, "Body", "box", Vector3(0.65, 0.75, 1.4), Vector3(0, 0, -0.5), steel)
			_part(r, "Drum", "cyl", Vector3(0.45, 0.5, 8), Vector3(0.55, -0.05, -0.35), frame, Vector3(0, 0, 90))
			for i in 6:
				var a := TAU * i / 6.0
				_part(r, "Barrel", "cyl", Vector3(0.07, 1.7, 5), Vector3(cos(a) * 0.18, sin(a) * 0.18, -2.0), frame, Vector3(90, 0, 0))
			_part(r, "Shroud", "cyl", Vector3(0.32, 0.3, 8), Vector3(0, 0, -1.35), steel, Vector3(90, 0, 0))
			_part(r, "Tip", "cyl", Vector3(0.3, 0.25, 8), Vector3(0, 0, -2.75), steel, Vector3(90, 0, 0))
		"tracker":
			_part(r, "Body", "box", Vector3(0.75, 0.85, 1.8), Vector3(0, 0.05, -0.7), steel)
			_part(r, "Barrel", "cyl", Vector3(0.22, 1.6, 8), Vector3(0, 0.1, -2.4), frame, Vector3(90, 0, 0))
			_part(r, "Brake", "box", Vector3(0.62, 0.36, 0.4), Vector3(0, 0.1, -3.2), steel)
			_part(r, "Mag", "box", Vector3(0.4, 0.6, 0.5), Vector3(0, -0.6, -0.5), frame)
			_part(r, "Sight", "box", Vector3(0.18, 0.12, 0.3), Vector3(0, 0.55, -0.9), M["titan_glow"])
		"splitter":
			_part(r, "Body", "box", Vector3(0.5, 0.62, 2.6), Vector3(0, 0, -1.1), steel)
			for side in [-1.0, 1.0]:
				_part(r, "Prong", "box", Vector3(0.12, 0.18, 1.0), Vector3(side * 0.16, 0, -2.85), frame)
			_part(r, "Glow", "box", Vector3(0.52, 0.08, 1.8), Vector3(0, 0.2, -1.1), M["titan_glow"])
			_part(r, "Cell", "box", Vector3(0.35, 0.45, 0.6), Vector3(0, -0.45, -0.4), frame)
		_:
			_part(r, "Body", "box", Vector3(0.5, 0.55, 1.6), Vector3(0, 0, -0.6), M["cover"], Vector3(0, 0, 4))
			_part(r, "Barrel", "cyl", Vector3(0.14, 1.5, 6), Vector3(0.03, 0.05, -2.1), frame, Vector3(90, 0, 0))
			for z in [-0.2, -1.0]:
				_part(r, "Tape", "box", Vector3(0.56, 0.6, 0.12), Vector3(0, 0, z), M["glove"], Vector3(0, 0, 4))
			_part(r, "Sight", "box", Vector3(0.1, 0.3, 0.1), Vector3(0.1, 0.4, -0.8), frame, Vector3(0, 0, -12))
	_save(r, "titan_weapon_%s.tscn" % id)


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

