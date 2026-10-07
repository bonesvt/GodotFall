extends Node
## Marrow's pull (vices.gd, Mature only). Once his Hold on Eco is full, roaming
## the hub or Solace can take her: the swirls in her eyes spin up (a close-up
## on her face), the player loses her, and she walks in a trance (player.gd
## entranced, eco_model.gd _trance_walk) down the street to the cinema's
## cellar door and down to his basement, where he gives her an errand to earn
## her next dose (hush_den.gd ERRANDS). Skip it and her next run is withdrawal.
## Outside town she walks a few steps, the view goes violet, and she comes to
## herself walking in at the top of Lantern Row. If a crowd or a prop blocks her,
## the view goes violet and she's at his door.
##
## In withdrawal on a run it can take her too (episode): the swirls spin up in
## a close-up, she drops her guard, and walks off the job to beg him for
## another errand. The run ends there, abandoned, and she comes to at his place.
##
## The run manager makes one, ticks it in the hub with whether she's free
## (nothing open, not resting or in a titan) and asks busy() to keep its own
## controls off while it runs.

const Vices := preload("res://scripts/hub/vices.gd")
const HushDen := preload("res://scripts/hub/hush_den.gd")
const ViewCamera := preload("res://scripts/view_camera.gd")

enum Step { IDLE, SPIN, WANDER, WALK, FADE, ARRIVE, EPISODE }

const SPIN_TIME := 3.0
const WANDER_TIME := 3.5
const FADE_TIME := 1.1
const STUCK_TIME := 2.5
const VEIL := Color(0.16, 0.04, 0.24)
const EPISODE_TIME := 4.5

## What a withdrawal episode looks like on the run.
const EPISODE_LINES := [
	"The violet floods back in. Eco lowers the gun. The fight goes quiet and far away, and only one thing makes sense: Marrow.",
	"Her hands won't hold the gun still. Eco: \"Not here. Not now...\" The swirl takes the rest of it, and she turns back the way she came.",
	"Eco stops dead in the middle of the fight. Her eyes have gone violet and spinning. She walks away from all of it.",
]
## The summary when one ends the run.
const EPISODE_REASON := "Withdrawal took Eco off the job. She walked away from the fight to beg Marrow for another errand."

## What Eco hears when it takes her, one per pull, in turn.
const PULL_LINES := [
	"The violet comes up behind her eyes. Marrow's voice, soft as a hand on her neck: \"Come home, Eco.\"",
	"Her legs stop answering. Somewhere under the cinema, Marrow is waiting, and her feet know the way.",
	"Eco: \"No. No, not now, I was...\" The swirl takes the rest of the sentence.",
]
## What Marrow says when she walks in, before the errand.
const ARRIVE_LINES := [
	"Marrow: \"There you are. Right on time. You don't even know you're doing it anymore.\"",
	"Marrow: \"Sit down before you fall down. I've got work for you.\"",
	"Marrow: \"Look at you, walking all that way for me. Good. Now earn it.\"",
]

var rm: Node
var step := Step.IDLE
## Seconds she's been roaming since the last roll of the dice.
var roam := 0.0
var rng := RandomNumberGenerator.new()
## Seconds into this run since the last roll for a withdrawal episode.
var run_roam := 0.0

var _t := 0.0
var _route: Array = []
var _after_fade := ""
var _stuck := 0.0
var _last := Vector3.ZERO
var _cam: Camera3D
var _veil_layer: CanvasLayer
var _veil: ColorRect
var _lines := 0


func _init(run_manager: Node) -> void:
	rm = run_manager
	name = "HushPull"
	rng.randomize()


