extends CanvasLayer
## Marrow's screen (vices.gd Hush), in the alley off Low Row or in his
## basement: buy a dose of Hush for the next run, or walk away from him for
## good while she still can. Mature only (the run manager checks the rating).
## Opened like a workbench (pausing the hub), closed on F or Esc.
##   Space   take a dose     X   walk away for good
##   L       buy a vial of Glass (glass.gd), once his Hold has been deep

const Armory := preload("res://scripts/hub/armory.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const LootArt := preload("res://scripts/run/loot_art.gd")
const SFX := preload("res://scripts/sfx.gd")
const HushDen := preload("res://scripts/hub/hush_den.gd")
const Glass := preload("res://scripts/hub/glass.gd")

const INK := Color(0.95, 0.92, 0.98)
const DIM := Color(0.95, 0.92, 0.98, 0.55)
const VIOLET := Color(0.8, 0.55, 1.0)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.45, 0.4)

## Marrow by how deep his Hold is: none, a taste, hooked, his.
const MARROW := {
	"None": "Marrow: \"Eco. The girl who lost her father. You look tired. I have something for tired.\"",
	"A taste": "Marrow: \"Back already. I knew you would be. Same as last time?\"",
	"Hooked": "Marrow: \"Your mother called round the temple again. I told her nothing. I keep your secrets, Eco.\"",
	"His": "Marrow: \"You don't need to ask anymore. You just come. Good. Sit.\"",
}
const MARROW_SOLD := "Marrow: \"There. Feel how quiet it gets? Go out and be brilliant. Then come home to me.\""
const MARROW_DOSED := "Marrow: \"You've already got one waiting in you. Greedy. I like that.\""
const MARROW_BROKE := "Marrow: \"Short? Bring me something nice. Or don't, and come anyway.\""
const MARROW_LOST := "Marrow: \"Walk, then. You'll be back. They always are.\""
const MARROW_WAITING := "Marrow: \"Did I say you could come back yet? Go on: %s.\""
const MARROW_PAID := "Marrow: \"Good. See how easy it is, doing as you're told? Here. You earned it.\""
const MARROW_LAUGHS := "Marrow: \"Leave? You can't even find the door without me.\""
const MARROW_GLASS_FIRST := "Marrow: \"Something new. Hush, cut with what the colony puts in its soldiers. Glass. And an earpiece, so I can keep you company out there.\""
const MARROW_GLASS := "Marrow: \"Careful with it. It doesn't wash off.\""
const MARROW_GLASS_FULL := "Marrow: \"You've got enough on you. Use them first.\""

var armory: Armory
## The hub talks' ConfigFile (npc_talk.state): Ophelia's romance and Mom's bond.
var state: ConfigFile
var kind := "hush"
## Benches report weapons unlocked by a level up; nothing here does that.
var unlocked: Array = []
## Set when she walks away, for the toast after.
var freed := false

var _stash: HBoxContainer
var _hold: Label
var _talk: Label
var _detail: Label
var _buttons: HBoxContainer


func _init(p_armory: Armory, p_state: ConfigFile = null) -> void:
	armory = p_armory
	state = p_state
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.02, 0.08, 0.75)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.1, 0.05, 0.14, 0.96), 18, 24))
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(640, 0)
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(_text("MARROW", 30, VIOLET))
	_talk = _wrap(_text(MARROW[Vices.hold_name()], 15, DIM))
	col.add_child(_talk)
	_stash = HBoxContainer.new()
	_stash.add_theme_constant_override("separation", 18)
	col.add_child(_stash)
	_hold = _text("", 17, VIOLET)
	col.add_child(_hold)
	_detail = _wrap(_text("", 15, INK))
	col.add_child(_detail)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	col.add_child(_buttons)
	col.add_child(_wrap(_text("Space %s   %sX walk away for good   F or Esc leave" % ["ask for work / hand it over" if Vices.earns_only() else "take a dose",
			"L buy Glass   " if Glass.on_sale() else ""], 14, DIM)))
	refresh()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			take()
		KEY_X:
			walk_away()
		KEY_L:
			buy_glass()
		_:
			return
	get_viewport().set_input_as_handled()


## Buys a dose for her next run (at full Hold: gets his errand, or hands it
## over done for one). Returns whether she got a dose.
func take() -> bool:
	if Vices.earns_only():
		return work()
	var ok := false
	if Vices.dosed:
		_talk.text = MARROW_DOSED
	elif not armory.can_afford(Vices.HUSH_COST):
		_talk.text = MARROW_BROKE
	else:
		armory._spend(Vices.HUSH_COST)
		armory.save()
		Vices.dose(state)
		_talk.text = MARROW_SOLD
		ok = true
	SFX.play(self, "cloth_2" if ok else "ui_error", -4.0)
	refresh()
	return ok


