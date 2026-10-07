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
## How far her posture has slumped (0..1, _slump): below 0 it follows Marrow's
## Hold (vices.gd slump()) on the player's own Eco; tools set it directly.
@export_range(-1.0, 1.0) var slump := -1.0
## Her right hand up at the side of her neck, head tipped away (0..1, _inject):
## the cheat box's Super Hush injector (super_hush_scene.gd) sets it.
@export_range(0.0, 1.0) var inject := 0.0
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
## How big her glutes' swing shows, over what their springs simulate (1 = as
## tuned; Bones picked half as much again, 2026-10-07).
@export_range(0.0, 3.0) var glute_swing := 1.5
## Walls, corners and other bodies push her soft parts (chest, glutes, hair
## and, with full body jiggle, the rest) out of them, and her soft parts and
## limbs press on each other (SELF_PAIRS, SELF_BODIES); moving clear lets them
## spring back.
@export var jiggle_collide := true
## While something presses them, how much further than their own swing her
## soft parts may be pushed (1 = no further); it eases back once they're free.
@export_range(1.0, 3.0) var contact_give := 2.0
## Her chest and glutes flatten against what presses them and bulge out to
## the sides (up to "squish" of their size) instead of only swinging away.
@export var jiggle_squish := true
## Scales how much they squash (the Press into things setting sets it with
## contact_give: follow_jiggle_setting).
@export_range(0.0, 2.0) var squish_scale := 1.0
## Her clothes ride her soft parts' swing and squash (eco_cling.gd), so a
## bouncing glute moves the skirt over it instead of poking through.
@export var cloth_cling := true
## Clothing meshes put on the soft weights (for tests).
var clung := 0
## Off duty (the hub and town), standing still with her back to a wall she
## eases back and leans on it: her capsule otherwise keeps walls some 27 cm
## off her, so this is where walls really press her soft parts.
@export var wall_lean := true
## Full body jiggle (experimental): soft springs in her stomach, thighs, upper
## arms and calves as well (scripts/ps2/eco_flesh.gd). Left unset, she follows
## the Full body jiggle setting (Game tab) with her jiggle style.
@export var body_jiggle := false:
	set(value):
		body_jiggle = value
		_set_flesh(value)
## Her suit upgrade (scripts/hub/armory.gd SUIT_TIERS): 0 is the bare pilot
## suit; each tier shows its armour pieces (the glb's suit_t<tier>_* meshes,
## from tools/eco/build_eco_vroid.py) on top of the tiers before it. Tier 5
## repaints the plates in Dad's colours and turns every trim gold.
@export_range(0, 5) var suit_tier := 0:
	set(value):
		suit_tier = clampi(value, 0, SUIT_TIERS)
		if is_inside_tree():
			apply_suit()
## The suit's weight (armory.gd SUIT_WEIGHTS), once she has a suit tier. Its
## kit's pieces are marked after their tier: "l" light only, "m" medium only,
## "h" heavy only, unmarked for all three. Each weight also changes the suit
## itself, whichever style she wears (body_material: KIT_TEX), and her makeup
## (KIT_FACE).
@export_enum("light", "medium", "heavy") var suit_weight := "medium":
	set(value):
		suit_weight = value
		if is_inside_tree():
			apply_suit()
## What she has on (wear() by name; picked in her wardrobe,
## scripts/hub/wardrobe.gd). "suit" is her own pilot suit (gwen), the other
## suit_* are the other looks baked by tools/eco/build_eco_vroid.py
## BASE_STYLES: each shows its own pieces with no suit upgrade, and the
## upgrades go over any of them. "skater", "y2k" and "date" are her clothes off duty (outfit_graph),
## every suit piece hidden; each comes in a Teen and a Mature version, picked
## by the content rating (scripts/radio/content_rating.gd, O key) as it changes.
@export_enum("suit", "suit_ghost", "suit_racer", "suit_harness", "suit_techwear", "suit_shade", "suit_homemade",
		"suit_ophelia", "suit_vesper", "suit_vesper_open", "suit_hush", "skater", "y2k", "date") var outfit := "suit":
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
## the most it may swing away from its pose, how far round its tip her skin
## reaches ("touch", metres: what walls push on, _collide), and how much of her movement
## through the world it feels (1 = all of it: hair streams back when she runs;
## low = only her own motion: the jiggle bounces with her steps and landings
## without being dragged back by her speed).
const Vices := preload("res://scripts/hub/vices.gd")
const HAIR := {"group": "hair", "stiffness": 0.14, "drag": 0.2, "gravity": 0.7, "limit": 30.0, "inertia": 0.6, "touch": 0.015}
const HAIR_TIP := {"group": "hair", "stiffness": 0.12, "drag": 0.2, "gravity": 0.6, "limit": 20.0, "inertia": 0.6, "touch": 0.015}
# the fringe hangs over her face: it may lift off it, but swinging far back would go into her head
const FRINGE := {"group": "hair", "stiffness": 0.16, "drag": 0.22, "gravity": 0.5, "limit": 12.0, "inertia": 0.35, "touch": 0.015}
const FRINGE_TIP := {"group": "hair", "stiffness": 0.14, "drag": 0.22, "gravity": 0.5, "limit": 10.0, "inertia": 0.35, "touch": 0.015}
const BUST := {"group": "bust", "stiffness": 0.14, "drag": 0.08, "gravity": 0.15, "limit": 24.0, "inertia": 0.2, "jiggle": true, "touch": 0.045, "squish": 0.3}
# the back hair chains below the nape: only the salon's long cuts (braids, ponytail; scripts/hub/hair.gd) hang from them
const BRAID := {"group": "hair", "stiffness": 0.1, "drag": 0.16, "gravity": 0.9, "limit": 28.0, "inertia": 0.5, "touch": 0.015}
const GLUTE := {"group": "glute", "stiffness": 0.18, "drag": 0.09, "gravity": 0.15, "limit": 18.0, "inertia": 0.2, "jiggle": true, "touch": 0.045, "squish": 0.3}
## Her own soft parts pressing on each other: [spring, spring, resting]. A
## pair never gets closer than their touch radii, or than her pose holds them
## if that's closer already, so one pressing in pushes the other away and hands
## it its swing. Resting pairs (her cheeks) touch already, so any squeeze
## between them passes across.
const SELF_PAIRS := [
	["J_Sec_L_Glute1", "J_Sec_R_Glute1", true],
	["J_Sec_L_Bust1", "J_Sec_R_Bust1", false],
	["J_Sec_L_Thigh", "J_Sec_R_Thigh", false],
	["J_Sec_L_Calf", "J_Sec_R_Calf", false],
	["J_Sec_L_Thigh", "J_Sec_L_Calf", false],
	["J_Sec_R_Thigh", "J_Sec_R_Calf", false],
	["J_Sec_C_Belly", "J_Sec_L_Thigh", false],
	["J_Sec_C_Belly", "J_Sec_R_Thigh", false],
	["J_Sec_L_Bust1", "J_Sec_L_UpperArmSoft", false],
	["J_Sec_R_Bust1", "J_Sec_R_UpperArmSoft", false],
]
## Her limbs and body as capsules her soft parts can't swing into: [from bone,
## to bone ("" = up her from bone's own axis by `up`), up, radius]. Same rule
## as SELF_PAIRS, so where her pose already has them closer it holds them there.
const TORSO := ["J_Bip_C_Spine", "J_Bip_C_UpperChest", 0.0, 0.1]
const NECK := ["J_Bip_C_UpperChest", "J_Bip_C_Neck", 0.0, 0.06]
const SKULL := ["J_Bip_C_Head", "", 0.1, 0.085]
const L_UPPER_ARM := ["J_Bip_L_UpperArm", "J_Bip_L_LowerArm", 0.0, 0.045]
const R_UPPER_ARM := ["J_Bip_R_UpperArm", "J_Bip_R_LowerArm", 0.0, 0.045]
const L_FOREARM := ["J_Bip_L_LowerArm", "J_Bip_L_Hand", 0.0, 0.035]
const R_FOREARM := ["J_Bip_R_LowerArm", "J_Bip_R_Hand", 0.0, 0.035]
const L_UPPER_LEG := ["J_Bip_L_UpperLeg", "J_Bip_L_LowerLeg", 0.0, 0.065]
const R_UPPER_LEG := ["J_Bip_R_UpperLeg", "J_Bip_R_LowerLeg", 0.0, 0.065]
## By spring bone, or by group: which of those each soft part keeps out of.
const SELF_BODIES := {
	"J_Sec_L_Bust1": [L_UPPER_ARM, L_FOREARM, R_FOREARM],
	"J_Sec_R_Bust1": [R_UPPER_ARM, L_FOREARM, R_FOREARM],
	"J_Sec_L_Glute1": [L_UPPER_LEG],
	"J_Sec_R_Glute1": [R_UPPER_LEG],
	"J_Sec_C_Belly": [L_UPPER_LEG, R_UPPER_LEG, L_FOREARM, R_FOREARM],
	"J_Sec_L_UpperArmSoft": [TORSO],
	"J_Sec_R_UpperArmSoft": [TORSO],
	"hair": [TORSO, NECK, SKULL, L_UPPER_ARM, R_UPPER_ARM],
}
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
## (bust, glute) or scale them (hair, flesh: "<key>_scale"). Extra keys:
## "soft" eases the swing into its limit instead of stopping it dead;
## "lateral" is how much side-to-side swing is kept (1 = all).
const JIGGLE_STYLES := {
	"classic": {},
	# about 2.5 bounces a second that take a second to die away, big rounded swings
	"anime": {
		"bust": {"stiffness": 0.07, "drag": 0.065, "gravity": 0.08, "limit": 30.0, "inertia": 0.25, "soft": true},
		"glute": {"stiffness": 0.08, "drag": 0.07, "gravity": 0.08, "limit": 22.0, "inertia": 0.25, "soft": true},
		"hair": {"stiffness_scale": 0.8, "drag_scale": 0.7, "gravity_scale": 0.6},
		"flesh": {"stiffness_scale": 0.7, "drag_scale": 0.8, "reach_scale": 1.25, "soft": true},
	},
	# about 5 bounces a second, one small rebound and still within a quarter second
	"realistic": {
		"bust": {"stiffness": 0.28, "drag": 0.22, "gravity": 0.3, "limit": 12.0, "inertia": 0.2, "lateral": 0.45},
		"glute": {"stiffness": 0.32, "drag": 0.25, "gravity": 0.3, "limit": 9.0, "inertia": 0.2, "lateral": 0.45},
		"hair": {"stiffness_scale": 1.15, "drag_scale": 1.4, "gravity_scale": 1.3},
		"flesh": {"stiffness_scale": 1.3, "drag_scale": 1.5, "reach_scale": 0.7, "lateral": 0.6},
	},
}

