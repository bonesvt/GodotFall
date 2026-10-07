extends Node3D
## Ophelia's cell in the colony's holding block (Level 2, levels.gd "rescue"):
## a concrete cell open to the street behind a humming energy screen. She's
## held in a stasis column, a transit pillar: colony cargo tech that keeps
## living stock still until a lift ship comes (the "Freight" lore, Bones
## 2026-10-05). She hangs limp a hand off the emitter pad in the colony's torn
## intake suit (hub_npc MISSION_OUTFITS "colony", or "colony_m" on Mature),
## mag-cuffs on her wrists and an inhibitor collar synced to the field. Two
## dead pads by the back wall are the ones already shipped, and a manifest
## plate glows over hers. Guards are posted round the block but nothing holds
## the screen shut: sneak up, F shorts it out and overloads the three pylons
## (run_manager rescue()), the field drops, she lands on her feet and follows
## Eco out (escort.gd). The cell opens toward local +z.

signal freed

const SFX := preload("res://scripts/sfx.gd")
const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const K := preload("res://scripts/hub/hub_kit.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const NpcIdles := preload("res://scripts/hub/npc_idles.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

const INTERACT_RANGE := 3.4
## Inside: across the front, height, front to back (m).
const SIZE := Vector3(5.0, 3.2, 4.2)
const WALL := 0.4
const SCREEN := Color(0.35, 0.85, 1.0)
const FIELD := Color(0.45, 0.9, 1.0)
## The column's centre on the floor (cell space), and how high she floats.
const COLUMN := Vector3(0.3, 0.0, -2.2)
const LIFT := 0.42
## The emitter pad's top, the field's radius, and how far out the pylons stand.
const PAD_TOP := 0.18
const FIELD_R := 0.6
const PYLON_R := 1.15
## The dead pads of the ones already shipped (cell space).
const EMPTY := [Vector3(-1.75, 0.0, -3.35), Vector3(1.95, 0.0, -3.4)]
const CUFFS := ["J_Bip_L_Hand", "J_Bip_R_Hand"]
const NECK := "J_Bip_C_Neck"

## Kept for the cache-like interface (nothing locks it now).
var locked := false
## She's out.
var opened := false
var ophelia: Node3D
var _screen: StaticBody3D
var _label: Label3D
var _manifest: Label3D
var _light: OmniLight3D
var _field: MeshInstance3D
var _field_light: OmniLight3D
var _rings: Array = []    # MeshInstance3D drifting up the field
var _pylons: Array = []   # the glowing strip on each pylon
var _glows: Array = []    # the lit rings on the pad, cap, cuffs and collar
var _restraints: Array = []   # Node3D per cuff and the collar, on her bones
var _rating := ""
var _t := 0.0


func _ready() -> void:
	_build()
	ophelia = HubNpc.create("ophelia", COLUMN + Vector3.UP * LIFT, 180.0)
	add_child(ophelia)
	_dress()
	_hold.call_deferred()
	_refresh()


## The intake suit for the content rating: Teen keeps the ID plate on the
## suit, Mature has the code on her skin.
func _dress() -> void:
	_rating = ContentRating.current()
	if ophelia != null:
		ophelia.wear("colony_m" if HubNpc.mature() else "colony")


## Hanging in the field, eyes shut; cuffs and collar on.
func _hold() -> void:
	if ophelia == null or ophelia._anim == null:
		return
	NpcIdles._load_poses(ophelia)
	for pose in ["stasis", "scene_sit"]:
		var name: String = NpcIdles.LIB + "/" + pose
		if ophelia._anim.has_animation(name):
			ophelia._anim.play(name, 0.0)
			break
	ophelia.posed = true
	ophelia.mood(["closed"])
	_restrain()


## Mag-cuffs on her wrists and the inhibitor collar on her neck: gunmetal
## bands with a thin line of the field's light round each.
func _restrain() -> void:
	var skel := ophelia.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	var iron := Art.material("gunmetal")
	var lit := Kit.glow(FIELD)
	for bone_name in CUFFS + [NECK]:
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
		var neck: bool = bone_name == NECK
		var band := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.062 if neck else 0.045
		cyl.bottom_radius = cyl.top_radius
		cyl.height = 0.045 if neck else 0.06
		cyl.radial_segments = 14
		band.mesh = cyl
		band.material_override = iron
		var line := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = cyl.top_radius
		torus.outer_radius = cyl.top_radius + 0.006
		torus.rings = 16
		torus.ring_segments = 4
		line.mesh = torus
		line.material_override = lit
		if neck:
			# round the neck (the bone runs up y), sat low on it
			band.position = Vector3(0, 0.02, 0)
			line.position = band.position
		else:
			# round the forearm (the bone runs along x in the rest pose)
			band.rotation_degrees = Vector3(0, 0, 90)
			line.rotation_degrees = Vector3(0, 0, 90)
			band.position = Vector3(0.03 * (1 if bone_name.contains("_L_") else -1), 0, 0)
			line.position = band.position
		holder.add_child(band)
		holder.add_child(line)
		_glows.append(line)
		_restraints.append(holder)


func _process(delta: float) -> void:
	if not opened and _rating != ContentRating.current():
		_dress()
		_refresh()
	if opened:
		return
	_t += delta
	# The field's rings drift up, slow; the field breathes.
	var h := SIZE.y - PAD_TOP - 0.3
	for i in _rings.size():
		var ring: MeshInstance3D = _rings[i]
		var f := fposmod(_t * 0.12 + float(i) / _rings.size(), 1.0)
		ring.position.y = PAD_TOP + 0.05 + f * h
		ring.transparency = 0.3 + 0.7 * absf(f * 2.0 - 1.0)
	if _field_light != null:
		_field_light.light_energy = 0.6 + 0.08 * sin(_t * 2.3)


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
	# A caged bulb overhead, turned low: the field is most of the light.
	var iron := Art.material("gunmetal")
	K.mesh(self, Vector3(0, h - 0.15, -d * 0.5), Vector3(0.24, 0.3, 0.24), iron)
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	bulb.mesh = sphere
	bulb.material_override = Kit.glow(Color(1.0, 0.75, 0.4))
	bulb.position = Vector3(-1.4, h - 0.36, -d * 0.5)
	add_child(bulb)
	K.mesh(self, bulb.position + Vector3(0, 0.21, 0), Vector3(0.24, 0.3, 0.24), iron)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.7, 0.4)
	lamp.light_energy = 0.5
	lamp.omni_range = 3.5
	lamp.position = bulb.position + Vector3.DOWN * 0.1
	add_child(lamp)
	_build_column(h)
	# The row's other pads, dark: already shipped.
	for at: Vector3 in EMPTY:
		_cyl(self, at + Vector3.UP * 0.07, 0.45, 0.14, iron)
		_cyl(self, at + Vector3.UP * (h - 0.1), 0.4, 0.2, iron)
		_cyl(self, at + Vector3.UP * 0.15, 0.3, 0.02, Art.material("gunmetal", Color(0.4, 0.42, 0.45)))
	# The manifest plate on the wall beside her pad.
	_manifest = Kit.label(self, Vector3(COLUMN.x - 1.75, 2.1, -d + 0.03), "", 22)
	_manifest.modulate = FIELD
	_manifest.outline_size = 0
	_manifest.billboard = BaseMaterial3D.BILLBOARD_DISABLED   # flat on the wall
	_manifest.position.z += 0.02
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


