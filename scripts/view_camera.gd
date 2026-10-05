extends Node
## First / third person view for the player (child "ViewCam" of scenes/player.tscn).
## Middle mouse (or F5) toggles it. Third person is a close over-the-shoulder camera:
## - looking straight ahead it frames her from just over the top of her head
##   (the crosshair clears it) down to just under her knees;
## - turning and aiming are exact (the camera hangs off the Head, so the
##   crosshair, shots and grapple aim exactly where it points), and it follows
##   her body almost rigidly, with only a hint of give on landings;
## - it pulls in front of walls it would clip;
## - it swaps shoulders on parkour: a wallrun puts it on the open side, away
##   from the wall (wall on your right = left shoulder), and it stays there
##   until the next swap. In tight spots it also moves to the free shoulder.
## Eco's full model shows in third person; the first-person arms and gun hide,
## and a pistol rides in her right hand instead (tracers start from it).
## Off duty (the hub and town, player.gd strolling) third person becomes a free
## orbit camera instead: the mouse swings it all the way round her, the keys
## walk her relative to the camera and she turns to face where she walks. It
## blends back to the shoulder camera on the training grounds and on runs.
## Settings > Game (prefs.gd apply_camera) sets how far back it sits, whether
## X swaps shoulders by hand, and whether the arrow keys nudge the hub camera
## up, down, left and right (the nudge is remembered).

const PlayerState := preload("res://scripts/ps2/eco_model.gd").PlayerState
const GUN := preload("res://assets/models/smart_pistol/smart_pistol.glb")
const EcoArms := preload("res://scripts/eco_fp_arms.gd")

## Remembered across zones and respawns for the session.
static var prefer_third_person := false
## Settings > Game (prefs.gd apply_camera). Metres behind her eyes on the
## shoulder; the orbit and resting distances scale with it. 0 = `distance`.
static var distance_setting := 0.0
## The swap_shoulder key (X) moves the camera to her other shoulder.
static var shoulder_swap_key := true
## The cam_nudge_* keys (arrows) slide the hub/town camera, in metres
## (x right, y up of the orbit point), and it stays where it was left.
static var hub_nudge_keys := true
static var hub_nudge := Vector2.ZERO
## The settings screen offers this range.
const DISTANCE_MIN := 1.0
const DISTANCE_MAX := 4.5
const NUDGE_X := 1.2
const NUDGE_DOWN := -0.8
const NUDGE_UP := 1.2

@export_group("Shoulder")
## Metres behind her eyes. With height and tp_fov this frames her from over
## her head to just under her knees when looking straight ahead.
@export var distance := 1.7
## Metres to the side (the shoulder), before the side is picked.
@export var shoulder := 0.5
## Metres above her eyes (puts the crosshair just over her head).
@export var height := 0.25
## Extra metres pulled back at full speed.
@export var speed_pullback := 0.0
## How quickly a shoulder swap slides across (higher = snappier).
@export var swap_rate := 5.0
@export var tp_fov := 80.0
## Metres behind her eyes while she sits or lies down somewhere (player.gd resting).
@export var rest_distance := 2.2

@export_group("Follow")
## How quickly the camera catches up with her body (higher = tighter).
@export var follow_rate := 30.0
## Vertical catch-up, a little softer so landings don't jolt.
@export var follow_rate_y := 18.0
## The most it may trail behind, in metres.
@export var max_lag := 0.12
## Collision: metres kept off walls.
@export var wall_margin := 0.25

@export_group("Orbit (hub and town)")
## Metres from the point it circles (over her shoulders).
@export var orbit_distance := 2.6
## Height of that point above her feet.
@export var orbit_height := 1.4
## How far it may swing below and above level, in degrees.
@export var orbit_pitch_min := -60.0
@export var orbit_pitch_max := 35.0
## How quickly it swaps between the orbit and the shoulder camera.
@export var orbit_blend_rate := 5.0
## Metres a second the nudge keys slide it.
@export var nudge_speed := 1.5

var third_person := false
## +1 = right shoulder, -1 = left.
var side := 1.0
## Orbiting her (third person while strolling), and where the orbit looks from.
var orbiting := false
var orbit_yaw := 0.0
var orbit_pitch := 0.0

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
var _gun_source: Node3D
## 0 = shoulder camera, 1 = orbit camera.
var _orbit_blend := 0.0
var _orbit_pivot := Vector3.ZERO
var _orbit_was_on := false
var _nudging := false


