extends CanvasLayer
## The counter of a shop in Solace (town_shops.gd sells, town.gd builds the
## shop): Seven Suns Noodles ("noodles"), Mercy Clinic ("clinic"), Sal's
## Salvage ("salvage"), Ink & Iron ("ink": piercings and tattoos) and Stitch &
## Steel ("outfitter": accessories and a fitting room). Ink & Iron and Stitch &
## Steel show Eco on a turntable trying on whatever is picked.
## The run manager opens it like a workbench (pausing the hub) and closes it on F or Esc.
##   W/S or Up/Down   pick         Space or Enter   buy (or put on / take off what she owns)
##   Q/E or Tab       other tab    A/D or drag      turn her round

const Armory := preload("res://scripts/hub/armory.gd")
const Shops := preload("res://scripts/hub/town_shops.gd")
const Extras := preload("res://scripts/hub/eco_extras.gd")
const Wardrobe := preload("res://scripts/hub/wardrobe.gd")
const BenchScreen := preload("res://scripts/hub/bench_screen.gd")
const LootArt := preload("res://scripts/run/loot_art.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const SFX := preload("res://scripts/sfx.gd")
const ECO := preload("res://assets/models/eco.tscn")

const INK := Color(0.98, 0.94, 0.86)
const DIM := Color(0.98, 0.94, 0.86, 0.55)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.45, 0.4)
## What she tries tattoos on in: a tank top, so there's skin to see them on.
const TATTOO_PREVIEW := "y2k"

## Each shop: its sign, colour, who's behind the counter (what they say when
## you walk up), and its tabs (catalogue kinds).
const SHOPS := {
	"noodles": {"title": "SEVEN SUNS NOODLES", "color": Color(1.0, 0.62, 0.22), "tabs": [["meals", "MENU"]],
		"hint": "One meal at a time, for the next run only.",
		"greet": ["Old Hiro: \"Sit. Eat. You look like a stray cat.\"",
			"Old Hiro: \"Burnt edges again? I saved them. Don't tell the others.\"",
			"Old Hiro: \"Your father ate here every Sunday. Same bowl. Same complaints.\""]},
	"clinic": {"title": "MERCY CLINIC", "color": Color(0.6, 1.0, 0.35), "tabs": [["implants", "IMPLANTS"]],
		"hint": "Implants are for good.",
		"greet": ["Doc Imani: \"Implants on credit, sweetheart. Except for you. Cash.\"",
			"Doc Imani: \"I won't ask why a mechanic needs a quiet heart. I'll just install it.\"",
			"Doc Imani: \"Sit still. You fidget like your father.\""]},
	"salvage": {"title": "SAL'S SALVAGE", "color": Color(1.0, 0.18, 0.22), "tabs": [["trades", "TRADES"]],
		"hint": "Trade as often as you like. Sal always wins a little.",
		"greet": ["Sal: \"We buy scrap. No questions. We sell scrap. Some questions.\"",
			"Sal: \"Colony boards came in yesterday. Very fresh. Don't ask how fresh.\"",
			"Sal: \"You again. You're my best customer and my worst.\""]},
	"ink": {"title": "INK & IRON", "color": Color(0.25, 0.95, 1.0), "tabs": [["piercings", "PIERCINGS"], ["tattoos", "TATTOOS"]],
		"hint": "Tattoos only show where her clothes leave skin bare.",
		"greet": ["Rook: \"Needle's clean. Hands are steady. Pick something you'll still like when you're forty.\"",
			"Rook: \"The recruiters sent a kid in for a regulation tattoo once. I gave him a duck.\"",
			"Rook: \"Sit. Breathe out. It stings less if you're angry, and you look angry.\""]},
	"outfitter": {"title": "STITCH & STEEL", "color": Color(1.0, 0.25, 0.75), "tabs": [["accessories", "ACCESSORIES"], ["outfits", "FITTING ROOM"]],
		"hint": "One accessory on her head, one on her eyes, one on her face. The fitting room is free.",
		"greet": ["Mara: \"I made your first flight suit. Now look at you. Don't answer that.\"",
			"Mara: \"Try anything on. Break it, you bought it. Bleed on it, I charge double.\"",
			"Mara: \"Your mother asks if you're eating. I tell her you're eating my profits.\""]},
}