const SUIT_TIERS := 5
const LEGACY_PLATE := preload("res://assets/materials/eco/eco_v_armor_legacy.tres")
## Her own suit's bodysuit (the glb's eco_v_body; STYLE_BODY has the others).
const GWEN_BODY := preload("res://assets/materials/eco/eco_v_body.tres")
## What each suit weight changes on the suit itself, laid over her style's
## bodysuit (tools/eco/build_eco_vroid.py kit_graph): [colour, mask, glow].
const KIT_TEX := {
	"light": [preload("res://assets/textures/eco/v_kit_light.png"), preload("res://assets/textures/eco/v_kit_light_mask.png"),
		preload("res://assets/textures/eco/v_kit_light_glow.png")],
	"medium": [preload("res://assets/textures/eco/v_kit_medium.png"), preload("res://assets/textures/eco/v_kit_medium_mask.png"),
		preload("res://assets/textures/eco/v_kit_medium_glow.png")],
	"heavy": [preload("res://assets/textures/eco/v_kit_heavy.png"), preload("res://assets/textures/eco/v_kit_heavy_mask.png"),
		preload("res://assets/textures/eco/v_kit_heavy_glow.png")],
}
## Her makeup with each suit weight on: a sharp wing and dark red lips (light),
## a grease smear (medium), war paint under her eyes (heavy).
const KIT_FACE := {
	"light": preload("res://assets/materials/eco/eco_v_face_light.tres"),
	"medium": preload("res://assets/materials/eco/eco_v_face_medium.tres"),
	"heavy": preload("res://assets/materials/eco/eco_v_face_heavy.tres"),
}
## Everything she can wear (outfit): her pilot suits, then her clothes. Each
## suit but her own has its bodysuit material, and its own pieces in the glb as
## base_<style>_* (a jacket, cowl, vest or skirt; harness and the vesper looks
## have none). The vesper looks are Vesper Kane's clothes (a concept character,
## Eco wears them for now): Mature rating only (MATURE_OUTFITS). The Hush
## courier suit (Marrow's runner) is the shade catsuit dyed violet under her
## skater hoodie, sneakers and some of the mechanic kit's gear, all re-dyed
## (STYLE_GEAR): it's her reward for Marrow's Hold reaching full (vices.gd
## hush_suit), and only in her wardrobe once she's earned it (wardrobe.gd).
const OUTFITS := ["suit", "suit_ghost", "suit_racer", "suit_harness", "suit_techwear", "suit_shade", "suit_homemade",
		"suit_ophelia", "suit_vesper", "suit_vesper_open", "suit_hush", "skater", "y2k", "date"]
