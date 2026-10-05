extends "res://scripts/ps2/ps2_model.gd"
## Root script of assets/models/eco.tscn, the heroine (rigged mesh from
## assets/models/eco/eco.glb). Picks her animation from the CharacterBody3D she
## belongs to (idle, walk, run, fall, crouch, slide; the player's movement state
## when there is one) and runs the spring bones that make her hair swing and
## settle and her chest and glutes jiggle. Drop the scene in anywhere: on her
## own she just idles.

## Play the idle loop (breathing, glancing around) while standing.
@export var idle_motion := true
## Ground speed (m/s) the walk animation is authored at.
@export var walk_speed := 1.3
## Ground speed (m/s) the run animation is authored at.
@export var run_speed := 6.0
## Above this ground speed she runs instead of walking.
@export var run_threshold := 3.2
## Ground speed (m/s) the strut is authored at: off duty (player.gd strolling)
## she walks with the walk animation plus the strut layered on top (_strut).
@export var strut_speed := 1.55
## How much strut to layer on the walk (1 = as tuned, 0 = a plain walk).
@export_range(0.0, 2.0) var strut := 1.0
## Seconds to blend from one animation into the next (slides and falls take half).
@export var anim_blend := 0.25
## Play the walk and run strides backwards (she's backpedalling; set by
## scripts/ps2/eco_combat_moves.gd while her legs face away from where she goes).
var stride_reverse := false
## Simulate the spring bones (hair, chest and glute jiggle).
@export var springs_enabled := true
## How her chest, glutes and hair move (JIGGLE_STYLES): "classic" (the tuning
## she has had since PR #27), "anime" (slower, floatier bounces that ease out
## at the edge of their swing) or "realistic" (firm, quick, mostly up and
## down, settling after one small rebound). Left unset, she follows the
## Jiggle style setting (Game tab, prefs.gd) and changes when it does.
@export_enum("classic", "anime", "realistic") var jiggle_style := "classic":
	set(value):
		jiggle_style = value if JIGGLE_STYLES.has(value) else "classic"
		_style_chosen = true
		if is_in_group("eco_jiggle"):
			remove_from_group("eco_jiggle")
		_apply_jiggle_style()
## How far her chest and glutes may bounce (1 = as tuned, 0 = not at all).
@export_range(0.0, 2.0) var jiggle := 1.0
## Her suit upgrade (scripts/hub/armory.gd SUIT_TIERS): 0 is the bare pilot
## suit; each tier shows its armour pieces (the glb's suit_t<tier>_* meshes,
## from tools/eco/build_eco_vroid.py) on top of the tiers before it. Tier 5
## repaints the plates in Dad's colours and turns every trim gold.
@export_range(0, 5) var suit_tier := 0:
	set(value):
		suit_tier = clampi(value, 0, SUIT_TIERS)
		if is_inside_tree():
			apply_suit()
## The suit's weight (armory.gd SUIT_WEIGHTS). Pieces are marked after their
## tier: "l" light only (the cloth-and-leather light suit), "m" medium and
## heavy, "h" heavy only, unmarked for all three. The light suit also swaps
## her bodysuit for its own cut (eco_v_body_light: no side cutouts, open
## across the top of her chest) once she has a suit tier.
@export_enum("light", "medium", "heavy") var suit_weight := "medium":
	set(value):
		suit_weight = value
		if is_inside_tree():
			apply_suit()
## What she has on (wear() by name; picked in her wardrobe,
## scripts/hub/wardrobe.gd). "suit" is her own pilot suit (gwen), the other
## suit_* are the other looks baked by tools/eco/build_eco_vroid.py
## BASE_STYLES: each shows with no suit upgrade, and the upgrades' cuts go over
## any of them. "skater", "y2k" and "date" are her clothes off duty (outfit_graph),
## every suit piece hidden; each comes in a Teen and a Mature version, picked
## by the content rating (scripts/radio/content_rating.gd, O key) as it changes.
@export_enum("suit", "suit_ghost", "suit_racer", "suit_harness", "suit_techwear", "suit_shade", "suit_homemade",
		"suit_ophelia", "suit_vesper", "suit_vesper_open", "skater", "y2k", "date") var outfit := "suit":
	set(value):
		outfit = value if value in OUTFITS else "suit"
		if is_inside_tree():
			apply_suit()
