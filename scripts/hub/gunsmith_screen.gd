extends CanvasLayer
## Eco's gunsmith bench. Pick a gun on the left; it sits in the middle as a 3D
## model you spin by dragging (wheel zooms), with a marker on each part you can
## work on. Click a marker and the panel on the right shows that part's
## upgrades (armory.gd tracks), attachments and paint; click one to buy or fit
## it, and the model changes to match.
##   Mouse     click a gun, a part marker or an option; drag to spin; wheel zooms
##   Q/E       previous / next gun          Tab    next part
## The run manager opens it (pausing the hub) and closes it on F or Esc.

const Armory := preload("res://scripts/hub/armory.gd")
const Weapon := preload("res://scripts/weapon.gd")
const Art := preload("res://scripts/ps2/ps2_assets.gd")
const LootArt := preload("res://scripts/run/loot_art.gd")
const SFX := preload("res://scripts/sfx.gd")
const BenchScreen := preload("res://scripts/hub/bench_screen.gd")

const INK := BenchScreen.INK
const DIM := BenchScreen.DIM
const ACCENT := BenchScreen.ACCENT
const GOOD := BenchScreen.GOOD
const BAD := BenchScreen.BAD
const SIDE_W := 380.0

## The parts of each gun you can work on: where the marker sits (the first
## node of `at` the model has, or the grip), the upgrade tracks it holds, the
## attachment slot it takes, and whether it's where the paint goes.
const PARTS := {
	"smart_pistol": [
		{"id": "module", "name": "Smart module", "at": ["TrackerScreen"], "tracks": ["smart_rounds"],
			"desc": "Dad's smashed tracker. Every rebuild turns more of each mag into smart rounds that lock on."},
		{"id": "muzzle", "name": "Muzzle", "at": ["Muzzle"], "slot": "muzzle", "desc": "What sits on the end of the shroud."},
		{"id": "mag", "name": "Magazine", "at": ["MagBase"], "slot": "mag", "desc": "The mag and its base plate."},
		{"id": "grip", "name": "Grip", "at": [], "slot": "grip", "desc": "Where her glove closes."},
		{"id": "shell", "name": "Shell", "at": ["Frame"], "finish": true, "desc": "Paint. Free, and it doesn't change how it shoots."},
	],
	"rivet_cannon": [
		{"id": "barrel", "name": "Barrel", "at": ["Barrel"], "tracks": ["calibre"], "slot": "muzzle",
			"desc": "The rivet driver's guide tube: heavier rivets, and what goes on the end."},
		{"id": "cylinder", "name": "Cylinder", "at": ["Drum"], "tracks": ["action", "magazine"], "slot": "mag",
			"desc": "The feed drum: a smoother turn and more chambers."},
		{"id": "grip", "name": "Grip", "at": [], "slot": "grip", "desc": "Where her glove closes."},
		{"id": "frame", "name": "Frame", "at": ["Frame"], "finish": true, "desc": "Paint. Free, and it doesn't change how it shoots."},
	],
	"machine_pistol": [
		{"id": "barrel", "name": "Barrel", "at": ["Vents"], "tracks": ["calibre"], "slot": "muzzle",
			"desc": "The slotted snout: hotter rounds, and what goes on the end."},
		{"id": "action", "name": "Action", "at": ["Slide"], "tracks": ["action"], "desc": "The bolt and charging handle."},
		{"id": "mag", "name": "Magazine", "at": ["MagBase"], "tracks": ["magazine"], "slot": "mag", "desc": "The stick mag and its base."},
		{"id": "grip", "name": "Grip", "at": [], "slot": "grip", "desc": "Where her glove closes."},
		{"id": "shell", "name": "Frame", "at": ["Upper"], "finish": true, "desc": "Paint. Free, and it doesn't change how it shoots."},
	],
}

var armory: Armory
var kind := "gunsmith"
## The gun on the bench, and the part picked on it.
var weapon := ""
var part := ""
## Options for the picked part: {kind: "track"|"attachment"|"finish", id, label, value, cost, state, note}
var options: Array = []
## A locked attachment shown on the model: the next click on it buys it.
var armed := ""
## Guns unlocked by level ups while this screen was open (for the HUD after).
var unlocked := []