## Outfits only offered under the Mature content rating (wardrobe.gd).
const MATURE_OUTFITS := ["suit_vesper", "suit_vesper_open", "suit_hush"]
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
	"suit_hush": preload("res://assets/materials/eco/eco_v_body_hush.tres"),
}
## Suit styles that wear pieces from elsewhere in the glb (her clothes, the
## kits' gear) with no suit upgrade, re-dyed: style -> {"pieces": mesh names,
## "hide": mesh name prefixes, "mats": {glb material name: its stand-in}}.
const STYLE_GEAR := {
	"hush": {
		"pieces": ["outfit_skater_t_hoodie", "outfit_skater_any_hood", "outfit_skater_any_shoes",
				"suit_t1m_toolpouch", "suit_t1m_wristcomp", "suit_t1m_belt"],
		"hide": ["Boots", "Goggles"],
		"mats": {
			"eco_v_hoodie_skater": preload("res://assets/materials/eco/eco_v_hoodie_hush.tres"),
			"eco_v_hoodie_skater_edge": preload("res://assets/materials/eco/eco_v_hoodie_hush_edge.tres"),
			"eco_v_hoodie_skater_hood": preload("res://assets/materials/eco/eco_v_hoodie_hush_hood.tres"),
			"eco_v_sneaker_skater": preload("res://assets/materials/eco/eco_v_sneaker_hush.tres"),
			"eco_v_sneaker_skater_sole": preload("res://assets/materials/eco/eco_v_sneaker_hush_sole.tres"),
			"eco_v_kit_canvas": preload("res://assets/materials/eco/eco_v_kit_canvas_hush.tres"),
			"eco_v_kit_rubber": preload("res://assets/materials/eco/eco_v_kit_rubber_hush.tres"),
			"eco_v_armor_glow": preload("res://assets/materials/eco/eco_v_armor_glow_hush.tres"),
			"eco_v_armor_strap": preload("res://assets/materials/eco/eco_v_armor_strap_hush.tres"),
			"eco_v_armor_edge": preload("res://assets/materials/eco/eco_v_armor_edge_hush.tres"),
		},
	},
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
const ColonyGear := preload("res://scripts/hub/colony_gear.gd")
const Extras := preload("res://scripts/hub/eco_extras.gd")
const EcoFlesh := preload("res://scripts/ps2/eco_flesh.gd")
const EcoCling := preload("res://scripts/ps2/eco_cling.gd")
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
## Starting off and pulling up from a run (_run_moves): seconds into each
## (-1 = not happening), how long since she stood still / was running, how
## hard the move is (0..1).
var _start_t := -1.0
var _stop_t := -1.0
var _since_still := 99.0
var _since_running := 99.0
var _stop_force := 1.0
## Footfalls (_footfalls): each foot's height, speed and fastest drop since
## its last landing (skeleton space), and how many each side has had.
var _feet := {}
var footfalls := {"L": 0, "R": 0}
var _pose_weight := 0.0
## How far into the trance walk she is (0..1, _trance_walk).
var _trance_weight := 0.0
## Her slump off duty, eased in (0..1, _slump).
var _slump_weight := 0.0
var _bones := {}
## What the strut changed last frame (bone -> [pose before, pose after]), so it
## can be undone when nothing re-posed the bone since (a paused animation).
var _strut_undo := {}
## _wall_lean: how far (m) she has eased back onto a wall, how long she's been
## standing still, and the ray's exclusions (her own bodies).
var _lean := 0.0
var _still_for := 0.0
var _lean_exclude: Array[RID] = []
## How far behind her middle her backside reaches, how far behind that a wall
## may be for her to lean on it, and how far she settles into it.
const LEAN_BACK := 0.13
const LEAN_REACH := 0.5
const LEAN_PRESS := 0.015
var _rest: EcoRest
var _face: MeshInstance3D
## Her meshes with the iris layer, and the Hush swirl they show (vices.gd).
var _iris_meshes: Array = []
var _hypno := 0.0
## The face's weights from before she fell asleep (blend shape index -> weight).
var _awake_face := {}
## The content rating her clothes were last put on for.
var _dressed_rating := ""
## Her bodysuit with her suit weight's changes laid over it, by "<outfit>/<weight>" (body_material).
var _kit_bodies := {}
# the heavy breastplate is on (apply_suit): her chest's springs stay at rest under it
var _plated := false
## Meshes swapped for full body jiggle ones (MeshInstance3D -> [mesh, skin] it had).
var _flesh_swapped := {}
## _collide's query (her own bodies excluded) and a ball per touch radius.
var _touch_query: PhysicsShapeQueryParameters3D
## World height of the seat or bed she is resting on (NAN when she isn't): her
## soft parts can't sink below it, so they flatten and spread on it instead.
var _support_y := NAN
## How far above the support a part's centre rests, as a share of its touch radius.
const SUPPORT_REST := 1.0
var _touch_shapes := {}


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
		_link_touches()
		_last_origin = skeleton.global_position
		if _body != null and _body.has_signal("damaged"):
			_body.damaged.connect(_on_damaged)
		add_to_group("eco_jolt")
		for bone_name: String in STRUT_BONES:
			_bones[bone_name] = skeleton.find_bone(STRUT_BONES[bone_name])
		_bones["hips_at"] = _bones["hips"]
		_rest = EcoRest.new(skeleton)
		if not _rest.usable():
			_rest = null
	if cloth_cling and springs_enabled and skeleton != null:
		_cling()
	if not _style_chosen:
		follow_jiggle_setting()
	elif body_jiggle:
		_set_flesh(true)
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
	var squeeze := 1.0 if suited_ and suit_tier > 0 and suit_weight == "light" else 0.0
	# the heavy kit's breastplate is one stiff plate strapped over her chest: it holds her still
	_plated = suited_ and suit_tier > 0 and suit_weight == "heavy"
	var rating := look().right(1)
	_dressed_rating = ContentRating.current()
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var tier := piece_tier(String(mi.name))
		var squeeze_shape := mi.find_blend_shape_by_name(&"kit_squeeze") if mi.mesh != null else -1
		if squeeze_shape >= 0:   # the light kit's compression bands pull her thighs in
			mi.set_blend_shape_value(squeeze_shape, squeeze)
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
					mi.set_surface_override_material(i, face_material())
		mi.set_instance_shader_parameter("trim_gold", 1.0 if legacy else 0.0)
	_style_gear(STYLE_GEAR.get(style(), {}) if suited_ and suit_tier == 0 else {})
	Extras.apply(self)  # her piercings, tattoos and accessories from Solace
	ColonyGear.apply(self)  # the Shepherd's gear, if it's put any on her (hymn.gd)


## Shows a suit style's borrowed pieces (STYLE_GEAR) in its colours, hides
## what it leaves off, and puts every other style's borrowed pieces back as
## they were.
func _style_gear(gear: Dictionary) -> void:
	var borrowed := []
	for each: Dictionary in STYLE_GEAR.values():
		borrowed.append_array(each["pieces"])
	var mats: Dictionary = gear.get("mats", {})
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh_name := String(mi.name)
		for prefix: String in gear.get("hide", []):
			if mesh_name.begins_with(prefix):
				mi.visible = false
		if not mesh_name in borrowed or mi.mesh == null:
			continue
		var worn: bool = mesh_name in gear.get("pieces", [])
		if worn:
			mi.visible = true
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if worn and m != null and mats.has(m.resource_name):
				mi.set_surface_override_material(i, mats[m.resource_name])
			elif not mesh_name.begins_with("suit_t") or m == null or m.resource_name != "eco_v_armor":
				mi.set_surface_override_material(i, null)


## Her clothes' body texture, or her suit style's bodysuit (null: the glb's
## own, her gwen suit), with her suit weight's changes laid over it once she
## has a suit tier (one material per style and weight, made once).
func body_material() -> Material:
	if not suited():
		return OUTFIT_BODY[look()]
	if suit_tier <= 0 or not KIT_TEX.has(suit_weight):
		return STYLE_BODY.get(outfit)
	var key := outfit + "/" + suit_weight
	if not _kit_bodies.has(key):
		var m: ShaderMaterial = STYLE_BODY.get(outfit, GWEN_BODY).duplicate()
		m.set_shader_parameter("use_kit", true)
		m.set_shader_parameter("kit_tex", KIT_TEX[suit_weight][0])
		m.set_shader_parameter("kit_mask_tex", KIT_TEX[suit_weight][1])
		m.set_shader_parameter("kit_glow_tex", KIT_TEX[suit_weight][2])
		_kit_bodies[key] = m
	return _kit_bodies[key]


## Her makeup: her date-night face, her suit weight's, or null (the glb's own).
func face_material() -> Material:
	if outfit == "date":
		return DATE_FACE
	if suited() and suit_tier > 0:
		return KIT_FACE.get(suit_weight)
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
		if _body.get("sidling") == true:
			return ["idle", 1.0]  # side-on in a gap: _sidle shuffles her feet
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
		if inject > 0.0:
			_inject(inject)
		_run_moves(delta)
		_wall_lean(delta)
		_brace_layer(delta)
		_wriggle(delta)
		_sidle(delta)
		_rest_layer(delta)
	if springs_enabled and skeleton != null:
		_footfalls(delta)
		_step_springs(delta)
	_eye_swirl()


## Marrow's Hold shows in her eyes: violet spirals in her irises (vices.gd,
## eco_toon.gdshaderinc iris_swirl).
func _eye_swirl() -> void:
	var h := Vices.eye_swirl()
	if is_equal_approx(h, _hypno):
		return
	_hypno = h
	if _iris_meshes.is_empty():
		for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i)
				if m != null and m.resource_name == "eco_v_iris":
					_iris_meshes.append(mi)
					break
	for mi: MeshInstance3D in _iris_meshes:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("hypno", h)


