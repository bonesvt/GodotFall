extends CanvasLayer
## Eco's suit locker, in the look of an old space-western title card: slanted
## blocks of red, mustard and teal on black, big condensed type. She stands
## in the middle in whichever suit she picked in her wardrobe. Across the top
## are her three kits, one per suit weight (armory.gd SUIT_WEIGHTS): LIGHT,
## MEDIUM, HEAVY. Down the left, that kit's overview and its five tiers
## ("sessions", armory.gd SUIT_TIERS); pick one and the camera swings round
## and closes in on the part of her the tier changes (FOCUS), with her
## wearing it. The right panel says what it does and what it costs.
##   Mouse     click a kit or a session (click it again to buy); drag her to
##             turn her, wheel zooms
##   Q/E, A/D or Tab   switch kit        W/S    pick a session
##   Space or Enter    buy the picked session
## The run manager opens it (pausing the hub) and closes it on F or Esc.

const Armory := preload("res://scripts/hub/armory.gd")
const Wardrobe := preload("res://scripts/hub/wardrobe.gd")
const LootArt := preload("res://scripts/run/loot_art.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const SFX := preload("res://scripts/sfx.gd")
const ECO := preload("res://assets/models/eco.tscn")

const BLACK := Color(0.06, 0.05, 0.05, 0.94)
const PAPER := Color(0.96, 0.92, 0.83)
const DIM := Color(0.96, 0.92, 0.83, 0.55)
const RED := Color(0.84, 0.16, 0.14)
const MUSTARD := Color(0.95, 0.71, 0.13)
const TEAL := Color(0.08, 0.55, 0.56)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.45, 0.4)
## Each kit's colour.
const KIT_COLOR := {"light": RED, "medium": MUSTARD, "heavy": TEAL}
## How far the blocks lean.
const SLANT := 0.22

## Where the camera goes for a kit's overview (index 0) and each of its tiers
## (1-5): `y` the height it looks at, `dist` how far back it stands, `yaw` how
## far she turns (0 facing the camera, + shows her left side, PI her back),
## `part` the caption.
const FOCUS := {
	"light": [
		{"y": 0.88, "dist": 3.6, "yaw": 0.35, "part": "THE RUNNER"},
		{"y": 1.0, "dist": 1.45, "yaw": -0.45, "part": "HIPS AND WRISTS"},
		{"y": 1.1, "dist": 2.2, "yaw": 0.85, "part": "LEFT SHOULDER AND THIGH"},
		{"y": 0.45, "dist": 1.9, "yaw": 0.3, "part": "KNEES AND SHINS"},
		{"y": 1.3, "dist": 1.6, "yaw": PI - 0.45, "part": "NECK, ARM AND BACK"},
		{"y": 1.42, "dist": 0.95, "yaw": 0.95, "part": "LEFT SHOULDER"},
	],
	"medium": [
		{"y": 0.88, "dist": 3.6, "yaw": -0.35, "part": "THE MECHANIC"},
		{"y": 1.0, "dist": 1.45, "yaw": 0.6, "part": "LEFT HIP AND WRIST"},
		{"y": 1.32, "dist": 1.45, "yaw": -0.3, "part": "NECK AND SHOULDERS"},
		{"y": 0.5, "dist": 1.9, "yaw": -0.35, "part": "KNEES AND THIGH"},
		{"y": 1.15, "dist": 1.8, "yaw": PI, "part": "BACK"},
		{"y": 1.42, "dist": 0.95, "yaw": -0.95, "part": "RIGHT SHOULDER"},
	],
	"heavy": [
		{"y": 0.88, "dist": 3.6, "yaw": 0.25, "part": "THE TITAN"},
		{"y": 1.2, "dist": 2.0, "yaw": 0.2, "part": "CHEST AND ARMS"},
		{"y": 1.3, "dist": 1.8, "yaw": 0.75, "part": "SHOULDERS"},
		{"y": 0.55, "dist": 2.2, "yaw": 0.25, "part": "LEGS"},
		{"y": 1.2, "dist": 2.0, "yaw": PI, "part": "BACK"},
		{"y": 0.88, "dist": 3.4, "yaw": 0.0, "part": "DAD'S COLOURS"},
	],
}
## Through how far the camera has caught up each second (an ease-out swing).
const SWING := 6.0
const CONFIRM_SOUND := "workbench_ratchet"

