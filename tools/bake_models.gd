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
##   godot -s res://tools/bake_models.gd -- eco smart_pistol

const MODEL_SCRIPT := preload("res://scripts/ps2/ps2_model.gd")
const ECO_SCRIPT := preload("res://scripts/ps2/eco_model.gd")
const OUT := "res://assets/models/"

var M := {}


func _init() -> void:
	for m in ["gunmetal", "glove", "pilot_suit", "grunt_fabric", "grunt_armor", "visor",
			"titan_armor", "titan_frame", "titan_glow", "light", "anchor", "cover",
			"skin", "canvas", "eco_hair"]:
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
	if want.call("eco"):
		_eco()
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


# --- Eco's sidearm: her father's broken smart pistol (first-person viewmodel) -

func _smart_pistol() -> void:
	var r := _root("SmartPistol")
	var body := _painted("gunmetal", Color(0.78, 0.8, 0.84))
	var dark := _painted("gunmetal", Color(0.42, 0.42, 0.46))
	var paint := _painted("titan_armor", Color(0.62, 0.7, 0.8))  # his titan's colours
	var stripe := _painted("titan_armor", Color(1.0, 0.55, 0.2))
	var tape := _painted("canvas", Color(0.72, 0.72, 0.7))
	# chunky smart-pistol upper with a rounded nose
	_part(r, "Upper", "box", Vector3(0.05, 0.06, 0.22), Vector3(0, 0.012, 0.0), paint)
	_part(r, "Nose", "cyl", Vector3(0.03, 0.05, 8), Vector3(0, 0.012, -0.11), paint, Vector3(0, 0, 90))
	_part(r, "Stripe", "box", Vector3(0.052, 0.012, 0.09), Vector3(0, 0.03, 0.05), stripe)
	_part(r, "Frame", "box", Vector3(0.042, 0.03, 0.18), Vector3(0, -0.03, -0.02), dark)
	_part(r, "Barrel", "cyl", Vector3(0.011, 0.03, 6), Vector3(0, 0.005, -0.14), dark, Vector3(90, 0, 0))
	# the auto-lock sensor on top: dead, cracked, taped back on
	_part(r, "SensorHousing", "box", Vector3(0.04, 0.03, 0.07), Vector3(0, 0.057, -0.07), body)
	var lens := _painted("visor", Color(0.9, 0.2, 0.15))
	_part(r, "SensorLens", "cyl", Vector3(0.013, 0.01, 8), Vector3(0, 0.057, -0.106), lens, Vector3(90, 0, 0)) \
		.set_instance_shader_parameter("glow", 0.15)
	_part(r, "SensorCrack", "box", Vector3(0.026, 0.003, 0.003), Vector3(0, 0.058, -0.112), dark, Vector3(0, 0, 35))
	_part(r, "SensorTape", "box", Vector3(0.046, 0.034, 0.016), Vector3(0, 0.054, -0.05), tape)
	_part(r, "Tape", "box", Vector3(0.056, 0.066, 0.025), Vector3(0, 0.012, -0.03), tape)
	# rear sights and the lock display facing the shooter, dark ever since it broke
	_part(r, "RearSight", "box", Vector3(0.034, 0.014, 0.012), Vector3(0, 0.048, 0.1), dark)
	_part(r, "Display", "box", Vector3(0.036, 0.026, 0.004), Vector3(0, 0.02, 0.111), lens) \
		.set_instance_shader_parameter("glow", 0.25)
	_part(r, "Hammer", "box", Vector3(0.014, 0.02, 0.016), Vector3(0, 0.05, 0.118), dark, Vector3(-25, 0, 0))
	_part(r, "Grip", "box", Vector3(0.038, 0.12, 0.054), Vector3(0, -0.088, 0.072), dark, Vector3(-16, 0, 0))
	_part(r, "MagBase", "box", Vector3(0.042, 0.014, 0.06), Vector3(0, -0.15, 0.09), paint, Vector3(-16, 0, 0))
	_part(r, "GuardBottom", "box", Vector3(0.012, 0.008, 0.055), Vector3(0, -0.062, -0.012), dark)
	_part(r, "GuardFront", "box", Vector3(0.012, 0.03, 0.008), Vector3(0, -0.048, -0.04), dark)
	_part(r, "Trigger", "box", Vector3(0.008, 0.022, 0.008), Vector3(0, -0.046, 0.0), body, Vector3(15, 0, 0))
	# Eco's hand: fingerless mechanic's glove, wrapped wrist, sleeve rolled to the elbow
	var glove: Material = M["glove"]
	var skin: Material = M["skin"]
	_part(r, "Palm", "box", Vector3(0.05, 0.085, 0.06), Vector3(0.012, -0.09, 0.098), glove, Vector3(-16, 0, 0))
	_part(r, "GloveBand", "box", Vector3(0.054, 0.03, 0.03), Vector3(0.005, -0.068, 0.042), glove, Vector3(-16, 0, 0))
	_part(r, "Fingers", "box", Vector3(0.05, 0.068, 0.024), Vector3(0.004, -0.098, 0.034), skin, Vector3(-16, 0, 0))
	_part(r, "Thumb", "box", Vector3(0.019, 0.019, 0.068), Vector3(-0.024, -0.04, 0.05), skin, Vector3(0, -8, 0))
	_part(r, "Knuckles", "box", Vector3(0.012, 0.03, 0.05), Vector3(0.038, -0.07, 0.07), _painted("gunmetal", Color(1.6, 1.3, 0.75)), Vector3(-16, 0, 0))
	_part(r, "Wrap", "box", Vector3(0.058, 0.06, 0.07), Vector3(0.016, -0.14, 0.15), _painted("canvas", Color(0.92, 0.88, 0.78)), Vector3(-40, 0, 0))
	_part(r, "Forearm", "cone", Vector3(0.04, 0.32, 0.034), Vector3(0.03, -0.24, 0.29), skin, Vector3(-50, 0, 0))
	_part(r, "Sleeve", "cyl", Vector3(0.05, 0.07, 8), Vector3(0.045, -0.35, 0.42), _painted("canvas", Color(0.86, 0.46, 0.26)), Vector3(-50, 0, 0))
	_pivot(r, "Muzzle", Vector3(0, 0.005, -0.16))
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