func _animate() -> void:
	var pick := pick_animation()
	var anim_name: String = pick[0]
	if anim_name == "idle" and not idle_motion:
		if _anim.is_playing():
			_anim.pause()
		return
	if _anim.current_animation != anim_name:
		var blend := anim_blend * 0.5 if anim_name in ["slide", "fall"] else anim_blend
		# from a stand straight into a run, and from a run to a stand, ease
		# across over longer so the stride builds up and winds down
		if anim_name == "run" and _anim.current_animation == "idle":
			blend = anim_blend * 1.4
		elif anim_name == "idle" and _anim.current_animation == "run":
			blend = anim_blend * 2.0
		_anim.play(anim_name, blend)
	var reverse: bool = stride_reverse or (_body != null and _body.get("backpedalling") == true)
	_anim.speed_scale = -pick[1] if reverse and anim_name in ["walk", "run"] else pick[1]


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
	# what she sits or lies on: her soft parts rest on it and squash (_collide)
	if rest_pose != "" and _rest.weight > 0.3 and is_inside_tree():
		_support_y = (global_transform * Vector3(0, rest_seat_height, 0)).y
	else:
		_support_y = NAN
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
	"shin.R": "J_Bip_R_LowerLeg", "foot.L": "J_Bip_L_Foot", "foot.R": "J_Bip_R_Foot",
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
	var tranced: bool = _body != null and _body.get("entranced") == true
	var off_duty := strolling() and strut > 0.0 and not tranced
	var walking := off_duty and _anim.current_animation == "walk"
	var standing := off_duty and _anim.current_animation == "idle" and not resting()
	_strut_weight = move_toward(_strut_weight, 1.0 if walking else 0.0, delta * 4.0)
	_pose_weight = move_toward(_pose_weight, 1.0 if standing else 0.0, delta * 2.0)
	_trance_weight = move_toward(_trance_weight, 1.0 if tranced else 0.0, delta * 1.5)
	if _trance_weight > 0.0:
		_trance_walk(_trance_weight)
	var slumped := slump if slump >= 0.0 else (Vices.slump() if _body != null else 0.0)
	_slump_weight = move_toward(_slump_weight, slumped if off_duty and not resting() else 0.0, delta * 0.5)
	if _strut_weight <= 0.0 and _pose_weight <= 0.0:
		if _slump_weight > 0.0:
			_slump(_slump_weight, 0.0)
		return
	# the deeper his Hold, the less of her old strut is left
	var w := _strut_weight * strut * (1.0 - 0.65 * _slump_weight)
	var p := _pose_weight * strut * (1.0 - 0.65 * _slump_weight)
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
	if _slump_weight > 0.0:
		_slump(_slump_weight, _strut_weight)


## The injector at her neck: right arm raised and bent so the hand sits under
## her jaw, head tipped to her left, shoulders braced. Laid over whatever she's
## doing (the strut's undo takes it off again next frame).
func _inject(k: float) -> void:
	_turn("upperarm.R", Vector3.RIGHT, 22.0 * k)
	_turn("upperarm.R", Vector3.BACK, -40.0 * k)
	_turn("forearm.R", Vector3.RIGHT, 128.0 * k)
	_turn("hand.R", Vector3.RIGHT, 20.0 * k)
	_turn("head", Vector3.BACK, 14.0 * k)
	_turn("chest", Vector3.RIGHT, -3.0 * k)


## Marrow's Hold in her body off duty (vices.gd slump): her chest caves and
## her shoulders round in, her head hangs low and a little to one side, her
## arms hang close with the elbows soft and the hands curled in toward her,
## like she's cold. `k` how far it's gone (0..1), `walking` how much she's
## walking (the arms still swing a little).
func _slump(k: float, walking: float) -> void:
	_turn("spine", Vector3.RIGHT, -5.0 * k)
	_turn("chest", Vector3.RIGHT, -7.0 * k)
	_turn("head", Vector3.RIGHT, -9.0 * k)
	_turn("head", Vector3.BACK, 5.0 * k)
	_turn("upperarm.R", Vector3.BACK, 7.0 * k)
	_turn("upperarm.L", Vector3.BACK, -7.0 * k)
	_turn("upperarm.R", Vector3.RIGHT, 5.0 * k)  # shoulders rolled forward
	_turn("upperarm.L", Vector3.RIGHT, 5.0 * k)
	_turn("forearm.R", Vector3.RIGHT, (14.0 - 4.0 * walking) * k)
	_turn("forearm.L", Vector3.RIGHT, (14.0 - 4.0 * walking) * k)
	_turn("hand.R", Vector3.BACK, -8.0 * k)
	_turn("hand.L", Vector3.BACK, 8.0 * k)


## Marrow's trance (player.gd entranced): she walks like she's being led, stiff
## and upright, chin lifted, head tipped a little to one side, arms hanging
## dead at her sides with hardly any swing, hips quiet. `k` eases it in and out.
func _trance_walk(k: float) -> void:
	var t := 0.0
	if _anim.current_animation == "walk" and _anim.current_animation_length > 0.0:
		t = _anim.current_animation_position / _anim.current_animation_length * TAU
	var sw := sin(t)
	_turn("hips", Vector3.UP, -5.0 * sw * k)  # undo most of the walk's hip twist
	_turn("chest", Vector3.UP, 4.0 * sw * k)
	_turn("head", Vector3.RIGHT, 1.5 * k)
	_turn("head", Vector3.BACK, 11.0 * k)
	# arms: pulled in to her sides, the walk's swing (right arm forward with
	# -sin t) mostly cancelled, elbows straight, hands slack
	_turn("upperarm.R", Vector3.RIGHT, 14.0 * sw * k)
	_turn("upperarm.L", Vector3.RIGHT, -14.0 * sw * k)
	_turn("upperarm.R", Vector3.BACK, 6.0 * k)
	_turn("upperarm.L", Vector3.BACK, -6.0 * k)
	_turn("forearm.R", Vector3.RIGHT, -8.0 * k)
	_turn("forearm.L", Vector3.RIGHT, -8.0 * k)
	_turn("hand.R", Vector3.RIGHT, -12.0 * k)
	_turn("hand.L", Vector3.RIGHT, -12.0 * k)


## How long the push-off into a run and the pull-up out of one last (seconds).
const START_TIME := 0.45
const STOP_TIME := 0.6
## Thigh and shin lengths, for bending her knees without lifting her feet.
const LEG_LENGTH := 0.82
## A foot lower than this (its bone, in skeleton space) is on the ground.
const FOOT_DOWN := 0.16


## Starting and stopping a run, laid over the animation like the strut: from a
## stand she drops a little and leans into the first strides; pulling up from
## a run she plants, sinks into her knees and leans back against the stop,
## arms swinging forward, then rocks forward and settles upright.
func _run_moves(delta: float) -> void:
	if skeleton == null or _bones.is_empty() or _body == null or resting():
		return
	var speed := Vector2(_body.velocity.x, _body.velocity.z).length()
	var on_ground: bool = _anim.current_animation in ["idle", "walk", "run"]
	_since_still = 0.0 if speed < 0.6 else _since_still + delta
	_since_running = 0.0 if speed > run_threshold and on_ground else _since_running + delta
	if on_ground and speed > run_threshold and _since_still < 0.3 and _start_t < 0.0 and _stop_t < 0.0:
		_start_t = 0.0
	if on_ground and speed < 0.6 and _since_running > 0.0 and _since_running < 0.3 and _stop_t < 0.0:
		_stop_t = 0.0
		_start_t = -1.0
	if not on_ground:
		_start_t = -1.0
		_stop_t = -1.0
	if _start_t >= 0.0:
		var u := _start_t / START_TIME
		var a := smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.35, 1.0, u))
		_bend_knees(10.0 * a, 10.0 * a)
		_turn("spine", Vector3.RIGHT, -9.0 * a)
		_turn("chest", Vector3.RIGHT, -5.0 * a)
		_turn("head", Vector3.RIGHT, 6.0 * a)  # eyes stay on where she's going
		_turn("forearm.R", Vector3.RIGHT, 12.0 * a)
		_turn("forearm.L", Vector3.RIGHT, 12.0 * a)
		_start_t += delta
		if _start_t > START_TIME:
			_start_t = -1.0
	if _stop_t >= 0.0:
		var u := _stop_t / STOP_TIME
		# brake: sink and lean back early on; settle: rock forward past upright, then stand
		var brake := smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.25, 0.6, u))
		var settle := smoothstep(0.35, 0.55, u) * (1.0 - smoothstep(0.6, 1.0, u))
		var sink := smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.3, 1.0, u))
		_bend_knees(16.0 * sink, 16.0 * sink)
		_turn("spine", Vector3.RIGHT, 10.0 * brake - 5.0 * settle)
		_turn("chest", Vector3.RIGHT, 5.0 * brake - 3.0 * settle)
		_turn("head", Vector3.RIGHT, -8.0 * brake + 3.0 * settle)
		_turn("upperarm.R", Vector3.RIGHT, 18.0 * brake - 4.0 * settle)
		_turn("upperarm.L", Vector3.RIGHT, 14.0 * brake - 4.0 * settle)
		_turn("forearm.R", Vector3.RIGHT, 25.0 * brake)
		_turn("forearm.L", Vector3.RIGHT, 22.0 * brake)
		_stop_t += delta
		if _stop_t > STOP_TIME:
			_stop_t = -1.0


