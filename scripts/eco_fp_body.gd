extends Node3D
## Eco's own body in first person (child of the player). Spawns two copies of
## assets/models/eco.tscn that animate from the player's movement:
## - "Body": seen when you look down. Head, neck and arms are collapsed (her
##   arm on the view-model gun, scripts/eco_fp_arms.gd, stands in for her
##   hands), it casts no shadow, and it is shifted each frame so her neck sits
##   just under and behind the camera, whatever the pose (run, crouch, slide).
##   Her chest and glute springs run on it, pushed harder than in third person
##   (fp_jiggle) and shoved by jumps, landings and quick looks (_jolt), so the
##   bounce reads when you look down at her.
## - "Shadow": the whole of her at the player's feet, drawn only into shadows.
##   In third person (scripts/view_camera.gd) it is drawn for real and "Body"
##   hides.

const ECO := preload("res://assets/models/eco.tscn")
const EcoModel := preload("res://scripts/ps2/eco_model.gd")
const HIDDEN_BONES := ["J_Bip_C_Neck", "J_Bip_C_Head", "J_Bip_R_UpperArm", "J_Bip_L_UpperArm"]

## Where the camera sits relative to the base of her neck: metres above it,
## and metres in front of it (about where her eyes are).
@export var camera_above_neck := 0.17
@export var camera_ahead := 0.1
## Looking down she leans over her chest: her neck comes this much further
## forward under the camera by the time she looks 60 degrees down, so her chest
## comes into view from about 35 degrees.
@export var look_down_lean := 0.08
## How far her chest may bounce in first person (eco_model.gd jiggle).
@export_range(0.0, 2.0) var fp_jiggle := 1.6
## How hard a change in her speed shoves the springs (metres of swing per m/s):
## a jump throws them down, a landing drops them and they bounce back up.
@export var jolt_per_speed := 0.006
## How hard a quick look shoves them (metres per radian the view turns).
@export var jolt_per_look := 0.03
@export var show_body := true
@export var cast_shadow := true

var body: EcoModel
var shadow: EcoModel
var _camera: Camera3D
var _neck_bone := -1
var _player: CharacterBody3D
var _last_velocity := Vector3.ZERO
var _last_pitch := 0.0
var _third_person := false
## Resting (rest()): where she stood, and the seat she is moving from and to
## (her full model leaves the player for them while she rests).
var _rest_stand := Transform3D()
var _rest_from := Transform3D()
var _rest_at := Transform3D()