## The stasis column: emitter pad and cap with lit rings, the field between
## them, rings of light drifting up it, and three pylons round it.
func _build_column(h: float) -> void:
	var iron := Art.material("gunmetal")
	var lit := Kit.glow(FIELD)
	_cyl(self, COLUMN + Vector3.UP * PAD_TOP * 0.5, 0.78, PAD_TOP, iron)
	_glows.append(_cyl(self, COLUMN + Vector3.UP * (PAD_TOP + 0.01), FIELD_R + 0.05, 0.02, lit))
	_cyl(self, COLUMN + Vector3.UP * (h - 0.14), 0.72, 0.28, iron)
	_glows.append(_cyl(self, COLUMN + Vector3.UP * (h - 0.29), FIELD_R + 0.05, 0.02, lit))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_color = Color(FIELD, 0.07)
	mat.render_priority = -1
	var top := h - 0.3
	_field = _cyl(self, COLUMN + Vector3.UP * (PAD_TOP + top) * 0.5, FIELD_R, top - PAD_TOP, mat)
	(_field.mesh as CylinderMesh).cap_top = false
	(_field.mesh as CylinderMesh).cap_bottom = false
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(FIELD, 0.5)
	for i in 4:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = FIELD_R - 0.012
		torus.outer_radius = FIELD_R + 0.004
		torus.rings = 32
		torus.ring_segments = 4
		ring.mesh = torus
		ring.material_override = ring_mat
		ring.position = COLUMN + Vector3.UP * (PAD_TOP + 0.4 * i)
		add_child(ring)
		_rings.append(ring)
	for i in 3:
		var a := deg_to_rad(90.0 + 120.0 * i)   # one behind her, two either side in front
		var at := COLUMN + Vector3(cos(a), 0, -sin(a)) * PYLON_R
		var face := Vector3(0, rad_to_deg(atan2(COLUMN.x - at.x, COLUMN.z - at.z)), 0)
		K.mesh(self, at + Vector3.UP * 0.8, Vector3(0.2, 1.6, 0.2), iron, face)
		var strip := K.mesh(self, at + Vector3.UP * 0.85 + (COLUMN - at).normalized() * 0.105, Vector3(0.05, 1.2, 0.01), Kit.glow(FIELD), face)
		_pylons.append(strip)
	_field_light = OmniLight3D.new()
	_field_light.light_color = FIELD
	_field_light.light_energy = 0.6
	_field_light.omni_range = 4.0
	_field_light.position = COLUMN + Vector3(0, 2.2, 0.3)
	add_child(_field_light)


