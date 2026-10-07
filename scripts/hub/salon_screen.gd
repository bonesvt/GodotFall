extends CanvasLayer
## Cut & Chrome, Juno's hair salon in Solace (town.gd): pick a haircut for Eco
## or for one of her romance options (hair.gd STYLES; Ophelia for now) on a
## turntable preview of them, and Juno cuts it. Haircuts are free and saved.
## The run manager opens it like a workbench screen (pausing the hub) and closes
## it on F or Esc.
##   W/S or Up/Down   pick a haircut      Space or Enter   cut it
##   Tab or Q/E       whose hair          A/D or drag       turn them round

const Hair := preload("res://scripts/hub/hair.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const BenchScreen := preload("res://scripts/hub/bench_screen.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const SFX := preload("res://scripts/sfx.gd")
const ECO := preload("res://assets/models/eco.tscn")

const INK := Color(0.98, 0.94, 0.86)
const DIM := Color(0.98, 0.94, 0.86, 0.55)
const ACCENT := Color(1.0, 0.45, 0.8)
const GOOD := Color(0.55, 1.0, 0.6)
const SPIN_SPEED := 0.4
## Whose hair Juno will cut, in tab order, with their tab names.
const CLIENTS := [["eco", "ECO"], ["ophelia", "OPHELIA"]]
## Juno's lines when a haircut is done (the first for Eco, the second for anyone else).
const DONE_LINES := [
	"Done. Look at you. The colony's going to cry into their rifles.",
	"Done. Tell her it was my idea if she sulks.",
]

## Which screen this is (the run manager and tests read it from any bench screen).
var kind := "salon"
## Who's in the chair (an index into CLIENTS), and the haircut picked.
var client := 0
var selected := 0
## Haircuts cut while the screen was open, [who, style] (for the run manager).
var cut := []
## Kept for the run manager, which reads it from any bench screen.
var unlocked := []

var _tab_label: Label
var _list: VBoxContainer
var _detail: Label
var _hint: Label
var _turntable: Node3D
var _camera: Camera3D
var _model: Node3D
var _model_who := ""
var _spin_hold := 0.0


func _init() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.03, 0.06, 0.6)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)

	var view := SubViewportContainer.new()
	view.stretch = true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.offset_left = 600
	view.gui_input.connect(_on_view_input)
	screen.add_child(view)
	view.add_child(_build_stage())

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", BenchScreen._box(Color(0.12, 0.08, 0.12, 0.95), 18, 24))
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(560, 0)
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(_text("CUT & CHROME", 30, ACCENT))
	col.add_child(_text("Juno's chair. Sit down, keep still, leave gorgeous.", 15, DIM))
	_tab_label = _text("", 20, INK)
	col.add_child(_tab_label)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	col.add_child(_list)
	_detail = _text("", 16, INK)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(512, 72)
	col.add_child(_detail)
	_hint = _text("W/S pick   Space cut it   Q/E whose hair   A/D turn   F or Esc done", 14, DIM)
	col.add_child(_hint)
	selected = _styles().find(Hair.current(who()))
	refresh()


func _process(delta: float) -> void:
	_spin_hold -= delta
	if _spin_hold <= 0.0 and _turntable != null:
		_turntable.rotate_y(delta * SPIN_SPEED)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_W, KEY_UP:
			select(selected - 1)
		KEY_S, KEY_DOWN:
			select(selected + 1)
		KEY_A, KEY_LEFT:
			_turn(-0.35)
		KEY_D, KEY_RIGHT:
			_turn(0.35)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				confirm()
		KEY_TAB, KEY_E:
			if not event.echo:
				switch_client(1)
		KEY_Q:
			if not event.echo:
				switch_client(-1)
		_:
			return
	get_viewport().set_input_as_handled()


## Whose hair is being looked at.
func who() -> String:
	return CLIENTS[client][0]


func _styles() -> Array:
	return Hair.style_ids(who())


func select(index: int) -> void:
	selected = posmod(index, _styles().size())
	SFX.play(self, "ui_hover", -10.0)
	refresh()


func switch_client(dir: int) -> void:
	client = posmod(client + dir, CLIENTS.size())
	selected = maxi(_styles().find(Hair.current(who())), 0)
	SFX.play(self, "ui_switch", -8.0)
	refresh()


## Cuts the picked haircut (saved, and put on every model of them). Returns
## whether it changed anything.
func confirm() -> bool:
	var style: String = _styles()[selected]
	if style == Hair.current(who()):
		SFX.play(self, "ui_error", -6.0)
		return false
	Hair.choose(get_tree(), who(), style)
	cut.append([who(), style])
	SFX.play(self, "haircut", -4.0, SFX.vary(0.04))
	refresh()
	_detail.text = DONE_LINES[0 if who() == "eco" else 1]
	return true


func refresh() -> void:
	var tabs := "   ".join(CLIENTS.map(func(c): return ("[ %s ]" % c[1]) if c[0] == who() else c[1]))
	_tab_label.text = tabs
	for c in _list.get_children():
		c.queue_free()
	var now := Hair.current(who())
	var styles := _styles()
	for i in styles.size():
		var style: String = styles[i]
		var line := "%s %s" % [">" if i == selected else " ", Hair.style_name(who(), style)]
		if style == now:
			line += "   (now)"
		var colour := ACCENT if i == selected else (GOOD if style == now else INK)
		_list.add_child(_text(line, 18, colour))
	_detail.text = "Juno: " + Hair.pitch(who(), styles[selected])
	_update_preview(styles[selected])


## The person in the chair wearing the picked haircut.
func _update_preview(style: String) -> void:
	if _model == null or _model_who != who():
		if _model != null:
			_model.free()
		_model_who = who()
		if who() == "eco":
			_model = ECO.instantiate()
			_model.rotation.y = PI  # she faces -Z; turn her to the camera
			_turntable.add_child(_model)
		else:
			_model = HubNpc.create(who(), Vector3.ZERO, 180.0)
			_turntable.add_child(_model)
	var model := _model.get_node_or_null("Model") if _model is HubNpc else _model
	Hair.apply(model, who(), style)


func _turn(amount: float) -> void:
	if _turntable != null:
		_turntable.rotate_y(amount)
		_spin_hold = 3.0


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_turntable.rotate_y(event.relative.x * 0.01)
		_spin_hold = 3.0


func _build_stage() -> SubViewport:
	var sub := SubViewport.new()
	sub.own_world_3d = true
	sub.msaa_3d = Viewport.MSAA_4X
	var stage := Node3D.new()
	sub.add_child(stage)
	Art.environment(stage, Color(0.12, 0.08, 0.13), Color(0.32, 0.22, 0.28))
	for node in stage.get_children():
		if node is WorldEnvironment:
			node.environment.fog_enabled = false
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-38, 200, 0)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.9)
	lamp.light_energy = 1.3
	lamp.omni_range = 20.0
	stage.add_child(lamp)
	_turntable = Node3D.new()
	stage.add_child(_turntable)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	stage.add_child(_camera)
	# head and shoulders, with room for a ponytail or braids below
	_camera.look_at_from_position(Vector3(0.0, 1.45, 1.9), Vector3(0, 1.38, 0))
	lamp.position = Vector3(0.6, 2.2, 1.6)
	return sub


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