## Which shop this is, and what the run manager reads off any bench screen.
var kind := "noodles"
var unlocked: Array = []
## What she bought while it was open (catalogue ids), for the toast after.
var bought: Array = []
## Her outfit changed in the fitting room.
var changed := false
var armory: Armory
var tab := 0
var selected := 0
var rows: Array = []

var _stash: HBoxContainer
var _tab_label: Label
var _list: VBoxContainer
var _detail: Label
var _status: Label
var _turntable: Node3D
var _camera: Camera3D
var _model: Node3D
var _spin_hold := 0.0
var _say := ""


func _init(p_kind: String, p_armory: Armory) -> void:
	kind = p_kind if SHOPS.has(p_kind) else "noodles"
	armory = p_armory
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func spec() -> Dictionary:
	return SHOPS[kind]


func has_preview() -> bool:
	return kind in ["ink", "outfitter"]


## The catalogue kind of the tab open ("meals", "piercings", "outfits", ...).
func tab_kind() -> String:
	return spec()["tabs"][tab][0]


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.04, 0.06, 0.62)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)
	if has_preview():
		var view := SubViewportContainer.new()
		view.stretch = true
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.offset_left = 640
		view.gui_input.connect(_on_view_input)
		screen.add_child(view)
		view.add_child(_build_stage())
	var color: Color = spec()["color"]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", BenchScreen._box(Color(0.1, 0.08, 0.1, 0.95), 18, 24))
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(600, 0)
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(_text(spec()["title"], 30, color))
	var greet: Array = spec()["greet"]
	var g := _text(greet[randi() % greet.size()], 15, DIM)
	g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g.custom_minimum_size = Vector2(552, 0)
	col.add_child(g)
	_stash = HBoxContainer.new()
	_stash.add_theme_constant_override("separation", 18)
	col.add_child(_stash)
	_tab_label = _text("", 19, INK)
	_tab_label.visible = spec()["tabs"].size() > 1
	col.add_child(_tab_label)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	col.add_child(_list)
	_detail = _text("", 16, INK)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(552, 48)
	col.add_child(_detail)
	_status = _text("", 16, color)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(552, 0)
	col.add_child(_status)
	var keys := "W/S pick   Space buy / wear   " + ("Q/E tab   " if spec()["tabs"].size() > 1 else "") + ("A/D turn   " if has_preview() else "") + "F or Esc done"
	var hint := _text(spec()["hint"] + "\n" + keys, 14, DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(552, 0)
	col.add_child(hint)
	refresh()


func _process(delta: float) -> void:
	_spin_hold -= delta
	if _turntable != null and _spin_hold <= 0.0:
		# drift back to facing the camera
		_turntable.rotation.y = lerp_angle(_turntable.rotation.y, 0.0, 1.0 - exp(-2.0 * delta))


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_W, KEY_UP:
			select(selected - 1)
		KEY_S, KEY_DOWN:
			select(selected + 1)
		KEY_A, KEY_LEFT:
			_turn(-0.4)
		KEY_D, KEY_RIGHT:
			_turn(0.4)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				confirm()
		KEY_TAB, KEY_E:
			if not event.echo:
				switch_tab(1)
		KEY_Q:
			if not event.echo:
				switch_tab(-1)
		_:
			return
	get_viewport().set_input_as_handled()


func select(index: int) -> void:
	selected = posmod(index, maxi(rows.size(), 1))
	_say = ""
	SFX.play(self, "ui_hover", -10.0)
	refresh()


func switch_tab(dir: int) -> void:
	tab = posmod(tab + dir, spec()["tabs"].size())
	selected = 0
	_say = ""
	SFX.play(self, "ui_switch", -8.0)
	refresh()


# --- what's on the shelf -------------------------------------------------------

func _ids() -> Array:
	var k := tab_kind()
	if k in ["meals", "implants", "piercings", "tattoos", "accessories"]:
		return _shelf().filter(func(id): return Shops.available(k, id))
	return _shelf()


## Everything the shop stocks, Mature-only things included.
func _shelf() -> Array:
	match tab_kind():
		"meals":
			return Shops.MEALS.keys()
		"implants":
			return Shops.IMPLANTS.keys()
		"trades":
			return Shops.TRADES.keys()
		"piercings":
			return Extras.PIERCINGS.keys()
		"tattoos":
			return Extras.TATTOOS.keys()
		"accessories":
			return Extras.ACCESSORIES.keys()
		"outfits":
			return Wardrobe.outfits("eco")
	return []


func item_name(id: String) -> String:
	match tab_kind():
		"meals":
			return Shops.MEALS[id]["name"]
		"implants":
			return Shops.IMPLANTS[id]["name"]
		"trades":
			return Shops.TRADES[id]["name"]
		"piercings":
			return Extras.PIERCINGS[id]["name"]
		"tattoos":
			return Extras.TATTOOS[id]["name"]
		"accessories":
			return Extras.ACCESSORIES[id]["name"]
		"outfits":
			return Wardrobe.outfit_name(id)
	return id


func _blurb(id: String) -> String:
	match tab_kind():
		"meals":
			return Shops.MEALS[id]["blurb"]
		"implants":
			return Shops.IMPLANTS[id]["blurb"]
		"trades":
			var t: Dictionary = Shops.TRADES[id]
			return "%s  for  %s.  %s" % [Armory.cost_text(t["give"]), Armory.cost_text(t["get"]), t["blurb"]]
		"piercings":
			return Extras.PIERCINGS[id]["blurb"]
		"tattoos":
			return "%s, %s. %s\n(Shown in her Y2K top. Her other clothes may cover it.)" % [Extras.TATTOOS[id]["name"], Extras.TATTOOS[id]["where"], Extras.TATTOOS[id]["blurb"]]
		"accessories":
			return Extras.ACCESSORIES[id]["blurb"]
		"outfits":
			return "Try it on. It's what she wears around home and town (pilot suits go out on runs too)."
	return ""


## What the row says on the right: a price, or that she has it.
func _row_state(id: String) -> Array:
	var k := tab_kind()
	match k:
		"meals":
			return ["eaten, for the next run", GOOD] if Shops.meal() == id else _price(Shops.MEALS[id]["cost"])
		"trades":
			return _price(Shops.TRADES[id]["give"])
		"outfits":
			return ["wearing", GOOD] if Wardrobe.choice("eco") == id else ["free", DIM]
		"implants":
			return ["installed", GOOD] if Shops.owns(k, id) else _price(Shops.price(k, id))
	if Shops.owns(k, id):
		return ["on", GOOD] if Shops.wearing(k, id) else ["owned, off", DIM]
	return _price(Shops.price(k, id))


func _price(cost: Dictionary) -> Array:
	return [Armory.cost_text(cost), GOOD if armory.can_afford(cost) else BAD]


## Buys the picked thing, or puts on / takes off what she already owns.
## Returns whether anything happened.
func confirm() -> bool:
	if rows.is_empty():
		return false
	var id: String = rows[selected]
	var k := tab_kind()
	var ok := false
	var purchased := k != "outfits"
	match k:
		"meals":
			ok = Shops.meal() != id and Shops.buy_meal(armory, id)
			_say = "Hiro: \"Eat it all. Then go do whatever you don't tell your mother about.\"" if ok else ""
		"trades":
			ok = Shops.trade(armory, id)
			_say = "Sal: \"Pleasure. Mostly mine.\"" if ok else ""
		"implants":
			ok = Shops.buy(armory, k, id)
			_say = "Doc Imani: \"Done. Don't pick at it.\"" if ok else ""
		"outfits":
			ok = Wardrobe.choice("eco") != id
			if ok:
				Wardrobe.choose("eco", id)
				changed = true
		_:
			if Shops.owns(k, id):
				Shops.set_worn(k, id, not Shops.wearing(k, id))
				ok = true
				purchased = false
			else:
				ok = Shops.buy(armory, k, id)
				if ok:
					_say = ("Rook: \"Keep it clean. Keep it out of the sun. Keep being a pain.\"" if kind == "ink"
							else "Mara: \"Suits you. Everything does, it's annoying.\"")
	if ok and purchased:
		bought.append(id)
	SFX.play(self, ("coins" if purchased else "ui_confirm") if ok else "ui_error", -6.0)
	refresh()
	return ok


func refresh() -> void:
	rows = _ids()
	selected = clampi(selected, 0, maxi(rows.size() - 1, 0))
	for c in _stash.get_children():
		c.queue_free()
	for m in Armory.MATERIALS:
		_stash.add_child(_text("%s %d" % [Armory.MATERIAL_NAMES[m].to_upper(), armory.amount(m)], 18, LootArt.COLORS[m]))
	var tabs: Array = spec()["tabs"]
	_tab_label.text = "   ".join(tabs.map(func(t): return ("[ %s ]" % t[1]) if t[0] == tab_kind() else t[1]))
	for c in _list.get_children():
		c.queue_free()
	for i in rows.size():
		_list.add_child(_row_view(i))
	if rows.is_empty():
		_detail.text = ""
		return
	var id: String = rows[selected]
	_detail.text = _blurb(id)
	_status.text = _say if _say != "" else _status_line()
	_update_preview(id)


## A line about where she stands: her meal, her implants.
func _status_line() -> String:
	match tab_kind():
		"meals":
			return "Eaten for the next run: %s." % Shops.MEALS[Shops.meal()]["name"] if Shops.MEALS.has(Shops.meal()) else "Nothing eaten yet for the next run."
		"implants":
			var have := Shops.owned("implants").map(func(i): return Shops.IMPLANTS[i]["name"])
			return "Installed: %s." % ", ".join(have) if not have.is_empty() else "No implants yet."
	return ""


## Whether a row is a Mature-only thing (tagged "M" on the shelf).
func _mature(id: String) -> bool:
	match tab_kind():
		"meals":
			return Shops.MEALS[id].get("mature", false)
		"piercings":
			return Extras.PIERCINGS[id].get("mature", false)
		"tattoos":
			return Extras.TATTOOS[id].get("mature", false)
		"accessories":
			return Extras.ACCESSORIES[id].get("mature", false)
	return false


func _row_view(i: int) -> PanelContainer:
	var id: String = rows[i]
	var on := i == selected
	var color: Color = spec()["color"]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", BenchScreen._box(Color(color.r, color.g, color.b, 0.2) if on else Color(0, 0, 0, 0), 10, 5))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	panel.add_child(line)
	var label := _text(item_name(id), 17, color if on else INK)
	label.custom_minimum_size = Vector2(260, 0)
	line.add_child(label)
	if _mature(id):
		line.add_child(_text("M", 13, Color(0.95, 0.4, 0.45)))
	var state := _row_state(id)
	var r := _text(state[0], 15, state[1])
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(r)
	panel.gui_input.connect(_on_row_input.bind(i))
	return panel


func _on_row_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index == selected:
			confirm()
		else:
			select(index)


# --- Eco trying things on ------------------------------------------------------------

## What she'd have on with the picked thing tried on.
func trying(id: String) -> Dictionary:
	var worn := Shops.worn()
	var k := tab_kind()
	if worn.has(k) and not (worn[k] as Array).has(id):
		var list: Array = (worn[k] as Array).duplicate()
		if k == "accessories":
			var slot: String = Extras.ACCESSORIES[id]["slot"]
			list = list.filter(func(o): return Extras.ACCESSORIES[o]["slot"] != slot)
		list.append(id)
		worn[k] = list
	return worn


func _update_preview(id: String) -> void:
	if _turntable == null:
		return
	if _model == null:
		_model = ECO.instantiate()
		_model.rotation.y = PI  # she faces -Z; turn her to the camera
		_turntable.add_child(_model)
	var outfit := id if tab_kind() == "outfits" else Wardrobe.choice("eco")
	if tab_kind() == "tattoos":
		outfit = TATTOO_PREVIEW  # bare arms and shoulders, so the ink shows
	if _model.get("outfit") != outfit:
		_model.wear(outfit)
	Extras.apply(_model, trying(id))
	_frame(id)


## Points the camera at whatever's picked: her face for piercings and
## accessories, the right part of her for a tattoo, all of her in the fitting room.
func _frame(id: String) -> void:
	var at := Vector3(0, 0.95, 0)
	var from := Vector3(0, 1.1, 3.0)
	match tab_kind():
		"piercings", "accessories":
			at = Vector3(0, 1.5, 0)
			from = Vector3(0.12 if id != "helix" else 0.32, 1.53, 0.42)
			if id == "navel":
				at = Vector3(0, 1.06, 0)
				from = Vector3(0.15, 1.12, 0.6)
			elif id == "choker":
				at = Vector3(0, 1.42, 0)
				from = Vector3(0.15, 1.46, 0.5)
		"tattoos":
			var where: String = Extras.TATTOOS[id]["where"]
			at = Vector3(0, 1.25, 0)
			from = Vector3(0, 1.35, 1.2)
			if where.contains("left"):
				from.x = 0.75   # her left is the camera's right
			elif where.contains("right"):
				from.x = -0.75
			if where.contains("blade"):
				from = Vector3(-0.3, 1.35, -1.2)
			if where.contains("neck"):
				at = Vector3(0, 1.45, 0)
				from = Vector3(0.55, 1.5, 0.5)
			if where.contains("hip"):
				at = Vector3(0, 0.95, 0)
				from = Vector3(0.9, 1.0, 0.25)
			elif where.contains("thigh"):
				at = Vector3(0, 0.65, 0)
				from = Vector3(-0.9, 0.75, 0.3)
			elif where.contains("back"):
				at = Vector3(0, 1.0, 0)
				from = Vector3(0, 1.08, -1.0)
	_camera.look_at_from_position(from, at)


func _turn(amount: float) -> void:
	if _turntable != null:
		_turntable.rotate_y(amount)
		_spin_hold = 4.0


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_turntable.rotate_y(event.relative.x * 0.01)
		_spin_hold = 4.0


func _build_stage() -> SubViewport:
	var sub := SubViewport.new()
	sub.own_world_3d = true
	sub.msaa_3d = Viewport.MSAA_4X
	var stage := Node3D.new()
	sub.add_child(stage)
	Art.environment(stage, Color(0.1, 0.08, 0.12), Color(0.34, 0.3, 0.34))
	for node in stage.get_children():
		if node is WorldEnvironment:
			node.environment.fog_enabled = false
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-35, 20, 0)
	var lamp := OmniLight3D.new()
	lamp.light_color = (spec()["color"] as Color).lerp(Color.WHITE, 0.6)
	lamp.light_energy = 1.2
	lamp.omni_range = 12.0
	lamp.position = Vector3(-1.2, 2.0, 1.6)
	stage.add_child(lamp)
	_turntable = Node3D.new()
	stage.add_child(_turntable)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	stage.add_child(_camera)
	return sub


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
