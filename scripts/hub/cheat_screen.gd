extends CanvasLayer
## The cheat box in Eco's loft: for testing (and for fun). Opened like a
## workbench (pausing the hub), closed on F or Esc.
##   1   max materials: 9999 scrap, alloy, circuits and lock cores
##   2   max relationships: Ophelia's affection and Mom's bond to full
##   3   unlock every cosmetic: piercings, tattoos and accessories (put on
##       at Ink & Iron and Stitch & Steel; Mature ones show under Mature)
##   4   super Hush: Marrow's Hold to full at once (vices.gd, Mature only)
## and an item for each of the other control systems, each with its own scene
## (cheat_scene.gd), Mature only:
##   5   TAKE ALL Hymn films: her Hymn to full (hymn.gd)
##   6   the colony case: every piece of the Shepherd's gear fitted in turn
##   7   Glass Rush: fully crystallised, three vials and his earpiece (glass.gd)
##   8   Ophelia's ECO pack: Keepsake full, her obsession all the way (obsession.gd)
##   9   Mom's dose box: Mom's and Ophelia's Hymn to 90 (hub_grip.gd)
##   0   the Family Plan: Mom and Ophelia in the whole set, their Hymn full
##   R   Biggie's toolkit: everything above (and Super Hush, and Redline) back to nothing
##   C   Cutter's Redline: he's there, and the needle (cutter_scene.gd)
## and the hypno looks' meters (vice_looks.gd), Mature only:
##   D   Faith's devotion up a stage
##   T   Colony City's Town's Grip up a stage
##   O   Ophelia's look: obsession up a stage
##   L   unlock the free endings' looks (Warden, Survivor, Unbound, Her Own)
##   (each meter wraps back to none after full)

const Armory := preload("res://scripts/hub/armory.gd")
const TownShops := preload("res://scripts/hub/town_shops.gd")
const Romance := preload("res://scripts/hub/romance.gd")
const Family := preload("res://scripts/hub/family.gd")
const SFX := preload("res://scripts/sfx.gd")
const NpcTalk := preload("res://scripts/hub/npc_talk.gd")
const Vices := preload("res://scripts/hub/vices.gd")
const HubGrip := preload("res://scripts/hub/hub_grip.gd")
const CheatScene := preload("res://scripts/hub/cheat_scene.gd")
const ViceLooks := preload("res://scripts/hub/vice_looks.gd")

const MAX_MATERIAL := 9999
const GOLD := Color(1.0, 0.82, 0.3)
const INK := Color(0.95, 0.93, 0.88)
const DIM := Color(0.95, 0.93, 0.88, 0.55)

var armory: Armory
## The hub's npc_talk (npc_talk.gd): its state holds affection and bond.
var npc_talk: Node
var kind := "cheats"
## Benches report weapons unlocked by a level up; nothing here does that.
var unlocked: Array = []
## What the box did, for the toast after.
var done: Array = []
## Super Hush was picked: the box closes and its scene plays (super_hush_scene.gd).
var inject := false
## One of the control items was picked: the box closes and its scene plays
## (cheat_scene.gd ITEMS key).
var scene := ""
var close_now := false

var _status: Label