## Bends both knees (thigh forward, shin back twice as far, foot level again)
## and lowers her hips by as much, so her feet stay on the ground.
func _bend_knees(left: float, right: float) -> void:
	var deg := (left + right) * 0.5
	if deg < 0.05:
		return
	_offset_hips(Vector3(0.0, -LEG_LENGTH * (1.0 - cos(deg_to_rad(deg))), 0.0))
	for side: String in ["L", "R"]:
		var d := left if side == "L" else right
		_turn("thigh." + side, Vector3.RIGHT, d)
		_turn("shin." + side, Vector3.RIGHT, -2.0 * d)
		_turn("foot." + side, Vector3.RIGHT, d)


## Each time a foot comes down and takes her weight, that side's glute, thigh,
## calf and (a little) chest get shoved down, so the side she lands on
## jiggles more than the other.
func _footfalls(delta: float) -> void:
	if _bones.is_empty() or delta <= 0.0:
		return
	for side: String in ["L", "R"]:
		var i: int = _bones.get("foot." + side, -1)
		if i < 0:
			continue
		var y := skeleton.get_bone_global_pose(i).origin.y
		var was: Array = _feet.get(side, [y, 0.0, 0.0])
		var vy: float = (y - float(was[0])) / delta
		var fastest: float = maxf(float(was[2]), -vy) if vy < 0.0 else float(was[2])
		# the low point of a step: it was coming down, now it isn't, and it's at the ground
		if float(was[1]) < 0.0 and vy >= 0.0 and y < FOOT_DOWN:
			if fastest > 0.4:
				footfall(side, minf(fastest, 4.0))
			fastest = 0.0
		_feet[side] = [y, vy, fastest]


## Shoves one side's springs down, as a foot landing with `impact` (m/s) would.
func footfall(side: String, impact: float) -> void:
	footfalls[side] = int(footfalls.get(side, 0)) + 1
	var tag := "_%s_" % side
	var down := -skeleton.global_transform.basis.y.normalized()
	for s in _springs:
		if not s.get("jiggle", false) or not s["ready"]:
			continue
		var bone_name := skeleton.get_bone_name(s["bone"])
		if not tag in bone_name or "Arm" in bone_name:
			continue
		var amount := 0.002 if s.has("reach") else 0.003
		if s["base"].get("group", "") == "bust":
			amount *= 0.4
		s["tip"] += down * amount * impact * jiggle


## Wind and water. Wind (world m/s) is Weather.wind plus any "wind_zone" she
## stands in (a box: meta "half" Vector3, "wind" Vector3, like the lab's fan),
## gusting; it streams her hair and ripples her chest and glutes. Water: in
## any "water" sheet (laid_out.gd water, meta "half" Vector2) her parts below
## its surface float up and move slowly.
const WIND_PUSH := {"hair": 0.0011, "bust": 0.00018, "glute": 0.00012}
const WATER_LIFT := {"hair": 0.004, "bust": 0.0024, "glute": 0.0016}
const WATER_DRAG := 0.55
const Weather := preload("res://scripts/game/weather.gd")
var _wind := Vector3.ZERO
var _water_y := -INF
var _weather_t := 0.0


func _weather(delta: float) -> void:
	_weather_t += delta
	var at := global_position
	var wind: Vector3 = Weather.wind
	_water_y = -INF
	if is_inside_tree():
		for z: Node3D in get_tree().get_nodes_in_group("wind_zone"):
			var half: Vector3 = z.get_meta("half", Vector3.ZERO)
			var local := z.global_transform.affine_inverse() * (at + Vector3.UP)
			if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
				wind += z.global_basis * (z.get_meta("wind", Vector3.ZERO) as Vector3)
		for w: Node3D in get_tree().get_nodes_in_group("water"):
			var half: Vector2 = w.get_meta("half", Vector2.ZERO)
			var local := w.global_transform.affine_inverse() * at
			if absf(local.x) <= half.x and absf(local.z) <= half.y and at.y < w.global_position.y + 0.05:
				_water_y = maxf(_water_y, w.global_position.y)
	# gusts: two slow beats that don't line up
	var gust := 1.0 + 0.45 * sin(_weather_t * 1.3) * sin(_weather_t * 0.37 + 1.0) + 0.15 * sin(_weather_t * 4.1)
	_wind = wind * gust


## A swinging spring's next tip, pushed by the wind and, under water, floated
## up and slowed.
func _in_weather(s: Dictionary, tip: Vector3, next: Vector3, steps: float) -> Vector3:
	var group: String = s["base"].get("group", "")
	if _wind != Vector3.ZERO:
		next += _wind * float(WIND_PUSH.get(group, 0.0)) * steps
	if next.y < _water_y:
		next = tip + (next - tip) * WATER_DRAG
		next += Vector3.UP * float(WATER_LIFT.get(group, 0.0)) * steps
	return next


## A jolt through her whole body (a hit, a blast's shock wave): every soft
## part is flung along `dir` (world space, its length the strength, about 1
## for a solid hit), then springs back and wobbles. Flesh moves a little less,
## the chest and glutes most.
func jolt(dir: Vector3) -> void:
	if dir.length() < 0.001:
		return
	for s in _springs:
		if not s["ready"]:
			continue
		var group: String = s["base"].get("group", "")
		var amount: float = 0.012 if s.has("reach") else JOLT.get(group, 0.008)
		# moving `prev` back gives the tip that much speed this step
		s["prev"] -= dir * amount * jiggle
	jolts += 1


## How far a jolt of strength 1 flings each group's tips in one step (m).
const JOLT := {"bust": 0.02, "glute": 0.022, "hair": 0.03}
## Jolts taken (for tests).
var jolts := 0


## Hit: the jolt pushes away from where it came from (straight back if unknown).
func _on_damaged(amount: float, from: Vector3) -> void:
	var push := global_position - from if from != Vector3.ZERO else global_basis.z
	push.y = 0.0
	jolt(push.normalized() * clampf(amount / 25.0, 0.4, 1.6))


## A blast at `pos` reaching `radius`: within four radii its shock jolts her,
## harder the nearer it is (fx.gd blast calls this on everyone in "eco_jolt").
func blast_at(pos: Vector3, radius: float) -> void:
	var away := global_position + Vector3.UP * 1.0 - pos
	var reach := radius * 4.0
	var d := away.length()
	if d > reach or d < 0.001:
		return
	jolt(away / d * 1.8 * pow(1.0 - d / reach, 1.5))


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


## Off duty and standing still with a wall just behind her, she eases back
## until her backside settles into it, tilting a little so her shoulders meet
## it too; she comes off it as soon as she moves.
func _wall_lean(delta: float) -> void:
	if skeleton == null or _bones.is_empty() or _body == null:
		return
	var speed := Vector2(_body.velocity.x, _body.velocity.z).length()
	_still_for = _still_for + delta if speed < 0.1 else 0.0
	var want := 0.0
	if wall_lean and strolling() and _body.get("third_person") == true and not resting() \
			and _anim.current_animation == "idle" and _still_for > 0.6:
		want = _wall_behind()
	_lean = move_toward(_lean, want, delta * (0.35 if want > _lean else 1.2))
	if _lean < 0.001:
		return
	# her shoulders sit about 3 cm shallower than her backside, 40 cm higher
	var tilt := rad_to_deg(atan2(0.03, 0.4)) * clampf(_lean / 0.1, 0.0, 1.0)
	_offset_hips(Vector3.BACK * _lean)
	_turn("hips", Vector3.RIGHT, tilt)
	_turn("thigh.L", Vector3.RIGHT, -tilt)  # feet stay flat under her
	_turn("thigh.R", Vector3.RIGHT, -tilt)


