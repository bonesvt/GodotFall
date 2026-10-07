extends CanvasLayer
## The cheat box in Eco's loft: for testing (and for fun). Opened like a
## workbench (pausing the hub), closed on F or Esc.
##   1   max materials: 9999 scrap, alloy, circuits and lock cores
##   2   max relationships: Ophelia's affection and Mom's bond to full
##   3   unlock every cosmetic: piercings, tattoos and accessories (put on
##       at Ink & Iron and Stitch & Steel; Mature ones show under Mature)
##   4   super Hush: Marrow's Hold to full at once (vices.gd, Mature only)

const Armory := preload("res://scripts/hub/armory.gd")
const TownShops := preload("res://scripts/hub/town_shops.gd")
const Romance := preload("res://scripts/hub/romance.gd")
const Family := preload("res://scripts/hub/family.gd")
const SFX := preload("res://scripts/sfx.gd")
const NpcTalk := preload("res://scripts/hub/npc_talk.gd")
const Vices := preload("res://scripts/hub/vices.gd")

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
	_status = _text("", 16, INK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(512, 0)
	col.add_child(_status)
	col.add_child(_text("1-4 pick   F or Esc close", 14, DIM))


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