var kind := "suit"
var armory: Armory
## The kit being looked at; picking it refits her (once she has a suit tier).
var weight := "medium"
## 0 the kit's overview, 1-5 its tiers.
var selected := 0
## Guns unlocked by level ups while this screen was open (for the HUD after).
var unlocked := []
## Her, on the stage, wearing what's picked (eco_model.gd).
var eco

var _font: Font
var _tabs: HBoxContainer
var _cards: VBoxContainer
var _session: Label
var _name: Label
var _armour: Label
var _passive: Label
var _passive_desc: Label
var _looks: Label
var _line: Label
var _cost: Label
var _buy: PanelContainer
var _buy_label: Label
var _caption: Label
var _level: Label
var _level_flash := 0.0
var _stash: HBoxContainer
var _turntable: Node3D
var _camera: Camera3D
var _preview_key := ""
## The camera's aim now and where it is swinging to: [y, dist, yaw].
var _at := Vector3(0.88, 3.6, 0.0)
var _to := Vector3(0.88, 3.6, 0.0)
## How far the player turned her or zoomed, on top of the focus.
var _drag_yaw := 0.0
var _zoom := 1.0


func _init(p_armory: Armory) -> void:
	armory = p_armory
	weight = armory.suit_weight
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_font = title_font()
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var view := SubViewportContainer.new()
	view.stretch = true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.gui_input.connect(_on_view_input)
	screen.add_child(view)
	view.add_child(_build_stage())

	# a mustard bar down the left edge and a black one along the bottom
	_block(screen, Vector2(0, 0), Vector2(14, 900), MUSTARD, 0.0)
	var foot := _block(screen, Vector2(0, 858), Vector2(1600, 42), BLACK, 0.0)
	foot.add_child(_text("Q/E  kit      W/S  session      SPACE  buy      DRAG  turn her      WHEEL  zoom      F/ESC  done",
			14, DIM, false))

	# the title card
	var title := _block(screen, Vector2(34, 22), Vector2(470, 0), BLACK)
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 0)
	title.add_child(tcol)
	tcol.add_child(_text("SUIT LOCKER", 58, PAPER))
	var strap := _block(tcol, Vector2.ZERO, Vector2(0, 0), RED)
	strap.add_child(_text("ECO'S ARMOUR.  EVERY SESSION KEEPS THE LAST.", 14, Color(0.06, 0.05, 0.05), false))

	# the kits
	_tabs = HBoxContainer.new()
	_tabs.position = Vector2(40, 150)
	_tabs.add_theme_constant_override("separation", 12)
	screen.add_child(_tabs)

	# the sessions
	_cards = VBoxContainer.new()
	_cards.position = Vector2(40, 238)
	_cards.custom_minimum_size = Vector2(420, 0)
	_cards.add_theme_constant_override("separation", 8)
	screen.add_child(_cards)

	# her level and stash, top right
	var top := VBoxContainer.new()
	top.position = Vector2(1120, 26)
	top.custom_minimum_size = Vector2(440, 0)
	screen.add_child(top)
	_level = _text("", 18, MUSTARD, false)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_level.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(_level)
	_stash = HBoxContainer.new()
	_stash.alignment = BoxContainer.ALIGNMENT_END
	_stash.add_theme_constant_override("separation", 14)
	top.add_child(_stash)

	# the picked session
	var panel := _block(screen, Vector2(1120, 150), Vector2(440, 0), BLACK)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	_session = _text("", 18, MUSTARD)
	col.add_child(_session)
	_name = _text("", 40, PAPER)
	col.add_child(_name)
	_armour = _text("", 16, DIM, false)
	col.add_child(_armour)
	var passive := _block(col, Vector2.ZERO, Vector2(0, 0), TEAL)
	_passive = _text("", 18, PAPER)
	passive.add_child(_passive)
	_passive_desc = _wrapped(16, PAPER)
	col.add_child(_passive_desc)
	col.add_child(_text("LOOKS", 16, MUSTARD))
	_looks = _wrapped(16, PAPER)
	col.add_child(_looks)
	_line = _wrapped(16, DIM)
	col.add_child(_line)
	_cost = _text("", 18, PAPER, false)
	col.add_child(_cost)
	_buy = _block(col, Vector2.ZERO, Vector2(0, 52), MUSTARD)
	_buy_label = _text("", 26, Color(0.06, 0.05, 0.05))
	_buy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buy.add_child(_buy_label)
	_buy.gui_input.connect(_on_buy_input)

	# what the camera is looking at, over the stage
	_caption = _text("", 22, PAPER)
	_caption.position = Vector2(560, 34)
	_caption.custom_minimum_size = Vector2(480, 0)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_caption.add_theme_constant_override("outline_size", 6)
	screen.add_child(_caption)
	refresh()
	_at = _to


