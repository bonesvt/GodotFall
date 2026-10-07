extends Node3D
## Eco's knife (Z or the mouse thumb button), in her left hand.
##   tap          a quick strike from the hip; the gun stays in her other hand
##   hold ~1 s    she draws the knife as her weapon: the gun goes away (can't
##                fire), she runs faster, left mouse attacks (two alternating
##                moves), I inspects
##   tap again, R or the mouse wheel (swap_weapon)   knife away, gun drawn back
## On a grunt that hasn't noticed her any strike becomes the takedown thrust,
## a silent kill; on anyone else it's a solid hit that alerts them. She carries
## the knife picked at the hub's knife case (armory.gd KNIVES; the run
## manager calls set_model()), and each has its own grip, draw, attacks,
## takedown and inspect (scripts/knife_moves.gd). Models:
## assets/models/knife/<id>.glb (tools/knife/build_knives.py).

const FX := preload("res://scripts/fx.gd")
const SFX := preload("res://scripts/sfx.gd")
const Moves := preload("res://scripts/knife_moves.gd")
const MODELS := {
	"needle": preload("res://assets/models/knife/needle.glb"),
	"kunai": preload("res://assets/models/knife/kunai.glb"),
	"butterfly": preload("res://assets/models/knife/butterfly.glb"),
}
const DEFAULT_MODEL := "needle"
const MATERIALS := "res://assets/materials/knife/"
## How much bigger than life the knife is drawn in her hand.
const VIEW_SCALE := 1.3
const REST := Moves.REST
const REST_ROT := Moves.REST_ROT

## Emitted on every stab: "miss", "hit", "kill" or "takedown".
signal stabbed(kind: String)
## Emitted when she draws the knife as her weapon (true) or puts it away (false).
signal switched(out: bool)

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
## Hold the key this long and she draws the knife as her weapon.
@export var hold_time := 1.0
## Ground speed multiplier while the knife is out.
@export var ready_speed := 1.2

var player: CharacterBody3D
var weapon: Node
var stab_timer := -1.0
var cooldown_timer := 0.0
var takedowns := 0
## True while the knife is her weapon (drawn with a long hold).
var out := false
var _held := 0.0
var _pressing := false  # the melee key is down (from a press we saw)
var _hold_used := false  # this press already drew the knife
var _ready_blend := 0.0
var _struck := false
var _blade_root: Node3D  # Eco's hand: pose follows the animation
var _blade: Node3D  # the knife in her fingers: spins and tosses on its own
var _grip: Node3D  # how this knife sits in her fist (the kunai: reverse grip)
var _tip: Node3D
## Which knife she carries (armory.gd KNIVES id) and its model in her hand.
var model_id := DEFAULT_MODEL
var model: Node3D
## This knife's moves (knife_moves.gd).
var moves: Dictionary = Moves.moves(DEFAULT_MODEL)
## The Butterfly's handles (null on the fixed blades) and their rest poses.
var _safe: Node3D
var _bite: Node3D
var _safe_rest := Basis.IDENTITY
var _bite_rest := Basis.IDENTITY
var _last_tip := Vector3.ZERO
var _trail_on := false
## Current knife animation: "", "draw", "thrust", "attack_a", "attack_b", "inspect".
var anim := ""
var anim_time := 0.0
var _next_attack := "attack_a"
var _events_done := 0
var _inspect_line := -1
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	var n: Node = get_parent()
	while n != null and not (n is CharacterBody3D):
		n = n.get_parent()
	player = n
	weapon = get_parent().get_node_or_null("Weapon")
	_build_blade()


func _physics_process(delta: float) -> void:
	cooldown_timer -= delta
	if _pressing and not Input.is_action_pressed("melee"):
		_pressing = false  # released somewhere we didn't hear (focus lost, paused)
	if _pressing:
		_held += delta
		if not out and not _hold_used and _held >= hold_time:
			_hold_used = true
			draw_knife()
	if weapon != null:
		weapon.holstered = out or stab_timer >= 0.0 or anim == "inspect"
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
		_pressing = true
		_held = 0.0
		_hold_used = false
	elif event.is_action_released("melee", true):
		if _pressing and not _hold_used:
			# A tap: a quick strike, or with the knife out, put it away.
			if out:
				put_away()
			else:
				stab()
		_pressing = false
	elif out and event.is_action_pressed("fire", false, true):
		stab()
	elif out and event.is_action_pressed("inspect", false, true) and anim == "":
		inspect()
	elif out and (event.is_action_pressed("swap_weapon", false, true) or event.is_action_pressed("reload", false, true)):
		put_away()


