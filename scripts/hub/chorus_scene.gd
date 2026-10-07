extends Node
## The end of the Chorus (glass.gd): his ledger read and his three Glass vats
## smashed, Eco faces Marrow in his basement. He tries to pull her under one
## last time; she has to hold on (F in each window, shorter the deeper his
## Hold). Hold on every time and it breaks: Marrow runs, his Hold and her
## glass are gone, and the townsfolk's eyes clear. Miss one and she comes to
## in his armchair, deeper in, and the vats brewing again by morning.
## Mature only. The run manager plays it from the basement and keeps its
## controls off while busy().

const Glass := preload("res://scripts/hub/glass.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const SFX := preload("res://scripts/sfx.gd")
const HushDen := preload("res://scripts/hub/hush_den.gd")

const VEIL := Color(0.16, 0.04, 0.24)
## Seconds of him talking before the first pull, and between pulls.
const LEAD := 3.0
const GAP := 1.4

const OPEN := "Marrow: \"You broke my vats. Do you know what the colony pays for one of those? Sit down, Eco. Look at me.\""
const PULLS := [
	"The spirals come up in her eyes. [F] Hold on.",
	"Marrow: \"You were nothing at that recruitment desk. You're something with me.\" [F] Hold on.",
	"Marrow: \"Your father would have—\" [F] HOLD ON.",
]
const HELD := [
	"Eco: \"No.\"",
	"Eco: \"I'm not nothing. I'm not yours.\"",
]
const FREE := "Eco: \"Don't you say his name.\" Something in her head snaps like glass. Marrow stumbles back, and for the first time he looks scared. He's out the back door before she can stand. The violet drains out of everything. Up in Solace, people are blinking like they've woken from a nap."
const LOST := "The violet closes over her. ...Eco comes to in his armchair. Marrow: \"There you are. Don't worry about the vats. I'll have them brewing again by morning.\""

var rm: Node
var t := -1.0
## Which pull she's on, and whether its window is open.
var beat := 0
var _window := 0.0
var _wait := 0.0
var _veil: ColorRect
## How it ended: "", "free" or "lost".
var outcome := ""


func _init(run_manager: Node) -> void:
	rm = run_manager
	name = "ChorusScene"


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_veil = ColorRect.new()
	_veil.color = Color(VEIL, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_veil)


func busy() -> bool:
	return t >= 0.0


func play() -> void:
	t = 0.0
	beat = 0
	_window = 0.0
	_wait = LEAD
	outcome = ""
	var player: Node = rm.player
	player.set("entranced", true)
	player.set("trance_dir", Vector3.ZERO)
	rm.hud.toast(OPEN, LEAD)
	SFX.play(self, "heartbeat", -6.0, 0.9)


## Whether a press counts now (tests call it).
func window_open() -> bool:
	return _window > 0.0


func _process(delta: float) -> void:
	if t < 0.0:
		return
	t += delta
	_veil.color.a = (0.18 + 0.2 * float(beat) / Glass.RESIST_BEATS + 0.06 * sin(t * 5.0)) if beat < Glass.RESIST_BEATS else 0.0
	if Input.is_action_just_pressed("interact"):
		hold_on()
	if _window > 0.0:
		_window -= delta
		if _window <= 0.0:
			_finish(false)
		return
	_wait -= delta
	if _wait <= 0.0:
		_pull()


## A pull: the spirals come up and the window opens.
func _pull() -> void:
	Vices.entranced = true
	_window = Glass.resist_window()
	rm.hud.toast(PULLS[beat % PULLS.size()], _window + 0.3)
	SFX.play(self, "heartbeat", -2.0)


## F: she holds on, if a window is open.
func hold_on() -> void:
	if _window <= 0.0 or t < 0.0:
		return
	_window = 0.0
	Vices.entranced = false
	beat += 1
	if beat >= Glass.RESIST_BEATS:
		_finish(true)
		return
	rm.hud.toast(HELD[(beat - 1) % HELD.size()], GAP)
	_wait = GAP


func _finish(free: bool) -> void:
	t = -1.0
	_window = 0.0
	_veil.color.a = 0.0
	Vices.entranced = false
	rm.player.set("entranced", false)
	outcome = "free" if free else "lost"
	if free:
		Glass.break_free()
		rm.hud.toast(FREE, 9.0)
		SFX.play(self, "glass_break", -2.0)
	else:
		Glass.resist_failed()
		rm.place_player(HushDen.WAKE)
		rm.hud.toast(LOST, 6.0)
	rm.chorus_changed()


## Stops it where it is (the hub was left under it).
func reset() -> void:
	if t < 0.0:
		return
	t = -1.0
	_window = 0.0
	_veil.color.a = 0.0
	Vices.entranced = false
	rm.player.set("entranced", false)