## A rest pose layered over her animation (scripts/ps2/eco_rest.gd): "sleep",
## "sit" or "lounge"; "" lets her animation play. She settles into it (and back
## out) over a moment, and moves from one to another without standing up.
@export var rest_pose := ""
## Top of the seat or bed under her for the rest pose, metres above her origin
## (which is the floor under her hips).
@export var rest_seat_height := 0.5

## Spring bones (the VRoid rig's J_Sec_* bones; the glute ones are added by
## tools/eco/build_eco_vroid.py): how hard each pulls back to its pose, how
## much speed it keeps per frame (1 - drag), how much gravity pulls its tip,
## the most it may swing away from its pose, and how much of her movement
## through the world it feels (1 = all of it: hair streams back when she runs;
## low = only her own motion: the jiggle bounces with her steps and landings
## without being dragged back by her speed).
const HAIR := {"group": "hair", "stiffness": 0.14, "drag": 0.2, "gravity": 0.7, "limit": 30.0, "inertia": 0.6}
const HAIR_TIP := {"group": "hair", "stiffness": 0.12, "drag": 0.2, "gravity": 0.6, "limit": 20.0, "inertia": 0.6}
# the fringe hangs over her face: it may lift off it, but swinging far back would go into her head
const FRINGE := {"group": "hair", "stiffness": 0.16, "drag": 0.22, "gravity": 0.5, "limit": 12.0, "inertia": 0.35}
const FRINGE_TIP := {"group": "hair", "stiffness": 0.14, "drag": 0.22, "gravity": 0.5, "limit": 10.0, "inertia": 0.35}
const BUST := {"group": "bust", "stiffness": 0.14, "drag": 0.08, "gravity": 0.15, "limit": 24.0, "inertia": 0.2, "jiggle": true}
# the back hair chains below the nape: only the salon's long cuts (braids, ponytail; scripts/hub/hair.gd) hang from them
const BRAID := {"group": "hair", "stiffness": 0.1, "drag": 0.16, "gravity": 0.9, "limit": 28.0, "inertia": 0.5}
const GLUTE := {"group": "glute", "stiffness": 0.18, "drag": 0.09, "gravity": 0.15, "limit": 18.0, "inertia": 0.2, "jiggle": true}
const SPRINGS := {
	# locks 01-02 hang at the back, 03-04 at the sides, 05-09 are the fringe;
	# the side and fringe locks bend once more at their second joint
	"J_Sec_Hair1_01": HAIR, "J_Sec_Hair1_02": HAIR, "J_Sec_Hair1_03": HAIR, "J_Sec_Hair1_04": HAIR,
	"J_Sec_Hair2_03": HAIR_TIP, "J_Sec_Hair2_04": HAIR_TIP,
	"J_Sec_Hair1_05": FRINGE, "J_Sec_Hair1_06": FRINGE, "J_Sec_Hair1_07": FRINGE, "J_Sec_Hair1_08": FRINGE,
	"J_Sec_Hair1_09": FRINGE,
	"J_Sec_Hair2_05": FRINGE_TIP, "J_Sec_Hair2_06": FRINGE_TIP, "J_Sec_Hair2_07": FRINGE_TIP,
	"J_Sec_Hair2_08": FRINGE_TIP, "J_Sec_Hair2_09": FRINGE_TIP,
	"J_Sec_Hair2_01": BRAID, "J_Sec_Hair2_02": BRAID, "J_Sec_Hair3_01": BRAID, "J_Sec_Hair3_02": BRAID,
	"J_Sec_Hair4_01": BRAID, "J_Sec_Hair4_02": BRAID,
	"J_Sec_L_Bust1": BUST, "J_Sec_R_Bust1": BUST,
	"J_Sec_L_Glute1": GLUTE, "J_Sec_R_Glute1": GLUTE,
}

