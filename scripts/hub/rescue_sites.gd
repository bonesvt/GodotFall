extends RefCounted
## Where a rescue happens (rescue.gd), built only while one's on
## (rescue_event.gd): the colony's white van parked by the dispensary, its side
## door open, and Cutter's stash, a tarp lean-to off the pilgrim road. (Marrow's
## basement is already there: hush_den.gd.) Each builder returns
## {"root", "seat", "seat_yaw", "seat_height", "captor", "captor_yaw", "cam"}:
## where the one taken sits (and which way, how high the seat is off `seat`'s
## floor), where the captor stands and faces, and a good spot to watch from.

const K := preload("res://scripts/hub/hub_kit.gd")
const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const HushDen := preload("res://scripts/hub/hush_den.gd")

## The van's middle, in the street by the dispensary kiosk (town.gd), nose to the gate.
const VAN := Vector3(-3.3, 0, 150.6)
const VAN_SIZE := Vector3(1.9, 2.1, 4.8)
const VAN_FLOOR := 0.5
## Cutter's stash, off the east side of the pilgrim road (town.gd ROAD_HALF 3.5).
const STASH := Vector3(6.3, 0, 116.0)


static func marrow() -> Dictionary:
	var w := HushDen.WAKE
	return {"root": null, "seat": w + Vector3(0, 0, 0.12), "seat_yaw": 0.0, "seat_height": 0.5,
		"captor": w + Vector3(0.8, 0, 0.45), "captor_yaw": 90.0,
		"cam": w + Vector3(1.5, 1.45, -1.8)}


