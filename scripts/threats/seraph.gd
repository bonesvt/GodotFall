extends "res://scripts/threats/choir_unit.gd"
## SERAPH: the Choir's floating spotter, a porcelain mask with one great eye,
## gold rings and trailing ribbons. It drifts on a slow circle over its post
## and watches with a wide cone. When the eye locks on Eco it sings: every
## Choir unit in earshot is alerted and, for as long as it keeps her in
## sight, knows exactly where she is. It never attacks. It's fragile, and a
## shot to the eye drops it.

## Choir units this close hear the song.
@export var song_range := 45.0
## Circle it drifts round its post on, and how high over the post it floats.
@export var drift_radius := 4.0
@export var hover_height := 0.0
## Stays at least this far from the pilot while singing.
@export var keep_away := 14.0

const EYE_HEIGHT := 1.6  # the eye sits here over the node's origin (grunt.gd EYE)

var _drift := 0.0
var _sing_t := 0.0


func _init() -> void:
	model_name = "seraph"
	gait = "hover"
	body_radius = 0.45
	body_height = 0.9
	head_y = -1.0  # see is_headshot
	max_health = 18.0
	move_speed = 3.0
	sight_range = 42.0
	view_cone = 75.0
	notice_rate_far = 0.3
	notice_rate_near = 3.0
	gravity = 0.0
	callout_range = 0.0  # the song does the calling


func _build_body() -> void:
	super()
	var sphere := SphereShape3D.new()
	sphere.radius = body_radius
	var col := get_child(0) as CollisionShape3D
	col.shape = sphere
	col.position.y = EYE_HEIGHT
	model.position.y = EYE_HEIGHT
	indicator.position.y = EYE_HEIGHT + 0.9


func _ready() -> void:
	super()
	_drift = rng.randf() * TAU


func is_headshot(pos: Vector3) -> bool:
	return pos.distance_to(global_position + Vector3.UP * EYE_HEIGHT - global_basis.z * 0.1) < 0.2


func _tell() -> float:
	if alerted:
		return 0.6 + 0.4 * sin(_sing_t * 9.0)
	return detection * 0.5


func _physics_process(delta: float) -> void:
	if dead:
		return
	if is_nan(home_yaw):
		home_yaw = rotation.y
	var goal := post + Vector3.UP * hover_height
	if not passive and target != null:
		_update_sight(delta)
		if alerted:
			since_seen = 0.0 if has_sight else since_seen + delta
			if since_seen > lose_track_time:
				lose_track()
		if alerted:
			_sing(delta)
			var to := target.global_position - global_position
			to.y = 0.0
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-6.0 * delta))
			if to.length() < keep_away:
				goal = global_position - to.normalized() * 3.0
				goal.y = post.y + hover_height
		else:
			_unaware_look(delta)
	if not alerted:
		_drift += delta * 0.25
		goal += Vector3(cos(_drift), 0.0, sin(_drift)) * drift_radius
	var d := goal - global_position
	velocity = velocity.move_toward(d.limit_length(1.0) * move_speed, 6.0 * delta)
	move_and_slide()


## While it can see her, every Choir unit in earshot knows where she is.
func _sing(delta: float) -> void:
	_sing_t += delta
	if not has_sight:
		return
	for c in get_tree().get_nodes_in_group("choir"):
		if c == self or c.dead or c.global_position.distance_to(global_position) > song_range:
			continue
		if c.target == null:
			c.target = target
		if not c.alerted:
			c.alert(false)
		c.last_known = target.global_position
		c.since_seen = 0.0


func alert(callout := true) -> void:
	var was := alerted
	super(callout)
	if alerted and not was:
		_sing_t = 0.0
		SFX.play_at(get_parent(), global_position + Vector3.UP * EYE_HEIGHT, "seraph_song", 0.0, SFX.vary(0.04))


## It never shoots.
func _combat(_delta: float) -> void:
	pass


func _die() -> void:
	super()
	# Drops out of the air instead of tipping over where it hung.
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", post.y, 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