## Bracing (player.gd brace): held at full press into something in front of
## her, she gets both hands up flat on it, elbows down, and turns her cheek
## aside; into something at her side, the near hand goes up on it and she
## looks away from it. Arm turns are from her T-pose (right arm; the left
## mirrors), found to put her palms on a wall at her core distance.
const BRACE_FRONT := {"upperarm": [[Vector3.FORWARD, 35.0], [Vector3.UP, -25.0]], "forearm": [[Vector3.UP, 125.0], [Vector3.RIGHT, 90.0]]}
const BRACE_SIDE := {"upperarm": [[Vector3.FORWARD, 20.0], [Vector3.UP, 85.0]], "forearm": [[Vector3.UP, 10.0], [Vector3.RIGHT, 90.0]]}
var _brace := 0.0
## Toward what she braces on, in her own space (-Z ahead, +X her right).
var _brace_dir := Vector3.FORWARD


func _brace_layer(delta: float) -> void:
	if skeleton == null or _bones.is_empty() or _body == null:
		return
	var want := 0.0
	if strolling() and not resting() and _body.get("brace") != null:
		want = float(_body.get("brace"))
		var n: Vector3 = _body.get("press_normal")
		if want > 0.0 and n != Vector3.ZERO:
			_brace_dir = global_basis.orthonormalized().inverse() * -n
			if _brace_dir.z > 0.4:
				want = 0.0  # behind her: that's a lean, not a brace
	_brace = move_toward(_brace, want, delta * (4.0 if want > _brace else 2.5))
	if _brace < 0.001:
		return
	var w := smoothstep(0.0, 1.0, _brace)
	var front := _brace_dir.z < -0.4 or absf(_brace_dir.x) < 0.6
	for side: String in ["R", "L"]:
		var near: bool = (_brace_dir.x > 0.0) == (side == "R")
		if front:
			_reach(side, BRACE_FRONT, w)
		elif near:
			_reach(side, BRACE_SIDE, w)
	if front:
		_turn("head", Vector3.UP, 45.0 * w)
		_turn("spine", Vector3.RIGHT, -4.0 * w)
	else:
		_turn("head", Vector3.UP, (20.0 if _brace_dir.x > 0.0 else -20.0) * w)


## Wriggling through a tight gap (player.gd squeeze): her hips and shoulders
## twist against each other in quick shimmies, and her soft parts give more
## (contact_give, squish_scale) while she does.
var _squeeze := 0.0
var _wriggle_time := 0.0


func _wriggle(delta: float) -> void:
	_squeeze = float(_body.get("squeeze")) if _body != null and strolling() and _body.get("squeeze") != null else 0.0
	if _squeeze < 0.001:
		_wriggle_time = 0.0
		return
	_wriggle_time += delta
	var shimmy := sin(_wriggle_time * TAU * 2.6) * _squeeze
	_turn("hips", Vector3.UP, 9.0 * shimmy)
	_turn("chest", Vector3.UP, -7.0 * shimmy)
	_turn("hips", Vector3.BACK, 3.0 * shimmy)
	_turn("head", Vector3.UP, 4.0 * shimmy)


## Side-on in a gap (player.gd sidling): she shuffles sideways, the leading
## foot stepping out and the other closing up to it, her hips swaying over
## them, her arms tucked in to her sides.
var _sidle_w := 0.0
var _sidle_phase := 0.0


func _sidle(delta: float) -> void:
	var on: bool = _body != null and strolling() and _body.get("sidling") == true and not resting()
	_sidle_w = move_toward(_sidle_w, 1.0 if on else 0.0, delta * 4.0)
	if _sidle_w < 0.001:
		_sidle_phase = 0.0
		return
	# how fast she's moving to her own right (+) or left (-)
	var right := global_basis.x.normalized()
	var lateral: float = Vector3(_body.velocity.x, 0, _body.velocity.z).dot(right)
	_sidle_phase = fmod(_sidle_phase + absf(lateral) * delta / SIDLE_STEP * TAU, TAU)
	var lead := "R" if lateral >= 0.0 else "L"
	var trail := "L" if lead == "R" else "R"
	var out := 1.0 if lead == "R" else -1.0
	var moving := clampf(absf(lateral) / 0.15, 0.0, 1.0) * _sidle_w
	var step := sin(_sidle_phase)
	# first half the lead foot reaches out, second half the trailing one follows in
	_turn("thigh." + lead, Vector3.FORWARD, -out * 12.0 * maxf(step, 0.0) * moving)
	_turn("thigh." + trail, Vector3.FORWARD, -out * 9.0 * maxf(-step, 0.0) * moving)
	_offset_hips(Vector3.RIGHT * out * 0.015 * sin(_sidle_phase - 0.6) * moving)
	_turn("hips", Vector3.BACK, out * 2.5 * step * moving)
	# arms in close, hands in front of her hips, out of the walls' way
	_turn("upperarm.R", Vector3.BACK, -8.0 * _sidle_w)
	_turn("upperarm.L", Vector3.BACK, 8.0 * _sidle_w)
	_turn("forearm.R", Vector3.RIGHT, 25.0 * _sidle_w)
	_turn("forearm.L", Vector3.RIGHT, 25.0 * _sidle_w)


## Metres of sideways shuffle per step (one foot out and the other in).
const SIDLE_STEP := 0.35


## Turns one arm (`side` "R" or "L") `w` of the way from its pose now to `spec`
## (turns from her T-pose, given for the right arm).
func _reach(side: String, spec: Dictionary, w: float) -> void:
	var mirror := -1.0 if side == "L" else 1.0
	for part: String in ["upperarm", "forearm"]:
		var key := part + "." + side
		var i: int = _bones.get(key, -1)
		if i < 0:
			continue
		var parent := skeleton.get_bone_parent(i)
		var pb := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
		var before := skeleton.get_bone_pose_rotation(i)
		var q := skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
		for t: Array in spec[part]:
			var axis: Vector3 = t[0]
			var deg: float = t[1] * (mirror if axis != Vector3.RIGHT else 1.0)
			q = (pb.inverse() * Basis(axis, deg_to_rad(deg)) * pb * Basis(q)).get_rotation_quaternion()
		var turned := before.slerp(q, w)
		skeleton.set_bone_pose_rotation(i, turned)
		_strut_undo[key] = [_strut_undo[key][0] if _strut_undo.has(key) else before, turned]


## How far she'd ease back to settle into a wall behind her (0 = none in reach).
func _wall_behind() -> float:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return 0.0
	if _lean_exclude.is_empty():
		var n: Node = self
		while n != null:
			if n is CollisionObject3D:
				_lean_exclude.append((n as CollisionObject3D).get_rid())
			n = n.get_parent()
	var back := global_basis.z.normalized()
	var from := global_position + Vector3.UP * 0.9
	var ray := PhysicsRayQueryParameters3D.create(from, from + back * (LEAN_BACK + LEAN_REACH), 0xFFFFFFFF, _lean_exclude)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or (hit["normal"] as Vector3).dot(-back) < 0.7:
		return 0.0
	return maxf(from.distance_to(hit["position"]) - LEAN_BACK + LEAN_PRESS, 0.0)


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
	_strut_undo["hips_at"] = [_strut_undo["hips_at"][0] if _strut_undo.has("hips_at") else before, moved]


## Takes the Jiggle style setting (Prefs.set_jiggle_style calls this on every
## Eco in the "eco_jiggle" group).
func follow_jiggle_setting() -> void:
	jiggle_style = Prefs.jiggle_style()
	_style_chosen = false
	add_to_group("eco_jiggle")
	body_jiggle = Prefs.body_jiggle()
	var press := Prefs.press_strength()
	contact_give = 1.0 + press
	squish_scale = minf(press, 1.5)


