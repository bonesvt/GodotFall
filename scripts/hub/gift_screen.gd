extends CanvasLayer
## Lucky Lantern's shop screen (gift_shop.gd), over a turntable of the gift
## picked. Eco trades the materials in her stash (armory.gd) for gifts, which
## go in her bag (`bag`: count(id) and add(id)) until she gives them to someone.
## Once Eco knows someone she's romancing well enough (FRIENDS_AT affection),
## each gift says whether they'd love it or hate it.
## The run manager opens it like a workbench (pausing the hub) and closes it on F or Esc.
##   W/S or Up/Down    pick a gift      Space or Enter    buy it

const Armory := preload("res://scripts/hub/armory.gd")
const GiftShop := preload("res://scripts/hub/gift_shop.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const LootArt := preload("res://scripts/run/loot_art.gd")
const SFX := preload("res://scripts/sfx.gd")

const INK := Color(0.98, 0.94, 0.86)
const DIM := Color(0.98, 0.94, 0.86, 0.55)
const ACCENT := Color(1.0, 0.6, 0.75)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.45, 0.4)
const SPIN_SPEED := 0.6
## How big gifts stand on the turntable (they're modelled at real size).
const PREVIEW_SIZE := 0.3
## Affection before Eco knows someone's taste in gifts (romance.gd's "friend").
const FRIENDS_AT := 25
const SHOPKEEPER := [
	"Auntie Pim: \"For someone special? Don't tell me. I'll guess.\"",
	"Auntie Pim: \"Your father bought your mother candles here every winter. Good taste runs in families.\"",
	"Auntie Pim: \"Militia boys come in for perfume. For whom, I don't ask.\"",
]

var armory: Armory
var kind := "gifts"
## npc_talk.gd, which keeps Eco's gift bag: gifts() and add_gift(id).
var bag: Object
## Who Eco is romancing: [{who, name, likes: [...], dislikes: [...], affection}].
var partners: Array = []
var selected := 0
var rows: Array = []
## Bought while open (for the toast after): gift ids in order.
var bought: Array = []
## Benches report weapons unlocked by a level up; nothing here does that.
var unlocked: Array = []

var _stash: HBoxContainer
var _list: VBoxContainer
var _detail: Label
var _taste: Label
var _hint: Label
var _greeting: Label
var _turntable: Node3D
var _preview_key := ""
var _spin_hold := 0.0


