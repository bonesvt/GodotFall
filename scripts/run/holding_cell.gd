extends Node3D
## Ophelia's cell in the colony's holding block (Level 2, levels.gd "rescue"):
## a concrete cell open to the street behind a humming energy screen, lit by
## one caged bulb. She's sat on the floor in the rags they put her in
## (hub_npc MISSION_OUTFITS "prison"), shackled at the wrists, chained to a
## ring in the back wall. Guards are posted round the block but nothing holds
## the screen shut: sneak up, F shorts it out and Eco pops the shackle pins
## (run_manager rescue()), and she follows Eco out (escort.gd).
## The cell opens toward local +z.

signal freed

const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const K := preload("res://scripts/hub/hub_kit.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const NpcIdles := preload("res://scripts/hub/npc_idles.gd")

const INTERACT_RANGE := 3.4
## Inside: across the front, height, front to back (m).
const SIZE := Vector3(5.0, 3.2, 4.2)
const WALL := 0.4
const SCREEN := Color(0.35, 0.85, 1.0)
## Where she sits, and the ring her chains run to (cell space).
const SEAT := Vector3(0.4, 0.08, -2.2)
const RING := Vector3(0.4, 0.75, -4.15)
## Links in each chain from a cuff to the ring, and how long the chain is.
const LINKS := 16
const CHAIN_LEN := 2.3
const HANDS := ["J_Bip_L_Hand", "J_Bip_R_Hand"]

## Kept for the cache-like interface (nothing locks it now).
var locked := false
## She's out.
var opened := false
var ophelia: Node3D
var _screen: StaticBody3D
var _label: Label3D
var _light: OmniLight3D
var _cuffs: Array = []   # BoneAttachment3D per wrist
var _chains: Array = []  # per wrist: [MeshInstance3D links]
var _pile: Node3D


func _ready() -> void:
	_build()
	ophelia = HubNpc.create("ophelia", SEAT, 180.0)
	add_child(ophelia)
	ophelia.wear("prison")
	_sit.call_deferred()
	_refresh()


## On the floor, knees up, shackled wrists resting on them.
func _sit() -> void:
	if ophelia == null or ophelia._anim == null:
		return
	NpcIdles._load_poses(ophelia)
	for pose in ["chained", "scene_sit"]:
		var name: String = NpcIdles.LIB + "/" + pose
		if ophelia._anim.has_animation(name):
			ophelia._anim.play(name, 0.0)
			break
	ophelia.posed = true
	ophelia.mood(["sad", "down"])
	_shackle()


## Iron cuffs on her wrists, and a chain from each to the ring.
func _shackle() -> void:
	var skel := ophelia.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	var iron := Art.material("gunmetal")
	for bone_name in HANDS:
		var bone := skel.find_bone(bone_name)
		if bone < 0:
			continue
		var at := BoneAttachment3D.new()
		at.bone_name = bone_name
		skel.add_child(at)
		var sc := (skel.global_transform * skel.get_bone_global_pose(bone)).basis.get_scale()
		var holder := Node3D.new()
		holder.scale = Vector3(1.0 / sc.x, 1.0 / sc.y, 1.0 / sc.z)
		at.add_child(holder)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.032
		torus.outer_radius = 0.05
		torus.rings = 12
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = iron
		ring.rotation_degrees = Vector3(0, 0, 90)  # round the forearm (the bone runs along x in the rest pose)
		holder.add_child(ring)
		_cuffs.append(holder)
		var links := []
		for i in LINKS:
			var link := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.022, 0.05, 0.11)
			link.mesh = box
			link.material_override = iron
			add_child(link)
			links.append(link)
		_chains.append(links)
	_drape()


func _process(_delta: float) -> void:
	if not opened and not _chains.is_empty():
		_drape()


## Hangs each chain from its cuff to the ring, sagging with the slack.
func _drape() -> void:
	var to_local := global_transform.affine_inverse()
	for k in _chains.size():
		var a: Vector3 = to_local * (_cuffs[k] as Node3D).global_position
		var b := RING + Vector3((k - 0.5) * 0.12, 0, 0)
		var sag := maxf(0.05, CHAIN_LEN - a.distance_to(b)) * 0.55
		var prev := a
		var links: Array = _chains[k]
		for i in LINKS:
			var t := float(i + 1) / LINKS
			var p := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
			p.y = maxf(p.y, 0.1)
			var link: MeshInstance3D = links[i]
			var dir := p - prev
			if dir.length() > 0.001:
				link.transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT), (p + prev) * 0.5)
				if i % 2 == 1:
					link.rotate_object_local(Vector3.BACK, PI * 0.5)
			prev = p


