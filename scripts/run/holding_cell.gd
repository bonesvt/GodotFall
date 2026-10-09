extends Node3D
## Ophelia's cell in the colony's holding block (Level 2, levels.gd "rescue"):
## Trial Bay 7, where the colony spent her nineteen lost days testing Hymn
## and the first of the Shepherd's gear before any of it came to Solace. A
## concrete cell open to the street behind a humming energy screen, tiled
## white inside, with a drain. She stands in the same white fitting frame as
## the dispensary's back room (fitting_scene.gd), under a column of white
## light, wearing the prototype compliance headphones, dose cuff, clarity
## visor and a tracker band locked round her neck (colony_gear.gd), her arms
## held up over her head with her wrists clamped together to the frame's top
## bar, her ankles clamped to its base, and
## a screen hung in front of her face flashing rings and words at her.
## Two empty frames beside hers, their visors hanging off them, were the
## subjects before her. The wall screen reads her trial (TRIAL_TEXT, LOG), a
## steel cart holds a tray of Hymn films cut into strips, and a sealed case
## of Glass reference vials from "supplier: M." is the first thing tying
## Marrow to the colony. Guards are posted round the block but nothing holds
## the screen shut: sneak up, F shorts it and kills the bay's power
## (run_manager rescue()), the light and the screen go out, the clamps spring
## open, her arms come down, Eco lifts the dead visor off her, pulls the
## headphones and unbolts the band, and she follows Eco out (escort.gd). The
## cuff's pins won't come out: she goes home wearing it (run_manager
## _rescue_bonus, hub_grip.gd). The cell opens toward local +z.

signal freed

