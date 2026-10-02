extends Node3D
## Eco's stiletto (Z or the mouse thumb button). A tap is a quick strike from
## her left hand. Holding the key draws it with a flip-spin and keeps it out
## with the pistol lowered, and she runs faster; left mouse swings while it's
## out (alternating slashes, with a light trail off the tip), and I plays an
## inspect flourish. On a grunt that hasn't noticed her the strike becomes a
## thrust and a silent takedown that kills outright; on anyone else it's a
## solid hit that alerts them. Model: assets/models/knife/stiletto.glb
## (tools/knife/build_stiletto.py).

const FX := preload("res://scripts/fx.gd")
const SFX := preload("res://scripts/sfx.gd")
const MODEL := preload("res://assets/models/knife/stiletto.glb")
const MATERIALS := "res://assets/materials/knife/"

## Emitted on every stab: "miss", "hit", "kill" or "takedown".
signal stabbed(kind: String)

## Damage to an enemy that already knows she's there.
@export var damage := 30.0
## How far in front of the camera the blade reaches, in metres.
@export var reach := 2.4
## Targets within this many degrees of the crosshair can be stabbed.
@export var reach_angle := 40.0
## Seconds from the button to the blade landing, and for the whole stab.
@export var hit_time := 0.09
@export var stab_time := 0.42
@export var cooldown := 0.55
## Hold the key this long and the knife stays out.
@export var hold_time := 0.22
## Ground speed multiplier while the knife is out.
@export var ready_speed := 1.2

var player: CharacterBody3D
var weapon: Node
var stab_timer := -1.0
var cooldown_timer := 0.0
var takedowns := 0
## True while the key is held and the knife stays out.
var readied := false
var _held := 0.0
var _long_hold := false  # this press already brought the knife out
var _ready_blend := 0.0
var _struck := false
var _blade_root: Node3D  # Eco's hand: pose follows the animation
var _blade: Node3D  # the stiletto in her fingers: spins and tosses on its own
var _tip: Node3D
var _last_tip := Vector3.ZERO
var _trail_on := false
## Current knife animation: "", "draw", "thrust", "slash_a", "slash_b", "inspect".
var anim := ""
var anim_time := 0.0
var _next_slash := "slash_a"
var _glint_done := false
var _inspect_line := -1
var rng := RandomNumberGenerator.new()

const DRAW_TIME := 0.5
const INSPECT_TIME := 2.6
const INSPECT_LINES := [
	"Wound the spring from a titan's servo myself.",
	"Cobalt edge. Sharpens itself on their armour.",
	"Dad said never bring a knife to a gunfight. I bring both.",
	"Balanced it twelve times. Thirteen's the charm.",
]

# Viewmodel poses, relative to the camera: tucked out of sight, then thrust.
const REST := Vector3(-0.34, -0.46, -0.12)
const THRUST := Vector3(-0.14, -0.17, -0.4)
const REST_ROT := Vector3(0.9, 0.5, 0.6)
const THRUST_ROT := Vector3(0.12, -0.55, -0.35)
# Held out, low and to the left, point forward, ready to strike.
const READY := Vector3(-0.2, -0.24, -0.34)
const READY_ROT := Vector3(0.3, -0.75, -0.7)


func _ready() -> void:
	var n: Node = get_parent()
	while n != null and not (n is CharacterBody3D):
		n = n.get_parent()
	player = n
	weapon = get_parent().get_node_or_null("Weapon")
	_build_blade()


func _physics_process(delta: float) -> void:
	cooldown_timer -= delta
	_held = _held + delta if Input.is_action_pressed("melee") else 0.0
	_set_readied(_held >= hold_time)
	if weapon != null:
		weapon.holstered = readied or stab_timer >= 0.0 or anim == "inspect"
	if stab_timer < 0.0:
		return
	stab_timer += delta
	if not _struck and stab_timer >= hit_time:
		_struck = true
		_strike()
	if stab_timer >= stab_time:
		stab_timer = -1.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("melee", false, true):
		_long_hold = false
	elif event.is_action_released("melee", true):
		# A tap stabs on release; holding past hold_time keeps the knife out instead.
		if not _long_hold and not readied:
			stab()
		_long_hold = false
	elif readied and event.is_action_pressed("fire", false, true):
		stab()
	elif readied and event.is_action_pressed("inspect", false, true) and anim == "":
		inspect()


func _set_readied(on: bool) -> void:
	if on == readied:
		return
	readied = on
	if on:
		_long_hold = true
	player.speed_mult = ready_speed if on else 1.0
	if on and stab_timer < 0.0:
		_play("draw")
		SFX.play(self, "knife_draw", -6.0, SFX.vary(0.04))
	elif not on and anim == "inspect":
		_play("")


