extends CanvasLayer
## Sal's side hatch (vices.gd): combat stims under the counter, for materials
## from Eco's stash (armory.gd). She carries up to Vices.BELT_SIZE and jabs
## them on a run with N. Mature only: the run manager only opens it under "M".
## Opened like a workbench (pausing the hub), closed on F or Esc.
##   W/S pick   Space buy

const Armory := preload("res://scripts/hub/armory.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const LootArt := preload("res://scripts/run/loot_art.gd")
const SFX := preload("res://scripts/sfx.gd")

const INK := Color(0.94, 0.96, 0.92)
const DIM := Color(0.94, 0.96, 0.92, 0.55)
const RED := Color(1.0, 0.35, 0.3)
const ACID := Color(0.7, 1.0, 0.35)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.45, 0.4)

const SAL_HELLO := [
	"Sal: \"Hatch is for friends. You're a friend. Friends pay up front.\"",
	"Sal: \"Lifted off a colony medic. Still in the wrapper. Mostly.\"",
	"Sal: \"You didn't get these from me. You don't even know me.\"",
]
const SAL_SOLD := "Sal: \"Pleasure. Don't jab it all at once, they come back hard.\""
const SAL_FULL := "Sal: \"Your belt's full. I sell stims, not coffins.\""
const SAL_BROKE := "Sal: \"Short. Come back when you've stripped something.\""
const SAL_WORRIED := "Sal: \"...You're shaking, kid. You sure? Fine. Your veins.\""

var armory: Armory
var kind := "stims"
var selected := 0
## Benches report weapons unlocked by a level up; nothing here does that.
var unlocked: Array = []

var _stash: HBoxContainer
var _belt: Label
var _list: VBoxContainer
var _talk: Label
var _detail: Label


func _init(p_armory: Armory) -> void:
	armory = p_armory
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.03, 0.05, 0.04, 0.72)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.07, 0.1, 0.08, 0.96), 18, 24))
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(640, 0)
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(_text("SAL'S SIDE HATCH", 30, ACID))
	var hello: String = SAL_WORRIED if Vices.craving() > 0.0 else SAL_HELLO[randi() % SAL_HELLO.size()]
	_talk = _wrap(_text(hello, 15, DIM))
	col.add_child(_talk)
	_stash = HBoxContainer.new()
	_stash.add_theme_constant_override("separation", 18)
	col.add_child(_stash)
	_belt = _text("", 16, ACID)
	col.add_child(_belt)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	col.add_child(_list)
	_detail = _wrap(_text("", 16, INK))
	_detail.custom_minimum_size.y = 44
	col.add_child(_detail)
	col.add_child(_wrap(_text("W/S pick   Space buy   F or Esc leave\nOn a run, N jabs the next stim on her belt. Each one hits hard, then she crashes. Jab too often and she'll get the shakes on runs without one.", 14, DIM)))
	refresh()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_W, KEY_UP:
			select(selected - 1)
		KEY_S, KEY_DOWN:
			select(selected + 1)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			buy(Vices.STIM_ORDER[selected])
		_:
			return
	get_viewport().set_input_as_handled()


func select(index: int) -> void:
	selected = posmod(index, Vices.STIM_ORDER.size())
	SFX.play(self, "ui_hover", -10.0)
	refresh()


## Buys a stim onto her belt. Returns whether it went through.
func buy(id: String) -> bool:
	var cost: Dictionary = Vices.STIMS[id]["cost"]
	var ok := false
	if Vices.belt_full():
		_talk.text = SAL_FULL
	elif not armory.can_afford(cost):
		_talk.text = SAL_BROKE
	else:
		armory._spend(cost)
		armory.save()
		Vices.add_stim(id)
		_talk.text = SAL_SOLD
		ok = true
	SFX.play(self, "cloth_2" if ok else "ui_error", -4.0)
	refresh()
	return ok


func refresh() -> void:
	if _stash == null:
		return
	for c in _stash.get_children():
		c.queue_free()
	for m in Armory.MATERIALS:
		_stash.add_child(_text("%s %d" % [Armory.MATERIAL_NAMES[m].to_upper(), armory.amount(m)], 18, LootArt.COLORS[m]))
	var on_belt: Array = Vices.belt.map(func(id): return Vices.stim_name(id))
	_belt.text = "Belt (%d/%d): %s" % [Vices.belt.size(), Vices.BELT_SIZE, ", ".join(on_belt) if not on_belt.is_empty() else "empty"]
	for c in _list.get_children():
		c.queue_free()
	for i in Vices.STIM_ORDER.size():
		_list.add_child(_row(i))
	var s: Dictionary = Vices.STIMS[Vices.STIM_ORDER[selected]]
	_detail.text = "%s  (%d s, then a %d s crash)" % [s["blurb"], int(s["time"]), int(Vices.CRASH_TIME)]


func _row(i: int) -> PanelContainer:
	var id: String = Vices.STIM_ORDER[i]
	var on := i == selected
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.7, 1.0, 0.35, 0.18) if on else Color(0, 0, 0, 0), 10, 5))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	panel.add_child(line)
	var label := _text(Vices.stim_name(id), 17, ACID if on else INK)
	label.custom_minimum_size = Vector2(260, 0)
	line.add_child(label)
	var cost: Dictionary = Vices.STIMS[id]["cost"]
	var r := _text(Armory.cost_text(cost), 15, GOOD if armory.can_afford(cost) else BAD)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(r)
	panel.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if i == selected:
				buy(id)
			else:
				select(i))
	return panel


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(592, 0)
	return l


static func _box(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box