## Puts her clothes on the skin's soft weights (eco_cling.gd), so they ride
## her chest's and glutes' swing and squash. Before the full body jiggle's
## reweighting, which builds on these.
func _cling() -> void:
	for node in skeleton.find_children("*", "MeshInstance3D", false, false):
		var mi := node as MeshInstance3D
		var swap := EcoCling.reweight(mi, skeleton)
		if not swap.is_empty():
			mi.skin = swap[1]
			mi.mesh = swap[0]
			clung += 1


## Turns the soft stomach, thigh, arm and calf springs on or off: on adds
## their bones (once) and swaps her meshes for ones weighted to them; off puts
## the original meshes back and lets the bones rest.
func _set_flesh(on: bool) -> void:
	if skeleton == null or (on and not springs_enabled):
		return  # not ready yet (_ready turns it on), or posed by hand (first-person arm)
	var had := _springs.any(func(s: Dictionary) -> bool: return s.get("flesh", false))
	if on == had:
		return
	if not on:
		_springs.assign(_springs.filter(func(s: Dictionary) -> bool: return not s.get("flesh", false)))
		_link_touches()
		for mi: MeshInstance3D in _flesh_swapped:
			if is_instance_valid(mi):
				# mesh first: the original mesh fits either skin, the soft one only its own
				mi.mesh = _flesh_swapped[mi][0]
				mi.skin = _flesh_swapped[mi][1]
		_flesh_swapped.clear()
		for bone_name: String in EcoFlesh.bone_names():
			var i := skeleton.find_bone(bone_name)
			if i >= 0:
				skeleton.reset_bone_pose(i)
		return
	for spring: Dictionary in EcoFlesh.add_bones(skeleton):
		var base: Dictionary = spring["base"]
		var s: Dictionary = base.duplicate()
		s["bone"] = spring["bone"]
		s["parent"] = skeleton.get_bone_parent(spring["bone"])
		s["aim"] = spring["aim"]
		s["ready"] = false
		s["base"] = base
		s["flesh"] = true
		_springs.append(s)
	_springs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["bone"] < b["bone"])
	_apply_jiggle_style()
	_link_touches()
	for node in skeleton.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var swap := EcoFlesh.reweight(mi, skeleton)
		if not swap.is_empty():
			_flesh_swapped[mi] = [mi.mesh, mi.skin]
			mi.skin = swap[1]  # skin first, so the mesh never meets a skin missing its new bones
			mi.mesh = swap[0]


## Sets every spring's settings from its group's own and jiggle_style's.
func _apply_jiggle_style() -> void:
	var style: Dictionary = JIGGLE_STYLES.get(jiggle_style, {})
	for s in _springs:
		var base: Dictionary = s["base"]
		for key: String in ["stiffness", "drag", "gravity", "limit", "inertia", "reach"]:
			if base.has(key):
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


## Pushes a spring's tip (world space) out of anything solid within its
## "touch" radius: brushing a corner presses that part back, and once she moves
## clear the spring lets it go.
func _collide(s: Dictionary, tip: Vector3) -> Vector3:
	var r: float = s.get("touch", 0.0)
	if not jiggle_collide or r <= 0.0 or not is_inside_tree():
		return tip
	if not is_nan(_support_y):
		tip.y = maxf(tip.y, _support_y + r * SUPPORT_REST)
	var space := skeleton.get_world_3d().direct_space_state
	if space == null:
		return tip
	if _touch_query == null:
		_touch_query = PhysicsShapeQueryParameters3D.new()
		_touch_query.collide_with_areas = false
		var mine: Array[RID] = []
		var n: Node = self
		while n != null:
			if n is CollisionObject3D:
				mine.append((n as CollisionObject3D).get_rid())
			n = n.get_parent()
		_touch_query.exclude = mine
	if not _touch_shapes.has(r):
		var ball := SphereShape3D.new()
		ball.radius = r
		_touch_shapes[r] = ball
	_touch_query.shape = _touch_shapes[r]
	_touch_query.transform = Transform3D(Basis(), tip)
	var hit := space.get_rest_info(_touch_query)
	if hit.is_empty():
		return tip
	var normal: Vector3 = hit["normal"]
	var depth := r - (tip - (hit["point"] as Vector3)).dot(normal)
	return tip + normal * depth if depth > 0.0 else tip


## Wires up SELF_PAIRS and SELF_BODIES for the springs she has now. A pair
## lives on its later spring, so the earlier one has already moved this frame.
func _link_touches() -> void:
	var by_name := {}
	for s in _springs:
		s["pairs"] = []
		s["bodies"] = []
		by_name[skeleton.get_bone_name(s["bone"])] = s
	for pair: Array in SELF_PAIRS:
		if by_name.has(pair[0]) and by_name.has(pair[1]):
			var a: Dictionary = by_name[pair[0]]
			var b: Dictionary = by_name[pair[1]]
			if _springs.find(a) > _springs.find(b):
				var swap := a
				a = b
				b = swap
			b["pairs"].append([a, pair[2]])
	for bone_name: String in by_name:
		var s: Dictionary = by_name[bone_name]
		for body: Array in SELF_BODIES.get(bone_name, SELF_BODIES.get(s["base"].get("group", ""), [])):
			var from := skeleton.find_bone(body[0])
			var to := skeleton.find_bone(body[1]) if body[1] != "" else -1
			if from >= 0 and (to >= 0 or body[1] == ""):
				s["bodies"].append([from, to, body[2], body[3]])


## Keeps a spring's tip (world space) off her own body and her other soft
## parts (SELF_PAIRS, SELF_BODIES): never closer than their radii, or than her
## pose holds it if that's closer. The other part of a pair is pushed too, and
## its spring carries that on as its own swing.
func _touch_self(s: Dictionary, tip: Vector3, target: Vector3) -> Vector3:
	if not jiggle_collide:
		return tip
	var r: float = s.get("touch", 0.0)
	for pair: Array in s.get("pairs", []):
		var o: Dictionary = pair[0]
		if not o["ready"] or not o.has("target"):
			continue
		var held: Vector3 = o["target"] - target
		var gap := held.length()
		if gap < 1e-4:
			continue
		var n := held / gap
		var closest: float = gap if pair[1] else minf(gap, r + float(o.get("touch", 0.0)))
		var press := closest - ((o["tip"] as Vector3) - tip).dot(n)
		if press > 0.0:
			tip -= n * press * 0.5
			o["tip"] += n * press * 0.5
			o["shoved"] = o.get("shoved", Vector3.ZERO) + n * press * 0.5
	if s.get("bodies", []).is_empty():
		return tip
	var to_world := skeleton.global_transform
	for body: Array in s["bodies"]:
		var from_xf := skeleton.get_bone_global_pose(body[0])
		var a := to_world * from_xf.origin
		var b := to_world * (skeleton.get_bone_global_pose(body[1]).origin if body[1] >= 0 else from_xf.origin + from_xf.basis.y.normalized() * float(body[2]))
		var closest := minf(_to_segment(target, a, b).length(), r + float(body[3]))
		var away := _to_segment(tip, a, b)
		var d := away.length()
		if d < closest and d > 1e-5:
			tip += away / d * (closest - d)
	return tip


## How far a spring may swing (or slide) this step: as far as contact has just
## pushed it, up to contact_give times its own limit, never less than its own
## limit; once free that extra room shrinks back over a few frames so it
## springs back instead of snapping. Its own swing never uses the extra room
## unless something is pushing it there. `was` and `now` are how far out it
## was before and after contact this step.
func _give(s: Dictionary, limit: float, was: float, now: float, steps: float) -> float:
	var shoved: Vector3 = s.get("shoved", Vector3.ZERO)
	s["shoved"] = Vector3.ZERO
	var room: float = s.get("room", limit)
	room = move_toward(room, limit, limit * 0.06 * steps)
	if now > was + 1e-5 or shoved.length() > 0.0005:
		room = maxf(room, minf(now, limit * (contact_give + _squeeze)))
	s["room"] = room
	return maxf(limit, room)