func _ready() -> void:
	_veil_layer = CanvasLayer.new()
	_veil_layer.layer = 4
	add_child(_veil_layer)
	_veil = ColorRect.new()
	_veil.color = Color(VEIL, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil_layer.add_child(_veil)


## A pull is under way: the run manager keeps F, B, N and the rest off.
func busy() -> bool:
	return step != Step.IDLE


## Called each physics tick in the hub. `free`: she's roaming with nothing
## open, not resting, not in a titan, not in his basement already.
func tick(delta: float, free: bool) -> void:
	if step == Step.IDLE:
		if not free or not Vices.can_pull():
			return
		roam += delta
		if roam >= Vices.PULL_EVERY:
			roam = 0.0
			if rng.randf() < Vices.PULL_CHANCE:
				start()
		return
	_advance(delta)


## His pull takes her, now.
func start() -> void:
	var player: Node3D = rm.player
	step = Step.SPIN
	_t = 0.0
	Vices.entranced = true
	player.set("entranced", true)
	player.set("trance_dir", Vector3.ZERO)
	_set_view(true)
	rm.hud.toast(PULL_LINES[_lines % PULL_LINES.size()], 5.0)
	_lines += 1
	_close_up(player)


func _advance(delta: float) -> void:
	_t += delta
	var player: Node3D = rm.player
	match step:
		Step.SPIN:
			if _t >= SPIN_TIME:
				_drop_close_up()
				if player.global_position.z > HushDen.PULL_TOWN_START.z - 4.0:
					_walk_from(player.global_position)
				else:
					step = Step.WANDER
					_t = 0.0
					var fwd := -player.global_basis.z
					player.set("trance_dir", Vector3(fwd.x, 0, fwd.z))
		Step.WANDER:
			if _t >= WANDER_TIME:
				_fade("town")
		Step.WALK:
			_walk(player, delta)
		Step.FADE:
			var half := FADE_TIME
			if _t < half:
				_veil.color.a = _t / half
			elif _after_fade != "":
				var where := _after_fade
				_after_fade = ""
				_land(where)
			else:
				_veil.color.a = clampf(2.0 - _t / half, 0.0, 1.0)
				if _t >= half * 2.0:
					_veil.color.a = 0.0
					if _route.is_empty():
						_arrive()
					else:
						step = Step.WALK
						_stuck = 0.0
						_last = player.global_position


## Called each physics tick on a run (not paused). `free`: on foot, not in a titan.
func run_tick(delta: float, free: bool) -> void:
	if step == Step.EPISODE:
		_t += delta
		if _t >= EPISODE_TIME:
			_end_episode()
		return
	if step != Step.IDLE or not free or not Vices.can_episode():
		return
	run_roam += delta
	if run_roam >= Vices.EPISODE_EVERY:
		run_roam = 0.0
		if rng.randf() < Vices.EPISODE_CHANCE:
			episode()


## Withdrawal takes her off the run, now.
func episode() -> void:
	var player: Node3D = rm.player
	step = Step.EPISODE
	_t = 0.0
	Vices.entranced = true
	player.set("entranced", true)
	player.set("trance_dir", Vector3.ZERO)
	player.set("untouchable_timer", EPISODE_TIME + 1.0)
	_arms(false)
	rm.hud.toast(EPISODE_LINES[_lines % EPISODE_LINES.size()], EPISODE_TIME)
	_lines += 1
	_close_up(player)


func _end_episode() -> void:
	var player: Node3D = rm.player
	_drop_close_up()
	step = Step.IDLE
	run_roam = 0.0
	Vices.entranced = false
	player.set("entranced", false)
	_arms(true)
	Vices.walk_off_job()
	rm.end_run("RUN ABANDONED", EPISODE_REASON)


## Lets go of her whatever it was doing (the run ended under it, say).
func reset() -> void:
	_drop_close_up()
	if step != Step.IDLE:
		step = Step.IDLE
		Vices.entranced = false
		rm.player.set("entranced", false)
		rm.player.set("trance_dir", Vector3.ZERO)
		_arms(true)
		_veil.color.a = 0.0
	run_roam = 0.0


## Her gun and knife, off while it has her on a run.
func _arms(on: bool) -> void:
	for path in ["Head/Camera3D/Weapon", "Head/Camera3D/Knife"]:
		var n: Node = rm.player.get_node_or_null(path)
		if n != null:
			n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _walk_from(pos: Vector3) -> void:
	_route = HushDen.PULL_ROUTE.filter(func(p: Vector3): return p.z > pos.z + 0.5)
	if _route.is_empty():
		_route = [HushDen.CELLAR]
	step = Step.WALK
	_t = 0.0
	_stuck = 0.0
	_last = pos


func _walk(player: Node3D, delta: float) -> void:
	var to: Vector3 = _route[0] - player.global_position
	to.y = 0.0
	if to.length() < 0.7:
		_route.pop_front()
		if _route.is_empty():
			player.set("trance_dir", Vector3.ZERO)
			_fade("basement")
			return
		to = _route[0] - player.global_position
		to.y = 0.0
	player.set("trance_dir", to.normalized())
	# a townsperson or a prop in her way: the view goes, and she's at his door
	_stuck += delta
	if _stuck >= STUCK_TIME:
		if player.global_position.distance_to(_last) < 0.8:
			_route.clear()
			player.set("trance_dir", Vector3.ZERO)
			_fade("basement")
			return
		_stuck = 0.0
		_last = player.global_position


func _fade(where: String) -> void:
	step = Step.FADE
	_t = 0.0
	_after_fade = where
	rm.player.set("trance_dir", Vector3.ZERO)


## Under the violet: she's moved on.
func _land(where: String) -> void:
	var player: Node3D = rm.player
	if where == "town":
		rm.place_player(HushDen.PULL_TOWN_START)
		_route = HushDen.PULL_ROUTE.filter(func(p: Vector3): return p.z > HushDen.PULL_TOWN_START.z + 0.5)
	else:
		rm.place_player(HushDen.ARRIVE)
		_route = []
	player.rotation.y = 0.0  # facing -Z: down the street from the gate, at his table in the basement


func _arrive() -> void:
	var player: Node3D = rm.player
	step = Step.IDLE
	Vices.entranced = false
	player.set("entranced", false)
	player.set("trance_dir", Vector3.ZERO)
	_set_view(false)
	var id := pick_errand()
	Vices.give_errand(id, true)
	rm.hud.toast(ARRIVE_LINES[(_lines - 1) % ARRIVE_LINES.size()] + "\n" + HushDen.ERRANDS[id]["task"], 9.0)


## One of his errands, at random.
func pick_errand() -> String:
	return HushDen.pick_errand()


## Third person while it has her, so the player sees her walk; their own view after.
func _set_view(on: bool) -> void:
	var view: Node = rm.player.get_node_or_null("ViewCam")
	if view != null:
		view.set_third_person(on or ViewCamera.prefer_third_person)


## A close-up on her face while the swirls spin up.
func _close_up(player: Node3D) -> void:
	_drop_close_up()
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var eyes := player.global_position + Vector3(0, 1.48, 0)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	add_child(_cam)
	_cam.look_at_from_position(eyes + fwd * 0.9 + Vector3(0, 0.02, 0), eyes)
	_cam.make_current()


func _drop_close_up() -> void:
	if _cam == null:
		return
	_cam.queue_free()
	_cam = null
	var cam: Camera3D = rm.player.get("camera")
	if cam != null:
		cam.make_current()