func _build() -> void:
	var concrete := Art.material("concrete")
	var w := SIZE.x
	var d := SIZE.z
	var h := SIZE.y
	# Floor slab, back and side walls, roof, and a lip over the front.
	Kit.box(self, Vector3(0, 0.04, -d * 0.5), Vector3(w + WALL * 2.0, 0.08, d), Color(0.4, 0.41, 0.42), Vector3.ZERO, concrete)
	Kit.box(self, Vector3(0, h * 0.5, -d - WALL * 0.5), Vector3(w + WALL * 2.0, h, WALL), Color(0.5, 0.51, 0.52), Vector3.ZERO, concrete)
	for sx in [-1.0, 1.0]:
		Kit.box(self, Vector3(sx * (w + WALL) * 0.5, h * 0.5, -d * 0.5), Vector3(WALL, h, d + WALL), Color(0.5, 0.51, 0.52), Vector3.ZERO, concrete)
	Kit.box(self, Vector3(0, h + 0.2, -d * 0.5 + 0.2), Vector3(w + WALL * 2.0 + 0.4, 0.4, d + WALL + 0.8), Color(0.3, 0.31, 0.33), Vector3.ZERO, concrete)
	# A thin grey pad on the floor and a steel bucket: all they gave her.
	K.mesh(self, Vector3(SEAT.x, 0.1, SEAT.z - 0.2), Vector3(1.0, 0.05, 1.9), Art.material("canvas", Color(0.32, 0.33, 0.34)))
	# The ring in the back wall her chains run to, and a caged bulb overhead.
	var iron := Art.material("gunmetal")
	K.mesh(self, RING + Vector3(0, 0, -0.02), Vector3(0.22, 0.22, 0.06), iron)
	var eye := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.05
	torus.outer_radius = 0.075
	eye.mesh = torus
	eye.material_override = iron
	eye.position = RING + Vector3(0, -0.05, 0.06)
	eye.rotation_degrees = Vector3(90, 0, 0)
	add_child(eye)
	K.mesh(self, Vector3(0, h - 0.15, -d * 0.5), Vector3(0.24, 0.3, 0.24), iron)
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	bulb.mesh = sphere
	bulb.material_override = Kit.glow(Color(1.0, 0.75, 0.4))
	bulb.position = Vector3(0, h - 0.36, -d * 0.5)
	add_child(bulb)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.7, 0.4)
	lamp.light_energy = 0.9
	lamp.omni_range = 4.5
	lamp.position = bulb.position + Vector3.DOWN * 0.1
	add_child(lamp)
	K.mesh(self, Vector3(-w * 0.5 + 0.5, 0.28, -d + 0.5), Vector3(0.4, 0.45, 0.4), Art.material("gunmetal"))
	# Emitter rails top and bottom, and the screen between them.
	var rail := Art.material("gunmetal")
	K.mesh(self, Vector3(0, 0.12, 0.05), Vector3(w, 0.24, 0.3), rail)
	K.mesh(self, Vector3(0, h - 0.12, 0.05), Vector3(w, 0.24, 0.3), rail)
	_screen = StaticBody3D.new()
	_screen.name = "Screen"
	add_child(_screen)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, h, 0.2)
	shape.shape = box
	shape.position = Vector3(0, h * 0.5, 0.05)
	_screen.add_child(shape)
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.albedo_color = Color(SCREEN, 0.1)
	var sheet := MeshInstance3D.new()
	var quad := BoxMesh.new()
	quad.size = Vector3(w, h - 0.48, 0.04)
	sheet.mesh = quad
	sheet.material_override = glass
	sheet.position = Vector3(0, h * 0.5, 0.05)
	_screen.add_child(sheet)
	# Bright bars through the screen so it reads as a cage from a distance.
	var bar_mat := Kit.glow(SCREEN.darkened(0.35))
	var n := 11
	for i in n:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.025, h - 0.48, 0.025)
		bar.mesh = bm
		bar.material_override = bar_mat
		bar.position = Vector3(-w * 0.5 + w * (i + 0.5) / n, h * 0.5, 0.05)
		_screen.add_child(bar)
	_light = OmniLight3D.new()
	_light.light_color = SCREEN
	_light.light_energy = 0.8
	_light.omni_range = 5.0
	_light.position = Vector3(0, h * 0.6, 0.6)
	add_child(_light)
	_label = Kit.label(self, Vector3(0, h + 1.2, 0.4), "", 64)


func can_open() -> bool:
	return not locked and not opened


func in_range(pos: Vector3) -> bool:
	var front := global_transform * Vector3(0, 0, 1.0)
	return Vector2(front.x - pos.x, front.z - pos.z).length() < INTERACT_RANGE and absf(front.y - pos.y) < 2.5


func unlock() -> void:
	locked = false
	_refresh()


func set_locked(value: bool) -> void:
	locked = value
	_refresh()


## Shorts out the screen and pops her shackles off the chains: the chains
## drop in a heap by the ring, the cuffs stay on her wrists. Gets her up.
## Returns false if it's already open.
func release() -> bool:
	if not can_open():
		return false
	opened = true
	_screen.queue_free()
	_screen = null
	_light.light_energy = 0.0
	for links in _chains:
		for link in links:
			link.queue_free()
	_chains.clear()
	_pile = Node3D.new()
	add_child(_pile)
	var iron := Art.material("gunmetal")
	for i in 14:
		var a := i * 2.4
		K.mesh(_pile, RING + Vector3(cos(a) * (0.1 + i * 0.012), -RING.y + 0.1 + (i % 3) * 0.02, 0.18 + sin(a) * 0.08 + i * 0.01),
				Vector3(0.022, 0.05, 0.11), iron, Vector3(0, i * 47.0, (i % 2) * 90.0))
	if ophelia != null and ophelia._anim != null:
		ophelia.posed = false
		if ophelia._anim.has_animation("idle"):
			ophelia._anim.play("idle", 0.6)
		ophelia.mood(["surprised"])
	_refresh()
	freed.emit()
	return true


func _refresh() -> void:
	if _label == null:
		return
	if opened:
		_label.text = ""
	else:
		_label.text = "OPHELIA"
		_label.modulate = SCREEN