## Jiggle styles: per spring group, values that replace the group's own
## (bust, glute) or scale them (hair: "<key>_scale"). Extra keys:
## "soft" eases the swing into its limit instead of stopping it dead;
## "lateral" is how much side-to-side swing is kept (1 = all).
const JIGGLE_STYLES := {
	"classic": {},
	# about 2.5 bounces a second that take a second to die away, big rounded swings
	"anime": {
		"bust": {"stiffness": 0.07, "drag": 0.065, "gravity": 0.08, "limit": 30.0, "inertia": 0.25, "soft": true},
		"glute": {"stiffness": 0.08, "drag": 0.07, "gravity": 0.08, "limit": 22.0, "inertia": 0.25, "soft": true},
		"hair": {"stiffness_scale": 0.8, "drag_scale": 0.7, "gravity_scale": 0.6},
	},
	# about 5 bounces a second, one small rebound and still within a quarter second
	"realistic": {
		"bust": {"stiffness": 0.28, "drag": 0.22, "gravity": 0.3, "limit": 12.0, "inertia": 0.2, "lateral": 0.45},
		"glute": {"stiffness": 0.32, "drag": 0.25, "gravity": 0.3, "limit": 9.0, "inertia": 0.2, "lateral": 0.45},
		"hair": {"stiffness_scale": 1.15, "drag_scale": 1.4, "gravity_scale": 1.3},
	},
}

const SUIT_TIERS := 5
const LEGACY_PLATE := preload("res://assets/materials/eco/eco_v_armor_legacy.tres")
const LIGHT_BODY := preload("res://assets/materials/eco/eco_v_body_light.tres")
const MEDIUM_BODY := preload("res://assets/materials/eco/eco_v_body_medium.tres")
const HEAVY_BODY := preload("res://assets/materials/eco/eco_v_body_heavy.tres")
## Everything she can wear (outfit): her pilot suits, then her clothes. Each
## suit but her own has its bodysuit material, and its own pieces in the glb as
## base_<style>_* (a jacket, cowl, vest or skirt; harness and the vesper looks
## have none). The vesper looks are Vesper Kane's clothes (a concept character,
## Eco wears them for now): Mature rating only (MATURE_OUTFITS).
const OUTFITS := ["suit", "suit_ghost", "suit_racer", "suit_harness", "suit_techwear", "suit_shade", "suit_homemade",
		"suit_ophelia", "suit_vesper", "suit_vesper_open", "skater", "y2k", "date"]
## Outfits only offered under the Mature content rating (wardrobe.gd).
const MATURE_OUTFITS := ["suit_vesper", "suit_vesper_open"]
const STYLE_BODY := {
	"suit_ghost": preload("res://assets/materials/eco/eco_v_body_ghost.tres"),
	"suit_racer": preload("res://assets/materials/eco/eco_v_body_racer.tres"),
	"suit_harness": preload("res://assets/materials/eco/eco_v_body_harness.tres"),
	"suit_techwear": preload("res://assets/materials/eco/eco_v_body_techwear.tres"),
	"suit_shade": preload("res://assets/materials/eco/eco_v_body_shade.tres"),
	"suit_homemade": preload("res://assets/materials/eco/eco_v_body_homemade.tres"),
	"suit_ophelia": preload("res://assets/materials/eco/eco_v_body_ophelia.tres"),
	"suit_vesper": preload("res://assets/materials/eco/eco_v_body_vesper.tres"),
	"suit_vesper_open": preload("res://assets/materials/eco/eco_v_body_vesper_open.tres"),
}
## Her clothes' body textures, by look() (<outfit>_t Teen, <outfit>_m Mature);
## their loose parts are the glb's outfit_<outfit>_<t|m|any>_* meshes.
const OUTFIT_BODY := {
	"skater_t": preload("res://assets/materials/eco/eco_v_body_skater_t.tres"),
	"skater_m": preload("res://assets/materials/eco/eco_v_body_skater_m.tres"),
	"y2k_t": preload("res://assets/materials/eco/eco_v_body_y2k_t.tres"),
	"y2k_m": preload("res://assets/materials/eco/eco_v_body_y2k_m.tres"),
	"date_t": preload("res://assets/materials/eco/eco_v_body_date_t.tres"),
	"date_m": preload("res://assets/materials/eco/eco_v_body_date_m.tres"),
}
## Clothes she leaves her goggles off for, and her boots for (her sneakers
## are outfit_<outfit>_any_shoes; she laces her boots up for a date).
const NO_GOGGLES := ["date", "skater", "y2k"]
const NO_BOOTS := ["skater", "y2k"]
## Her date-night makeup (deeper smoky eyes, a sharper wing, red lips).
const DATE_FACE := preload("res://assets/materials/eco/eco_v_face_date.tres")
const ContentRating := preload("res://scripts/radio/content_rating.gd")
const EcoRest := preload("res://scripts/ps2/eco_rest.gd")
const Prefs := preload("res://scripts/game/prefs.gd")
const Hair := preload("res://scripts/hub/hair.gd")
## Her face while she sleeps (blend shape -> weight); the import's fierce look
## comes back when she wakes.
const ASLEEP_FACE := {"Fcl_EYE_Close": 1.0, "Fcl_EYE_Angry": 0.0, "Fcl_BRW_Angry": 0.25, "Fcl_MTH_Down": 0.0}

