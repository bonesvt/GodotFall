extends CharacterBody3D
## The Shepherd (hymn.gd, Mature only): the colony's enforcer for citizens who
## skip their dose. Tall, white and grey, a dispensary tank on its back and a
## calm voice on a loudspeaker. It comes after Eco through the hub and town
## (run_manager.gd spawns it while Hymn.hunted), never to kill:
##   darts     every DART_EVERY s with her in sight and range, a Hymn dart
##             (Hymn.dart) and a step of sedation; full sedation brings her in
##   pulse     every PULSE_EVERY s close by: a sonic pulse that plays one of
##             his words (trigger_words.gd), locking her up while it closes in
##   grab      within GRAB_RANGE it takes her
## Brought in, she's "processed": the view whites out and the next piece of
## its gear goes on her in the dispensary's back room (Hymn.processed,
## fitting_scene.gd). Out of its
## sight for LOSE_TIME s, it loses her and walks off.

const Hymn := preload("res://scripts/hub/hymn.gd")
const SFX := preload("res://scripts/sfx.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const ThreatModel := preload("res://scripts/threats/threat_model.gd")
const ShepherdModel := preload("res://scripts/hub/shepherd_model.gd")

enum Step { HUNT, PROCESS, GONE }

const SPEED := 5.2
const GRAB_RANGE := 1.4
const DART_RANGE := 22.0
const DART_EVERY := 2.4
const DART_SPEED := 30.0
## Sedation a dart adds (1 brings her in), and how fast it wears off a second.
const DART_SEDATE := 0.22
const SEDATE_WEAR := 0.03
const PULSE_RANGE := 9.0
const PULSE_EVERY := 10.0
const LOSE_TIME := 14.0
const FADE := 1.2
const HEIGHT := 2.15

const CALLS := [
	"Shepherd: \"Citizen Eco. Your dose is waiting. Walk with me.\"",
	"Shepherd: \"There is nothing to be afraid of. Stop running.\"",
	"Shepherd: \"Hymn keeps you calm. Calm keeps you safe.\"",
	"Shepherd: \"Everyone else took theirs, Eco.\"",
]
const LOST := "The Shepherd's loudspeaker goes quiet. It's lost her. For now."
const TAKEN := "White. Then a calm voice counting down from ten. Eco wakes on the dispensary bench. There's nothing left for them to put on her."

var rm: Node
var step := Step.HUNT
## How sedated she is from its darts, 0..1.
var sedation := 0.0
var unseen := 0.0
var _dart_t := 1.0
var _pulse_t := 4.0
var _call_t := 0.0
var _calls := 0
var _t := 0.0
var _last_seen := Vector3.ZERO
var _stuck_t := 0.0
var _side := 1.0
var _last_pos := Vector3.ZERO
var _veil: ColorRect
var _darts: Array = []
var piece := ""
## Its body, on the Choir's puppet (threat_model.gd).
var puppet: Node3D
var _col: CollisionShape3D


static func create(run_manager: Node, pos: Vector3) -> CharacterBody3D:
	var s: CharacterBody3D = load("res://scripts/hub/shepherd.gd").new()
	s.rm = run_manager
	s.name = "Shepherd"
	s.position = pos
	return s


func _ready() -> void:
	add_to_group("shepherd")
	var col := CollisionShape3D.new()
	_col = col
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = HEIGHT
	col.shape = cap
	col.position.y = HEIGHT * 0.5
	add_child(col)
	_build_model()
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_veil = ColorRect.new()
	_veil.color = Color(0.95, 0.97, 1.0, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_veil)
	_last_seen = global_position
	_last_pos = global_position
	_say()


## Its body (shepherd_model.gd) on the Choir's puppet (threat_model.gd): it
## walks with the biped gait, and its slit, seal, tank and darts flare white
## (tell) as it lines up a dart.
func _build_model() -> void:
	puppet = Node3D.new()
	puppet.name = "Model"
	puppet.set_script(ThreatModel)
	puppet.gait = "biped"
	puppet.stride_len = 1.9
	puppet.swing = 22.0
	puppet.add_child(ShepherdModel.build())
	add_child(puppet)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.75, 0.9, 1.0)
	lamp.light_energy = 1.4
	lamp.omni_range = 4.0
	lamp.position = Vector3(0, 2.0, -0.4)
	add_child(lamp)

func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _player() -> Node3D:
	return rm.player


## Can it see her: a ray from its eye to her chest with nothing solid between.
func sees() -> bool:
	var p := _player()
	var from := global_position + Vector3(0, 2.0, 0)
	var to := p.global_position + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid(), p.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_darts(delta)
	match step:
		Step.HUNT:
			_hunt(delta)
		Step.PROCESS:
			_process_her(delta)
		Step.GONE:
			queue_free()