func _process(delta: float) -> void:
	_ready_blend = move_toward(_ready_blend, 1.0 if readied else 0.0, delta * 6.0)
	var r := smoothstep(0.0, 1.0, _ready_blend)
	var base := REST.lerp(READY, r)
	var base_rot := REST_ROT.lerp(READY_ROT, r)
	if readied and anim == "":
		# A little run bob so it reads as held, not floating.
		var bob := sin(Time.get_ticks_msec() * 0.012) * 0.006 * clampf(player.horizontal_speed() / 10.0, 0.0, 1.0)
		base += Vector3(0.0, bob, 0.0)

	var hand := [base, base_rot]
	var blade := [Vector3.ZERO, Vector3.ZERO]
	if anim != "":
		anim_time += delta
		var length := _anim_length(anim)
		if anim_time >= length:
			_play("")
		else:
			var keys := _hand_keys(anim, base, base_rot)
			hand = _sample(keys, anim_time)
			var bkeys := _blade_keys(anim)
			if not bkeys.is_empty():
				blade = _sample(bkeys, anim_time)
			_anim_events()
	_blade_root.visible = anim != "" or _ready_blend > 0.01
	_blade_root.position = hand[0]
	_blade_root.rotation = hand[1]
	_blade.position = blade[0]
	_blade.rotation = blade[1]
	_update_trail()


## Starts a knife animation ("" stops it).
func _play(name: String) -> void:
	anim = name
	anim_time = 0.0
	_glint_done = false
	_trail_on = false


func _anim_length(name: String) -> float:
	match name:
		"draw":
			return DRAW_TIME
		"inspect":
			return INSPECT_TIME
	return stab_time


## Hand keyframes [time, position, rotation] for an animation; ends on `base`.
func _hand_keys(name: String, base: Vector3, base_rot: Vector3) -> Array:
	match name:
		"draw":
			# Snaps up from the hip, overshoots, settles into the guard.
			return [
				[0.0, REST, REST_ROT],
				[0.2, READY + Vector3(0.03, 0.07, -0.02), READY_ROT + Vector3(-0.35, 0.2, 0.3)],
				[0.38, READY + Vector3(0.0, -0.01, 0.0), READY_ROT + Vector3(0.08, 0.0, -0.05)],
				[DRAW_TIME, base, base_rot],
			]
		"thrust":
			return [
				[0.0, base, base_rot],
				[hit_time, THRUST, THRUST_ROT],
				[hit_time + 0.08, THRUST + Vector3(0, 0, -0.02), THRUST_ROT],
				[stab_time, base, base_rot],
			]
		"slash_a":
			# Backhand from her left across to the right, edge flat.
			return [
				[0.0, Vector3(-0.32, -0.12, -0.28), Vector3(0.2, 1.0, -1.5)],
				[hit_time, Vector3(-0.06, -0.15, -0.42), Vector3(0.05, -0.15, -1.55)],
				[hit_time + 0.08, Vector3(0.16, -0.22, -0.3), Vector3(-0.15, -1.35, -1.6)],
				[stab_time, base, base_rot],
			]
		"slash_b":
			# Forehand back: high right down to low left.
			return [
				[0.0, Vector3(0.1, -0.03, -0.32), Vector3(0.6, -1.1, -2.3)],
				[hit_time, Vector3(-0.08, -0.15, -0.42), Vector3(0.05, -0.1, -2.0)],
				[hit_time + 0.08, Vector3(-0.32, -0.3, -0.26), Vector3(-0.45, 0.95, -1.9)],
				[stab_time, base, base_rot],
			]
		"inspect":
			var show := Vector3(-0.08, -0.12, -0.32)
			var show_rot := Vector3(0.1, -0.2, -1.45)  # blade across the view, edge up
			return [
				[0.0, base, base_rot],
				[0.35, show, show_rot],
				[0.75, show + Vector3(0.01, 0.005, 0.0), show_rot + Vector3(0.0, 0.08, 0.0)],
				[0.9, READY + Vector3(0.02, 0.02, 0.0), READY_ROT],
				[1.55, READY + Vector3(0.02, 0.0, 0.0), READY_ROT],
				[1.7, READY + Vector3(0.0, -0.05, 0.0), READY_ROT + Vector3(0.2, 0.0, 0.0)],
				[2.05, READY + Vector3(0.0, 0.0, 0.0), READY_ROT],
				[2.2, READY + Vector3(0.02, 0.01, -0.03), READY_ROT + Vector3(-0.15, -0.1, 0.0)],
				[INSPECT_TIME, base, base_rot],
			]
	return [[0.0, base, base_rot]]