var _level: Label
var _level_flash := 0.0
var _stash: HBoxContainer
var _guns: VBoxContainer
var _part_title: Label
var _part_desc: Label
var _options: VBoxContainer
var _note: Label
var _stats: Label
var _spots: Control
var _spot_views := {}
var _pivot: Node3D
var _camera: Camera3D
var _model: Node3D
var _model_key := ""
var _model_id := ""
var _yaw := PI / 2.0 - 0.35
var _pitch := -0.12
var _distance := 1.0


func _init(p_armory: Armory) -> void:
	armory = p_armory
	weapon = armory.equipped
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var view := SubViewportContainer.new()
	view.stretch = true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.gui_input.connect(_on_view_input)
	screen.add_child(view)
	view.add_child(_build_stage())
	_spots = Control.new()
	_spots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(_spots)

	# Left: the bench, Eco's level and stash, and her guns.
	var left := _panel(screen, Vector2(24, 24), Vector2(SIDE_W, 852))
	left.add_child(_text("ECO'S GUNSMITH BENCH", 26, ACCENT))
	left.add_child(_text("Pick a gun, then click a part on it.", 15, DIM))
	_level = _text("", 16, ACCENT)
	_level.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_level)
	_stash = HBoxContainer.new()
	_stash.add_theme_constant_override("separation", 12)
	left.add_child(_stash)
	left.add_child(_text("GUNS", 18, INK))
	_guns = VBoxContainer.new()
	_guns.add_theme_constant_override("separation", 6)
	left.add_child(_guns)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	left.add_child(_text("Drag the gun to spin it, wheel to zoom.\nQ/E gun   Tab part   F or Esc done", 14, DIM))

	# Right: the picked part.
	var right := _panel(screen, Vector2(1600 - 24 - SIDE_W, 24), Vector2(SIDE_W, 852))
	_part_title = _text("", 24, ACCENT)
	right.add_child(_part_title)
	_part_desc = _text("", 15, DIM)
	_part_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_part_desc)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 4)
	right.add_child(_options)
	_note = _text("", 15, INK)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_note)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(fill)
	_stats = _text("", 15, INK)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_stats)
	part = _parts()[0]["id"]
	refresh()


func _process(delta: float) -> void:
	if _pivot != null:
		_pivot.rotation = Vector3(_pitch, _yaw, 0.0)
		_camera.position = Vector3(0, 0, _distance)
	_place_spots()
	if _level_flash > 0.0:
		_level_flash -= delta
		_level.modulate = Color(1, 1, 1).lerp(Color(1.4, 1.2, 0.5), clampf(_level_flash, 0.0, 1.0))


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_Q:
			switch_weapon(-1)
		KEY_E:
			switch_weapon(1)
		KEY_TAB:
			var ids: Array = _parts().map(func(p): return p["id"])
			select_part(ids[posmod(ids.find(part) + 1, ids.size())])
		_:
			return
	get_viewport().set_input_as_handled()


# --- actions ----------------------------------------------------------------------

## Puts a gun on the bench. Locked guns stay on the rack.
func select_weapon(id: String) -> bool:
	if not armory.owns_weapon(id):
		SFX.play(self, "ui_error", -4.0)
		return false
	if id != weapon:
		weapon = id
		armed = ""
		part = _parts()[0]["id"]
		SFX.play(self, "ui_switch", -8.0)
	refresh()
	return true


func switch_weapon(dir: int) -> void:
	var owned: Array = Armory.WEAPONS.keys().filter(func(id): return armory.owns_weapon(id))
	select_weapon(owned[posmod(owned.find(weapon) + dir, owned.size())])


func select_part(id: String) -> void:
	part = id
	armed = ""
	SFX.play(self, "ui_hover", -8.0)
	refresh()


## Clicks option `index` of the picked part: buys the next level of a track,
## fits an attachment (a locked one shows on the gun first, and the second
## click buys it), or paints a finish. Returns whether something changed.
func choose(index: int) -> bool:
	if index < 0 or index >= options.size():
		return false
	var o: Dictionary = options[index]
	var before: int = armory.pilot_level()
	var ok := false
	var sound := "workbench_tools"
	match o["kind"]:
		"track":
			ok = armory.buy_upgrade(weapon, o["id"])
		"attachment":
			var p := _part()
			if armory.owns_attachment(o["id"]) or armed == o["id"]:
				ok = armory.fit(weapon, p["slot"], o["id"])
				armed = ""
			else:
				armed = o["id"]
				SFX.play(self, "ui_switch", -8.0)
				refresh()
				return false
		"finish":
			armory.set_finish(weapon, o["id"])
			ok = true
			sound = "ui_click"
	SFX.play(self, sound if ok else "ui_error", -4.0)
	var after: int = armory.pilot_level()
	if after > before:
		_level_flash = 1.6
		SFX.play(self, "ui_confirm", -2.0)
		unlocked.append_array(Armory.unlocks_between(before, after))
	refresh()
	return ok


