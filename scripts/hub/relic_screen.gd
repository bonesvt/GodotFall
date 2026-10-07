extends CanvasLayer
## The reliquary at the idol: every relic Eco has found or been given
## (relics.gd), what it does and what it costs, and the ones she hasn't got
## yet with a hint where to look. She wears up to Relics.SLOTS on a run.
## Opened like a workbench (pausing the hub), closed on F or Esc.
##   Up/Down (W/S)   pick       Space/Enter   wear or take off   (or click a row)

const Relics := preload("res://scripts/hub/relics.gd")
const SFX := preload("res://scripts/sfx.gd")

const EYE := Color(0.35, 1.0, 0.85)
const INK := Color(0.95, 0.93, 0.88)
const DIM := Color(0.95, 0.93, 0.88, 0.5)
const SOURCE_COLORS := {"precursor": Color(0.35, 1.0, 0.85), "npc": Color(1.0, 0.75, 0.45), "colony": Color(0.6, 0.75, 1.0)}

## Where the source column starts on a row (px).
const SOURCE_COLUMN := 420.0

var kind := "relics"
## Benches report weapons unlocked by a level up; nothing here does that.
var unlocked: Array = []
var selected := 0
var _rows: VBoxContainer
var _detail: Label
var _slots: Label


func _init() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.02, 0.04, 0.04, 0.72)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.08, 0.08, 0.96)
	box.border_color = EYE
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", box)
	panel.position = Vector2(28, 24)
	panel.custom_minimum_size = Vector2(760, 0)
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(_text("THE RELIQUARY", 28, EYE))
	col.add_child(_text("The idol's open hands. Eco keeps what she's found here, and takes up to %d on a run." % Relics.SLOTS, 15, DIM))
	_slots = _text("", 17, INK)
	col.add_child(_slots)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	col.add_child(_rows)
	_detail = _text("", 16, INK)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(716, 96)
	col.add_child(_detail)
	col.add_child(_text("Up/Down pick   Space wear or take off   F or Esc close", 14, DIM))
	_refresh()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_UP, KEY_W:
			select(selected - 1)
		KEY_DOWN, KEY_S:
			select(selected + 1)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			toggle_selected()
		_:
			return
	get_viewport().set_input_as_handled()


func select(index: int) -> void:
	var ids := Relics.listed()
	selected = posmod(index, ids.size())
	SFX.play(self, "ui_hover", -10.0)
	_refresh()


## Wears or takes off the picked relic. Returns whether she's wearing it now.
func toggle_selected() -> bool:
	var id: String = Relics.listed()[selected]
	if not Relics.owns(id):
		SFX.play(self, "ui_error", -6.0)
		return false
	var on := Relics.toggle(id)
	SFX.play(self, "ui_confirm" if on else "ui_switch", -4.0)
	_refresh()
	return on


func _refresh() -> void:
	var ids := Relics.listed()
	selected = clampi(selected, 0, ids.size() - 1)
	var worn: Array = Relics.worn.filter(func(id): return Relics.allowed(id)).map(func(id): return Relics.relic_name(id))
	_slots.text = "Wearing (%d/%d): %s" % [worn.size(), Relics.SLOTS, ", ".join(worn) if not worn.is_empty() else "nothing"]
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	for i in ids.size():
		_rows.add_child(_row(i, ids[i]))
	var id: String = ids[selected]
	var r: Dictionary = Relics.RELICS[id]
	if Relics.owns(id):
		_detail.text = "%s\n+ %s\n- %s" % [Relics.text(id, "blurb"), Relics.text(id, "perk"), Relics.text(id, "curse")]
	else:
		var hint: String = Relics.HINTS[r.get("giver", r["source"])]
		_detail.text = "Not found yet. %s" % hint


func _row(i: int, id: String) -> Control:
	var r: Dictionary = Relics.RELICS[id]
	var owned := Relics.owns(id)
	var on := i == selected
	var b := Button.new()
	b.flat = not on
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 16)
	var mark := "[ON] " if Relics.wearing(id) else "     "
	b.text = mark + (Relics.relic_name(id) if owned else "???")
	var c: Color = SOURCE_COLORS[r["source"]] if owned else DIM
	b.add_theme_color_override("font_color", c)
	b.add_theme_color_override("font_hover_color", c.lightened(0.2))
	# the source in its own column, lined up down the list
	var source := _text(Relics.SOURCES[r["source"]], 16, c)
	source.mouse_filter = Control.MOUSE_FILTER_IGNORE
	source.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	source.offset_left = SOURCE_COLUMN
	source.vertical_alignment = VERTICAL_ALIGNMENT_CENTER  # level with the name
	b.add_child(source)
	b.pressed.connect(func():
		selected = i
		toggle_selected())
	return b


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