func _ready() -> void:
	process_priority = 100  # after the player and the animation players
	var cam := get_parent().find_child("Camera3D", true, false)
	if cam is Camera3D:
		_camera = cam
	_player = get_parent() as CharacterBody3D
	if show_body:
		body = _spawn("Body", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		body.jiggle = fp_jiggle
		_neck_bone = body.skeleton.find_bone("J_Bip_C_Neck") if body.skeleton != null else -1
	if cast_shadow:
		shadow = _spawn("Shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)


## Suit pieces hidden on the first-person body: round her neck or on her face, they
## would sit round the camera.
const FP_HIDDEN := ["suit_t4h_collar*", "suit_t1l_choker*", "suit_t1l_tag*", "suit_t1l_nose_ring*",
		"suit_t1m_scarf*", "suit_t1m_plaster*", "suit_t1h_comm*"]


## Dresses both copies in her suit upgrade (eco_model.gd suit_tier and suit_weight).
func set_suit(tier: int, weight := "medium") -> void:
	for eco in [body, shadow]:
		if eco != null:
			eco.suit_weight = weight
			eco.suit_tier = tier
	if body != null:
		for pattern in FP_HIDDEN:
			for mesh in body.find_children(pattern, "MeshInstance3D", true, false):
				(mesh as MeshInstance3D).visible = false


func _spawn(node_name: String, shadows: GeometryInstance3D.ShadowCastingSetting) -> EcoModel:
	var eco := ECO.instantiate() as EcoModel
	eco.name = node_name
	add_child(eco)
	for mesh in eco.find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).cast_shadow = shadows
	return eco


## Third person: her whole model is seen, the first-person body hides.
func set_third_person(on: bool) -> void:
	_third_person = on
	if body != null:
		body.visible = not on
	if shadow != null:
		var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		for mesh in shadow.find_children("*", "GeometryInstance3D", true, false):
			(mesh as GeometryInstance3D).cast_shadow = mode


## Settles her full model into a rest pose (eco_model.gd rest_pose) at a seat:
## `at` is the floor under her hips, facing the way she faces, and
## `seat_height` the top of the seat or bed. She walks over from where she
## stands, and from one rest pose to another moves over without standing up.
func rest(pose: String, at: Transform3D, seat_height: float) -> void:
	if shadow == null:
		return
	if not shadow.resting():
		_rest_stand = global_transform
		_rest_from = at
	else:
		_rest_from = _rest_at
	_rest_at = at
	shadow.top_level = true
	shadow.global_transform = _rest_stand
	shadow.rest_seat_height = seat_height
	shadow.rest_pose = pose
	_show_gun(false)
	if shadow.has_method("wear"):
		shadow.wear("sleep" if pose == "sleep" else "suit")


## Gets her up from her rest pose, back to where the player stands now.
func get_up() -> void:
	if shadow == null or shadow.rest_pose == "":
		return
	_rest_stand = global_transform
	shadow.rest_pose = ""
	if shadow.has_method("wear"):
		shadow.wear("suit")


## Whether she is resting, or still settling in or getting up.
func is_resting() -> bool:
	return shadow != null and shadow.resting()


func _show_gun(on: bool) -> void:
	var hold := shadow.find_child("GunHold", true, false) as Node3D if shadow != null else null
	if hold != null:
		hold.visible = on


func _rest_follow() -> void:
	if shadow == null or not shadow.top_level:
		return
	if not shadow.resting():
		shadow.top_level = false
		shadow.transform = Transform3D()
		_show_gun(true)
		return
	var seat := _rest_from.interpolate_with(_rest_at, shadow.rest_blend())
	shadow.global_transform = _rest_stand.interpolate_with(seat, shadow.rest_weight())


func _process(delta: float) -> void:
	_rest_follow()
	if body == null or _third_person or body.skeleton == null:
		return
	var sk: Skeleton3D = body.skeleton
	for bone_name: String in HIDDEN_BONES:
		var i := sk.find_bone(bone_name)
		if i >= 0:
			sk.set_bone_pose_scale(i, Vector3.ONE * 0.001)
	if _camera == null or _neck_bone < 0:
		return
	# line the base of her neck up under the camera (in this node's yaw frame)
	var to_local := global_transform.affine_inverse()
	var neck_local := to_local * (sk.global_transform * sk.get_bone_global_pose(_neck_bone).origin)
	var cam_local := to_local * _camera.global_position
	var down := clampf(-_camera.global_rotation.x / deg_to_rad(60.0), 0.0, 1.0)
	var want := cam_local + Vector3(0, -camera_above_neck, camera_ahead - look_down_lean * down)
	body.position += want - neck_local
	_jolt(delta)


## Shoves her chest and glutes (eco_model.gd nudge) the opposite way to how her
## body just jolted: a jump's kick up, a landing's stop, the view tipping up or
## down. Turning left and right swings them on its own (her body turns with you).
func _jolt(delta: float) -> void:
	if _player == null or delta <= 0.0:
		return
	var dv := _player.velocity - _last_velocity
	_last_velocity = _player.velocity
	var pitch := _camera.global_rotation.x
	var dpitch := wrapf(pitch - _last_pitch, -PI, PI)
	_last_pitch = pitch
	# small speed changes (steps, steering) are the springs' own business
	var shove := -dv * jolt_per_speed if dv.length() > 1.5 else Vector3.ZERO
	shove += Vector3.UP * dpitch * jolt_per_look
	if shove.length() > 0.0001:
		body.nudge(shove.limit_length(0.06))