## Movement states of scripts/player.gd (enum State).
enum PlayerState { GROUND, AIR, SLIDE, WALLRUN, GRAPPLE }

var skeleton: Skeleton3D
var _anim: AnimationPlayer
## Whether jiggle_style was set on this copy (a tool or test) rather than taken
## from the setting.
var _style_chosen := false
var _springs: Array[Dictionary] = []
var _last_origin := Vector3.ZERO
## Strut and off-duty stance blend in and out over a moment (0..1).
var _strut_weight := 0.0
var _pose_weight := 0.0
var _bones := {}
## What the strut changed last frame (bone -> [pose before, pose after]), so it
## can be undone when nothing re-posed the bone since (a paused animation).
var _strut_undo := {}
var _rest: EcoRest
var _face: MeshInstance3D
## The face's weights from before she fell asleep (blend shape index -> weight).
var _awake_face := {}
## The content rating her clothes were last put on for.
var _dressed_rating := ""


func _ready() -> void:
	super()
	process_priority = 10  # after her AnimationPlayer, so the springs follow this frame's pose
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		for bone_name: String in SPRINGS:
			var i := skeleton.find_bone(bone_name)
			if i >= 0:
				var s: Dictionary = SPRINGS[bone_name].duplicate()
				s["bone"] = i
				s["parent"] = skeleton.get_bone_parent(i)
				# a spring points from its bone to its first child (VRoid bones
				# don't point along their own axes)
				var children := skeleton.get_bone_children(i)
				s["aim"] = skeleton.get_bone_rest(children[0]).origin if children.size() > 0 else Vector3.UP * 0.1
				s["ready"] = false
				s["base"] = SPRINGS[bone_name]
				_springs.append(s)
		# parents before children, so a lock's second joint follows its root
		_springs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["bone"] < b["bone"])
		_apply_jiggle_style()
		_last_origin = skeleton.global_position
		for bone_name: String in STRUT_BONES:
			_bones[bone_name] = skeleton.find_bone(STRUT_BONES[bone_name])
		_bones["hips_at"] = _bones["hips"]
		_rest = EcoRest.new(skeleton)
		if not _rest.usable():
			_rest = null
	if not _style_chosen:
		follow_jiggle_setting()
	_face = find_child("Face", true, false) as MeshInstance3D
	Hair.apply(self, "eco")  # her haircut from the salon in Solace
	set_process(_anim != null or not _springs.is_empty())
	apply_suit()
	if _anim != null and idle_motion:
		_anim.play("idle")


## The tier a suit_t<tier>[l|m|h]_* mesh belongs to (0 for everything else).
static func piece_tier(mesh_name: String) -> int:
	return int(mesh_name.substr(6, 1)) if mesh_name.begins_with("suit_t") else 0


## Whether a suit weight wears a piece: "l" light only, "m" medium only, "h" heavy only,
## anything else every weight.
static func piece_worn(mesh_name: String, weight: String) -> bool:
	match mesh_name.substr(7, 1):
		"l":
			return weight == "light"
		"m":
			return weight == "medium"
		"h":
			return weight == "heavy"
	return true


## Puts her in one of her suits or clothes (OUTFITS) by name; false (and nothing
## changes) for anything else, such as clothes she doesn't have.
func wear(outfit_name: String) -> bool:
	if not outfit_name in OUTFITS:
		return false
	outfit = outfit_name
	return true


## Her suit's style: "gwen" for her own, else the name after "suit_" ("" in clothes).
func style() -> String:
	if not suited():
		return ""
	return "gwen" if outfit == "suit" else outfit.trim_prefix("suit_")


