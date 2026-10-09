extends CanvasLayer
## The Rig (redline.gd): a chair in Biggie's den, a red-lit injector arm over
## it. Eco sits, and picks: spend one Redline charge on a mod, take any mod off
## for free, or get up having done nothing. Opened like a workbench (pausing
## the hub), closed on F or Esc. Mature only. The run manager re-dresses her
## once it's shut (changed) and says what the last one felt like (felt).

const Redline := preload("res://scripts/hub/redline.gd")
const SFX := preload("res://scripts/sfx.gd")

const RED := Color(1.0, 0.3, 0.25)
const INK := Color(0.95, 0.93, 0.9)
const DIM := Color(0.95, 0.93, 0.9, 0.55)

## Benches report weapons unlocked by a level up; nothing here does that.
var unlocked: Array = []
## Something went on or came off.
var changed := false
## The last mod put on ("" for none), for its line after.
var felt := ""
var close_now := false

var _list: VBoxContainer
var _charges: Label
var _status: Label


func _init() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.01, 0.02, 0.72)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.04, 0.05, 0.96)
	box.border_color = RED
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", box)
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 28
	panel.offset_top = 24
	panel.offset_bottom = -24
	panel.offset_right = 28 + 760
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(_text("THE RIG", 30, RED))
	col.add_child(_text("An old barber's chair under a red-lit injector arm. Biggie's rule: \"Your body, your call. I just keep it clean.\"", 15, DIM))
	_charges = _text("", 18, INK)
	col.add_child(_charges)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_status = _text("", 16, INK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)
	col.add_child(_button("Get up (leave it as it is)", func(): close_now = true))
	col.add_child(_text("Each mod costs one Redline charge. Taking one off is free. F or Esc to get up.", 14, DIM))
	_refresh()


## Puts `mod` on for a charge. False if she can't.
func install(mod: String) -> bool:
	var why := Redline.blocked(mod)
	if why != "" or not Redline.install(mod):
		_say("%s: %s." % [Redline.MODS[mod]["name"], why if why != "" else "not now"])
		return false
	changed = true
	felt = mod
	_say(Redline.FEEL[mod])
	SFX.play(self, "titan_hiss_short", -6.0, 1.4)
	_refresh()
	return true


## Takes `mod` off, free.
func remove(mod: String) -> bool:
	if not Redline.remove(mod):
		return false
	changed = true
	if felt == mod:
		felt = ""
	_say("%s comes off. It doesn't hurt. It feels like setting something down." % Redline.MODS[mod]["name"])
	SFX.play(self, "cache_unlock", -6.0, 1.2)
	_refresh()
	return true


func _refresh() -> void:
	_charges.text = "Redline charges: %d     Mods on: %d" % [Redline.charges, Redline.mods.size()]
	for c in _list.get_children():
		c.queue_free()
	for mod: String in Redline.ORDER:
		var info: Dictionary = Redline.MODS[mod]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var on := mod in Redline.mods
		words.add_child(_text(("ON   " if on else "") + String(info["name"]), 18, RED if on else INK))
		var line := _text("%s %s" % [info["look"], info["does"]], 14, DIM)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(line)
		row.add_child(words)
		var b: Button
		if on:
			b = _button("Take off", func(): remove(mod))
		else:
			var why := Redline.blocked(mod)
			b = _button("Put on (1 charge)" if why == "" else why.capitalize(), func(): install(mod))
			b.disabled = why != ""
		b.custom_minimum_size = Vector2(190, 0)
		row.add_child(b)
		_list.add_child(row)


func _say(line: String) -> void:
	_status.text = line


func _button(text: String, call: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(call)
	return b


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
