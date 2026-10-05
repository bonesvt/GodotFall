extends Node
## Third person combat feel presets (child "TpFeel" of scenes/player.tscn).
## F7 cycles them while playing, to try them side by side; the pick is kept in
## user://settings.cfg ([game] tp_feel). Each preset sets:
## - the shoulder camera's follow (scripts/view_camera.gd exports), plus what
##   this node layers on top of it: a heavier kick per shot, a "focus" that
##   pulls the camera in and narrows the view while you're shooting, a lead
##   toward the side you strafe to with a little roll, a dip on landings and
##   a shake when she's hit;
## - her body (scripts/ps2/eco_combat_moves.gd): legs that run where she goes
##   while her chest stays on the aim, backpedalling, turning on the spot,
##   sideways leans, shoulders rocked by each shot and flinches;
## - her gun (scripts/ps2/eco_gun_stance.gd): kept up on the move or dropped to
##   low ready, and how fast it comes up;
## - how quickly one animation blends into the next (eco_model.gd).
## "current" is the game as it was before any of this.

const Prefs := preload("res://scripts/game/prefs.gd")
const HUD := preload("res://scripts/hud.gd")

const ORDER := ["current", "fluid", "snappy"]
const PRESETS := {
	"current": {
		"label": "Current",
		"follow_rate": 30.0, "follow_rate_y": 18.0, "max_lag": 0.12, "speed_pullback": 0.0,
		"kick": 1.0, "focus": 0.0, "lead": 0.0, "roll": 0.0, "land_dip": 0.0, "shake": 0.0,
		"leg_twist": 0.0, "turn_in_place": 0.0, "strafe_lean": 0.0, "shot_rock": 0.0, "flinch": 0.0,
		"aim_while_moving": false, "raise_rate": 14.0, "lower_rate": 6.0, "anim_blend": 0.25,
	},
	# smooth and weighty: the camera floats a little behind her, she turns on
	# her feet and leans into every change, the gun drops while she runs
	"fluid": {
		"label": "Fluid (smooth, weighty)",
		"follow_rate": 12.0, "follow_rate_y": 9.0, "max_lag": 0.35, "speed_pullback": 0.5,
		"kick": 1.3, "focus": 0.6, "lead": 0.12, "roll": 1.5, "land_dip": 0.12, "shake": 0.6,
		"leg_twist": 1.0, "turn_in_place": 60.0, "strafe_lean": 0.45, "shot_rock": 4.0, "flinch": 9.0,
		"aim_while_moving": false, "raise_rate": 10.0, "lower_rate": 4.0, "anim_blend": 0.3,
	},
	# fast and arcade: the camera is locked on, the gun never leaves the aim,
	# everything snaps, shots hit hard
	"snappy": {
		"label": "Snappy (fast, arcade)",
		"follow_rate": 45.0, "follow_rate_y": 30.0, "max_lag": 0.08, "speed_pullback": 0.2,
		"kick": 1.7, "focus": 1.0, "lead": 0.05, "roll": 0.0, "land_dip": 0.06, "shake": 1.0,
		"leg_twist": 1.0, "turn_in_place": 0.0, "strafe_lean": 0.3, "shot_rock": 7.0, "flinch": 6.0,
		"aim_while_moving": true, "raise_rate": 26.0, "lower_rate": 8.0, "anim_blend": 0.14,
	},
}

## The preset in use (a key of PRESETS).
var preset := "fluid"
## 0..1: how far the shooting focus is in.
var focus := 0.0

var player: CharacterBody3D
var _view: Node
var _camera: Camera3D
var _weapon: Node
var _eco_body: Node
var _p: Dictionary = PRESETS["current"]
var _was_air := false
var _air_vy := 0.0
var _dip := 0.0
var _dip_vel := 0.0
var _shake := 0.0
var _lead := 0.0
var _roll := 0.0
var _fov_touched := false
var _back := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_priority = 95  # after ViewCam (90) placed the camera
	process_physics_priority = 10  # after the player set the camera roll
	player = get_parent() as CharacterBody3D
	_view = player.get_node_or_null("ViewCam")
	_camera = player.get_node_or_null("Head/Camera3D")
	_weapon = player.get_node_or_null("Head/Camera3D/Weapon")
	_eco_body = player.get_node_or_null("EcoBody")
	if player.has_signal("damaged"):
		player.damaged.connect(func(amount: float, _from: Vector3) -> void:
			_shake = minf(_shake + clampf(amount / 25.0, 0.3, 1.0), 1.0))
	var saved = Prefs.cfg().get_value("game", "tp_feel", "fluid")
	apply_preset.call_deferred(saved if PRESETS.has(saved) else "fluid")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F7:
		var next: String = ORDER[(ORDER.find(preset) + 1) % ORDER.size()]
		apply_preset(next)
		Prefs.cfg().set_value("game", "tp_feel", next)
		Prefs.save()
		_flash("Third person feel: %s" % PRESETS[next]["label"])