func _init(p_armory: Armory, p_npc_talk: Node = null) -> void:
	armory = p_armory
	npc_talk = p_npc_talk
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.03, 0.03, 0.05, 0.7)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.09, 0.08, 0.06, 0.96)
	box.border_color = GOLD
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", box)
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(560, 0)
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(_text("CHEAT BOX", 30, GOLD))
	col.add_child(_text("A dented ammo crate with DO NOT OPEN scratched on the lid. Eco opened it.", 15, DIM))
	col.add_child(_button("1   Max materials (9999 of everything)", max_materials))
	col.add_child(_button("2   Max relationships (Ophelia, Mom and Biggie to full)", max_relationships))
	col.add_child(_button("3   Unlock all cosmetics (piercings, tattoos, accessories)", unlock_cosmetics))
	col.add_child(_button("4   Super Hush (Marrow's Hold to full, Mature only)", super_hush))
	col.add_child(_button("5   TAKE ALL Hymn films (her Hymn to full)", func(): control_item("hymn")))
	col.add_child(_button("6   The colony case (all the Shepherd's gear, fitted in turn)", func(): control_item("set")))
	col.add_child(_button("7   Glass Rush (fully crystallised, vials, his earpiece)", func(): control_item("glass")))
	col.add_child(_button("8   Ophelia's ECO pack (Keepsake full, her obsession all the way)", func(): control_item("keepsake")))
	col.add_child(_button("9   Mom's dose box (Mom and Ophelia's Hymn to 90)", func(): control_item("dosebox")))
	col.add_child(_button("0   The Family Plan (Mom and Ophelia, the whole set)", func(): control_item("family")))
	col.add_child(_button("R   Biggie's toolkit (reset every control system)", func(): control_item("toolkit")))
	col.add_child(_button("C   Cutter's Redline (the needle; from the second, a change)", redline_item))
	col.add_child(_button("D   Faith look: devotion up a stage", func(): look_meter("devotion")))
	col.add_child(_button("T   Colony City look: Town's Grip up a stage", func(): look_meter("town_grip")))
	col.add_child(_button("O   Ophelia's look: obsession up a stage", func(): look_meter("obsession")))
	col.add_child(_button("L   Unlock the free endings' looks", unlock_looks))
	_status = _text("", 16, INK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(512, 0)
	col.add_child(_status)
	col.add_child(_text("1-9, 0, R, C, D, T, O, L pick   F or Esc close", 14, DIM))


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1, KEY_KP_1:
			max_materials()
		KEY_2, KEY_KP_2:
			max_relationships()
		KEY_3, KEY_KP_3:
			unlock_cosmetics()
		KEY_4, KEY_KP_4:
			super_hush()
		KEY_5, KEY_KP_5:
			control_item("hymn")
		KEY_6, KEY_KP_6:
			control_item("set")
		KEY_7, KEY_KP_7:
			control_item("glass")
		KEY_8, KEY_KP_8:
			control_item("keepsake")
		KEY_9, KEY_KP_9:
			control_item("dosebox")
		KEY_0, KEY_KP_0:
			control_item("family")
		KEY_R:
			control_item("toolkit")
		KEY_C:
			redline_item()
		KEY_D:
			look_meter("devotion")
		KEY_T:
			look_meter("town_grip")
		KEY_O:
			look_meter("obsession")
		KEY_L:
			unlock_looks()
		_:
			return
	get_viewport().set_input_as_handled()


func max_materials() -> void:
	for m in Armory.MATERIALS:
		armory.stash[m] = MAX_MATERIAL
	armory.save()
	_did("Materials maxed: %d of everything." % MAX_MATERIAL)


## Everyone in the hub she can romance goes to full affection, everyone else
## to a full bond (their heart and bond scenes still play, in turn).
func max_relationships() -> void:
	if npc_talk == null:
		return
	var who_got := []
	for who: String in NpcTalk.NAMES:
		if who in ["eco", "narrator"]:
			continue
		if npc_talk.romanceable(who):
			Romance.add(npc_talk.state, who, Romance.MAX)
			who_got.append(String(NpcTalk.NAMES[who]).capitalize())
		else:  # Mom's bond (vices.gd reads it), Biggie's
			Family.add(npc_talk.state, who, Family.MAX)
			who_got.append(String(NpcTalk.NAMES[who]).capitalize())
	npc_talk.state.save(npc_talk.save_path)
	_did("Relationships maxed: %s." % ", ".join(who_got) if not who_got.is_empty() else "Nobody to max out yet.")


func unlock_cosmetics() -> void:
	unlock_cosmetics_count()


## Unlocks them and returns how many were new.
func unlock_cosmetics_count() -> int:
	var n := TownShops.unlock_all()
	_did("Unlocked %d cosmetics. Put them on at Ink & Iron and Stitch & Steel in town." % n if n > 0 else "Every cosmetic is already yours.")
	return n


## A vial of glowing violet resin, three times the usual: his Hold goes to
## full, so his pull, his errands and withdrawal all start now.
func super_hush() -> bool:
	if not Vices.allowed():
		_did("Super Hush is Mature only (Settings > Game > rating).")
		return false
	Vices.hold = Vices.MAX_HOLD
	Vices.walked_away = false
	Vices.save()
	Vices.reward_check()  # his gifts: told after the scene
	inject = true
	close_now = true
	_did("Super Hush: Marrow's Hold is full. He stops selling, his pull can take her, and a run without a dose is withdrawal.")
	return true


## One of the control items: the box closes and its scene plays out
## (cheat_scene.gd), which sets its system to full at the end. Mature only.
## Cutter's Redline: the box closes, he's right there, and the needle.
func redline_item() -> bool:
	if not Vices.allowed():
		_did("Redline is Mature only (Settings > Game > rating).")
		return false
	scene = "redline"
	close_now = true
	_did("Cutter's Redline: watch.")
	return true


func control_item(id: String) -> bool:
	if not Vices.allowed():
		_did("The control items are Mature only (Settings > Game > rating).")
		return false
	if id in ["family", "dosebox"] and (npc_talk == null or not HubGrip.allowed()):
		_did("Nobody home for the Family Plan.")
		return false
	scene = id
	close_now = true
	_did("%s: watch." % CheatScene.ITEMS[id]["name"])
	return true


## One of the hypno looks' meters up a stage (25), back to none after full.
## Returns the meter's new level (-1 under Teen).
func look_meter(meter_name: String) -> float:
	if not ViceLooks.allowed():
		_did("The hypno looks are Mature only (Settings > Game > rating).")
		return -1.0
	var now := ViceLooks.level(meter_name)
	ViceLooks.add(meter_name, -ViceLooks.MAX if now >= ViceLooks.MAX else ViceLooks.STAGE_AT[0])
	var level := ViceLooks.level(meter_name)
	var wearing := ViceLooks.forced()
	_did("%s is at %d. %s" % [meter_name.capitalize(), int(level),
			("She's in %s now." % ViceLooks.look_name(wearing)) if wearing != "" else "Nothing has her."])
	return level


func unlock_looks() -> void:
	if not ViceLooks.allowed():
		_did("The hypno looks are Mature only (Settings > Game > rating).")
		return
	var n := 0
	for id: String in ViceLooks.FREE:
		if ViceLooks.unlock(id):
			n += 1
	_did("Unlocked %d looks in her wardrobe: Warden, Survivor, Unbound and Her Own." % n if n > 0 else "She has every free look already.")


func _did(line: String) -> void:
	_status.text = line
	done.append(line)
	SFX.play(self, "ui_confirm", -4.0)


func _button(text: String, call: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(call)
	return b


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
