extends CharacterBody3D
## Cutter (redline.gd, Mature only): Ophelia's old dealer, jealous of the big
## names moving in on his town. He comes after Eco through the hub and Solace
## (run_manager.gd spawns him now and then, maybe_cutter()). He's faster than
## the Shepherd and he doesn't dart her: he runs her down. Within GRAB_RANGE he
## has her, and the scene plays (cutter_scene.gd): Redline, in her eye. Out of
## his sight for LOSE_TIME s, he loses her and slinks off.

const SFX := preload("res://scripts/sfx.gd")
const ThreatModel := preload("res://scripts/threats/threat_model.gd")
const CutterModel := preload("res://scripts/hub/cutter_model.gd")

enum Step { HUNT, CAUGHT, GONE }

const SPEED := 6.4
const GRAB_RANGE := 1.3
const LOSE_TIME := 12.0
const HEIGHT := 1.9

const CALLS := [
	"Cutter, from somewhere behind her: \"Eco! Eco, wait up! I just wanna talk!\"",
	"Cutter: \"Marrow gets you, the colony gets you. What about me? I was here first.\"",
	"Cutter: \"Ophelia used to love my stuff. You'll love it more.\"",
	"Cutter: \"Hold still! It's only a little red!\"",
	"Cutter: \"You can't run on that Hymn forever, sweetheart.\"",
]
const LOST := "The footsteps behind her stop. Cutter's lost her. She can hear him swearing a street away."

var rm: Node
var step := Step.HUNT
var unseen := 0.0
var _t := 0.0
var _call_t := 2.0
var _calls := 0
var _last_seen := Vector3.ZERO
var _stuck_t := 0.0
var _side := 1.0
var _last_pos := Vector3.ZERO
var puppet: Node3D


static func create(run_manager: Node, pos: Vector3) -> CharacterBody3D:
	var c: CharacterBody3D = load("res://scripts/hub/cutter.gd").new()
	c.rm = run_manager
	c.name = "Cutter"
	c.position = pos
	return c


func _ready() -> void:
	add_to_group("cutter")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = HEIGHT
	col.shape = cap
	col.position.y = HEIGHT * 0.5
	add_child(col)
	puppet = Node3D.new()
	puppet.name = "Model"
	puppet.set_script(ThreatModel)
	puppet.gait = "biped"
	puppet.stride_len = 2.0
	puppet.swing = 28.0
	puppet.add_child(CutterModel.build())
	add_child(puppet)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.2, 0.15)
	lamp.light_energy = 0.9
	lamp.omni_range = 3.0
	lamp.position = Vector3(0, 1.7, -0.4)
	add_child(lamp)
	_last_seen = global_position
	_last_pos = global_position


func _player() -> Node3D:
	return rm.player


## Can he see her: nothing solid between his eyes and her chest.
func sees() -> bool:
	var p := _player()
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.7, 0), p.global_position + Vector3(0, 1.2, 0))
	q.exclude = [get_rid(), p.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _physics_process(delta: float) -> void:
	_t += delta
	match step:
		Step.HUNT:
			_hunt(delta)
		Step.GONE:
			queue_free()


func _hunt(delta: float) -> void:
	var p := _player()
	if rm.bench != null or rm.call("_scene_busy"):
		return  # a screen or a scene has her: he waits
	var see := sees()
	var to_her := p.global_position - global_position
	to_her.y = 0.0
	if see:
		unseen = 0.0
		_last_seen = p.global_position
	else:
		unseen += delta
		if unseen >= LOSE_TIME:
			give_up()
			return
	if to_her.length() <= GRAB_RANGE:
		catch()
		return
	_move(delta, _last_seen)
	_call_t -= delta
	if _call_t <= 0.0:
		_call_t = 7.0
		rm.hud.toast(CALLS[_calls % CALLS.size()], 3.5)
		_calls += 1


## Runs at `target`, sliding round what's in the way; side-steps if stuck.
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
	if fmod(_t, 1.0) < delta:
		if global_position.distance_to(_last_pos) < 0.4 and dir.length() > 0.3:
			_stuck_t = 1.0
			_side = -_side
		_last_pos = global_position


## He has her: the scene takes it from here.
func catch() -> void:
	if step != Step.HUNT:
		return
	step = Step.CAUGHT
	velocity = Vector3.ZERO
	rm.cutter_caught(self)


## The scene's done with him: he's off, laughing.
func leave() -> void:
	step = Step.GONE


func give_up() -> void:
	rm.hud.toast(LOST, 4.0)
	step = Step.GONE


func busy() -> bool:
	return step == Step.CAUGHT