## Flattens a pressed spring's bone along the push (world space) and bulges it
## out the other ways, keeping its volume; `deep` is how far it's pressed
## (1 = as far as contact lets it go; past that it's being pushed through, so
## it spreads further). Eases in and out.
func _squash(s: Dictionary, i: int, push: Vector3, deep: float, bone_basis: Basis, to_skel: Basis, steps: float) -> void:
	var want := 0.0
	if jiggle_squish and jiggle_collide and push.length() > 0.0005:
		# up to "squish" as contact presses it to its limit, then up to half as
		# much again as it's pushed on past it (eased, so it never stops dead)
		var past := maxf(deep - 1.0, 0.0)
		want = minf(float(s["squish"]) * (squish_scale + 0.8 * _squeeze) * (clampf(deep, 0.0, 1.0) + 0.5 * tanh(past * 1.5)), 0.6)
		# the bone axis the push is most along
		var local := (bone_basis.orthonormalized().inverse() * (to_skel * push)).abs()
		s["squash_axis"] = 0 if local.x >= local.y and local.x >= local.z else (1 if local.y >= local.z else 2)
	var was: float = s.get("squash", 0.0)
	var now := lerpf(was, want, minf((0.35 if want > was else 0.12) * steps, 1.0))
	if now < 0.002:
		now = 0.0
	s["squash"] = now
	if now == 0.0 and was == 0.0:
		return
	var scale := Vector3.ONE / sqrt(1.0 - now)
	scale[s.get("squash_axis", 1)] = 1.0 - now
	skeleton.set_bone_pose_scale(i, scale)


## From the nearest point of the segment a-b to p.
static func _to_segment(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
	return p - (a + ab * t)


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
	_weather(delta)
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
		# soft-body springs (eco_flesh.gd) slide their bone up to `reach` metres instead of turning it
		var slide: bool = s.has("reach")
		var limit: float = (float(s["reach"]) if slide else deg_to_rad(s["limit"])) * (jiggle if s.get("jiggle", false) else 1.0)
		if _plated and s["base"].get("group", "") == "bust":
			limit = 0.0
		var target := origin + rest_dir * length
		s["target"] = target
		if limit <= 0.0 or not s["ready"] or (s["tip"] as Vector3).distance_to(target) > 1.0:
			s["tip"] = target
			s["prev"] = target
			s["prev_target"] = target
			s["ready"] = true
			if limit <= 0.0:
				if slide:
					skeleton.set_bone_pose_position(i, skeleton.get_bone_rest(i).origin)
				else:
					skeleton.set_bone_pose_rotation(i, skeleton.get_bone_rest(i).basis.get_rotation_quaternion())
					if s.get("squash", 0.0) > 0.0:
						s["squash"] = 0.0
						skeleton.set_bone_pose_scale(i, Vector3.ONE)
				continue
		elif moved.length() < 1.0 and not slide:
			# carry the spring along with the part of her movement it shouldn't feel
			var carry := moved * (1.0 - float(s["inertia"]))
			s["tip"] += carry
			s["prev"] += carry
		var tip: Vector3 = s["tip"]
		var prev: Vector3 = s["prev"]
		if slide:
			# damp the flesh's speed relative to her body, not to the world: moving
			# steadily (running, a swinging leg) leaves it in place, speeding up,
			# slowing down and landing set it wobbling. Stepped a frame (at 60 fps)
			# at a time, so a slow frame doesn't kick it.
			var from_target: Vector3 = s["prev_target"]
			s["prev_target"] = target
			var count := ceili(steps)
			var sub := steps / count
			var next: Vector3 = tip
			for n in count:
				# where her body held it at the start of this step, and how far that moves
				var goal := from_target.lerp(target, float(n) / count)
				var moving := (target - from_target) / count
				next = tip + moving + ((tip - prev) - moving) * pow(1.0 - s["drag"], sub)
				next += (goal - tip) * minf(s["stiffness"] * sub, 1.0)
				prev = tip
				tip = next
			if next.y < _water_y:
				next = tip + (next - tip) * WATER_DRAG
			if s.has("lateral"):
				var across := to_world.basis.x.normalized()
				next -= across * (next - target).dot(across) * (1.0 - float(s["lateral"]))
			var free_at := next
			next = _collide(s, _touch_self(s, next, target))
			limit = _give(s, limit, (free_at - target).length(), (next - target).length(), steps)
			var off: Vector3 = next - target
			var d := off.length()
			if s.get("soft", false) and d > limit * 0.6:
				off *= (limit * 0.6 + limit * 0.4 * tanh((d - limit * 0.6) / (limit * 0.4))) / d
			elif d > limit:
				off *= limit / d
			s["prev"] = prev
			s["tip"] = target + off
			skeleton.set_bone_pose_position(i, skeleton.get_bone_rest(i).origin + parent_pose.basis.inverse() * (to_skel.basis * off))
			continue
		var next: Vector3 = tip + (tip - prev) * (1.0 - s["drag"])
		next += (target - tip) * minf(s["stiffness"] * steps, 1.0)
		next += Vector3.DOWN * s["gravity"] * 0.01 * steps * length
		next = _in_weather(s, tip, next, steps)
		if s.has("lateral"):
			# keep only part of the swing across her body
			var side := to_world.basis.x.normalized()
			next -= side * (next - target).dot(side) * (1.0 - float(s["lateral"]))
		var free_at := next
		next = _collide(s, _touch_self(s, next, target))
		var push: Vector3 = next - free_at + s.get("shoved", Vector3.ZERO)
		var normal_limit := limit
		limit = _give(s, limit, (free_at - origin).angle_to(rest_dir), (next - origin).angle_to(rest_dir), steps)
		var dir: Vector3 = (next - origin).normalized()
		var angle: float = dir.angle_to(rest_dir)
		if s.has("squish"):
			var deep := angle / maxf(normal_limit * (contact_give + _squeeze), 1e-3)
			# pushed past even the extra room: the part spreads instead of going through
			var held := origin + rest_dir.slerp(dir, minf(limit / maxf(angle, 1e-5), 1.0)).normalized() * length
			deep += (_collide(s, held) - held).length() / maxf(float(s.get("touch", 0.05)), 1e-3)
			_squash(s, i, push, deep, rest_xf.basis, to_skel.basis, steps)
		var knee := limit * 0.6
		if s.get("soft", false) and angle > knee:
			# ease into the limit: swings up to 60% of it stay as they are, bigger ones round off
			var eased := knee + (limit - knee) * tanh((angle - knee) / (limit - knee))
			dir = rest_dir.slerp(dir, eased / angle).normalized()
		elif angle > limit:
			dir = rest_dir.slerp(dir, limit / angle).normalized()
		s["prev"] = tip
		s["tip"] = origin + dir * length
		if glute_swing != 1.0 and s["base"].get("group", "") == "glute":
			# shown bigger (or smaller) than simulated, so the spring itself behaves the same
			var swung := dir.angle_to(rest_dir)
			var turn_axis := rest_dir.cross(dir)
			if swung > 1e-4 and turn_axis.length() > 1e-6:
				dir = rest_dir.rotated(turn_axis.normalized(), swung * glute_swing)
		# rotate the bone so its child lies along the simulated direction
		var from_skel := aim_skel.normalized()
		var to_dir: Vector3 = (to_skel.basis * dir).normalized()
		if from_skel.dot(to_dir) > 0.99999:
			skeleton.set_bone_pose_rotation(i, skeleton.get_bone_rest(i).basis.get_rotation_quaternion())
			continue
		var swing := Basis(Quaternion(from_skel, to_dir))
		var local := parent_pose.basis.inverse() * swing * rest_xf.basis
		skeleton.set_bone_pose_rotation(i, local.get_rotation_quaternion())