# --- Eco, the heroine (third person) ---------------------------------------
# A young mechanic in a makeshift work outfit, Jak and Daxter proportions:
# slightly large head and eyes, chunky gloves and boots, lean athletic build.
# Short white hair with the iridescent eco_hair shader. About 1.75 m to the
# top of the hair. Pivots: LegL/LegR (walk), Upper (breathing), ArmL/ArmR,
# Head (idle look), all driven by scripts/ps2/eco_model.gd.

func _eco() -> void:
	var r := _root("Eco")
	r.set_script(ECO_SCRIPT)
	r.set("stride", 1.5)
	var skin: Material = M["skin"]
	var hair: Material = M["eco_hair"]
	var leather: Material = M["glove"]
	var strap := _painted("glove", Color(0.62, 0.58, 0.56))
	var metal: Material = M["gunmetal"]
	var brass := _painted("glove", Color(1.7, 1.45, 0.8))
	var jacket := _painted("canvas", Color(0.86, 0.46, 0.26))
	var jacket_dark := _painted("canvas", Color(0.64, 0.31, 0.18))
	var shirt := _painted("canvas", Color(0.3, 0.32, 0.37))
	var pants := _painted("canvas", Color(0.6, 0.6, 0.42))
	var pants_dark := _painted("canvas", Color(0.48, 0.48, 0.33))
	var scarf := _painted("canvas", Color(0.3, 0.52, 0.68))
	var rag := _painted("canvas", Color(0.82, 0.26, 0.2))
	var bandage := _painted("canvas", Color(0.92, 0.88, 0.78))
	var titan_paint := _painted("titan_armor", Color(0.62, 0.7, 0.8))
	var titan_stripe := _painted("titan_armor", Color(1.0, 0.55, 0.2))
	var dark := _painted("gunmetal", Color(0.16, 0.14, 0.16))

	# legs: baggy cargo pants tucked into steel-toed work boots
	for side in [-1.0, 1.0]:
		var leg := _pivot(r, "LegL" if side < 0.0 else "LegR", Vector3(side * 0.095, 0.9, 0))
		_part(leg, "Thigh", "cone", Vector3(0.066, 0.44, 0.084), Vector3(0, -0.22, 0), pants)
		_part(leg, "CargoPocket", "box", Vector3(0.035, 0.1, 0.1), Vector3(side * 0.078, -0.27, 0), pants_dark)
		_part(leg, "KneePad", "box", Vector3(0.105, 0.1, 0.04), Vector3(0, -0.45, -0.062), strap, Vector3(-6, 0, 0))
		_part(leg, "Shin", "cone", Vector3(0.05, 0.3, 0.064), Vector3(0, -0.6, 0), pants)
		_part(leg, "BootCuff", "cyl", Vector3(0.068, 0.1, 8), Vector3(0, -0.73, 0), leather)
		_part(leg, "BootStrap", "box", Vector3(0.14, 0.022, 0.15), Vector3(0, -0.76, -0.01), strap)
		_part(leg, "Boot", "box", Vector3(0.12, 0.12, 0.25), Vector3(0, -0.84, -0.04), leather)
		_part(leg, "ToeCap", "box", Vector3(0.126, 0.075, 0.08), Vector3(0, -0.86, -0.135), metal)
		_part(leg, "Sole", "box", Vector3(0.13, 0.03, 0.27), Vector3(0, -0.885, -0.04), dark)
		if side > 0.0:  # thigh holster with the pistol grip showing
			_part(leg, "HolsterStrap", "cyl", Vector3(0.086, 0.025, 8), Vector3(0, -0.16, 0), strap)
			_part(leg, "Holster", "box", Vector3(0.045, 0.16, 0.085), Vector3(0.088, -0.22, 0.0), leather)
			_part(leg, "PistolGrip", "box", Vector3(0.035, 0.07, 0.045), Vector3(0.09, -0.12, 0.02), metal, Vector3(-12, 0, 0))

	# hips: belt with a tool pouch, a wrench and a red rag in the back pocket
	_ell(r, "Pelvis", 0.155, Vector3(1.05, 0.6, 0.7), Vector3(0, 0.94, 0.005), pants)
	_part(r, "Belt", "cyl", Vector3(0.15, 0.05, 10), Vector3(0, 1.0, 0), leather).scale = Vector3(1.0, 1.0, 0.8)
	_part(r, "Buckle", "box", Vector3(0.05, 0.04, 0.02), Vector3(0, 1.0, -0.12), brass)
	_part(r, "ToolPouch", "box", Vector3(0.07, 0.1, 0.07), Vector3(0.15, 0.95, 0.03), leather, Vector3(0, 0, -6))
	_part(r, "WrenchShaft", "box", Vector3(0.018, 0.2, 0.01), Vector3(-0.16, 0.89, -0.03), metal, Vector3(0, 0, 8))
	_part(r, "WrenchHead", "torus", Vector3(0.012, 0.03, 0), Vector3(-0.174, 0.78, -0.03), metal, Vector3(90, 0, 8))
	_part(r, "Rag", "box", Vector3(0.06, 0.15, 0.01), Vector3(0.07, 0.9, 0.12), rag, Vector3(0, 0, 10))

	var up := _pivot(r, "Upper", Vector3.ZERO)
	# torso: charcoal work shirt under a cropped, open rust work jacket
	_ell(up, "Waist", 0.11, Vector3(0.86, 1.05, 0.62), Vector3(0, 1.13, 0), shirt)
	_ell(up, "Chest", 0.155, Vector3(0.95, 0.88, 0.66), Vector3(0, 1.3, 0), shirt)
	_ell(up, "Jacket", 0.175, Vector3(1.05, 0.82, 0.68), Vector3(0, 1.322, 0.006), jacket)
	_part(up, "ShirtFront", "box", Vector3(0.085, 0.2, 0.03), Vector3(0, 1.28, -0.1), shirt)
	for side in [-1.0, 1.0]:
		_part(up, "Lapel", "box", Vector3(0.03, 0.22, 0.02), Vector3(side * 0.055, 1.3, -0.108), jacket_dark, Vector3(0, side * 10, side * -8))
	_part(up, "Collar", "cone", Vector3(0.085, 0.07, 0.102), Vector3(0, 1.45, 0.012), jacket_dark)
	_part(up, "Scarf", "torus", Vector3(0.05, 0.085, 0), Vector3(0, 1.465, -0.004), scarf, Vector3(-14, 0, 0))
	_part(up, "ScarfTail", "box", Vector3(0.05, 0.13, 0.02), Vector3(0.05, 1.38, -0.118), scarf, Vector3(-8, 0, 16))
	_part(up, "BackPatch", "box", Vector3(0.12, 0.12, 0.01), Vector3(0, 1.34, 0.131), titan_paint)
	_part(up, "BackPatchStripe", "box", Vector3(0.12, 0.025, 0.012), Vector3(0, 1.34, 0.133), titan_stripe)
	# crossbody strap holding a plate from her father's titan on her left shoulder
	_part(up, "StrapFront", "box", Vector3(0.03, 0.44, 0.015), Vector3(0.005, 1.27, -0.118), strap, Vector3(0, 0, -36))
	_part(up, "StrapBack", "box", Vector3(0.03, 0.44, 0.015), Vector3(0.005, 1.27, 0.128), strap, Vector3(0, 0, -36))
	_ell(up, "ShoulderPlate", 0.09, Vector3(1.0, 0.45, 1.08), Vector3(-0.205, 1.435, 0), titan_paint, Vector3(0, 0, 18))
	_part(up, "PlateStripe", "box", Vector3(0.03, 0.02, 0.17), Vector3(-0.205, 1.472, 0), titan_stripe, Vector3(0, 0, 18))
	_part(up, "PlateRivet", "cyl", Vector3(0.012, 0.02, 6), Vector3(-0.255, 1.46, -0.06), metal, Vector3(0, 0, 18))

	# arms: rolled jacket sleeves, bare forearms, chunky mechanic's gloves
	for side in [-1.0, 1.0]:
		var arm := _pivot(up, "ArmL" if side < 0.0 else "ArmR", Vector3(side * 0.2, 1.41, 0), Vector3(0, 0, side * 7))
		_part(arm, "Shoulder", "sphere", Vector3(0.062, 0, 0), Vector3.ZERO, jacket)
		_part(arm, "Sleeve", "cone", Vector3(0.048, 0.25, 0.058), Vector3(0, -0.13, 0), jacket)
		_part(arm, "RolledCuff", "cyl", Vector3(0.058, 0.05, 8), Vector3(0, -0.26, 0), jacket_dark)
		_part(arm, "Forearm", "cone", Vector3(0.038, 0.22, 0.047), Vector3(0, -0.38, 0), skin)
		if side < 0.0:
			_part(arm, "Bandage", "cyl", Vector3(0.046, 0.08, 8), Vector3(0, -0.41, 0), bandage)
		_part(arm, "GloveCuff", "cyl", Vector3(0.05, 0.05, 8), Vector3(0, -0.5, 0), leather)
		_part(arm, "Hand", "box", Vector3(0.07, 0.1, 0.09), Vector3(0, -0.57, -0.005), leather)
		_part(arm, "Fingers", "box", Vector3(0.066, 0.06, 0.075), Vector3(side * 0.004, -0.645, -0.01), leather, Vector3(10, 0, 0))
		_part(arm, "Thumb", "box", Vector3(0.025, 0.05, 0.026), Vector3(-side * 0.012, -0.585, -0.054), leather)
		_part(arm, "KnucklePlate", "box", Vector3(0.012, 0.035, 0.07), Vector3(side * 0.037, -0.6, -0.005), metal)

	_part(up, "Neck", "cyl", Vector3(0.042, 0.1, 8), Vector3(0, 1.5, 0), skin)
	var head := _pivot(up, "Head", Vector3(0, 1.55, 0))
	head.scale = Vector3.ONE * 1.1  # Jak-style slightly big head
	_eco_head(head, skin, hair, strap, brass, dark)
	_save(r, "eco.tscn")