## Whether she has a pilot suit on (not her clothes).
func suited() -> bool:
	return outfit.begins_with("suit")


## Which version of her clothes she has on: "<outfit>_t" or "<outfit>_m" for
## the content rating ("" in a suit).
func look() -> String:
	if suited():
		return ""
	return outfit + ("_m" if ContentRating.current() == "M" else "_t")


## Shows the armour of every tier up to suit_tier, in Dad's colours at the top
## tier, or her clothes and their loose parts.
func apply_suit() -> void:
	var suited_ := suited()
	var legacy := suited_ and suit_tier >= SUIT_TIERS
	var rating := look().right(1)
	_dressed_rating = ContentRating.current()
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var tier := piece_tier(String(mi.name))
		var mesh_name := String(mi.name)
		if mesh_name.begins_with("Goggles"):
			mi.visible = not outfit in NO_GOGGLES
		elif mesh_name.begins_with("Boots"):
			mi.visible = not outfit in NO_BOOTS
		if mesh_name.begins_with("outfit_"):  # her clothes' loose parts, for her rating or any
			mi.visible = mesh_name.begins_with("outfit_%s_" % outfit) and mesh_name.get_slice("_", 2) in [rating, "any"]
		elif mesh_name.begins_with("base_"):  # the bare suit's own pieces (its jacket)
			mi.visible = suited_ and suit_tier == 0 and mesh_name.begins_with("base_%s_" % style())
		elif tier > 0 and mi.mesh != null:
			mi.visible = suited_ and tier <= suit_tier and piece_worn(mesh_name, suit_weight)
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i)
				if m != null and m.resource_name == "eco_v_armor":
					mi.set_surface_override_material(i, LEGACY_PLATE if legacy else null)
		elif tier == 0 and mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i)
				if m != null and m.resource_name == "eco_v_body":
					mi.set_surface_override_material(i, body_material())
				elif m != null and m.resource_name == "eco_v_face":
					mi.set_surface_override_material(i, DATE_FACE if outfit == "date" else null)
		mi.set_instance_shader_parameter("trim_gold", 1.0 if legacy else 0.0)


## Her clothes' body texture, or the bodysuit for her weight: each weight has
## its own cut (tools/eco/build_eco_vroid.py suit_graph); the bare suit uses
## the base one (her style's).
func body_material() -> Material:
	if not suited():
		return OUTFIT_BODY[look()]
	if suit_tier <= 0:
		return STYLE_BODY.get(outfit)
	match suit_weight:
		"light":
			return LIGHT_BODY
		"medium":
			return MEDIUM_BODY
		"heavy":
			return HEAVY_BODY
	return null


## The animation she should play now, with its playback speed.
func pick_animation() -> Array:
	if _body == null:
		return ["idle", 1.0]
	var speed := Vector2(_body.velocity.x, _body.velocity.z).length()
	var state = _body.get("state")
	if state != null:
		match state:
			PlayerState.SLIDE:
				return ["slide", 1.0]
			PlayerState.AIR, PlayerState.GRAPPLE:
				return ["fall", 1.0]
			PlayerState.WALLRUN:
				return ["run", maxf(speed / run_speed, 0.8)]
		if _body.get("crouching"):
			return ["crouch", 1.0]
	elif not _body.is_on_floor():
		return ["fall", 1.0]
	if speed > run_threshold:
		return ["run", speed / run_speed]
	if speed > 0.3:
		if strolling():
			# a longer, more deliberate stride as she speeds up
			return ["walk", speed / maxf(strut_speed, speed * 0.8)]
		return ["walk", speed / walk_speed]
	return ["idle", 1.0]


## Whether she's off duty (the player's strolling flag: the hub and town).
func strolling() -> bool:
	return _body != null and _body.get("strolling") == true


func _process(delta: float) -> void:
	if not suited() and ContentRating.current() != _dressed_rating:
		apply_suit()  # the rating changed (O): the other version of her clothes
	if _anim != null:
		_animate()
		_strut(delta)
		_rest_layer(delta)
	if springs_enabled and skeleton != null:
		_step_springs(delta)