## At full Hold he doesn't sell: he hands out an errand (hush_den.gd ERRANDS)
## and pays for it, done, with a dose. Returns whether she got one.
func work() -> bool:
	var ok := false
	if Vices.dosed:
		_talk.text = MARROW_DOSED
	elif Vices.errand == "":
		var id := HushDen.pick_errand()
		Vices.give_errand(id)
		_talk.text = HushDen.ERRANDS[id]["task"]
	elif not Vices.errand_done:
		_talk.text = MARROW_WAITING % HushDen.ERRANDS[Vices.errand]["short"]
	else:
		ok = Vices.errand_paid(state)
		_talk.text = MARROW_PAID
	SFX.play(self, "cloth_2" if ok else "ui_confirm", -4.0)
	refresh()
	return ok


## Buys a vial of Glass (glass.gd), once he's selling it. Returns whether she did.
func buy_glass() -> bool:
	if not Glass.on_sale():
		return false
	var ok := false
	if Glass.vials >= Glass.MAX_VIALS:
		_talk.text = MARROW_GLASS_FULL
	elif not armory.can_afford(Glass.VIAL_COST):
		_talk.text = MARROW_BROKE
	else:
		var first := not Glass.earpiece
		armory._spend(Glass.VIAL_COST)
		armory.save()
		Glass.buy()
		_talk.text = MARROW_GLASS_FIRST if first else MARROW_GLASS
		ok = true
	SFX.play(self, "cloth_2" if ok else "ui_error", -4.0)
	refresh()
	return ok


## Walks away from him for good, if she can. Returns whether she did.
func walk_away() -> bool:
	if not Vices.can_walk_away(state):
		_talk.text = MARROW_LAUGHS
		SFX.play(self, "ui_error", -4.0)
		refresh()
		return false
	Vices.walk_away(state)
	freed = true
	_talk.text = MARROW_LOST
	SFX.play(self, "ui_confirm", -4.0)
	refresh()
	return true


func refresh() -> void:
	if _stash == null:
		return
	for c in _stash.get_children():
		c.queue_free()
	for m in Armory.MATERIALS:
		_stash.add_child(_text("%s %d" % [Armory.MATERIAL_NAMES[m].to_upper(), armory.amount(m)], 18, LootArt.COLORS[m]))
	_hold.text = "His hold on you: %s  %s%s" % [Vices.hold_name(), _meter(), "    (a dose is waiting for your next run)" if Vices.dosed else ""]
	var lines := ["Hush: glowing Precursor resin. One dose carries your whole next run: harder hits, faster healing, and grunts are slow to notice you. The deeper his hold, the stronger it gets.",
		"After a run on Hush you won't wake up at the temple. You'll wake up here. Ophelia and Mom feel every dose."]
	if Vices.earns_only():
		lines.append("He doesn't sell to you anymore. You work for it: run his errand, then come back to him. Go out on a run without a dose in you and it's a run in withdrawal. And some days, walking round town, your feet will just bring you here.")
	elif Vices.hold >= Vices.TRANCE_HOLD:
		lines.append("You're his now: you'll end up here after every run, Hush or not, until his hold loosens.")
	if Vices.can_walk_away(state) and Vices.hold >= Vices.BREAK_AT:
		lines.append("You think of the people waiting for you at home. You could still walk out of here.")
	elif Vices.hold >= Vices.BREAK_AT:
		lines.append("You can't make yourself leave. Stay clean for a while, or let someone close get through to you.")
	if Glass.on_sale():
		lines.append("Glass: Hush cut with colony combat tech. Crack a vial on a run (L) and the world slows down for a few seconds while you hit harder. It crystallises you: violet glass on your skin and less health, a step every vial, easing off a step for every run without it. You carry %d of %d." % [Glass.vials, Glass.MAX_VIALS])
	_detail.text = "\n".join(lines)
	for c in _buttons.get_children():
		c.queue_free()
	if Vices.earns_only():
		var job := "Dose: earned. Hand it over" if Vices.errand_done else ("Dose: %s first" % HushDen.ERRANDS[Vices.errand]["short"] if Vices.errand != "" else "Dose: ask him for work")
		_buttons.add_child(_text(job, 16, GOOD if Vices.errand_done and not Vices.dosed else VIOLET))
		_buttons.add_child(_button("Hand it over [Space]" if Vices.errand_done else "Ask for work [Space]", take))
	else:
		var cost := _text("Dose: %s" % Armory.cost_text(Vices.HUSH_COST), 16, GOOD if armory.can_afford(Vices.HUSH_COST) and not Vices.dosed else BAD)
		_buttons.add_child(cost)
		_buttons.add_child(_button("Take a dose [Space]", take))
	if Glass.on_sale():
		_buttons.add_child(_text("Glass: %s" % Armory.cost_text(Glass.VIAL_COST), 16, GOOD if armory.can_afford(Glass.VIAL_COST) and Glass.vials < Glass.MAX_VIALS else BAD))
		_buttons.add_child(_button("Buy Glass [L]", buy_glass))
	if Vices.hold > 0.0 or Vices.dosed:
		_buttons.add_child(_button("Walk away for good [X]", walk_away))


func _meter() -> String:
	var n := int(round(Vices.hold / 10.0))
	return "■".repeat(n) + "□".repeat(10 - n)


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