func _init(p_armory: Armory, p_bag: Object, p_partners := []) -> void:
	armory = p_armory
	bag = p_bag
	partners = p_partners
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var back := ColorRect.new()
	back.color = Color(0.07, 0.04, 0.06, 0.6)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(back)

	var view := SubViewportContainer.new()
	view.stretch = true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.offset_left = 640
	view.gui_input.connect(_on_view_input)
	screen.add_child(view)
	view.add_child(_build_stage())

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.16, 0.08, 0.12, 0.95), 18, 24))
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(600, 0)
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(_text("LUCKY LANTERN GIFTS", 30, ACCENT))
	_greeting = _text(SHOPKEEPER[randi() % SHOPKEEPER.size()], 15, DIM)
	_greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_greeting.custom_minimum_size = Vector2(552, 0)
	col.add_child(_greeting)
	_stash = HBoxContainer.new()
	_stash.add_theme_constant_override("separation", 18)
	col.add_child(_stash)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	col.add_child(_list)
	_detail = _text("", 16, INK)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(552, 44)
	col.add_child(_detail)
	_taste = _text("", 16, ACCENT)
	_taste.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_taste.custom_minimum_size = Vector2(552, 0)
	col.add_child(_taste)
	_hint = _text("W/S pick   Space buy   G by someone in the hub gives a gift   F or Esc done", 14, DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(552, 0)
	col.add_child(_hint)
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
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				confirm()
		_:
			return
	get_viewport().set_input_as_handled()


func select(index: int) -> void:
	selected = posmod(index, rows.size())
	SFX.play(self, "ui_hover", -10.0)
	refresh()


## Buys the selected gift. Returns whether it went through.
func confirm() -> bool:
	var ok := buy(rows[selected])
	SFX.play(self, "cloth_2" if ok else "ui_error", -4.0)
	if ok:
		SFX.play(self, "ui_confirm", -8.0)
	refresh()
	return ok


## Spends the gift's price from the stash and puts it in the bag.
func buy(id: String) -> bool:
	if not armory._spend(GiftShop.cost(id)):
		return false
	armory.save()
	bag.add_gift(id)
	bought.append(id)
	return true


## What each partner Eco knows well enough thinks of `id`, one line each.
func taste_lines(id: String) -> Array:
	var out := []
	for p: Dictionary in partners:
		if int(p.get("affection", 0)) < FRIENDS_AT:
			out.append("%s: get to know them better to learn what they like." % p["name"])
		elif p["likes"].has(id):
			out.append("%s would love this." % p["name"])
		elif p["dislikes"].has(id):
			out.append("%s would hate this." % p["name"])
		else:
			out.append("%s: it's fine. Nothing special." % p["name"])
	return out


func refresh() -> void:
	rows = GiftShop.ids()
	selected = clampi(selected, 0, rows.size() - 1)
	for c in _stash.get_children():
		c.queue_free()
	for m in Armory.MATERIALS:
		_stash.add_child(_text("%s %d" % [Armory.MATERIAL_NAMES[m].to_upper(), armory.amount(m)], 18, LootArt.COLORS[m]))
	for c in _list.get_children():
		c.queue_free()
	for i in rows.size():
		_list.add_child(_row_view(i))
	var id: String = rows[selected]
	_detail.text = GiftShop.GIFTS[id]["blurb"]
	_taste.text = "\n".join(taste_lines(id))
	_update_preview(id)


func _row_view(i: int) -> PanelContainer:
	var id: String = rows[i]
	var on := i == selected
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(1.0, 0.6, 0.75, 0.2) if on else Color(0, 0, 0, 0), 10, 5))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	panel.add_child(line)
	var label := _text(GiftShop.gift_name(id), 17, ACCENT if on else INK)
	label.custom_minimum_size = Vector2(250, 0)
	line.add_child(label)
	var n: int = bag.gifts().count(id)
	var have := _text("x%d in bag" % n if n > 0 else "", 15, GOOD)
	have.custom_minimum_size = Vector2(90, 0)
	line.add_child(have)
	var cost := GiftShop.cost(id)
	var r := _text(Armory.cost_text(cost), 15, GOOD if armory.can_afford(cost) else BAD)
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
	Art.environment(stage, Color(0.12, 0.08, 0.1), Color(0.32, 0.24, 0.26))
	for node in stage.get_children():
		if node is WorldEnvironment:
			node.environment.fog_enabled = false
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-42, 205, 0)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.82)
	lamp.light_energy = 1.4
	lamp.omni_range = 10.0
	lamp.position = Vector3(0.4, 0.8, 0.9)
	stage.add_child(lamp)
	# A little round pink plinth under the gift.
	var plinth := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.24
	cyl.bottom_radius = 0.26
	cyl.height = 0.04
	plinth.mesh = cyl
	plinth.material_override = preload("res://scripts/hub/town_props.gd").paint(Color(0.9, 0.55, 0.65), 0.6)
	plinth.position.y = -0.02
	stage.add_child(plinth)
	_turntable = Node3D.new()
	_turntable.rotation.y = 0.5
	stage.add_child(_turntable)
	var camera := Camera3D.new()
	camera.fov = 30.0
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 0.42, 1.25), Vector3(0, 0.13, 0))
	return sub


## The selected gift, scaled so the biggest and smallest both fill the view.
func _update_preview(id: String) -> void:
	if id == _preview_key:
		return
	_preview_key = id
	for c in _turntable.get_children():
		c.free()
	var g := GiftShop.model(id)
	_turntable.add_child(g)
	var box := _bounds(g)
	var size := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var k := PREVIEW_SIZE / maxf(size, 0.01)
	g.scale = Vector3.ONE * k
	var c := box.get_center()
	g.position = Vector3(-c.x * k, -box.position.y * k, -c.z * k)


static func _bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func _box(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box