func _animate() -> void:
	var pick := pick_animation()
	var anim_name: String = pick[0]
	if anim_name == "idle" and not idle_motion:
		if _anim.is_playing():
			_anim.pause()
		return
	if _anim.current_animation != anim_name:
		var blend := anim_blend * 0.5 if anim_name in ["slide", "fall"] else anim_blend
		_anim.play(anim_name, blend)
	_anim.speed_scale = -pick[1] if stride_reverse and anim_name in ["walk", "run"] else pick[1]


## Whether she is in (or settling into) a rest pose.
func resting() -> bool:
	return rest_pose != "" or (_rest != null and _rest.weight > 0.0)


## How far she has settled into her rest pose (0 = her animation, 1 = the pose),
## and how far she has moved from her last pose into this one.
func rest_weight() -> float:
	return smoothstep(0.0, 1.0, _rest.weight) if _rest != null else 0.0


func rest_blend() -> float:
	return smoothstep(0.0, 1.0, _rest.blend) if _rest != null else 1.0


## Lays her rest pose over this frame's animation, and closes her eyes while she sleeps.
func _rest_layer(delta: float) -> void:
	if _rest == null:
		return
	_rest.seat_height = rest_seat_height
	_rest.step(delta, rest_pose)
	_set_asleep(_rest.pose == "sleep" and _rest.weight > 0.6 and rest_pose == "sleep")


func _set_asleep(asleep: bool) -> void:
	if _face == null or _face.mesh == null or asleep == not _awake_face.is_empty():
		return
	if asleep:
		for shape: String in ASLEEP_FACE:
			var i := _face.find_blend_shape_by_name(shape)
			if i >= 0:
				_awake_face[i] = _face.get_blend_shape_value(i)
				_face.set_blend_shape_value(i, ASLEEP_FACE[shape])
	else:
		for i: int in _awake_face:
			_face.set_blend_shape_value(i, _awake_face[i])
		_awake_face.clear()


## Bones the strut moves (skeleton names), applied parents first.
const STRUT_BONES := {
	"hips": "J_Bip_C_Hips", "spine": "J_Bip_C_Spine", "chest": "J_Bip_C_Chest", "head": "J_Bip_C_Head",
	"thigh.R": "J_Bip_R_UpperLeg", "thigh.L": "J_Bip_L_UpperLeg", "shin.L": "J_Bip_L_LowerLeg",
	"upperarm.R": "J_Bip_R_UpperArm", "upperarm.L": "J_Bip_L_UpperArm",
	"forearm.R": "J_Bip_R_LowerArm", "forearm.L": "J_Bip_L_LowerArm",
	"hand.R": "J_Bip_R_Hand", "hand.L": "J_Bip_L_Hand",
}