func _ready() -> void:
	process_priority = 90  # after the player moved; before EcoBody (100)
	player = get_parent() as CharacterBody3D
	_head = player.get_node("Head")
	_camera = player.get_node("Head/Camera3D")
	_eco_body = player.get_node_or_null("EcoBody")
	_fp_fov = player.base_fov
	set_third_person.call_deferred(prefer_third_person)


func _input(event: InputEvent) -> void:
	# The orbit takes the mouse before the player would turn her with it.
	if orbiting and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = player.get("mouse_sensitivity")
		orbit_yaw = wrapf(orbit_yaw - event.relative.x * sens, -PI, PI)
		orbit_pitch = clampf(orbit_pitch - event.relative.y * sens,
			deg_to_rad(orbit_pitch_min), deg_to_rad(orbit_pitch_max))
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_view") and not event.is_echo():
		prefer_third_person = not third_person
		set_third_person(prefer_third_person)
	elif event.is_action_pressed("swap_shoulder") and not event.is_echo():
		swap_shoulder()


## Moves the shoulder camera to her other shoulder (the swap_shoulder key). It
## stays there until a wallrun or a wall in the way moves it again.
func swap_shoulder() -> bool:
	if not third_person or orbiting or not shoulder_swap_key:
		return false
	side = -side
	_swap_cooldown = 0.8
	return true


## Shoulder distance in metres: the setting, else the tuned default.
func shoulder_distance() -> float:
	return clampf(distance_setting, DISTANCE_MIN, DISTANCE_MAX) if distance_setting > 0.0 else distance


## The setting relative to the tuned default; the orbit and resting distances follow it.
func _distance_scale() -> float:
	return shoulder_distance() / distance


func _nudge_input() -> Vector2:
	return Vector2(Input.get_axis("cam_nudge_left", "cam_nudge_right"), Input.get_axis("cam_nudge_down", "cam_nudge_up"))


## Arrow keys held while orbiting slide the camera (hub_nudge).
func _update_nudge(delta: float) -> void:
	if not hub_nudge_keys or not InputMap.has_action("cam_nudge_up"):
		return
	var dir := _nudge_input()  # menus and bench screens pause the hub, so no clash
	if dir == Vector2.ZERO:
		if _nudging:
			_nudging = false
			_save_nudge()
		return
	_nudging = true
	hub_nudge = Vector2(clampf(hub_nudge.x + dir.x * nudge_speed * delta, -NUDGE_X, NUDGE_X),
		clampf(hub_nudge.y + dir.y * nudge_speed * delta, NUDGE_DOWN, NUDGE_UP))


## Remembers where the nudge was left (settings.cfg).
func _save_nudge() -> void:
	var prefs = load("res://scripts/game/prefs.gd")
	prefs.set_value("game", "hub_nudge_x", hub_nudge.x)
	prefs.set_value("game", "hub_nudge_y", hub_nudge.y)
	prefs.save()


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
		_set_orbit(false)
		_orbit_blend = 0.0
		_camera.position = Vector3.ZERO
		_camera.rotation = Vector3.ZERO


## Starts or ends the orbit. Leaving it, she turns to where the camera looks,
## so the shoulder camera picks up the same view.
func _set_orbit(on: bool) -> void:
	if on == orbiting:
		return
	orbiting = on
	if on:
		orbit_yaw = player.rotation.y
		orbit_pitch = clampf(_head.rotation.x, deg_to_rad(orbit_pitch_min), deg_to_rad(orbit_pitch_max))
		_orbit_pivot = player.global_position + Vector3.UP * orbit_height
		_head.rotation.x = 0.0
		player.set("move_yaw", orbit_yaw)
	else:
		player.set("move_yaw", NAN)
		player.rotation.y = orbit_yaw
		_head.rotation.x = clampf(orbit_pitch, -1.55, 1.55)


## Where tracers and the grapple rope start in third person: her pistol.
func muzzle_position() -> Vector3:
	if _gun_muzzle != null and is_instance_valid(_gun_muzzle):
		return _gun_muzzle.global_position
	return _head.global_position + _head.global_basis * Vector3(0.25, -0.35, -0.4)