func _process(delta: float) -> void:
	_at = _at.lerp(_to, 1.0 - exp(-delta * SWING))
	_place_camera()
	if _level_flash > 0.0:
		_level_flash -= delta
		_level.modulate = Color(1, 1, 1).lerp(Color(1.4, 1.2, 0.5), clampf(_level_flash, 0.0, 1.0))


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_W, KEY_UP:
			select(selected - 1)
		KEY_S, KEY_DOWN:
			select(selected + 1)
		KEY_A, KEY_LEFT, KEY_Q:
			if not event.echo:
				switch_kit(-1)
		KEY_D, KEY_RIGHT, KEY_E, KEY_TAB:
			if not event.echo:
				switch_kit(1)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				confirm()
		_:
			return
	get_viewport().set_input_as_handled()


# --- actions ----------------------------------------------------------------------

## Picks the overview (0) or a tier (1-5) of the kit on show.
func select(index: int) -> void:
	selected = posmod(index, Armory.SUIT_TIERS.size() + 1)
	SFX.play(self, "ui_hover", -10.0)
	refresh()


## Shows the next or previous kit.
func switch_kit(dir: int) -> void:
	var order: Array = Armory.SUIT_WEIGHT_ORDER
	set_kit(order[posmod(order.find(weight) + dir, order.size())])


## Shows a kit by weight name, and refits her suit to it if she has a tier.
func set_kit(w: String) -> void:
	if not Armory.SUIT_WEIGHTS.has(w):
		return
	weight = w
	armory.set_suit_weight(w)
	_drag_yaw = 0.0
	SFX.play(self, "ui_switch", -8.0)
	refresh()


## Buys the picked tier (the next one only). Returns whether it went through.
func confirm() -> bool:
	if selected == 0:
		return false
	var tier := selected
	var ok := false
	var before: int = armory.pilot_level()
	if armory.suit_tier == tier - 1:
		ok = armory.buy_suit_tier()
		if ok:
			armory.set_suit_weight(weight)   # her first tier comes in the kit on show
	SFX.play(self, CONFIRM_SOUND if ok else "ui_error", -4.0)
	var after: int = armory.pilot_level()
	if after > before:
		_level_flash = 1.6
		SFX.play(self, "ui_confirm", -2.0)
		unlocked.append_array(Armory.unlocks_between(before, after))
	refresh()
	return ok


## The tier she is shown in: the picked one, or for the overview the one she
## has (the first, if none yet, so the kit's look shows).
func preview_tier() -> int:
	return selected if selected > 0 else maxi(armory.suit_tier, 1)


## The camera's target for the pick: FOCUS's entry.
func focus() -> Dictionary:
	return FOCUS[weight][selected]


# --- drawing ----------------------------------------------------------------------

func refresh() -> void:
	_draw_tabs()
	_draw_cards()
	_draw_detail()
	_draw_level()
	_draw_stash()
	_update_preview()
	var f := focus()
	_to = Vector3(f["y"], f["dist"], f["yaw"])
	_caption.text = "◢  %s" % f["part"]


func _draw_tabs() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	for w in Armory.SUIT_WEIGHT_ORDER:
		var on: bool = w == weight
		var kit: Dictionary = Armory.SUIT_WEIGHTS[w]
		var tab := _block(null, Vector2.ZERO, Vector2(128, 70), KIT_COLOR[w] if on else BLACK)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -4)
		tab.add_child(col)
		col.add_child(_text(String(kit["name"]).to_upper(), 30, Color(0.06, 0.05, 0.05) if on else PAPER))
		col.add_child(_text(String(kit["kit"]).to_upper(), 14, Color(0.06, 0.05, 0.05) if on else KIT_COLOR[w]))
		tab.gui_input.connect(_on_tab_input.bind(w))
		_tabs.add_child(tab)