## Where a part's marker is on screen (for tests), or null when it has none.
func spot_position(id: String) -> Variant:
	return _spot_views[id].position if _spot_views.has(id) else null


# --- state ------------------------------------------------------------------------

func _parts() -> Array:
	var tracks := Armory.upgrade_tracks(weapon)
	var out := []
	for p in PARTS.get(weapon, PARTS["smart_pistol"]):
		var q: Dictionary = p.duplicate()
		q["tracks"] = p.get("tracks", []).filter(func(t): return t in tracks)
		out.append(q)
	return out


func _part() -> Dictionary:
	for p in _parts():
		if p["id"] == part:
			return p
	return _parts()[0]


func _options_for(p: Dictionary) -> Array:
	var out := []
	var now := armory.weapon_profile(weapon)
	for track in p.get("tracks", []):
		var level := armory.upgrade_level(weapon, track)
		var most := Armory.max_level(track)
		var info: Dictionary = Armory.UPGRADES[track]
		out.append({"kind": "track", "id": track, "label": info["name"],
			"value": "■".repeat(level) + "□".repeat(most - level),
			"cost": null if level >= most else armory.upgrade_cost(weapon, track),
			"state": "MAX" if level >= most else "",
			"note": "%s: %s." % [info["name"], info["desc"]]})
	if p.has("slot"):
		var slot: String = p["slot"]
		for a in Armory.ATTACHMENTS[slot]:
			var owned := armory.owns_attachment(a["id"])
			var fitted: bool = armory.fitted_attachment(weapon, slot) == a["id"]
			out.append({"kind": "attachment", "id": a["id"], "label": a["name"], "value": "",
				"cost": null if owned else a["cost"],
				"state": "FITTED" if fitted else ("OWNED" if owned else ""),
				"note": "%s\n%s" % [a["desc"], BenchScreen._stat_diff(now, _with_attachment(slot, a["id"]))]})
	if p.get("finish", false):
		for f in Armory.FINISHES:
			out.append({"kind": "finish", "id": f["id"], "label": f["name"], "value": "", "cost": null,
				"state": "PAINTED" if armory.finish_of(weapon) == f["id"] else "",
				"note": "Paint. Free, and it doesn't change how it shoots.", "swatch": f["shell"]})
	return out


## The profile with a locked attachment tried on, for the preview.
func _with_attachment(slot: String, id: String) -> Dictionary:
	var saved: Dictionary = armory.fitted.get(weapon, {}).duplicate()
	if not armory.fitted.has(weapon):
		armory.fitted[weapon] = {}
	armory.fitted[weapon][slot] = id
	var p := armory.weapon_profile(weapon)
	armory.fitted[weapon] = saved
	return p


# --- drawing ----------------------------------------------------------------------

func refresh() -> void:
	var p := _part()
	part = p["id"]
	options = _options_for(p)
	_draw_level()
	_draw_stash()
	_draw_guns()
	_part_title.text = p["name"].to_upper()
	_part_desc.text = p["desc"]
	for c in _options.get_children():
		c.queue_free()
	for i in options.size():
		_options.add_child(_option_view(i))
	_note.text = ""
	for o in options:
		if o["id"] == armed:
			_note.text = "%s\nClick it again to buy it for %s." % [o["note"], Armory.cost_text(o["cost"])]
	if _note.text == "" and not options.is_empty():
		_note.text = "\n".join(options.filter(func(o): return o["kind"] == "track").map(func(o): return o["note"]))
	var profile := armory.weapon_profile(weapon)
	if armed != "" and p.has("slot"):
		profile = _with_attachment(p["slot"], armed)
	_stats.text = "%s\n%s\nLook: tier %d of %d." % [Armory.WEAPONS[weapon]["name"], BenchScreen._stat_line(profile).replace("   ", "\n"), profile["tier"], Armory.MODEL_TIERS]
	_show_model(profile)


