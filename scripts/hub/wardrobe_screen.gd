extends CanvasLayer
## Eco's wardrobe (wardrobe.gd): pick what Eco, Mom and Ophelia wear, on a
## turntable preview of them. Mom and Ophelia can also be left to change
## outfits every run. The run manager opens it like a workbench screen
## (pausing the hub) and closes it on F or Esc.
##   W/S or Up/Down   pick an outfit     Space or Enter   wear it
##   Tab or Q/E       whose clothes      A/D or drag       turn them round

const Wardrobe := preload("res://scripts/hub/wardrobe.gd")
const Hair := preload("res://scripts/hub/hair.gd")
const HubNpc := preload("res://scripts/hub/hub_npc.gd")
const BenchScreen := preload("res://scripts/hub/bench_screen.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const SFX := preload("res://scripts/sfx.gd")
const ECO := preload("res://assets/models/eco.tscn")

const INK := Color(0.98, 0.94, 0.86)
const DIM := Color(0.98, 0.94, 0.86, 0.55)
const ACCENT := Color(1.0, 0.62, 0.35)
const GOOD := Color(0.55, 1.0, 0.6)
const SPIN_SPEED := 0.4

## Which screen this is (the run manager and tests read it from any bench screen).
var kind := "wardrobe"
## Whose clothes are up (an index into Wardrobe.PEOPLE), and the outfit picked.
var person := 0
var selected := 0
## Picks made while the screen was open, [who, outfit] (for the run manager).
var changed := []
## Kept for the run manager, which reads it from any bench screen.
var unlocked := []
## Runs ended so far, so "changes every run" previews tonight's outfit.
var run := 0

var _tab_label: Label
var _list: VBoxContainer
var _detail: Label
var _turntable: Node3D
var _model: Node3D
var _model_who := ""
var _spin_hold := 0.0


func _init(p_run := 0) -> void:
	run = p_run
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.03, 0.04, 0.6)
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
	panel.add_theme_stylebox_override("panel", BenchScreen._box(Color(0.12, 0.09, 0.08, 0.95), 18, 24))
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(560, 0)
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(_text("WARDROBE", 30, ACCENT))
	col.add_child(_text("Everyone's clothes ended up in here somehow.", 15, DIM))
	_tab_label = _text("", 20, INK)
	col.add_child(_tab_label)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	col.add_child(_list)
	_detail = _text("", 16, INK)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(512, 48)
	col.add_child(_detail)
	col.add_child(_text("W/S pick   Space wear it   Q/E whose clothes   A/D turn   F or Esc done", 14, DIM))
	selected = maxi(_options().find(Wardrobe.choice(who())), 0)
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
				switch_person(1)
		KEY_Q:
			if not event.echo:
				switch_person(-1)
		_:
			return
	get_viewport().set_input_as_handled()


## Whose clothes are up.
func who() -> String:
	return Wardrobe.PEOPLE[person][0]


func _options() -> Array:
	return Wardrobe.options(who())


func select(index: int) -> void:
	selected = posmod(index, _options().size())
	SFX.play(self, "ui_hover", -10.0)
	refresh()


func switch_person(dir: int) -> void:
	person = posmod(person + dir, Wardrobe.PEOPLE.size())
	selected = maxi(_options().find(Wardrobe.choice(who())), 0)
	SFX.play(self, "ui_switch", -8.0)
	refresh()


## Saves the picked outfit for them. Returns whether it changed anything.
func confirm() -> bool:
	var outfit: String = _options()[selected]
	if outfit == Wardrobe.choice(who()):
		SFX.play(self, "ui_error", -6.0)
		return false
	Wardrobe.choose(who(), outfit)
	changed.append([who(), outfit])
	SFX.play(self, "ui_confirm", -4.0)
	refresh()
	return true


func refresh() -> void:
	_tab_label.text = "   ".join(Wardrobe.PEOPLE.map(func(p): return ("[ %s ]" % p[1]) if p[0] == who() else p[1]))
	for c in _list.get_children():
		c.queue_free()
	var now := Wardrobe.choice(who())
	var options := _options()
	for i in options.size():
		var outfit: String = options[i]
		var line := "%s %s" % [">" if i == selected else " ", Wardrobe.outfit_name(outfit)]
		if outfit == now:
			line += "   (wearing)"
		var colour := ACCENT if i == selected else (GOOD if outfit == now else INK)
		_list.add_child(_text(line, 18, colour))
	if who() == "eco" and options.size() == 1:
		_detail.text = "Just the suit for now. The rest of her clothes are still at the tailor's."
	elif options[selected] == Wardrobe.ROTATE:
		_detail.text = "She picks for herself: something different after every run."
	else:
		_detail.text = "Eco wears it everywhere, runs included (an upgraded suit goes over it)." if who() == "eco" else ""
	_update_preview(options[selected])


## The person on the turntable wearing the picked outfit.
func _update_preview(outfit: String) -> void:
	if _model == null or _model_who != who():
		if _model != null:
			_model.free()
		_model_who = who()
		if who() == "eco":
			_model = ECO.instantiate()
			_model.rotation.y = PI  # she faces -Z; turn her to the camera
			_turntable.add_child(_model)
			Hair.apply(_model, "eco")
		else:
			_model = HubNpc.create(who(), Vector3.ZERO, 180.0)
			_turntable.add_child(_model)
	if _model is HubNpc:
		var list := Wardrobe.outfits(who())
		_model.wear(outfit if outfit != Wardrobe.ROTATE else list[run % list.size()])
	elif _model.has_method("wear"):
		_model.wear(outfit)


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
	Art.environment(stage, Color(0.13, 0.1, 0.09), Color(0.34, 0.27, 0.22))
	for node in stage.get_children():
		if node is WorldEnvironment:
			node.environment.fog_enabled = false
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-38, 200, 0)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.86, 0.75)
	lamp.light_energy = 1.3
	lamp.omni_range = 20.0
	lamp.position = Vector3(0.8, 2.4, 2.4)
	stage.add_child(lamp)
	_turntable = Node3D.new()
	stage.add_child(_turntable)
	var camera := Camera3D.new()
	camera.fov = 30.0
	stage.add_child(camera)
	# head to toe
	camera.look_at_from_position(Vector3(0.0, 1.0, 3.9), Vector3(0, 0.88, 0))
	return sub


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