## Draws the knife as her weapon: the gun goes away, she runs lighter.
func draw_knife() -> void:
	if out:
		return
	out = true
	if player != null:
		player.speed_mult = ready_speed
	if weapon != null:
		weapon.holstered = true
		if "stowed" in weapon:
			weapon.stowed = true
		if weapon.has_method("stop_inspect"):
			weapon.stop_inspect()
	if stab_timer < 0.0:
		_play("draw")
	switched.emit(true)


## Puts the knife away and brings the gun back up with its draw.
func put_away() -> void:
	if not out:
		return
	out = false
	if player != null:
		player.speed_mult = 1.0
	if anim == "inspect" or anim == "draw":
		_play("")
	if weapon != null and weapon.has_method("draw"):
		weapon.draw()
	switched.emit(false)


func _process(delta: float) -> void:
	_ready_blend = move_toward(_ready_blend, 1.0 if out else 0.0, delta * 6.0)
	var r := smoothstep(0.0, 1.0, _ready_blend)
	var ready: Array = moves["ready"]
	var base: Vector3 = REST.lerp(ready[0], r)
	var base_rot: Vector3 = REST_ROT.lerp(ready[1], r)
	if out and anim == "" and player != null:
		# A little run bob so it reads as held, not floating.
		var bob := sin(Time.get_ticks_msec() * 0.012) * 0.006 * clampf(player.horizontal_speed() / 10.0, 0.0, 1.0)
		base += Vector3(0.0, bob, 0.0)

	var hand := [base, base_rot]
	var blade := [Vector3.ZERO, Vector3.ZERO]
	var handles := Vector3.ZERO
	var pivot := Vector3.ZERO
	if anim != "":
		anim_time += delta
		var a := _anim(anim)
		if anim_time >= float(a["length"]):
			_play("")
		else:
			hand = _sample(_resolve(a["hand"], base, base_rot), anim_time)
			if a.has("blade"):
				blade = _sample(a["blade"], anim_time)
				pivot = a.get("pivot", Vector3.ZERO)
			if a.has("handles"):
				handles = _sample(a["handles"], anim_time)[0]
			var trail: Array = a.get("trail", [])
			_trail_on = not trail.is_empty() and anim_time > trail[0] and anim_time < trail[1]
			_anim_events(a)
	_blade_root.visible = anim != "" or _ready_blend > 0.01
	_blade_root.position = hand[0]
	_blade_root.rotation = hand[1]
	# The knife turns about the animation's pivot (a ring, the pivot pins).
	var b := Basis.from_euler(blade[1])
	_blade.transform = Transform3D(b, blade[0] + pivot - b * pivot)
	if _safe != null:
		_safe.basis = _safe_rest * Basis(Vector3.UP, handles.x)
	if _bite != null:
		_bite.basis = _bite_rest * Basis(Vector3.UP, -handles.y)
	_update_trail()


## This knife's animation `name` (knife_moves.gd).
func _anim(name: String) -> Dictionary:
	return moves["anims"].get(name, moves["anims"]["attack_a"])


## Swaps "base" in hand keys for the pose she's holding.
static func _resolve(keys: Array, base: Vector3, base_rot: Vector3) -> Array:
	var out_keys := []
	for k in keys:
		out_keys.append([k[0], base if k[1] is String else k[1], base_rot if k[2] is String else k[2]])
	return out_keys


## Seconds the animation `name` of the knife in hand lasts.
func anim_length(name: String) -> float:
	return float(_anim(name)["length"])


## Starts a knife animation ("" stops it).
func _play(name: String) -> void:
	anim = name
	anim_time = 0.0
	_events_done = 0
	_trail_on = false


## Smooth interpolation through [time, a, b] keys.
static func _sample(keys: Array, t: float) -> Array:
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


## Sounds and sparkle timed to the animation.
func _anim_events(a: Dictionary) -> void:
	var events: Array = a.get("events", [])
	while _events_done < events.size() and anim_time >= float(events[_events_done][0]):
		var e: Array = events[_events_done]
		_events_done += 1
		match e[1]:
			"sound":
				SFX.play(self, e[2], -14.0 if e[2] == "knife_draw" else -16.0, SFX.vary(0.04))
			"glint":
				_edge_glint()
			"star":
				FX.star(_tip, _tip.global_position, Color(0.75, 0.95, 1.0, 0.95), 0.06, 0.12, 4)