## Off duty she struts: layered over the walk (in step with it), her hips sway
## out over each standing leg and roll up on that side, each foot lands in
## front of the other, her shoulders sit back and counter the hips, her arms
## swing loose with the wrists flicked out, chin up. Standing still she rests
## her weight on one hip. In skeleton space she faces -Z, her right is +X.
func _strut(delta: float) -> void:
	if skeleton == null or _bones.is_empty():
		return
	for key: String in _strut_undo:
		var i: int = _bones[key]
		var undo: Array = _strut_undo[key]
		if key == "hips_at":
			if skeleton.get_bone_pose_position(i).is_equal_approx(undo[1]):
				skeleton.set_bone_pose_position(i, undo[0])
		elif skeleton.get_bone_pose_rotation(i).is_equal_approx(undo[1]):
			skeleton.set_bone_pose_rotation(i, undo[0])
	_strut_undo.clear()
	var off_duty := strolling() and strut > 0.0
	var walking := off_duty and _anim.current_animation == "walk"
	var standing := off_duty and _anim.current_animation == "idle" and not resting()
	_strut_weight = move_toward(_strut_weight, 1.0 if walking else 0.0, delta * 4.0)
	_pose_weight = move_toward(_pose_weight, 1.0 if standing else 0.0, delta * 2.0)
	if _strut_weight <= 0.0 and _pose_weight <= 0.0:
		return
	var w := _strut_weight * strut
	var p := _pose_weight * strut
	# the walk's own phase: its right thigh swings forward with sin(t)
	var t := 0.0
	if _anim.current_animation == "walk" and _anim.current_animation_length > 0.0:
		t = _anim.current_animation_position / _anim.current_animation_length * TAU
	var sw := sin(t)
	var stance := -cos(t)  # +1 her weight on her right leg, -1 on her left
	# hips: shift over the standing leg, roll up on its side, twist with the stride
	var shift := 0.045 * stance * w + 0.055 * p
	var roll := 9.0 * stance * w + 8.0 * p
	_offset_hips(Vector3(shift, -0.012 * absf(stance) * w - 0.02 * p, 0.0))
	_turn("hips", Vector3.BACK, roll)
	_turn("hips", Vector3.UP, 7.0 * sw * w - 6.0 * p)
	# legs: back to upright under the rolled hips, then crossed in toward the line
	# she walks (most as each foot reaches forward, least as the legs pass)
	var reach := 0.35 + 0.65 * absf(sw)
	var lean := rad_to_deg(atan(shift / 0.88))
	_turn("thigh.R", Vector3.BACK, -roll - lean - 4.5 * reach * w)
	_turn("thigh.L", Vector3.BACK, -roll - lean + 4.5 * reach * w + 4.0 * p)
	_turn("thigh.R", Vector3.RIGHT, 4.0 * sw * w)
	_turn("thigh.L", Vector3.RIGHT, -4.0 * sw * w + 10.0 * p)
	_turn("shin.L", Vector3.RIGHT, -18.0 * p)  # standing: her free knee bends in
	# torso: upright, shoulders back, countering the hips so her head stays level
	_turn("spine", Vector3.RIGHT, 2.0 * w + 1.0 * p)
	_turn("chest", Vector3.BACK, -0.75 * roll)
	_turn("chest", Vector3.UP, -6.0 * sw * w + 4.0 * p)
	_turn("chest", Vector3.RIGHT, 3.0 * (w + p))
	_turn("head", Vector3.BACK, -0.2 * roll + 4.0 * p)
	_turn("head", Vector3.RIGHT, 3.0 * (w + p))
	# arms: a looser, smaller swing kept a little behind her, elbows soft, wrists flicked out
	_turn("upperarm.R", Vector3.RIGHT, 7.0 * sw * w - 4.0 * w)
	_turn("upperarm.L", Vector3.RIGHT, -7.0 * sw * w - 4.0 * w)
	_turn("upperarm.R", Vector3.BACK, 4.0 * w + 6.0 * p)
	_turn("upperarm.L", Vector3.BACK, -4.0 * w - 2.0 * p)
	_turn("forearm.R", Vector3.RIGHT, 10.0 * w + 8.0 * p)
	_turn("forearm.L", Vector3.RIGHT, 10.0 * w + 6.0 * p)
	_turn("hand.R", Vector3.BACK, 14.0 * (w + p))
	_turn("hand.L", Vector3.BACK, -14.0 * (w + p))


## Rotates a bone about a skeleton-space axis through its joint, on top of its
## current pose (like tools/eco/build_eco_vroid.py turn()).
func _turn(bone: String, axis: Vector3, deg: float) -> void:
	var i: int = _bones.get(bone, -1)
	if i < 0 or absf(deg) < 0.01:
		return
	var parent := skeleton.get_bone_parent(i)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
	var before := skeleton.get_bone_pose_rotation(i)
	var turned := (parent_basis.inverse() * Basis(axis, deg_to_rad(deg)) * parent_basis * Basis(before)).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(i, turned)
	_strut_undo[bone] = [_strut_undo[bone][0] if _strut_undo.has(bone) else before, turned]


## Moves her hips (and everything on them) by a skeleton-space offset.
func _offset_hips(offset: Vector3) -> void:
	var i: int = _bones.get("hips", -1)
	if i < 0:
		return
	var parent := skeleton.get_bone_parent(i)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
	var before := skeleton.get_bone_pose_position(i)
	var moved := before + parent_basis.inverse() * offset
	skeleton.set_bone_pose_position(i, moved)
	_strut_undo["hips_at"] = [before, moved]


## Takes the Jiggle style setting (Prefs.set_jiggle_style calls this on every
## Eco in the "eco_jiggle" group).
func follow_jiggle_setting() -> void:
	jiggle_style = Prefs.jiggle_style()
	_style_chosen = false
	add_to_group("eco_jiggle")