func _draw_cards() -> void:
	for c in _cards.get_children():
		c.queue_free()
	var kit: Dictionary = Armory.SUIT_WEIGHTS[weight]
	for i in Armory.SUIT_TIERS.size() + 1:
		var on := i == selected
		var card := _block(null, Vector2.ZERO, Vector2(420, 0), MUSTARD if on else BLACK)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var ink := Color(0.06, 0.05, 0.05) if on else PAPER
		var num := _text("—" if i == 0 else "%d" % i, 40, ink if on else KIT_COLOR[weight])
		num.custom_minimum_size = Vector2(34, 0)
		row.add_child(num)
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", -4)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(names)
		names.add_child(_text("THE KIT" if i == 0 else "SESSION #%d" % i, 13, ink if on else DIM))
		names.add_child(_text(String(kit["kit"]).to_upper() if i == 0 else String(Armory.SUIT_TIERS[i - 1]["name"]).to_upper(), 24, ink))
		var state := _text(_state_text(i), 15, ink if on else _state_color(i), false)
		state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(state)
		card.gui_input.connect(_on_card_input.bind(i))
		_cards.add_child(card)


func _state_text(i: int) -> String:
	if i == 0:
		return "WEARING" if armory.suit_tier > 0 and armory.suit_weight == weight else ("FREE SWAP" if armory.suit_tier > 0 else "NEEDS SESSION 1")
	if armory.suit_tier >= i:
		return "WEARING" if armory.suit_tier == i else "OWNED"
	if armory.suit_tier == i - 1:
		return Armory.cost_text(Armory.SUIT_TIERS[i - 1]["cost"])
	return "LOCKED"


func _state_color(i: int) -> Color:
	if i > 0 and armory.suit_tier == i - 1:
		return GOOD if armory.can_afford(Armory.SUIT_TIERS[i - 1]["cost"]) else BAD
	return MUSTARD if _state_text(i) == "WEARING" else DIM


func _draw_detail() -> void:
	var kit: Dictionary = Armory.SUIT_WEIGHTS[weight]
	if selected == 0:
		_session.text = "THE %s KIT" % String(kit["name"]).to_upper()
		_name.text = String(kit["kit"]).to_upper()
		_armour.text = "%d armour now" % roundi(armory.suit_profile(-1, weight)["max_armor"]) if armory.suit_tier > 0 else "Buy session 1 to wear it."
		_passive.text = "%s  ×%.1f ARMOUR" % [String(kit["name"]).to_upper(), kit["armor_mult"]]
		_passive_desc.text = kit["bonus"]
		_looks.text = kit["look"]
		_line.text = "\"%s\"" % kit["line"]
		_cost.text = "Free to switch, as often as she likes."
		_buy.visible = false
		return
	var t: Dictionary = Armory.SUIT_TIERS[selected - 1]
	_session.text = "SESSION #%d" % selected
	_name.text = String(t["name"]).to_upper()
	_armour.text = "%d armour in the %s kit" % [roundi(t["armor"] * kit["armor_mult"]), String(kit["name"]).to_lower()]
	_passive.text = String(t["passive"]).to_upper()
	_passive_desc.text = t["passive_desc"]
	_looks.text = Armory.SUIT_KIT_LOOKS[weight][selected - 1]
	_line.text = "\"%s\"" % t["line"]
	var next := armory.suit_tier == selected - 1
	_buy.visible = next
	if armory.suit_tier >= selected:
		_cost.text = "Wearing it." if armory.suit_tier == selected else "Owned."
	elif next:
		_cost.text = Armory.cost_text(t["cost"])
		_cost.add_theme_color_override("font_color", GOOD if armory.can_afford(t["cost"]) else BAD)
		_buy_label.text = "BUY   ▸   SPACE"
	else:
		_cost.text = "Needs session #%d first." % (selected - 1)
	if not next:
		_cost.add_theme_color_override("font_color", PAPER)


func _draw_level() -> void:
	var text := "LEVEL %d" % armory.pilot_level()
	for id in unlocked:
		text += "   %s UNLOCKED AT THE RACK" % Armory.WEAPONS[id]["short"]
	_level.text = text