## The colony van: white, a grey stripe and the colony's seal lit on its side,
## its sliding door open on the street side, a white bench inside.
static func colony(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "RescueVan"
	parent.add_child(root)
	var v := VAN
	var white := _mat(Color(0.92, 0.93, 0.95), 0.25)
	var grey := _mat(Color(0.45, 0.48, 0.52), 0.3)
	var dark := _mat(Color(0.06, 0.07, 0.08), 0.1)
	var glass := _mat(Color(0.1, 0.13, 0.16), 0.8)
	var inside := _mat(Color(0.82, 0.84, 0.86), 0.1)
	var lit := _glow(Color(0.8, 0.92, 1.0), 2.5)
	var hw := VAN_SIZE.x * 0.5
	var hl := VAN_SIZE.z * 0.5
	# the body: floor, roof, the far side, the back, and the near side either side of the door
	_box(root, v + Vector3(0, VAN_FLOOR - 0.05, 0), Vector3(VAN_SIZE.x, 0.1, VAN_SIZE.z), inside)
	_box(root, v + Vector3(0, VAN_FLOOR - 0.25, 0), Vector3(VAN_SIZE.x - 0.1, 0.3, VAN_SIZE.z - 0.2), grey)
	_box(root, v + Vector3(0, VAN_SIZE.y, 0), Vector3(VAN_SIZE.x, 0.1, VAN_SIZE.z), white)
	_box(root, v + Vector3(-hw + 0.04, VAN_FLOOR + 0.8, 0), Vector3(0.08, 1.6, VAN_SIZE.z), white)
	_box(root, v + Vector3(0, VAN_FLOOR + 0.8, hl - 0.04), Vector3(VAN_SIZE.x, 1.6, 0.08), white)
	_box(root, v + Vector3(hw - 0.04, VAN_FLOOR + 0.8, hl - 0.55), Vector3(0.08, 1.6, 1.0), white)   # behind the door
	_box(root, v + Vector3(hw - 0.04, VAN_FLOOR + 0.8, -hl + 0.95), Vector3(0.08, 1.6, 1.9), white)  # in front of it
	# the cab: lower, rounded off with a sloped windscreen
	var cab := v + Vector3(0, 0, -hl - 0.5)
	_box(root, cab + Vector3(0, 0.75, 0), Vector3(VAN_SIZE.x, 1.0, 1.0), white)
	_box(root, cab + Vector3(0, 1.55, 0.25), Vector3(VAN_SIZE.x, 0.7, 0.5), white)
	_box(root, cab + Vector3(0, 1.45, -0.18), Vector3(VAN_SIZE.x - 0.12, 0.62, 0.06), glass, Vector3(-32, 0, 0))
	for s in [-1.0, 1.0]:
		_box(root, cab + Vector3(s * (hw - 0.02), 1.5, 0.2), Vector3(0.05, 0.45, 0.6), glass)
		_box(root, cab + Vector3(s * 0.7, 0.75, -0.51), Vector3(0.28, 0.12, 0.02), _glow(Color(1.0, 0.98, 0.9), 2.0))  # headlamps
	_box(root, cab + Vector3(0, 0.4, -0.52), Vector3(VAN_SIZE.x, 0.22, 0.06), grey)  # bumper
	# the stripe and the seal down its street side
	_box(root, v + Vector3(hw + 0.005, 1.2, -hl + 0.45), Vector3(0.01, 0.16, 2.9), grey)  # up to the door, not across it
	_box(root, v + Vector3(hw + 0.005, 1.2, hl - 0.55), Vector3(0.01, 0.16, 0.95), grey)
	_disc(root, v + Vector3(hw + 0.012, 1.55, -hl + 1.45), 0.22, lit)
	_disc(root, v + Vector3(hw + 0.016, 1.55, -hl + 1.45), 0.15, white)
	# the door, slid back along the side
	_box(root, v + Vector3(hw + 0.07, VAN_FLOOR + 0.8, hl - 0.55), Vector3(0.05, 1.55, 1.0), white)
	# wheels
	for s in [-1.0, 1.0]:
		for z in [-hl - 0.4, hl - 0.7]:
			var wheel := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.34
			cyl.bottom_radius = 0.34
			cyl.height = 0.24
			wheel.mesh = cyl
			wheel.material_override = dark
			wheel.rotation_degrees = Vector3(0, 0, 90)
			wheel.position = v + Vector3(s * (hw - 0.08), 0.34, z)
			root.add_child(wheel)
	# inside: a white bench along the far side, a strip light, the fitting arm folded on the roof
	_box(root, v + Vector3(-hw + 0.35, VAN_FLOOR + 0.22, -0.2), Vector3(0.5, 0.44, 1.6), white)
	_box(root, v + Vector3(-hw + 0.12, VAN_FLOOR + 0.75, -0.2), Vector3(0.06, 0.6, 1.6), white)
	_box(root, v + Vector3(0, VAN_SIZE.y - 0.07, 0), Vector3(0.12, 0.03, 3.0), lit)
	_box(root, v + Vector3(-0.2, VAN_SIZE.y - 0.25, 0.9), Vector3(0.12, 0.3, 0.12), grey)
	_box(root, v + Vector3(-0.2, VAN_SIZE.y - 0.42, 0.55), Vector3(0.08, 0.08, 0.7), grey)
	var light := OmniLight3D.new()
	light.light_color = Color(0.88, 0.94, 1.0)
	light.light_energy = 0.7
	light.omni_range = 3.5
	light.position = v + Vector3(0, VAN_SIZE.y - 0.4, 0)
	root.add_child(light)
	# solid: the van's all one block to walk round (its door step left open)
	Kit.box(root, v + Vector3(-0.1, VAN_SIZE.y * 0.5, -0.5), Vector3(VAN_SIZE.x - 0.2, VAN_SIZE.y, VAN_SIZE.z + 1.0), K.STONE, Vector3.ZERO, null)
	for c in root.get_children():
		if c is StaticBody3D:
			for m in c.find_children("*", "MeshInstance3D", true, false):
				m.visible = false
	return {"root": root, "seat": v + Vector3(-hw + 0.42, VAN_FLOOR, -0.2), "seat_yaw": -90.0, "seat_height": 0.44,
		"captor": v + Vector3(hw + 0.75, 0, -0.95), "captor_yaw": 60.0,
		"cam": v + Vector3(hw + 2.7, 1.45, 0.7), "out": v + Vector3(hw + 0.45, 0, 0.1)}


## Cutter's stash: a red tarp strung off two poles over a stained mattress and
## a few crates, a red lantern, his tag sprayed on a board, and a tin of his works.
static func cutter(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "RescueStash"
	parent.add_child(root)
	var s := STASH
	var tarp := _mat(Color(0.6, 0.1, 0.1), 0.05)
	var wood := Art.material("wood", Color(0.45, 0.36, 0.28))
	var pole := Art.material("gunmetal", Color(0.3, 0.3, 0.32))
	var mattress := Art.material("canvas", Color(0.62, 0.58, 0.48))
	for z in [-1.3, 1.3]:
		_box(root, s + Vector3(-0.9, 1.0, z), Vector3(0.07, 2.0, 0.07), pole)
	_box(root, s + Vector3(0.0, 1.55, 0), Vector3(2.2, 0.03, 2.8), tarp, Vector3(0, 0, -24))
	_box(root, s + Vector3(1.15, 0.85, 0), Vector3(0.03, 1.45, 2.8), tarp, Vector3(0, 0, 8))
	_box(root, s + Vector3(0.45, 0.07, -0.55), Vector3(0.9, 0.14, 1.8), mattress)
	_box(root, s + Vector3(0.45, 0.15, -1.25), Vector3(0.55, 0.1, 0.35), Art.material("canvas", Color(0.7, 0.66, 0.6)))
	# the crate she's sat on, and his
	_box(root, s + Vector3(0.25, 0.22, 0.75), Vector3(0.55, 0.44, 0.5), wood)
	_box(root, s + Vector3(-0.5, 0.2, 1.0), Vector3(0.5, 0.4, 0.5), wood)
	_box(root, s + Vector3(-0.5, 0.48, 1.0), Vector3(0.38, 0.16, 0.38), wood)
	# his works: a tin, open, glowing vials in a row
	_box(root, s + Vector3(-0.5, 0.58, 1.0), Vector3(0.26, 0.04, 0.16), pole)
	for i in 4:
		var vial := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.012
		cyl.bottom_radius = 0.012
		cyl.height = 0.08
		vial.mesh = cyl
		vial.material_override = _glow(Color(1.0, 0.12, 0.1), 2.0)
		vial.position = s + Vector3(-0.59 + i * 0.06, 0.64, 1.0)
		root.add_child(vial)
	# his tag on a board leant on the pole
	_box(root, s + Vector3(-0.85, 0.75, -0.6), Vector3(0.04, 1.2, 0.9), wood, Vector3(0, 0, 8))
	var tag := Label3D.new()
	tag.text = "C"
	tag.font_size = 160
	tag.modulate = Color(1.0, 0.15, 0.12)
	tag.outline_size = 0
	tag.position = s + Vector3(-0.8, 0.85, -0.6)
	tag.rotation_degrees = Vector3(0, 90, 8)
	root.add_child(tag)
	# the red lantern hung under the tarp
	_box(root, s + Vector3(-0.3, 1.25, 0.2), Vector3(0.12, 0.18, 0.12), _glow(Color(1.0, 0.2, 0.12), 3.0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.25, 0.18)
	light.light_energy = 1.8
	light.omni_range = 5.0
	light.position = s + Vector3(-0.3, 1.15, 0.2)
	root.add_child(light)
	return {"root": root, "seat": s + Vector3(0.25, 0, 0.75), "seat_yaw": 90.0, "seat_height": 0.44,
		"captor": s + Vector3(-0.75, 0, 0.45), "captor_yaw": -90.0,
		"cam": s + Vector3(-2.0, 1.25, 2.3)}


static func _mat(c: Color, rough_sheen: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0 - rough_sheen * 0.6
	return m


static func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func _box(root: Node3D, pos: Vector3, size: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	root.add_child(mi)
	return mi


static func _disc(root: Node3D, pos: Vector3, r: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.01
	mi.mesh = cyl
	mi.material_override = m
	mi.rotation_degrees = Vector3(0, 0, 90)
	mi.position = pos
	root.add_child(mi)