## Sets every spring's settings from its group's own and jiggle_style's.
func _apply_jiggle_style() -> void:
	var style: Dictionary = JIGGLE_STYLES.get(jiggle_style, {})
	for s in _springs:
		var base: Dictionary = s["base"]
		for key: String in ["stiffness", "drag", "gravity", "limit", "inertia"]:
			s[key] = base[key]
		s.erase("soft")
		s.erase("lateral")
		var tune: Dictionary = style.get(base.get("group", ""), {})
		for key: String in tune:
			if key.ends_with("_scale"):
				var k := key.trim_suffix("_scale")
				s[k] = base[k] * float(tune[key])
			else:
				s[key] = tune[key]


## Shoves her chest and glute springs by a world-space offset (metres at the
## spring's tip), as if her body had jolted the other way: they swing out and
## bounce back. The first-person body (scripts/eco_fp_body.gd) uses it so jumps,
## landings and quick looks read on screen.
func nudge(push: Vector3) -> void:
	for s in _springs:
		if s.get("jiggle", false) and s["ready"]:
			s["tip"] += push


func _step_springs(delta: float) -> void:
	var to_world := skeleton.global_transform
	var to_skel := to_world.affine_inverse()
	var steps := clampf(delta * 60.0, 0.25, 3.0)
	var moved := to_world.origin - _last_origin
	_last_origin = to_world.origin
	for s in _springs:
		var i: int = s["bone"]
		var parent_pose := skeleton.get_bone_global_pose(s["parent"])
		if absf(parent_pose.basis.determinant()) < 1e-6:
			continue  # parent collapsed (first-person body hides the head)
		var rest_xf := parent_pose * skeleton.get_bone_rest(i)
		var aim_skel: Vector3 = rest_xf.basis * (s["aim"] as Vector3)
		var aim_world := to_world.basis * aim_skel
		var length := maxf(aim_world.length(), 0.02)
		var origin := to_world * rest_xf.origin
		var rest_dir := aim_world / length
		var limit: float = deg_to_rad(s["limit"]) * (jiggle if s.get("jiggle", false) else 1.0)
		var target := origin + rest_dir * length
		if limit <= 0.0 or not s["ready"] or (s["tip"] as Vector3).distance_to(target) > 1.0:
			s["tip"] = target
			s["prev"] = target
			s["ready"] = true
			if limit <= 0.0:
				skeleton.set_bone_pose_rotation(i, skeleton.get_bone_rest(i).basis.get_rotation_quaternion())
				continue
		elif moved.length() < 1.0:
			# carry the spring along with the part of her movement it shouldn't feel
			var carry := moved * (1.0 - float(s["inertia"]))
			s["tip"] += carry
			s["prev"] += carry
		var tip: Vector3 = s["tip"]
		var prev: Vector3 = s["prev"]
		var next: Vector3 = tip + (tip - prev) * (1.0 - s["drag"])
		next += (target - tip) * minf(s["stiffness"] * steps, 1.0)
		next += Vector3.DOWN * s["gravity"] * 0.01 * steps * length
		if s.has("lateral"):
			# keep only part of the swing across her body
			var side := to_world.basis.x.normalized()
			next -= side * (next - target).dot(side) * (1.0 - float(s["lateral"]))
		var dir: Vector3 = (next - origin).normalized()
		var angle: float = dir.angle_to(rest_dir)
		var knee := limit * 0.6
		if s.get("soft", false) and angle > knee:
			# ease into the limit: swings up to 60% of it stay as they are, bigger ones round off
			var eased := knee + (limit - knee) * tanh((angle - knee) / (limit - knee))
			dir = rest_dir.slerp(dir, eased / angle).normalized()
		elif angle > limit:
			dir = rest_dir.slerp(dir, limit / angle).normalized()
		s["prev"] = tip
		s["tip"] = origin + dir * length
		# rotate the bone so its child lies along the simulated direction
		var from_skel := aim_skel.normalized()
		var to_dir: Vector3 = (to_skel.basis * dir).normalized()
		if from_skel.dot(to_dir) > 0.99999:
			skeleton.set_bone_pose_rotation(i, skeleton.get_bone_rest(i).basis.get_rotation_quaternion())
			continue
		var swing := Basis(Quaternion(from_skel, to_dir))
		var local := parent_pose.basis.inverse() * swing * rest_xf.basis
		skeleton.set_bone_pose_rotation(i, local.get_rotation_quaternion())