func _draw_level() -> void:
	var text := "LEVEL %d" % armory.pilot_level()
	for id in unlocked:
		text += "   %s UNLOCKED AT THE RACK" % Armory.WEAPONS[id]["short"]
	var next: String = armory.next_unlock()
	if next != "" and unlocked.is_empty():
		text += "   Next: %s at level %d" % [Armory.WEAPONS[next]["name"], Armory.unlock_level(next)]
	_level.text = text


func _draw_stash() -> void:
	for c in _stash.get_children():
		c.queue_free()
	for m in Armory.MATERIALS:
		var short: String = "CORES" if m == "lock_cores" else Armory.MATERIAL_NAMES[m].to_upper()
		_stash.add_child(_text("%s %d" % [short, armory.amount(m)], 15, LootArt.COLORS[m]))


func _draw_guns() -> void:
	for c in _guns.get_children():
		c.queue_free()
	for id in Armory.WEAPONS:
		var w: Dictionary = Armory.WEAPONS[id]
		var owned := armory.owns_weapon(id)
		var on: bool = id == weapon
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", BenchScreen._box(Color(1.0, 0.72, 0.35, 0.25) if on else Color(1, 1, 1, 0.05), 10, 10))
		var col := VBoxContainer.new()
		card.add_child(col)
		col.add_child(_text(w["name"], 20, ACCENT if on else (INK if owned else DIM)))
		var sub := ""
		if not owned:
			sub = "Unlocks at level %d" % Armory.unlock_level(id)
		else:
			sub = "Look tier %d of %d" % [armory.weapon_tier(id), Armory.MODEL_TIERS]
			if id == armory.equipped:
				sub += "   IN HAND"
		col.add_child(_text(sub, 14, DIM))
		card.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				select_weapon(id))
		_guns.add_child(card)


func _option_view(i: int) -> PanelContainer:
	var o: Dictionary = options[i]
	var on: bool = o["id"] == armed or o["state"] in ["FITTED", "PAINTED"]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", BenchScreen._box(Color(1.0, 0.72, 0.35, 0.2) if on else Color(1, 1, 1, 0.04), 8, 8))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	panel.add_child(line)
	if o.has("swatch"):
		var sw := ColorRect.new()
		sw.color = o["swatch"]
		sw.custom_minimum_size = Vector2(16, 16)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(sw)
	var label := _text(o["label"], 17, ACCENT if on else INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	line.add_child(label)
	if o["value"] != "":
		line.add_child(_text(o["value"], 12 if o["value"].length() > 5 else 15, INK))
	var right := ""
	var color := DIM
	if o["cost"] != null:
		right = Armory.cost_text(o["cost"])
		color = GOOD if armory.can_afford(o["cost"]) else BAD
	else:
		right = o["state"]
		color = ACCENT if right in ["FITTED", "PAINTED"] else DIM
	var r := _text(right, 13, color)
	r.custom_minimum_size = Vector2(96, 0)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(r)
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			choose(i))
	panel.mouse_entered.connect(func(): if armed == "": _note.text = o["note"])
	return panel


# --- the gun in the middle --------------------------------------------------------

func _build_stage() -> SubViewport:
	var sub := SubViewport.new()
	sub.own_world_3d = true
	sub.msaa_3d = Viewport.MSAA_4X
	var stage := Node3D.new()
	sub.add_child(stage)
	Art.environment(stage, Color(0.1, 0.09, 0.11), Color(0.3, 0.25, 0.22))
	for node in stage.get_children():
		if node is WorldEnvironment:
			node.environment.fog_enabled = false
		if node is DirectionalLight3D:
			node.rotation_degrees = Vector3(-42, 205, 0)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 1.2
	lamp.omni_range = 30.0
	lamp.position = Vector3(0.4, 0.8, 1.0)
	stage.add_child(lamp)
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.5, 0.75, 1.0)
	rim.light_energy = 0.8
	rim.position = Vector3(-0.6, 0.4, -0.8)
	stage.add_child(rim)
	_pivot = Node3D.new()
	stage.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_camera.position = Vector3(0, 0, _distance)
	stage.add_child(_camera)
	# A key light that rides with the camera, so whichever side she turns to
	# the bench lamp is on it.
	var key := OmniLight3D.new()
	key.light_color = Color(1.0, 0.9, 0.78)
	key.light_energy = 0.9
	key.omni_range = 6.0
	key.position = Vector3(0.35, 0.45, 0.1)
	_camera.add_child(key)
	return sub


