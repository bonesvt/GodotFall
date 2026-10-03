extends Node3D
## Eco's own body in first person (child of the player). Spawns two copies of
## assets/models/eco.tscn that animate from the player's movement:
## - "Body": seen when you look down. Head, neck and arms are collapsed (the
##   view-model pistol arm stands in for her hands), it casts no shadow, and it
##   is shifted each frame so her neck sits just under and behind the camera,
##   whatever the pose (run, crouch, slide).
## - "Shadow": the whole of her at the player's feet, drawn only into shadows.
##   In third person (scripts/view_camera.gd) it is drawn for real and "Body"
##   hides.

const ECO := preload("res://assets/models/eco.tscn")
const EcoModel := preload("res://scripts/ps2/eco_model.gd")
const HIDDEN_BONES := ["J_Bip_C_Neck", "J_Bip_C_Head", "J_Bip_R_UpperArm", "J_Bip_L_UpperArm"]

## Where the camera sits relative to the base of her neck: metres above it,
## and metres in front of it (keeps her chest out of the near plane).
@export var camera_above_neck := 0.17
@export var camera_ahead := 0.21
@export var show_body := true
@export var cast_shadow := true

var body: EcoModel
var shadow: EcoModel
var _camera: Camera3D
var _neck_bone := -1
var _third_person := false


func _ready() -> void:
	process_priority = 100  # after the player and the animation players
	var cam := get_parent().find_child("Camera3D", true, false)
	if cam is Camera3D:
		_camera = cam
	if show_body:
		body = _spawn("Body", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		body.springs_enabled = false
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


## Shapes both copies by what she has trained (eco_model.gd set_fitness).
func set_fitness(amounts: Dictionary) -> void:
	for eco in [body, shadow]:
		if eco != null:
			eco.set_fitness(amounts)


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


func _process(_delta: float) -> void:
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
	var want := cam_local + Vector3(0, -camera_above_neck, camera_ahead)
	body.position += want - neck_local