func _draw_stash() -> void:
	for c in _stash.get_children():
		c.queue_free()
	for m in Armory.MATERIALS:
		_stash.add_child(_text("%s %d" % [Armory.MATERIAL_NAMES[m].to_upper(), armory.amount(m)], 16, LootArt.COLORS[m], false))


# --- the stage ----------------------------------------------------------------------

func _build_stage() -> SubViewport:
	var sub := SubViewport.new()
	sub.own_world_3d = true
	sub.msaa_3d = Viewport.MSAA_4X
	var stage := Node3D.new()
	sub.add_child(stage)
	Art.environment(stage, Color(0.07, 0.06, 0.08), Color(0.3, 0.25, 0.22))
	for node in stage.get_children():
		if node is WorldEnvironment:
			node.environment.fog_enabled = false
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-42, 205, 0)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 1.3
	lamp.omni_range = 30.0
	lamp.position = Vector3(1.4, 2.6, 2.4)
	stage.add_child(lamp)
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.45, 0.75, 1.0)
	rim.light_energy = 0.9
	rim.omni_range = 12.0
	rim.position = Vector3(-1.6, 1.8, -1.8)
	stage.add_child(rim)
	_turntable = Node3D.new()
	stage.add_child(_turntable)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	stage.add_child(_camera)
	# a key light that rides with the camera, so whatever it closes in on is lit
	var key := OmniLight3D.new()
	key.light_color = Color(1.0, 0.92, 0.82)
	key.light_energy = 0.7
	key.omni_range = 6.0
	key.position = Vector3(0.4, 0.5, 0.0)
	_camera.add_child(key)
	_place_camera()
	return sub


func _place_camera() -> void:
	if _camera == null:
		return
	var dist := _at.y * _zoom
	_turntable.rotation.y = _at.z + _drag_yaw
	_camera.look_at_from_position(Vector3(0.0, _at.x + dist * 0.06, dist), Vector3(0.0, _at.x, 0.0))


## Dresses her for the pick: her wardrobe's suit (or her own, if she picked
## clothes), the kit on show, the tier picked. Rebuilt only when it changes.
func _update_preview() -> void:
	var pick: String = Wardrobe.choice("eco")
	var outfit := pick if pick.begins_with("suit") else "suit"
	var tier := preview_tier()
	var key := "%s/%s/%d" % [outfit, weight, tier]
	if key == _preview_key:
		return
	_preview_key = key
	if eco == null:
		eco = ECO.instantiate()
		eco.rotation.y = PI  # she faces -Z; turn her to the camera
		_turntable.add_child(eco)
	eco.wear(outfit)
	eco.suit_weight = weight
	eco.suit_tier = tier


# --- input ------------------------------------------------------------------------

func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_drag_yaw += event.relative.x * 0.01
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(_zoom - 0.08, 0.6)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(_zoom + 0.08, 1.6)


func _on_tab_input(event: InputEvent, w: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_kit(w)


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index == selected:
			confirm()
		else:
			select(index)


func _on_buy_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		confirm()


# --- widgets ----------------------------------------------------------------------

## The screen's type: a heavy condensed face (whichever the system has),
## slanted like the title cards it is after.
static func title_font() -> Font:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Impact", "Haettenschweiler", "Bebas Neue", "Oswald", "Arial Narrow",
			"Liberation Sans Narrow", "DejaVu Sans Condensed"])
	sys.font_weight = 800
	sys.font_stretch = 75
	var slanted := FontVariation.new()
	slanted.base_font = sys
	slanted.variation_transform = Transform2D(Vector2(1.0, 0.2), Vector2(0.0, 1.0), Vector2.ZERO)
	return slanted


## A slanted block of flat colour (added to `parent` at `at`, when given).
func _block(parent: Control, at: Vector2, size: Vector2, color: Color, slant := SLANT) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.skew = Vector2(slant, 0.0)
	box.content_margin_left = 16 + 24 * slant
	box.content_margin_right = 16 + 24 * slant
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", box)
	panel.position = at
	panel.custom_minimum_size = size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if parent != null:
		parent.add_child(panel)
	return panel


func _text(text: String, size: int, color: Color, display := true) -> Label:
	var l := Label.new()
	l.text = text
	if display and _font != null:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _wrapped(size: int, color: Color) -> Label:
	var l := _text("", size, color, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(390, 0)
	return l