static func _cyl(parent: Node, pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 24
	mi.mesh = cyl
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


func can_open() -> bool:
	return not locked and not opened


func in_range(pos: Vector3) -> bool:
	var front := global_transform * Vector3(0, 0, 1.0)
	return Vector2(front.x - pos.x, front.z - pos.z).length() < INTERACT_RANGE and absf(front.y - pos.y) < 2.5


func unlock() -> void:
	if locked and is_inside_tree():
		SFX.play_at(self, global_position + Vector3(0, 1.5, 0), "cache_unlock", -4.0)
	locked = false
	_refresh()


func set_locked(value: bool) -> void:
	locked = value
	_refresh()


## Shorts out the screen and overloads the pylons: they flare and die, the
## field drops and she lands on her feet, still cuffed and collared but with
## the light gone out of them. Returns false if it's already open.
func release() -> bool:
	if not can_open():
		return false
	opened = true
	# the screen shorts out with a crack, the pylons die, the field sighs off
	SFX.play_at(self, global_position + Vector3(0, 1.5, 0), "spark", 0.0, 0.8)
	SFX.play_at(self, global_position + Vector3(0, 1.5, 0), "titan_powerdown", -4.0, 1.2)
	SFX.play_at(self, global_position + Vector3(0, 0.5, 0), "titan_hiss_short", -8.0, 1.3)
	_screen.queue_free()
	_screen = null
	var dead := Art.material("gunmetal", Color(0.35, 0.36, 0.38))
	for strip: MeshInstance3D in _pylons:
		strip.material_override = Kit.glow(Color(1.0, 0.55, 0.3))
		get_tree().create_timer(0.25, false).timeout.connect(_burn_out.bind(strip, dead))
	for line: MeshInstance3D in _glows:
		line.material_override = dead
	_field.visible = false
	for ring in _rings:
		ring.visible = false
	_field_light.light_energy = 0.0
	_light.light_energy = 0.3   # the street's spill, now the screen's gone
	if ophelia != null:
		var drop := create_tween()
		drop.tween_property(ophelia, "position:y", COLUMN.y + PAD_TOP, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if ophelia._anim != null:
			ophelia.posed = false
			if ophelia._anim.has_animation("idle"):
				ophelia._anim.play("idle", 0.25)
		ophelia.mood(["surprised"])
	_refresh()
	freed.emit()
	return true


func _burn_out(strip: MeshInstance3D, dead: Material) -> void:
	if is_instance_valid(strip):
		strip.material_override = dead


func _refresh() -> void:
	if _label == null:
		return
	if opened:
		_label.text = ""
	else:
		_label.text = "OPHELIA"
		_label.modulate = SCREEN
	# Mature: Eco can read the manifest, and the forty before her are gone.
	if _manifest != null:
		_manifest.text = "" if opened else ("MANIFEST 7-ORB\nITEM 41 OF 60\nAWAITING LIFT" if HubNpc.mature() else "TRANSIT HOLD\nAWAITING LIFT")