## Blade keyframes [time, offset, rotation] relative to her hand (spins, tosses).
func _blade_keys(name: String) -> Array:
	match name:
		"draw":
			# One and a half end-over-end flips round her fingers as it comes up.
			return [
				[0.0, Vector3.ZERO, Vector3(-TAU * 1.5, 0, 0)],
				[0.36, Vector3.ZERO, Vector3(0.12, 0, 0)],
				[DRAW_TIME, Vector3.ZERO, Vector3.ZERO],
			]
		"inspect":
			return [
				[0.0, Vector3.ZERO, Vector3.ZERO],
				[0.85, Vector3.ZERO, Vector3.ZERO],
				# fingers spin it twice round the grip
				[1.5, Vector3.ZERO, Vector3(-TAU * 2.0, 0, 0)],
				[1.55, Vector3.ZERO, Vector3(-TAU * 2.0, 0, 0)],
				# toss it up, it flips once, catch
				[1.8, Vector3(0, 0.16, -0.02), Vector3(-TAU * 2.5, 0, 0)],
				[2.05, Vector3.ZERO, Vector3(-TAU * 3.0, 0, 0)],
				[INSPECT_TIME, Vector3.ZERO, Vector3(-TAU * 3.0, 0, 0)],
			]
	return []


## Smooth interpolation through [time, pos, rot] keys.
func _sample(keys: Array, t: float) -> Array:
	if t <= keys[0][0]:
		return [keys[0][1], keys[0][2]]
	for i in range(1, keys.size()):
		if t <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var k := smoothstep(0.0, 1.0, (t - a[0]) / maxf(b[0] - a[0], 0.0001))
			return [(a[1] as Vector3).lerp(b[1], k), (a[2] as Vector3).lerp(b[2], k)]
	var last: Array = keys[keys.size() - 1]
	return [last[1], last[2]]


## Sounds and sparkle timed to the animations.
func _anim_events() -> void:
	match anim:
		"draw":
			if not _glint_done and anim_time >= 0.36:
				_glint_done = true
				FX.star(_tip, _tip.global_position, Color(0.75, 0.95, 1.0, 0.95), 0.07, 0.12, 4)
		"slash_a", "slash_b", "thrust":
			_trail_on = anim_time > 0.02 and anim_time < hit_time + 0.1
		"inspect":
			if not _glint_done and anim_time >= 0.4:
				_glint_done = true
				SFX.play(self, "flourish", -8.0)
				_edge_glint()
			if anim_time >= 0.85 and anim_time - get_process_delta_time() < 0.85:
				SFX.play(self, "knife_spin", -6.0)
			if anim_time >= 1.55 and anim_time - get_process_delta_time() < 1.55:
				SFX.play(self, "knife_swish", -9.0, 1.3)
			if anim_time >= 2.05 and anim_time - get_process_delta_time() < 2.05:
				SFX.play(self, "knife_catch", -4.0)
				FX.star(_tip, _tip.global_position, Color(0.75, 0.95, 1.0, 0.9), 0.05, 0.1, 4)


## A glint that runs from the guard to the point.
func _edge_glint() -> void:
	var tw := create_tween()
	var star := FX.star(_blade, _blade.global_position, Color(0.85, 0.97, 1.0, 1.0), 0.05, 0.4, 4)
	star.position = Vector3(0, 0.004, -0.06)
	tw.tween_property(star, "position", Vector3(0, 0.002, -0.24), 0.32).set_trans(Tween.TRANS_SINE)


## Light trail behind the tip while a swing is moving.
func _update_trail() -> void:
	var tip := _tip.global_position
	if _trail_on and _blade_root.visible:
		FX.tracer(player.get_parent(), _last_tip, tip, Color(0.6, 0.95, 1.0, 0.7), 0.012, 0.09)
	_last_tip = tip


func is_inspecting() -> bool:
	return anim == "inspect"


## Knife inspect: shows off the edge, spins it, tosses it and catches it.
func inspect() -> void:
	_play("inspect")
	var pick := rng.randi_range(0, INSPECT_LINES.size() - 2)
	if pick >= _inspect_line:
		pick += 1
	_inspect_line = pick
	if weapon != null and weapon.has_signal("inspected"):
		weapon.inspected.emit(INSPECT_LINES[pick])


func is_stabbing() -> bool:
	return stab_timer >= 0.0