const SFX := preload("res://scripts/sfx.gd")
const Kit := preload("res://scripts/run/level_kit.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const K := preload("res://scripts/hub/hub_kit.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const NpcIdles := preload("res://scripts/hub/npc_idles.gd")
const ColonyGear := preload("res://scripts/hub/colony_gear.gd")
const Poses := preload("res://scripts/hub/family_poses.gd")
const ContentRating := preload("res://scripts/radio/content_rating.gd")

const INTERACT_RANGE := 3.4
## Inside: across the front, height, front to back (m).
const SIZE := Vector3(5.0, 3.2, 4.2)
const WALL := 0.4
const SCREEN := Color(0.35, 0.85, 1.0)
## The bay's white: the light she stands in, the tile, the frame's power.
const FIELD := Color(0.92, 0.96, 1.0)
const TILE := Color(0.86, 0.88, 0.9)
const GLASS := Color(0.72, 0.32, 1.0)
## Where she stands (cell space), facing the screen.
const COLUMN := Vector3(0.3, 0.0, -2.2)
## The white light's radius round her.
const FIELD_R := 0.7
## Kept for the test and the old interface: the floor's top.
const PAD_TOP := 0.08
## The empty frames of the subjects before her (cell space).
const EMPTY := [Vector3(-1.75, 0.0, -3.35), Vector3(1.95, 0.0, -3.4)]
## What the colony put on her for the trial, and what stays on once she's out.
const TRIAL_GEAR := ["headphones", "cuff", "visor", "band"]
const KEPT_GEAR := ["cuff"]
## The screen hung in front of her face, and what it flashes at her, a word at
## a time over turning white rings.
const FEED_AT := Vector3(0.0, 1.5, 0.55)
const FEED_WORDS := ["CALM", "YOU ARE DOING SO WELL", "STAY", "SOLACE IS SAFE", "BREATHE WITH US", "GOOD", "BE ON TIME", "STAY"]
const FEED_WORD_TIME := 1.1
## The wall screen over her frame, and the last lines of the trial log.
const TRIAL_TEXT := "HYMN TRIAL  BAY 7
SUBJECT 07   DAY 19
COMPLIANCE 64%
HYMN v0.3"
const LOG := "D17  SUBJECT STOPPED ASKING THE DATE
D18  SUBJECT SMILES ON THE CHIME
D19  RESPONDS TO PRAISE.
     RECOMMEND WIDER ROLLOUT: SOLACE"

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
var _log: Label3D
var _rings: Array = []    # MeshInstance3D drifting down the light
var _pylons: Array = []   # the power strips up her frame's posts
var _glows: Array = []    # the bay's lit seams, dark once it's shorted
var _clamps: Array = []   # the frame's clamps on her, open once it's shorted
var _pose: SkeletonModifier3D   # her arms held up together over her head
## The screen in front of her face: its words, its rings, and its backing.
var _feed: Node3D
var _feed_word: Label3D
var _feed_rings: Array = []
var _rating := ""
var _t := 0.0


func _ready() -> void:
	_build()
	ophelia = HubNpc.create("ophelia", COLUMN + Vector3.UP * PAD_TOP, 180.0)
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


## Her arms held straight up over her head, wrists together, in the frame's
## clamp (a hold like family_poses.gd's, from the rest pose).
const ARMS_UP := [
	["J_Bip_L_UpperArm", "J_Bip_L_LowerArm", Vector3(-0.28, 0.96, -0.04)],
	["J_Bip_L_LowerArm", "J_Bip_L_Hand", Vector3(0.62, 0.78, -0.02)],
	["J_Bip_L_Hand", "J_Bip_L_Middle1", Vector3(0.2, 0.98, 0.0)],
	["J_Bip_R_UpperArm", "J_Bip_R_LowerArm", Vector3(0.28, 0.96, -0.04)],
	["J_Bip_R_LowerArm", "J_Bip_R_Hand", Vector3(-0.62, 0.78, -0.02)],
	["J_Bip_R_Hand", "J_Bip_R_Middle1", Vector3(-0.2, 0.98, 0.0)],
]


## Standing stock still in the frame in the white light, eyes shut behind the
## visor, with the trial's gear on (the band locked round her neck), her arms
## held up over her head and the frame's clamps on her wrists and ankles.
func _hold() -> void:
	if ophelia == null or ophelia._anim == null:
		return
	if ophelia._anim.has_animation("idle"):
		ophelia._anim.play("idle", 0.0)
		ophelia._anim.seek(0.0, true)
		ophelia._anim.speed_scale = 0.0   # held, not breathing easy
	ophelia.posed = true
	ophelia.mood(["closed", "smile"])
	ColonyGear.apply(ophelia, TRIAL_GEAR)
	var skel := ophelia.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null or opened:
		return
	if _pose != null:
		_pose.free()
	var hold := Poses.Hold.new()
	hold.name = "TrialHold"
	hold.turns = ARMS_UP
	hold.after = _posed
	_pose = hold
	skel.add_child(_pose)
	skel.move_child(_pose, 0)


## Her bones only read back posed inside the hold, so the clamps are measured
## there, the first time, and built just after.
func _posed(skel: Skeleton3D) -> void:
	if opened or _pose == null or _pose.has_meta("measured"):
		return
	var at := {}
	for b in ["J_Bip_L_Hand", "J_Bip_R_Hand", "J_Bip_L_LowerArm", "J_Bip_R_LowerArm", "J_Bip_L_Foot", "J_Bip_R_Foot"]:
		var p: Variant = _bone_at(skel, b)
		if p == null:
			return
		at[b] = p
	_pose.set_meta("measured", true)
	_clamp.call_deferred(at)


## The frame's clamps: one white band round both her wrists together, a bar
## from it up to the frame's top bar, and a band round each ankle locked to
## its base plate, each lit with the bay's light. Built in cell space round
## where the hold has her, since she's held still.
func _clamp(at: Dictionary) -> void:
	for c in _clamps:
		c.queue_free()
	_clamps.clear()
	if opened:
		return
	var white := _flat(Color(0.93, 0.94, 0.96))
	var lit := Kit.glow(FIELD)
	var l_wrist: Vector3 = (at["J_Bip_L_Hand"] as Vector3).lerp(at["J_Bip_L_LowerArm"] as Vector3, 0.2)
	var r_wrist: Vector3 = (at["J_Bip_R_Hand"] as Vector3).lerp(at["J_Bip_R_LowerArm"] as Vector3, 0.2)
	var wrists := (l_wrist + r_wrist) * 0.5
	_clamp_part(_band(wrists, Vector3.UP, 0.075, 0.08, white, lit))
	var top := Vector3(COLUMN.x, 2.2, COLUMN.z - 0.35)
	_clamp_part(_bar(wrists + (top - wrists).normalized() * 0.05, top, 0.035, white))
	for side in ["L", "R"]:
		var ankle: Vector3 = (at["J_Bip_%s_Foot" % side] as Vector3) + Vector3.UP * 0.06
		_clamp_part(_band(ankle, Vector3.UP, 0.055, 0.07, white, lit))
		_clamp_part(_bar(ankle - Vector3.UP * 0.04, Vector3(ankle.x, 0.06, ankle.z), 0.04, white))


## Where her wrists are held (cell space), or null before the clamps are on.
func wrists_at() -> Variant:
	return null if _clamps.is_empty() else (_clamps[0] as Node3D).position


func _clamp_part(n: Node3D) -> void:
	_clamps.append(n)


## Where a bone of hers is, in cell space (null if she hasn't got it).
func _bone_at(skel: Skeleton3D, bone_name: String) -> Variant:
	var b := skel.find_bone(bone_name)
	if b < 0:
		return null
	return to_local((skel.global_transform * skel.get_bone_global_pose(b)).origin)


## A clamp band at `at` round `axis`, with a lit line round its middle.
func _band(at: Vector3, axis: Vector3, radius: float, height: float, m: Material, lit: Material) -> Node3D:
	var n := Node3D.new()
	n.name = "Clamp"
	add_child(n)
	n.position = at
	n.basis = Basis(Quaternion(Vector3.UP, axis.normalized()))
	var band := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 16
	band.mesh = cyl
	band.material_override = m
	n.add_child(band)
	var line := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius
	torus.outer_radius = radius + 0.006
	torus.rings = 16
	torus.ring_segments = 4
	line.mesh = torus
	line.material_override = lit
	n.add_child(line)
	_glows.append(line)
	return n


## A square bar from a to b.
func _bar(a: Vector3, b: Vector3, thick: float, m: Material) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(thick, a.distance_to(b), thick)
	mi.mesh = bm
	mi.material_override = m
	add_child(mi)
	mi.position = (a + b) * 0.5
	mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	return mi


## The gear she has on (empty under Teen, where the gear never shows).
func gear_on() -> Array:
	var on := []
	for piece in TRIAL_GEAR:
		if ophelia != null and ColonyGear.piece_node(ophelia, piece) != null:
			on.append(piece)
	return on


func _process(delta: float) -> void:
	if not opened and _rating != ContentRating.current():
		_dress()
		_refresh()
	if opened:
		return
	_t += delta
	# The screen's rings turn out from its middle; a new word every so often.
	for i in _feed_rings.size():
		var ring: MeshInstance3D = _feed_rings[i]
		var f := fposmod(_t * 0.45 + float(i) / _feed_rings.size(), 1.0)
		var r := 0.15 + f * 1.4
		ring.scale = Vector3(r, 1.0, r * 0.95)
		ring.transparency = f
	if _feed_word != null:
		_feed_word.text = FEED_WORDS[int(_t / FEED_WORD_TIME) % FEED_WORDS.size()]
	# Rings of the light sink down over her, slow; the light breathes.
	var h := SIZE.y - PAD_TOP - 0.3
	for i in _rings.size():
		var ring: MeshInstance3D = _rings[i]
		var f := fposmod(_t * 0.1 + float(i) / _rings.size(), 1.0)
		ring.position.y = PAD_TOP + 0.05 + (1.0 - f) * h
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
	_tile(w, d, h)
	_build_light(h)
	_build_frame(COLUMN, true)
	_build_feed(h)
	# The subjects before her: their frames dark, their visors hung on them.
	for i in EMPTY.size():
		_build_frame(EMPTY[i], false, i)
	_build_cart()
	# The trial on a screen on the left wall over the cart, and its log under it.
	var sx := -w * 0.5 + 0.02
	var screen_back := K.mesh(self, Vector3(sx, 1.95, -1.6), Vector3(0.02, 1.4, 1.8), Kit.glow(Color(0.06, 0.08, 0.1)))
	_glows.append(screen_back)
	_manifest = _wall_text(Vector3(sx + 0.04, 2.25, -1.6), 40)
	_log = _wall_text(Vector3(sx + 0.04, 1.6, -1.6), 22)
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


## White tile over the concrete inside (floor, back and sides) with grey
## grout lines, and a drain in the floor in front of her frame.
func _tile(w: float, d: float, h: float) -> void:
	var tile := _flat(TILE)
	var grout := _flat(TILE.darkened(0.35))
	K.mesh(self, Vector3(0, 0.085, -d * 0.5), Vector3(w, 0.01, d), tile)
	K.mesh(self, Vector3(0, h * 0.5, -d + 0.01), Vector3(w, h, 0.01), tile)
	for sx in [-1.0, 1.0]:
		K.mesh(self, Vector3(sx * (w * 0.5 - 0.01), h * 0.5, -d * 0.5), Vector3(0.01, h, d), tile)
	# grout every 0.5 m on the back wall and the floor
	var x := -w * 0.5 + 0.5
	while x < w * 0.5:
		K.mesh(self, Vector3(x, h * 0.5, -d + 0.02), Vector3(0.012, h, 0.004), grout)
		K.mesh(self, Vector3(x, 0.092, -d * 0.5), Vector3(0.012, 0.004, d), grout)
		x += 0.5
	var y := 0.5
	while y < h:
		K.mesh(self, Vector3(0, y, -d + 0.02), Vector3(w, 0.012, 0.004), grout)
		y += 0.5
	var drain := _cyl(self, COLUMN + Vector3(0, 0.093, 0.9), 0.14, 0.006, Art.material("gunmetal", Color(0.3, 0.31, 0.33)))
	drain.name = "Drain"


## The white light she stands in: a lamp in the ceiling over her frame, the
## column of light down to the floor, and rings of it sinking over her.
func _build_light(h: float) -> void:
	var iron := Art.material("gunmetal")
	_cyl(self, COLUMN + Vector3.UP * (h - 0.08), 0.5, 0.16, iron)
	_glows.append(_cyl(self, COLUMN + Vector3.UP * (h - 0.17), FIELD_R - 0.1, 0.02, Kit.glow(FIELD)))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_color = Color(FIELD, 0.07)
	mat.render_priority = -1
	var top := h - 0.2
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
	_field_light = OmniLight3D.new()
	_field_light.light_color = FIELD
	_field_light.light_energy = 1.1
	_field_light.omni_range = 4.0
	_field_light.position = COLUMN + Vector3(0, 2.4, 0.3)
	add_child(_field_light)


## The screen in front of her face, hung off the ceiling on a pole and turned
## to her: dark glass, white rings turning out from its middle and one word at
## a time. From the street you see its grey back.
func _build_feed(h: float) -> void:
	_feed = Node3D.new()
	_feed.name = "Feed"
	_feed.position = COLUMN + FEED_AT
	_feed.rotation_degrees = Vector3(0, 180, 0)   # its face (+z) toward her
	add_child(_feed)
	var casing := _flat(Color(0.55, 0.58, 0.62))
	K.mesh(_feed, Vector3(0, 0, -0.02), Vector3(0.62, 0.4, 0.04), casing)
	K.mesh(_feed, Vector3(0, (h - FEED_AT.y) * 0.5 + 0.1, -0.02), Vector3(0.03, h - FEED_AT.y - 0.2, 0.03), casing)
	_glows.append(K.mesh(_feed, Vector3(0, 0, 0.001), Vector3(0.56, 0.34, 0.002), Kit.glow(Color(0.04, 0.05, 0.08))))
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(FIELD, 0.8)
	for i in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.1
		torus.outer_radius = 0.106
		torus.rings = 32
		torus.ring_segments = 4
		ring.mesh = torus
		ring.material_override = ring_mat
		ring.rotation_degrees = Vector3(90, 0, 0)
		ring.position = Vector3(0, 0, 0.004)
		_feed.add_child(ring)
		_feed_rings.append(ring)
	_feed_word = Kit.label(_feed, Vector3(0, -0.12, 0.006), FEED_WORDS[0], 40)
	_feed_word.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_feed_word.pixel_size = 0.0018
	_feed_word.outline_size = 0
	_feed_word.render_priority = 2
	_feed_word.modulate = FIELD


## A white fitting frame behind someone standing at `at` facing +z: two posts
## and a top bar, a power strip up each post. `live` is hers, lit; the others
## are dark, with a dead visor hung off the top bar.
func _build_frame(at: Vector3, live: bool, n := 0) -> void:
	var white := _flat(Color(0.93, 0.94, 0.96))
	var trim := _flat(Color(0.55, 0.6, 0.68))
	for s in [-1.0, 1.0]:
		Kit.box(self, at + Vector3(0.55 * s, 1.1, -0.35), Vector3(0.1, 2.2, 0.1), Color.WHITE, Vector3.ZERO, white)
		var strip := K.mesh(self, at + Vector3(0.55 * s, 1.1, -0.295), Vector3(0.03, 1.6, 0.01), Kit.glow(FIELD) if live else trim)
		if live:
			_pylons.append(strip)
	K.mesh(self, at + Vector3(0, 2.2, -0.35), Vector3(1.2, 0.1, 0.1), white)
	K.mesh(self, at + Vector3(0, 0.03, -0.1), Vector3(1.2, 0.06, 0.6), trim)
	if live:
		_glows.append(K.mesh(self, at + Vector3(0, 2.2, -0.295), Vector3(0.9, 0.025, 0.01), Kit.glow(FIELD)))
		return
	# the visor of whoever stood here, hung by its strap off the top bar
	var visor := Node3D.new()
	visor.name = "HungVisor%d" % n
	visor.position = at + Vector3(0.2, 1.95, -0.3)
	visor.rotation_degrees = Vector3(0, 0, 12)
	add_child(visor)
	K.mesh(visor, Vector3.ZERO, Vector3(0.19, 0.06, 0.09), white)
	K.mesh(visor, Vector3(0, 0, 0.046), Vector3(0.15, 0.012, 0.004), trim)
	K.mesh(visor, Vector3(0, 0.14, -0.02), Vector3(0.012, 0.24, 0.012), trim)


## The steel cart by the screen: a tray of Hymn films cut into strips, and a
## sealed case of Glass reference vials from Marrow.
func _build_cart() -> void:
	var steel := Art.material("gunmetal", Color(0.75, 0.78, 0.82))
	var at := Vector3(-1.6, 0.0, -1.2)
	K.mesh(self, at + Vector3(0, 0.85, 0), Vector3(0.8, 0.04, 0.5), steel)
	K.mesh(self, at + Vector3(0, 0.35, 0), Vector3(0.8, 0.03, 0.5), steel)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			K.mesh(self, at + Vector3(0.37 * sx, 0.44, 0.22 * sz), Vector3(0.03, 0.86, 0.03), steel)
	# the tray, and the films on it in a neat row, faintly glowing
	var tray := K.mesh(self, at + Vector3(-0.15, 0.885, 0), Vector3(0.36, 0.03, 0.3), _flat(Color(0.93, 0.94, 0.96)))
	tray.name = "FilmTray"
	var film := Kit.glow(Color(0.95, 0.98, 1.0))
	for i in 6:
		_glows.append(K.mesh(self, at + Vector3(-0.29 + i * 0.056, 0.903, 0), Vector3(0.035, 0.004, 0.22), film))
	# the case: dark, latched, a colony seal on the lid, violet vials in foam
	var case := Node3D.new()
	case.name = "GlassCase"
	case.position = at + Vector3(0.2, 0.87, 0)
	add_child(case)
	K.mesh(case, Vector3(0, 0.03, 0), Vector3(0.3, 0.06, 0.22), _flat(Color(0.12, 0.13, 0.16)))
	for i in 4:
		var vial := _cyl(case, Vector3(-0.09 + i * 0.06, 0.09, 0), 0.014, 0.08, Kit.glow(GLASS))
		vial.name = "Vial%d" % i
	var tag := Kit.label(case, Vector3(0, 0.07, 0.115), "REFERENCE: GLASS\nSUPPLIER: M.", 22)
	tag.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	tag.pixel_size = 0.0016
	tag.rotation_degrees = Vector3(-90, 0, 0)   # printed on the lid
	tag.position = Vector3(0, 0.061, 0.07)
	tag.outline_size = 0
	tag.modulate = GLASS


func _wall_text(at: Vector3, size: int) -> Label3D:
	var l := Kit.label(self, at, "", size)
	l.modulate = FIELD
	l.outline_size = 0
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED   # flat on the left wall
	l.rotation_degrees = Vector3(0, 90, 0)
	l.pixel_size = 0.0035
	l.render_priority = 2   # over the screen's dark glass
	return l


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.35
	return m


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


## Shorts out the screen and the bay's power with it: the frame's strips
## flare and die, the white light goes out, and a beat later Eco lifts the
## dead visor off her, pulls the headphones and the band (_unmask). The cuff stays on.
## Returns false if it's already open.
func release() -> bool:
	if not can_open():
		return false
	opened = true
	# the screen shorts out with a crack, the frame dies, the light goes out
	SFX.play_at(self, global_position + Vector3(0, 1.5, 0), "spark", 0.0, 0.8)
	SFX.play_at(self, global_position + Vector3(0, 1.5, 0), "titan_powerdown", -4.0, 1.2)
	SFX.play_at(self, global_position + Vector3(0, 0.5, 0), "titan_hiss_short", -8.0, 1.3)
	_screen.queue_free()
	_screen = null
	var dead := Art.material("gunmetal", Color(0.35, 0.36, 0.38))
	for strip: MeshInstance3D in _pylons:
		strip.material_override = Kit.glow(Color(1.0, 0.55, 0.3))
		get_tree().create_timer(0.25, false).timeout.connect(_burn_out.bind(strip, dead))
	for line in _glows:
		if is_instance_valid(line):
			line.material_override = dead
	_field.visible = false
	for ring in _rings:
		ring.visible = false
	_field_light.light_energy = 0.0
	_light.light_energy = 0.3   # the street's spill, now the screen's gone
	# the screen in her face goes dark, and the clamps spring open
	for ring in _feed_rings:
		ring.visible = false
	_feed_word.text = ""
	for c in _clamps:
		c.queue_free()
	_clamps.clear()
	if _pose != null:
		_pose.queue_free()   # her arms come down
		_pose = null
	if ophelia != null:
		if ophelia._anim != null:
			ophelia._anim.speed_scale = 1.0
			ophelia.posed = false
			if ophelia._anim.has_animation("idle"):
				ophelia._anim.play("idle", 0.25)
		ophelia.mood(["closed"])
		get_tree().create_timer(0.9, false).timeout.connect(_unmask)
	_refresh()
	freed.emit()
	return true


## The visor, headphones and neck band come off her (the cuff's pins don't): she blinks
## in the dark like she's just woken up.
func _unmask() -> void:
	if not is_instance_valid(ophelia):
		return
	SFX.play_at(self, ophelia.global_position + Vector3(0, 1.5, 0), "titan_hiss_short", -14.0, 1.6)
	ColonyGear.apply(ophelia, KEPT_GEAR)
	ophelia.mood(["surprised"])


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
	# the trial on the wall, dark once the bay's power is gone
	if _manifest != null:
		_manifest.text = "" if opened else TRIAL_TEXT
	if _log != null:
		_log.text = "" if opened else LOG