func _process(delta: float) -> void:
	if not third_person:
		return
	_set_orbit(player.get("strolling") == true)
	_attach_gun()  # follows a gun change at the bench
	if orbiting:
		player.set("move_yaw", orbit_yaw)
		_update_nudge(delta)
	_orbit_blend = move_toward(_orbit_blend, 1.0 if orbiting else 0.0, orbit_blend_rate * delta)
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
	# resting (player.gd resting) the camera centres on her and stands back a little
	var rest: bool = player.get("resting") == true
	var offset := Vector3(0.0 if rest else _side_x * shoulder, height, (rest_distance * _distance_scale() if rest else shoulder_distance()) + speed_pullback * speed_t)
	var want := _anchor + _head.global_basis * offset
	# Pull in front of anything between her and the camera.
	var pivot := target + _head.global_basis * Vector3(_side_x * shoulder * 0.5, height * 0.5, 0.0)
	var hit := _ray(pivot, want)
	if not hit.is_empty():
		var dir := (want - pivot).normalized()
		var d := maxf(pivot.distance_to(hit.position) - wall_margin, 0.05)
		want = pivot + dir * d
	_camera.position = _head.global_transform.affine_inverse() * want
	if _orbit_blend > 0.0:
		_blend_orbit(want, delta)
	elif _orbit_was_on:
		_camera.rotation = Vector3.ZERO  # hand the rotation back to the head
	_orbit_was_on = _orbit_blend > 0.0


## Places the camera on its orbit round her, blended with the shoulder view.
func _blend_orbit(shoulder_at: Vector3, delta: float) -> void:
	var look := Basis.from_euler(Vector3(orbit_pitch, orbit_yaw, 0.0))
	# the nudge slides the point it circles: up, and sideways across the view
	var nudge := hub_nudge if hub_nudge_keys else Vector2.ZERO
	var target := _orbit_centre() + Vector3.UP * (orbit_height + nudge.y) \
		+ Basis(Vector3.UP, orbit_yaw) * Vector3(nudge.x, 0.0, 0.0)
	var a := 1.0 - exp(-follow_rate * delta)
	_orbit_pivot = _orbit_pivot.lerp(target, a)
	if _orbit_pivot.distance_to(target) > max_lag:
		_orbit_pivot = target + (_orbit_pivot - target).normalized() * max_lag
	var at := _orbit_pivot + look * Vector3(0.0, 0.0, orbit_distance * _distance_scale())
	var hit := _ray(target, at)
	if not hit.is_empty():
		var dir := (at - target).normalized()
		at = target + dir * maxf(target.distance_to(hit.position) - wall_margin, 0.05)
	# ease in and out of the swap
	var t := smoothstep(0.0, 1.0, _orbit_blend)
	var shoulder_basis := _head.global_basis.orthonormalized()
	var basis := Basis(shoulder_basis.get_rotation_quaternion().slerp(look.get_rotation_quaternion(), t))
	_camera.global_transform = Transform3D(basis, shoulder_at.lerp(at, t))


## Where the orbit circles: her feet, or the seat she has settled on while
## resting (her model leaves the player for it, eco_fp_body.gd rest()).
func _orbit_centre() -> Vector3:
	if player.get("resting") == true:
		var model = player.get_node_or_null("EcoBody")
		var shadow: Node3D = model.get("shadow") if model != null else null
		if shadow != null and shadow.top_level:
			return shadow.global_position
	return player.global_position


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


## A copy of the equipped gun in her right hand while in third person (the
## gun stance, scripts/ps2/eco_gun_stance.gd, seats it in her palm and aims it).
func _attach_gun() -> void:
	if not third_person:
		if _gun != null and is_instance_valid(_gun):
			_gun.get_parent().queue_free()
		_gun = null
		_gun_muzzle = null
		_gun_source = null
		return
	var weapon := _camera.get_node_or_null("Weapon")
	var source: Node3D = weapon.get("_pistol") if weapon != null else null
	if _gun != null and is_instance_valid(_gun) and source == _gun_source:
		return
	if _gun != null and is_instance_valid(_gun):
		_gun.get_parent().free()
	var model: Node = _eco_body.get("shadow") if _eco_body != null else null
	var sk: Skeleton3D = model.get("skeleton") if model != null else null
	if sk == null or sk.find_bone("J_Bip_R_Hand") < 0:
		return
	var hold := BoneAttachment3D.new()
	hold.name = "GunHold"
	hold.bone_name = "J_Bip_R_Hand"
	sk.add_child(hold)
	if source != null and is_instance_valid(source):
		_gun = source.duplicate() as Node3D
		# the first-person arm (eco_fp_arms.gd) rides on the view-model gun; the
		# copy doesn't keep its name, so find it by its script
		for child in _gun.get_children():
			if child.get_script() == EcoArms or child.name == "Arm":
				child.free()
	else:
		_gun = GUN.instantiate()
	_gun_source = source
	_gun.transform = Transform3D()
	hold.add_child(_gun)
	for mi in _gun.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_gun_muzzle = _gun.find_child("Muzzle", true, false) as Node3D
	var stance = _eco_body.get("stance")
	if stance != null:
		stance.gun = _gun