## Rebuilds the gun when what it shows changes, centred on the pivot.
func _show_model(profile: Dictionary) -> void:
	var key := "%s/%s/%s/%d" % [profile["id"], profile["attachments"], profile["finish"]["id"], profile["tier"]]
	if key == _model_key:
		return
	_model_key = key
	if _model != null:
		_model.free()
	_model = Weapon.gun_model(profile)
	_pivot.add_child(_model)
	var box := AABB()
	var first := true
	for mi in _model.find_children("*", "VisualInstance3D", true, false):
		var b: AABB = (_model.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	_model.position = -box.get_center()
	# A new gun is framed to fill the middle of the screen; refits keep the zoom.
	if profile["id"] != _model_id:
		_model_id = profile["id"]
		_distance = clampf(box.get_longest_axis_size() * 2.8, 0.55, 1.8)
	_build_spots()


## The point on the model a part's marker sits on, in world space.
func _anchor(p: Dictionary) -> Vector3:
	for name in p["at"]:
		var n := _model.find_child(name, true, false) as Node3D
		if n == null:
			continue
		if n is VisualInstance3D:
			return n.global_transform * (n as VisualInstance3D).get_aabb().get_center()
		var meshes := n.find_children("*", "VisualInstance3D", true, false)
		if not meshes.is_empty():
			var mi: VisualInstance3D = meshes[0]
			return mi.global_transform * mi.get_aabb().get_center()
		return n.global_position
	var gun := _model.get_node_or_null("Gun") as Node3D
	return (gun.global_transform if gun != null else _model.global_transform) * Weapon.GRIP_XFORM.origin


func _build_spots() -> void:
	for c in _spots.get_children():
		c.free()
	_spot_views.clear()
	for p in _parts():
		var spot := Control.new()
		spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot := Button.new()
		dot.text = "+"
		dot.custom_minimum_size = Vector2(28, 28)
		dot.position = Vector2(-14, -14)
		dot.focus_mode = Control.FOCUS_NONE
		dot.add_theme_font_size_override("font_size", 16)
		dot.pressed.connect(select_part.bind(p["id"]))
		spot.add_child(dot)
		var tag := _text(p["name"].to_upper(), 14, INK)
		tag.position = Vector2(18, -11)
		tag.add_theme_constant_override("outline_size", 6)
		tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spot.add_child(tag)
		_spots.add_child(spot)
		_spot_views[p["id"]] = spot


## Keeps every marker over its part as the gun turns, the picked one gold.
func _place_spots() -> void:
	if _model == null or _spot_views.is_empty():
		return
	var scale := get_viewport().get_visible_rect().size / Vector2(_camera.get_viewport().size)
	for p in _parts():
		var spot: Control = _spot_views.get(p["id"])
		if spot == null:
			continue
		var at := _anchor(p)
		spot.visible = not _camera.is_position_behind(at)
		spot.position = _camera.unproject_position(at) * scale
		var on: bool = p["id"] == part
		var dot: Button = spot.get_child(0)
		dot.add_theme_stylebox_override("normal", BenchScreen._box(Color(1.0, 0.72, 0.35, 0.95) if on else Color(0.12, 0.1, 0.09, 0.85), 14, 0))
		dot.add_theme_stylebox_override("hover", BenchScreen._box(Color(1.0, 0.82, 0.5, 1.0), 14, 0))
		dot.add_theme_color_override("font_color", Color(0.1, 0.07, 0.05) if on else ACCENT)
		(spot.get_child(1) as Label).add_theme_color_override("font_color", ACCENT if on else INK)


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_yaw += event.relative.x * 0.01
		_pitch = clampf(_pitch + event.relative.y * 0.006, -0.9, 0.9)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(_distance - 0.08, 0.55)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(_distance + 0.08, 1.8)


# --- widgets ----------------------------------------------------------------------

func _panel(screen: Control, at: Vector2, size: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", BenchScreen._box(Color(0.13, 0.1, 0.08, 0.92), 16, 20))
	panel.position = at
	panel.size = size
	panel.custom_minimum_size = size
	screen.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	return col


func _text(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
