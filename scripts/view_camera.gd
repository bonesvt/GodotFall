extends Node
## First / third person view for the player (child "ViewCam" of scenes/player.tscn).
## F5 toggles it. Third person is a loose over-the-shoulder camera:
## - turning and aiming stay tight (the camera still hangs off the Head, so the
##   crosshair, shots and grapple aim exactly where it points);
## - only its position trails the body, so runs, slides, jumps and landings make
##   it sway and catch up instead of being bolted to her back;
## - it pulls back a little at speed and pulls in front of walls it would clip;
## - it swaps shoulders on parkour: a wallrun puts it on the open side, away
##   from the wall (wall on your right = left shoulder), and it stays there
##   until the next swap. In tight spots it also moves to the free shoulder.
## Eco's full model shows in third person; the first-person arms and gun hide,
## and a pistol rides in her right hand instead (tracers start from it).

const PlayerState := preload("res://scripts/ps2/eco_model.gd").PlayerState
const GUN := preload("res://assets/models/smart_pistol/smart_pistol.glb")

## Remembered across zones and respawns for the session.
static var prefer_third_person := false

@export_group("Shoulder")
## Metres behind her eyes.
@export var distance := 3.1
## Metres to the side (the shoulder), before the side is picked.
@export var shoulder := 0.75
## Metres above her eyes.
@export var height := 0.3
## Extra metres pulled back at full speed.
@export var speed_pullback := 0.9
## How quickly a shoulder swap slides across (higher = snappier).
@export var swap_rate := 5.0
@export var tp_fov := 80.0

@export_group("Looseness")
## How quickly the camera catches up with her body (higher = tighter).
@export var follow_rate := 7.0
## Vertical catch-up is slower, so jumps and landings breathe.
@export var follow_rate_y := 5.0
## The most it may trail behind, in metres.
@export var max_lag := 0.9
## Collision: metres kept off walls.
@export var wall_margin := 0.25

var third_person := false
## +1 = right shoulder, -1 = left.
var side := 1.0

var player: CharacterBody3D
var _head: Node3D
var _camera: Camera3D
var _eco_body: Node
var _side_x := 1.0
var _anchor := Vector3.ZERO
var _was_wallrun := false
var _swap_cooldown := 0.0
var _fp_fov := 90.0
var _gun: Node3D
var _gun_muzzle: Node3D


func _ready() -> void:
	process_priority = 90  # after the player moved; before EcoBody (100)
	player = get_parent() as CharacterBody3D
	_head = player.get_node("Head")
	_camera = player.get_node("Head/Camera3D")
	_eco_body = player.get_node_or_null("EcoBody")
	_fp_fov = player.base_fov
	set_third_person.call_deferred(prefer_third_person)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_view") and not event.is_echo():
		prefer_third_person = not third_person
		set_third_person(prefer_third_person)


func set_third_person(on: bool) -> void:
	third_person = on
	player.set("third_person", on)
	_anchor = _head.global_position
	for node_name in ["Weapon", "Knife"]:
		var n := _camera.get_node_or_null(node_name) as Node3D
		if n != null:
			n.visible = not on
	if _eco_body != null and _eco_body.has_method("set_third_person"):
		_eco_body.set_third_person(on)
	_attach_gun()
	player.base_fov = tp_fov if on else _fp_fov
	if not on:
		_camera.position = Vector3.ZERO


## Where tracers and the grapple rope start in third person: her pistol.
func muzzle_position() -> Vector3:
	if _gun_muzzle != null and is_instance_valid(_gun_muzzle):
		return _gun_muzzle.global_position
	return _head.global_position + _head.global_basis * Vector3(0.25, -0.35, -0.4)


func _process(delta: float) -> void:
	if not third_person:
		return
	_swap_cooldown -= delta
	_pick_shoulder()
	_side_x = lerpf(_side_x, side, 1.0 - exp(-swap_rate * delta))

	# Trail the body: catch up exponentially, never more than max_lag behind.
	var target := _head.global_position
	var a := 1.0 - exp(-follow_rate * delta)
	var ay := 1.0 - exp(-follow_rate_y * delta)
	_anchor = Vector3(lerpf(_anchor.x, target.x, a), lerpf(_anchor.y, target.y, ay), lerpf(_anchor.z, target.z, a))
	if _anchor.distance_to(target) > max_lag:
		_anchor = target + (_anchor - target).normalized() * max_lag

	var speed_t := clampf((player.velocity.length() - 7.0) / 15.0, 0.0, 1.0)
	var offset := Vector3(_side_x * shoulder, height, distance + speed_pullback * speed_t)
	var want := _anchor + _head.global_basis * offset
	# Pull in front of anything between her and the camera.
	var pivot := target + _head.global_basis * Vector3(_side_x * shoulder * 0.5, height * 0.5, 0.0)
	var hit := _ray(pivot, want)
	if not hit.is_empty():
		var dir := (want - pivot).normalized()
		var d := maxf(pivot.distance_to(hit.position) - wall_margin, 0.05)
		want = pivot + dir * d
	_camera.position = _head.global_transform.affine_inverse() * want


## Wallruns put the camera on the open side; a blocked shoulder hands over to a
## clear one.
func _pick_shoulder() -> void:
	var wallrun: bool = player.get("state") == PlayerState.WALLRUN
	if wallrun and not _was_wallrun:
		var n: Vector3 = player.get("wall_normal")
		var d := n.dot(player.global_basis.x)
		if absf(d) > 0.2:
			side = signf(d)
			_swap_cooldown = 0.8
	_was_wallrun = wallrun
	if wallrun or _swap_cooldown > 0.0:
		return
	var eye := _head.global_position
	var right := player.global_basis.x
	var reach := shoulder + wall_margin + 0.15
	if not _ray(eye, eye + right * side * reach).is_empty() \
			and _ray(eye, eye - right * side * reach).is_empty():
		side = -side
		_swap_cooldown = 0.8


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q)


## A copy of the pistol in her right hand while in third person.
func _attach_gun() -> void:
	if not third_person:
		if _gun != null and is_instance_valid(_gun):
			_gun.get_parent().queue_free()
		_gun = null
		_gun_muzzle = null
		return
	if _gun != null and is_instance_valid(_gun):
		return
	var model: Node = _eco_body.get("shadow") if _eco_body != null else null
	var sk: Skeleton3D = model.get("skeleton") if model != null else null
	if sk == null or sk.find_bone("J_Bip_R_Hand") < 0:
		return
	var hold := BoneAttachment3D.new()
	hold.name = "GunHold"
	hold.bone_name = "J_Bip_R_Hand"
	sk.add_child(hold)
	_gun = GUN.instantiate()
	hold.add_child(_gun)
	# grip in the palm, barrel along her fingers
	_gun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-90.0), deg_to_rad(-90.0), 0.0)), Vector3(0.06, -0.02, 0.0))
	_gun_muzzle = _gun.find_child("Muzzle", true, false) as Node3D
