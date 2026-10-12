extends Node
## The morning dose (hymn.gd), when Eco takes it at the dispensary: the dose is
## a film, a thin glowing strip she lays on her own tongue. A close-up on her face
## as it dissolves, a soft white wash across the view while the
## town goes quiet, and the calm voice: "Good morning, citizen." Deep in Hymn
## (SMILE_AT and up) she says it back. About LENGTH s; after the first one F
## skips it. The run manager plays it when the dispensary closes on a dose and
## keeps its own controls off while busy().

const Hymn := preload("res://scripts/hub/hymn.gd")
const SFX := preload("res://scripts/sfx.gd")

const LENGTH := 4.2
const SWALLOW := 0.6
const WASH := 1.4
const VOICE := 2.0
const SMILE_AT := 60.0
const WHITE := Color(0.95, 0.97, 1.0)

var rm: Node
var t := -1.0
## Seen one this session: F skips the next.
var seen := false
var _veil: ColorRect
var _said := {}


func _init(run_manager: Node) -> void:
	rm = run_manager
	name = "DoseScene"


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_veil = ColorRect.new()
	_veil.color = Color(WHITE, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_veil)


func busy() -> bool:
	return t >= 0.0


func play() -> void:
	t = 0.0
	_said.clear()
	rm.player.set("entranced", true)
	rm.player.set("trance_dir", Vector3.ZERO)
	rm.pilot_hud.visible = false
	rm.hud.status_label.visible = false
	rm.hud.corners_hidden = true
	rm.hush_pull._close_up(rm.player)
	rm.hud.toast("The officer peels a thin, glowing strip off a sheet. Eco lays it on her tongue. It melts, sweet.", 2.2)


func _process(delta: float) -> void:
	if t < 0.0:
		return
	t += delta
	if seen and t > 0.3 and Input.is_action_just_pressed("interact"):
		_finish()
		return
	_mouth(smoothstep(0.2, 0.5, t) * (1.0 - smoothstep(SWALLOW + 0.3, SWALLOW + 0.7, t)) * 0.6)
	if t >= SWALLOW and not _said.has("swallow"):
		_said["swallow"] = true
		SFX.play(self, "titan_hiss_short", -14.0, 2.4)
	# the wash: in, a breath, out
	_veil.color.a = 0.55 * smoothstep(WASH - 0.4, WASH + 0.3, t) * (1.0 - smoothstep(LENGTH - 1.0, LENGTH, t))
	if t >= VOICE and not _said.has("voice"):
		_said["voice"] = true
		var line := "Calm voice: \"Good morning, citizen.\""
		if Hymn.level >= SMILE_AT:
			line += "\nEco, smiling: \"Good morning.\""
		rm.hud.toast(line, 2.4)
		SFX.play(self, "chime_2", -10.0)
	if t >= LENGTH:
		_finish()


## Her mouth open a little (0..1) on both copies of her (eco_model.gd), for the film.
func _mouth(open: float) -> void:
	var eco: Node = rm.player.get_node_or_null("EcoBody")
	if eco == null:
		return
	for mi in eco.find_children("*", "MeshInstance3D", true, false):
		var b: int = (mi as MeshInstance3D).find_blend_shape_by_name("Fcl_MTH_A")
		if b >= 0:
			(mi as MeshInstance3D).set_blend_shape_value(b, open)


func _finish() -> void:
	_mouth(0.0)
	t = -1.0
	seen = true
	_veil.color.a = 0.0
	rm.hush_pull._drop_close_up()
	rm.player.set("entranced", false)
	rm.pilot_hud.visible = true
	rm.hud.status_label.visible = true
	rm.hud.corners_hidden = false


func reset() -> void:
	if t >= 0.0:
		_finish()