## Starts a stab if the knife is ready. Returns false while on cooldown.
func stab() -> bool:
	if cooldown_timer > 0.0 or stab_timer >= 0.0:
		return false
	stab_timer = 0.0
	cooldown_timer = cooldown
	_struck = false
	# Unaware target in reach: a thrust (the takedown). Otherwise alternate slashes.
	var t := find_target()
	if t != null and t.has_method("is_unaware") and t.is_unaware():
		_play("thrust")
	else:
		_play(_next_slash)
		_next_slash = "slash_b" if _next_slash == "slash_a" else "slash_a"
	_last_tip = _tip.global_position
	SFX.play(self, "knife_swish", -4.0, SFX.vary(0.06))
	if weapon != null:
		# The pistol hand swings aside and can't fire mid-stab.
		weapon.holstered = true
		if weapon.has_method("stop_inspect"):
			weapon.stop_inspect()
	return true


## The enemy the blade would hit right now, or null.
func find_target() -> Node3D:
	var cam: Camera3D = player.camera
	var from := cam.global_position
	var fwd: Vector3 = -player.head.global_basis.z
	var best: Node3D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.has_method("take_damage") or ("dead" in e and e.dead):
			continue
		var chest: Vector3 = e.global_position + Vector3.UP * 1.1
		var to := chest - from
		# Measure to the body's surface, not its centre.
		var d := maxf(to.length() - 0.35, 0.0)
		if d > reach or d >= best_d:
			continue
		if to.length() > 0.5 and rad_to_deg(fwd.angle_to(to)) > reach_angle:
			continue
		var query := PhysicsRayQueryParameters3D.create(from, chest)
		query.exclude = [player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider != e:
			continue  # something solid in the way
		best = e
		best_d = d
	return best


func _strike() -> void:
	var target := find_target()
	if target == null:
		stabbed.emit("miss")
		return
	var at: Vector3 = target.global_position + Vector3.UP * 1.2
	var fx_parent: Node = player.get_parent()
	var takedown: bool = target.has_method("is_unaware") and target.is_unaware()
	var killed: bool
	if takedown:
		killed = target.take_damage(target.health * 10.0 + 1000.0, at, false)
	else:
		killed = target.take_damage(damage, at, false)
	var kind := "takedown" if takedown and killed else ("kill" if killed else "hit")
	if takedown and killed:
		takedowns += 1
	stabbed.emit(kind)
	if weapon != null:
		weapon.hit_confirmed.emit("kill" if killed else "body")
	SFX.play(self, "knife_hit", 0.0, SFX.vary(0.08))
	if killed:
		SFX.play(self, "kill", -2.0)
	var dir: Vector3 = (at - player.camera.global_position).normalized()
	FX.star(fx_parent, at - dir * 0.3, Color(1.0, 0.9, 0.6), 0.3 if killed else 0.18, 0.06, 6)
	FX.debris(fx_parent, at - dir * 0.3, -dir, Color(0.42, 0.45, 0.4), 4, 3.0, 0.03, 0.35)
	if takedown:
		# A silent kill: a cold glint instead of a bang.
		FX.shock_ring(fx_parent, at - dir * 0.3, dir, Color(0.6, 0.95, 1.0, 0.9), 0.08, 0.14)


func _build_blade() -> void:
	_blade_root = Node3D.new()
	_blade_root.position = REST
	_blade_root.visible = false
	add_child(_blade_root)
	_blade = Node3D.new()  # pivot at the grip, where her fingers hold it
	_blade_root.add_child(_blade)
	var blade: Node3D = MODEL.instantiate()
	blade.name = "Stiletto"
	blade.scale = Vector3.ONE * 1.3
	_blade.add_child(blade)
	_tip = Node3D.new()
	_tip.name = "Tip"
	_tip.position = Vector3(0, 0, -0.25 * 1.3)
	_blade.add_child(_tip)
	for mi in blade.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m != null and ResourceLoader.exists(MATERIALS + m.resource_name + ".tres"):
				(mi as MeshInstance3D).set_surface_override_material(i, load(MATERIALS + m.resource_name + ".tres"))
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Eco's left fist round the grip and her forearm running back off screen.
	var glove := StandardMaterial3D.new()
	glove.albedo_color = Color(0.32, 0.24, 0.18)
	glove.roughness = 0.8
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = Color(0.78, 0.78, 0.76)
	sleeve.roughness = 0.9
	var fist := BoxMesh.new()
	fist.size = Vector3(0.036, 0.046, 0.06)
	fist.material = glove
	_part(_blade_root, fist, Vector3(0.0, -0.004, 0.0), Vector3.ONE)
	var arm := CylinderMesh.new()
	arm.top_radius = 0.022
	arm.bottom_radius = 0.032
	arm.height = 0.4
	arm.radial_segments = 8
	arm.material = sleeve
	var forearm := _part(_blade_root, arm, Vector3(0.0, -0.012, 0.22), Vector3.ONE)
	forearm.rotation.x = PI / 2.0


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