## Puts a preset (a key of PRESETS) into effect.
func apply_preset(name_: String) -> void:
	if not PRESETS.has(name_):
		return
	preset = name_
	_p = PRESETS[name_]
	if _view != null:
		for k in ["follow_rate", "follow_rate_y", "max_lag", "speed_pullback"]:
			_view.set(k, _p[k])
	if _eco_body == null:
		return
	var moves = _eco_body.get("moves")
	if moves != null:
		for k in ["leg_twist", "turn_in_place", "strafe_lean", "shot_rock", "flinch"]:
			moves.set(k, _p[k])
	var stance = _eco_body.get("stance")
	if stance != null:
		for k in ["aim_while_moving", "raise_rate", "lower_rate"]:
			stance.set(k, _p[k])
	var shadow = _eco_body.get("shadow")
	if shadow != null:
		shadow.set("anim_blend", _p["anim_blend"])


func _on_shoulder() -> bool:
	return player.get("third_person") == true and _view != null and _view.get("orbiting") != true \
		and player.get("resting") != true


func _process(delta: float) -> void:
	if _camera == null or delta <= 0.0:
		return
	var since: float = _weapon.get("since_shot") if _weapon != null else INF
	var shooting := since < 1.2
	focus = move_toward(focus, 1.0 if shooting else 0.0, delta * (6.0 if shooting else 1.6))
	_landing(delta)
	_shake = move_toward(_shake, 0.0, delta * 2.5)
	if not _on_shoulder():
		return
	# camera kick on top of the weapon's own punch (weapon.gd sets it each frame)
	var punch: Vector2 = _weapon.get("_punch") if _weapon != null else Vector2.ZERO
	var extra: float = _p["kick"] - 1.0
	var rot := Vector3(punch.x * extra, punch.y * extra, 0.0)
	if _shake > 0.0 and _p["shake"] > 0.0:
		var s: float = _shake * _shake * _p["shake"] * deg_to_rad(1.6)
		rot += Vector3(_rng.randf_range(-s, s), _rng.randf_range(-s, s), 0.0)
	_camera.rotation.x += rot.x
	_camera.rotation.y += rot.y

	# focus in while shooting, lead toward where she strafes, dip on landing
	var side: float = _view.get("_side_x") if _view.get("_side_x") != null else 1.0
	var lat := player.velocity.dot(player.global_basis.x)
	_lead = lerpf(_lead, clampf(lat / 7.0, -1.0, 1.0), 1.0 - exp(-4.0 * delta))
	# coming back toward the camera: no pull-in, and the camera's trail
	# (view_camera.gd follow lag) doesn't let her crowd the lens
	var head := _camera.get_parent() as Node3D
	var back_dir := head.global_basis.z
	back_dir.y = 0.0
	back_dir = back_dir.normalized()
	var back := clampf(player.velocity.dot(back_dir) / 5.0, 0.0, 1.0)
	_back = lerpf(_back, back, 1.0 - exp(-6.0 * delta))
	var f := smoothstep(0.0, 1.0, focus) * float(_p["focus"]) * (1.0 - _back)
	var anchor: Vector3 = _view.get("_anchor")
	var trail := maxf(-(anchor - head.global_position).dot(back_dir), 0.0)
	var offset := Vector3(side * 0.12 * f + _lead * float(_p["lead"]), -0.04 * f - _dip, -0.45 * f)
	_camera.position += offset
	if trail > 0.005:
		# step back by the trail, unless that would put it in a wall
		var from := _camera.global_position
		var to := from + back_dir * (trail + 0.2)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = [player.get_rid()]
		if player.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			_camera.global_position = from + back_dir * trail


func _physics_process(delta: float) -> void:
	if _camera == null:
		return
	var on := _on_shoulder()
	# roll into strafes (the player set the camera's roll this tick)
	var lat := player.velocity.dot(player.global_basis.x) if on else 0.0
	_roll = lerpf(_roll, -clampf(lat / 7.0, -1.0, 1.0) * deg_to_rad(float(_p["roll"])), 1.0 - exp(-5.0 * delta))
	if on:
		_camera.rotation.z += _roll
		# the shooting focus narrows the view (the player eases fov to base_fov)
		var tp_fov: float = _view.get("tp_fov")
		player.base_fov = tp_fov - 7.0 * smoothstep(0.0, 1.0, focus) * float(_p["focus"])
		_fov_touched = true
	elif _fov_touched and player.get("third_person") == true:
		player.base_fov = _view.get("tp_fov")
		_fov_touched = false


## A dip on landing that springs back, deeper the harder she came down.
func _landing(delta: float) -> void:
	var air := not player.is_on_floor()
	if air:
		_air_vy = player.velocity.y
	elif _was_air and _air_vy < -6.0:
		_dip_vel += clampf(-_air_vy / 20.0, 0.0, 1.0) * float(_p["land_dip"]) * 14.0
	_was_air = air
	_dip_vel += (-_dip * 220.0 - _dip_vel * 18.0) * delta
	_dip += _dip_vel * delta
	_dip = clampf(_dip, -0.3, 0.3)


func _flash(text: String) -> void:
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.get_script() == HUD:
			n.flash_message(text, 2.0)
			return