func _hunt(delta: float) -> void:
	var p := _player()
	if rm.bench != null or rm.hush_pull.step != rm.hush_pull.Step.IDLE:
		return  # a screen open, or Marrow's pull has her: it waits
	var see := sees()
	var to_her := p.global_position - global_position
	to_her.y = 0.0
	var dist := to_her.length()
	if see:
		unseen = 0.0
		_last_seen = p.global_position
	else:
		unseen += delta
		if unseen >= LOSE_TIME:
			give_up()
			return
	sedation = maxf(sedation - SEDATE_WEAR * delta, 0.0)
	if dist <= GRAB_RANGE:
		take_her()
		return
	_move(delta, _last_seen)
	_call_t += delta
	if _call_t >= 7.0:
		_call_t = 0.0
		_say()
	_dart_t -= delta
	puppet.set("tell", clampf(1.0 - _dart_t / 0.6, 0.0, 1.0) if see and dist <= DART_RANGE else 0.0)
	if see and dist <= DART_RANGE and _dart_t <= 0.0:
		_dart_t = DART_EVERY
		fire_dart()
	_pulse_t -= delta
	if see and dist <= PULSE_RANGE and _pulse_t <= 0.0:
		_pulse_t = PULSE_EVERY
		pulse()


## Walks at `target`, sliding round what's in its way; side-steps if stuck.
func _move(delta: float, target: Vector3) -> void:
	var dir := target - global_position
	dir.y = 0.0
	if dir.length() < 0.3:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		dir = dir.normalized()
		if _stuck_t > 0.0:
			_stuck_t -= delta
			dir = (dir + dir.cross(Vector3.UP) * _side * 1.5).normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		rotation.y = atan2(-dir.x, -dir.z)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	# barely moved for a second while trying to: try going round the other way
	if fmod(_t, 1.0) < delta:
		if global_position.distance_to(_last_pos) < 0.4 and dir.length() > 0.3:
			_stuck_t = 1.2
			_side = -_side
		_last_pos = global_position


func _say() -> void:
	rm.hud.toast(CALLS[_calls % CALLS.size()], 3.5)
	_calls += 1
	SFX.play_at(get_parent(), global_position, "radio_squelch_on", -4.0)


## A Hymn dart at her: it flies, and hits if she's still where it's going.
func fire_dart() -> void:
	var p := _player()
	var from := global_position + Vector3(0.42, 1.0, 0) .rotated(Vector3.UP, rotation.y)
	var to := p.global_position + Vector3(0, 1.1, 0)
	var dart := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = 0.025
	m.height = 0.22
	dart.mesh = m
	dart.material_override = _mat(Color(0.85, 0.95, 1.0), 4.0)
	get_parent().add_child(dart)
	dart.global_position = from
	dart.look_at(to, Vector3.UP)
	dart.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_darts.append({"node": dart, "to": to, "dir": (to - from).normalized(), "left": from.distance_to(to)})
	SFX.play_at(get_parent(), from, "titan_hiss_short", -6.0, 1.8)


func _tick_darts(delta: float) -> void:
	for d in _darts.duplicate():
		var n: MeshInstance3D = d["node"]
		var step_len := DART_SPEED * delta
		n.global_position += d["dir"] * step_len
		d["left"] -= step_len
		if d["left"] <= 0.0:
			if is_instance_valid(_player()) and _player().global_position.distance_to(d["to"] - Vector3(0, 1.1, 0)) < 1.0:
				dart_hit()
			n.queue_free()
			_darts.erase(d)


func dart_hit() -> void:
	Hymn.dart()
	sedation = minf(sedation + DART_SEDATE, 1.0)
	SFX.play(_player(), "hit_body", -6.0)
	rm.hud.toast("A dart in her shoulder. Cold, then calm. (sedated %d%%)" % roundi(sedation * 100.0), 2.0)
	if sedation >= 1.0:
		take_her()


## The sonic pulse: one of the colony's words, right in her head.
func pulse() -> void:
	SFX.play_at(get_parent(), global_position, "radio_static_burst", -2.0, 0.7)
	var tw: Node = rm.hush_pull.triggers
	if not tw.busy():
		tw.fire(false, true)


func take_her() -> void:
	if step != Step.HUNT:
		return
	step = Step.PROCESS
	_t = 0.0
	var p := _player()
	Hymn.save()
	p.set("entranced", true)
	p.set("trance_dir", Vector3.ZERO)


func _process_her(_delta: float) -> void:
	if _t < FADE:
		_veil.color.a = _t / FADE
		return
	# white: the fitting in the back room takes it from here (fitting_scene.gd)
	piece = Hymn.processed()
	# whoever she loves is closest, within reach, comes too (hub_grip.gd)
	var near := {}
	for w in HubGrip.WHO:
		var npc: Node3D = rm.hub_npcs.get(w)
		if npc != null and is_instance_valid(npc):
			near[w] = npc.global_position
	var with := HubGrip.closest(_player().global_position, near) if HubGrip.allowed() else ""
	var with_piece := HubGrip.take(with) if with != "" else ""
	if piece == "" and with_piece == "":
		rm.hud.toast(TAKEN, 6.0)  # nothing left to put on her
	rm.processed_by_shepherd(piece, with, with_piece)
	step = Step.GONE


## The Hymn bell on her collar rang at t: it knows where she is.
func heard(at: Vector3) -> void:
	if step == Step.HUNT and global_position.distance_to(at) <= Hymn.BELL_RANGE * 2.0:
		_last_seen = at
		unseen = 0.0


func give_up() -> void:
	Hymn.escaped()
	rm.hud.toast(LOST, 4.0)
	step = Step.GONE


func busy() -> bool:
	return step == Step.PROCESS