## A glint that runs from the guard to the point.
func _edge_glint() -> void:
	var tw := create_tween()
	var star := FX.star(_grip, _grip.global_position, Color(0.85, 0.97, 1.0, 1.0), 0.05, 0.4, 4)
	star.position = Vector3(0, 0.004, -0.06)
	tw.tween_property(star, "position", _tip.position * 0.95, 0.32).set_trans(Tween.TRANS_SINE)


## Light trail behind the tip while a swing is moving.
func _update_trail() -> void:
	var tip := _tip.global_position
	if _trail_on and _blade_root.visible and player != null:
		FX.tracer(player.get_parent(), _last_tip, tip, Color(0.6, 0.95, 1.0, 0.7), 0.012, 0.09)
	_last_tip = tip


func is_inspecting() -> bool:
	return anim == "inspect"


## The knife's inspect: each knife shows off its own way.
func inspect() -> void:
	_play("inspect")
	var lines: Array = moves["lines"]
	var pick := rng.randi_range(0, lines.size() - 2)
	if pick >= _inspect_line:
		pick += 1
	_inspect_line = pick
	if weapon != null and weapon.has_signal("inspected"):
		weapon.inspected.emit(lines[pick])


func is_stabbing() -> bool:
	return stab_timer >= 0.0


## Starts a stab if the knife is ready. Returns false while on cooldown.
func stab() -> bool:
	if cooldown_timer > 0.0 or stab_timer >= 0.0:
		return false
	stab_timer = 0.0
	cooldown_timer = cooldown
	_struck = false
	# Unaware target in reach: the takedown thrust. Otherwise alternate attacks.
	var t := find_target()
	if t != null and t.has_method("is_unaware") and t.is_unaware():
		_play("thrust")
	else:
		_play(_next_attack)
		_next_attack = "attack_b" if _next_attack == "attack_a" else "attack_a"
	_last_tip = _tip.global_position
	SFX.play(self, "knife_swish", -10.0, SFX.vary(0.08))
	if weapon != null:
		# The pistol hand swings aside and can't fire mid-stab.
		weapon.holstered = true
		if weapon.has_method("stop_inspect"):
			weapon.stop_inspect()
	return true


func find_target() -> Node3D:
	# From her eyes, not the camera: in third person it hangs metres behind her.
	var from: Vector3 = player.head.global_position
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
	SFX.play(self, "knife_hit", -6.0, SFX.vary(0.08))
	if killed and not takedown:
		SFX.play(self, "kill", -10.0)  # takedowns stay silent
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
	_grip = Node3D.new()
	_blade.add_child(_grip)
	_tip = Node3D.new()
	_tip.name = "Tip"
	_grip.add_child(_tip)
	set_model(model_id)

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


## Puts the knife `id` (armory.gd KNIVES) in her hand, with its own moves;
## unknown ids get the Needle.
func set_model(id: String) -> void:
	if not MODELS.has(id):
		id = DEFAULT_MODEL
	model_id = id
	moves = Moves.moves(id)
	if _blade == null:
		return  # _ready builds it
	if model != null:
		model.free()
	if anim != "" and not moves["anims"].has(anim):
		_play("")
	model = knife_model(id)
	model.name = "Knife_" + id
	model.scale = Vector3.ONE * VIEW_SCALE
	_grip.rotation = moves["grip"]
	_grip.add_child(model)
	_tip.position = Vector3(0, 0, -blade_length(model) * VIEW_SCALE)
	_safe = model.find_child("SafeHandle", true, false) as Node3D
	_bite = model.find_child("BiteHandle", true, false) as Node3D
	if _safe != null:
		_safe_rest = _safe.basis
	if _bite != null:
		_bite_rest = _bite.basis


## A knife's model with the game materials on (for her hand, the knife case and
## the case's preview screen). The blade points down -z from the grip.
static func knife_model(id: String) -> Node3D:
	var node: Node3D = MODELS.get(id, MODELS[DEFAULT_MODEL]).instantiate()
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m != null and ResourceLoader.exists(MATERIALS + m.resource_name + ".tres"):
				(mi as MeshInstance3D).set_surface_override_material(i, load(MATERIALS + m.resource_name + ".tres"))
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## How far the point reaches past the middle of the grip, in model metres.
static func blade_length(node: Node3D) -> float:
	var reach := 0.0
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = (mi as Node3D).transform
		var p: Node = mi.get_parent()
		while p != node and p is Node3D:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var box: AABB = xf * (mi as MeshInstance3D).get_aabb()
		reach = maxf(reach, -box.position.z)
	return reach


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