func _eco_head(head: Node3D, skin: Material, hair: Material, strap: Material,
		brass: Material, dark: Material) -> void:
	_ell(head, "Skull", 0.112, Vector3(0.9, 1.02, 1.0), Vector3(0, 0.1, 0.005), skin)
	_ell(head, "Jaw", 0.075, Vector3(1.0, 0.9, 1.0), Vector3(0, 0.035, -0.03), skin)
	_part(head, "Nose", "prism", Vector3(0.024, 0.026, 0.034), Vector3(0, 0.077, -0.108), skin, Vector3(-90, 0, 0))
	for side in [-1.0, 1.0]:
		_ell(head, "Ear", 0.026, Vector3(0.45, 1.0, 0.75), Vector3(side * 0.1, 0.09, 0.012), skin)
	_part(head, "Mouth", "box", Vector3(0.03, 0.007, 0.01), Vector3(0, 0.038, -0.1), _painted("skin", Color(0.82, 0.5, 0.48)))
	_part(head, "Smudge", "box", Vector3(0.022, 0.008, 0.004), Vector3(0.062, 0.068, -0.088), dark, Vector3(0, -30, 8)) \
		.set_instance_shader_parameter("paint", Color(1, 1, 1, 1))

	# big, striking eyes: aqua irises with a faint glow, sharp winged liner
	var sclera := _painted("skin", Color(1.12, 1.12, 1.14))
	var iris: ShaderMaterial = M["light"].duplicate()
	iris.set_shader_parameter("emission", Color(0.25, 0.95, 0.88))
	iris.set_shader_parameter("emission_energy", 0.9)
	var pupil := _painted("gunmetal", Color(0.08, 0.1, 0.14))
	for side in [-1.0, 1.0]:
		var x: float = side * 0.04
		_ell(head, "EyeWhite", 0.026, Vector3(1.0, 1.15, 0.5), Vector3(x, 0.104, -0.094), sclera, Vector3(0, side * -12, 0))
		_ell(head, "Iris", 0.017, Vector3(1.0, 1.12, 0.42), Vector3(x - side * 0.002, 0.102, -0.102), iris, Vector3(0, side * -12, 0))
		_ell(head, "Pupil", 0.008, Vector3(1.0, 1.25, 0.4), Vector3(x - side * 0.002, 0.102, -0.1075), pupil)
		_part(head, "Glint", "sphere", Vector3(0.0045, 0, 0), Vector3(x + 0.004, 0.11, -0.108), M["light"])
		# heavy upper lid gives a steady, determined look rather than a startled one
		_ell(head, "Lid", 0.028, Vector3(1.08, 0.62, 0.58), Vector3(x, 0.129, -0.095), skin, Vector3(0, side * -12, side * -6))
		_part(head, "Liner", "box", Vector3(0.058, 0.007, 0.01), Vector3(x, 0.119, -0.106), dark, Vector3(0, side * -12, side * -6))
		_part(head, "Wing", "box", Vector3(0.018, 0.006, 0.008), Vector3(x + side * 0.031, 0.122, -0.098), dark, Vector3(0, side * -30, side * 22))
		_part(head, "Brow", "box", Vector3(0.046, 0.011, 0.012), Vector3(x, 0.148, -0.1), hair, Vector3(0, side * -12, side * -7))

	# short white hair: a cap swept back, spiky fringe and tufts (Jak style)
	var cap := _part(head, "HairCap", "hemi", Vector3(0.124, 0, 0), Vector3(0, 0.115, 0.012), hair, Vector3(24, 0, 0))
	cap.scale = Vector3(0.96, 1.0, 1.05)
	(cap.mesh as SphereMesh).radial_segments = 12
	(cap.mesh as SphereMesh).rings = 4
	var spikes := [
		# fringe, swept across the forehead
		[Vector3(0.03, 0.2, -0.085), Vector3(-0.5, -0.5, -0.65), 0.11, 0.032],
		[Vector3(-0.01, 0.205, -0.08), Vector3(-0.65, -0.45, -0.55), 0.12, 0.03],
		[Vector3(-0.05, 0.19, -0.075), Vector3(-0.75, -0.6, -0.3), 0.1, 0.028],
		[Vector3(0.065, 0.185, -0.08), Vector3(0.25, -0.75, -0.55), 0.09, 0.026],
		# crown, swept back and up
		[Vector3(0.0, 0.22, -0.03), Vector3(0.0, 0.55, 0.85), 0.12, 0.036],
		[Vector3(0.05, 0.21, -0.01), Vector3(0.45, 0.4, 0.8), 0.11, 0.032],
		[Vector3(-0.05, 0.21, -0.01), Vector3(-0.45, 0.4, 0.8), 0.11, 0.032],
		[Vector3(0.0, 0.2, 0.05), Vector3(0.0, 0.3, 1.0), 0.11, 0.036],
		# back of the head, short tufts down to the nape
		[Vector3(0.05, 0.13, 0.085), Vector3(0.4, -0.55, 0.75), 0.09, 0.032],
		[Vector3(-0.05, 0.13, 0.085), Vector3(-0.4, -0.55, 0.75), 0.09, 0.032],
		[Vector3(0.0, 0.09, 0.09), Vector3(0.0, -0.9, 0.45), 0.08, 0.032],
		# over the ears
		[Vector3(0.096, 0.14, -0.03), Vector3(0.3, -0.92, -0.2), 0.09, 0.026],
		[Vector3(-0.096, 0.14, -0.03), Vector3(-0.3, -0.92, -0.2), 0.09, 0.026],
		[Vector3(0.1, 0.16, 0.04), Vector3(0.6, -0.5, 0.55), 0.085, 0.028],
		[Vector3(-0.1, 0.16, 0.04), Vector3(-0.6, -0.5, 0.55), 0.085, 0.028],
	]
	for i in spikes.size():
		var s: Array = spikes[i]
		_spike(head, "Hair%d" % i, s[0], s[1], s[2], s[3], hair)

	# work goggles pushed up on her forehead, strap round the back of her head
	_part(head, "GoggleStrap", "torus", Vector3(0.118, 0.13, 0), Vector3(0, 0.15, 0.02), strap, Vector3(-28, 0, 0))
	var glass := _painted("visor", Color(0.35, 0.75, 0.8))
	for side in [-1.0, 1.0]:
		_part(head, "GoggleRim", "cyl", Vector3(0.03, 0.03, 10), Vector3(side * 0.038, 0.225, -0.068), brass, Vector3(-40, 0, 0))
		_part(head, "GoggleLens", "cyl", Vector3(0.022, 0.032, 10), Vector3(side * 0.038, 0.225, -0.068), glass, Vector3(-40, 0, 0)) \
			.set_instance_shader_parameter("glow", 0.3)
	_part(head, "GoggleBridge", "box", Vector3(0.024, 0.012, 0.014), Vector3(0, 0.227, -0.073), brass, Vector3(-40, 0, 0))
