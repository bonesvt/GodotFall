extends CanvasLayer
## Having it out with Ophelia (obsession.gd), the next time Eco talks to her
## after finding the rose papers in her tent. Opened like a workbench (pausing
## the hub): her side of it, then Eco's choice.
##   1   help her anyway: she drugged Eco, and Eco says so; they get through
##       it, but trust comes back slower. Both of them get better.
##   2   walk away: "I can't do this." She doesn't stop, and it gets worse.

const Obsession := preload("res://scripts/hub/obsession.gd")
const Romance := preload("res://scripts/hub/romance.gd")
const SFX := preload("res://scripts/sfx.gd")

const ROSE := Color(0.95, 0.45, 0.62)
const INK := Color(0.96, 0.92, 0.94)
const DIM := Color(0.96, 0.92, 0.94, 0.55)

const LINES := [
	"Eco puts the tin on the bed between them. The jar, the stained Night Owls. KEEPSAKE, in Ophelia's handwriting. Ophelia goes very still.",
	"Eco: \"Every pack you gave me. Every one I smoked out there thinking about you. You put this in them.\"",
	"Ophelia: \"You always come home smelling like smoke and somebody else's fight, and then you go again. I just wanted you to want to come home. To me.\"",
	"Eco: \"So you drugged me. You don't get to call that missing me.\"",
]
const HELPED := "Eco: \"I don't forgive this yet. But I'm not leaving you with it. We fix it. No more tins, no more packs.\" She throws the rest of the Night Owls in the stove. Ophelia tips the jar in after them, crying. Trust comes back slower than the rest."
const LEFT := "Eco: \"I can't trust you. I can't do this.\" She walks out. Behind her, Ophelia doesn't cry. She just sits by the gate, and watches it, and waits."

var kind := "obsession"
var unlocked: Array = []
var close_now := false
var result := ""
var npc_talk: Node

var _status: Label
var _choices: Label
var _close_in := -1.0


func _init(p_npc_talk: Node = null) -> void:
	npc_talk = p_npc_talk
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.08, 0.03, 0.06, 0.72)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.13, 0.07, 0.1, 0.96)
	box.border_color = ROSE
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", box)
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(640, 0)
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	col.add_child(_text("OPHELIA", 28, ROSE))
	_status = _text("\n\n".join(LINES), 16, INK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(590, 0)
	col.add_child(_status)
	_choices = _text("1   Help her anyway: \"We fix it. No more packs.\"\n2   Walk away: \"I can't trust you.\"", 18, INK)
	col.add_child(_choices)
	col.add_child(_text("1-2 choose", 14, DIM))


func _process(delta: float) -> void:
	if _close_in >= 0.0:
		_close_in -= delta
		if _close_in < 0.0:
			close_now = true


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or result != "":
		return
	match event.keycode:
		KEY_1, KEY_KP_1:
			choose("helped")
		KEY_2, KEY_KP_2:
			choose("left")
		_:
			return
	get_viewport().set_input_as_handled()


func choose(how: String) -> void:
	result = how
	Obsession.resolve(how)
	if npc_talk != null:
		# a betrayal either way: it costs her, more if Eco walks
		Romance.add(npc_talk.state, "ophelia", -10 if how == "helped" else -30)
		npc_talk.state.save(npc_talk.save_path)
	_status.text = HELPED if how == "helped" else LEFT
	_choices.text = ""
	SFX.play(self, "ui_confirm" if how == "helped" else "door_metal_close", -6.0)
	_close_in = 3.0


func _text(t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
