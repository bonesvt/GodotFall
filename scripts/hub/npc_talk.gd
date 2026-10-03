extends CanvasLayer
## Conversations between Eco and the people in the hub. Press F by one of them
## (run_manager.gd) and they talk: each line is voiced (assets/audio/voice/npc/,
## made by tools/npc/voices.py) and captioned at the bottom of the screen.
## F skips to the next line; walking away ends it.
##
## The words live in dialogue/npc/<who>.txt: [intro] the first time Eco talks
## to them, [won] / [lost] once after each run that ended that way, otherwise
## the [any] conversations in turn. Who has met whom and where each of them is
## in their [any] list is saved to `save_path`.

signal finished(who: String)

const DIALOGUE_DIR := "res://dialogue/npc/"
const VOICE_DIR := "res://assets/audio/voice/npc/"
const DEFAULT_PATH := "user://hub_npcs.cfg"
## Pause after each line, and how long a line with no voice file stays up.
const GAP := 0.35
const WORDS_PER_SEC := 2.6
## Walk this far (m) from whoever you're talking to and the talk ends.
const LEAVE_RANGE := 5.5

const NAMES := {"mom": "MOM", "ophelia": "OPHELIA", "biggie": "BIGGIE", "eco": "ECO"}
const COLORS := {"mom": Color(0.6, 0.85, 0.6), "ophelia": Color(0.78, 0.55, 1.0), "biggie": Color(0.95, 0.75, 0.4), "eco": Color(1.0, 0.45, 0.45)}

var save_path := DEFAULT_PATH
var state := ConfigFile.new()
## The conversation playing: its NPC node, lines [[speaker, text], ...] and the line on now.
var npc: Node3D
var lines: Array = []
var index := -1
var line_left := 0.0
var _eco_voice: AudioStreamPlayer
var _panel: PanelContainer
var _name: Label
var _text: Label
var _banks := {}


func _ready() -> void:
	layer = 6
	state.load(save_path)
	_eco_voice = AudioStreamPlayer.new()
	add_child(_eco_voice)
	_build_caption()


func active() -> bool:
	return npc != null


## Parses dialogue/npc/<who>.txt: {"intro": [...], "won": [...], "lost": [...],
## "any": [[...], ...]}, each conversation a list of [speaker, text].
static func parse(text: String) -> Dictionary:
	var bank := {"any": []}
	var cur: Array = []
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			cur = []
			var tag := line.substr(1, line.length() - 2)
			if tag == "any":
				bank["any"].append(cur)
			else:
				bank[tag] = cur
			continue
		var colon := line.find(":")
		if colon > 0:
			cur.append([line.substr(0, colon).strip_edges(), line.substr(colon + 1).strip_edges()])
	return bank


func bank(who: String) -> Dictionary:
	if not _banks.has(who):
		var f := FileAccess.open(DIALOGUE_DIR + who + ".txt", FileAccess.READ)
		_banks[who] = parse(f.get_as_text()) if f != null else {"any": []}
	return _banks[who]


## Which conversation they'd have now. `run_id` counts finished runs and
## `won` says how the last one went (run_id 0: no run yet).
func pick(who: String, run_id: int, won: bool) -> Array:
	var b := bank(who)
	if not state.get_value(who, "met", false) and b.has("intro"):
		state.set_value(who, "met", true)
		state.set_value(who, "run_seen", run_id)
		return b["intro"]
	if run_id > int(state.get_value(who, "run_seen", 0)):
		state.set_value(who, "run_seen", run_id)
		var tag := "won" if won else "lost"
		if b.has(tag):
			return b[tag]
	var any: Array = b["any"]
	if any.is_empty():
		return []
	var n: int = state.get_value(who, "next_any", 0)
	state.set_value(who, "next_any", (n + 1) % any.size())
	return any[n % any.size()]


func start(p_npc: Node3D, run_id: int, won: bool) -> void:
	stop()
	lines = pick(p_npc.who, run_id, won)
	state.save(save_path)
	if lines.is_empty():
		return
	npc = p_npc
	index = -1
	_next()


## F: on to the next line now.
func advance() -> void:
	if active():
		_next()


func stop() -> void:
	if npc != null:
		var who: String = npc.who
		npc.hush()
		npc = null
		_eco_voice.stop()
		_panel.visible = false
		finished.emit(who)
	lines = []
	index = -1


static func voice_path(speaker: String, text: String) -> String:
	return VOICE_DIR + ("%s|%s" % [speaker, text]).sha1_text() + ".ogg"


func _next() -> void:
	index += 1
	if index >= lines.size():
		stop()
		return
	var speaker: String = lines[index][0]
	var text: String = lines[index][1]
	var path := voice_path(speaker, text)
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	var length := float(text.split(" ", false).size()) / WORDS_PER_SEC + 0.6
	if stream != null:
		length = stream.get_length()
	_eco_voice.stop()
	if speaker == "eco":
		npc.hush()
		npc.talking = true   # still facing her
		if stream != null:
			_eco_voice.stream = stream
			_eco_voice.play()
	else:
		npc.say(stream)
	line_left = length + GAP
	_name.text = NAMES.get(speaker, speaker.to_upper())
	_name.add_theme_color_override("font_color", COLORS.get(speaker, Color.WHITE))
	_text.text = text
	_panel.visible = true


## Called every frame by the run manager while the hub runs. `pilot` is where
## Eco is, so walking off ends it.
func tick(delta: float, pilot: Vector3) -> void:
	if not active():
		return
	if not is_instance_valid(npc) or pilot.distance_to(npc.global_position) > LEAVE_RANGE:
		stop()
		return
	line_left -= delta
	if line_left <= 0.0:
		_next()


## The line on screen, for tests: "speaker: text", or "".
func current_line() -> String:
	if not active() or index < 0 or index >= lines.size():
		return ""
	return "%s: %s" % lines[index]


func _build_caption() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.02, 0.05, 0.72)
	style.set_corner_radius_all(10)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -380
	_panel.offset_right = 380
	_panel.offset_top = -260   # above the speed readout
	_panel.offset_bottom = -135
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 17)
	box.add_child(_name)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 22)
	_text.add_theme_color_override("font_color", Color(0.96, 0.94, 0.92))
	_text.custom_minimum_size = Vector2(716, 0)
	box.add_child(_text)
	var hint := Label.new()
	hint.text = "[F] next"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.68, 0.72))
	box.add_child(hint)
